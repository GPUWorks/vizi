#include "vz_helpers.h"
#include "vz_resources.h"
#include "vz_atoms.h"
#include "vz_view_thread.h"

#include "pugl/pugl.h"
#include "nanovg.h"

#include <erl_nif.h>
#include <string.h>

#ifdef LINUX
#include <X11/Xlib.h>
#elif WINDOWS
#include <windows.h>
#endif

/*
Helpers
*/

static bool vz_copy_string(ErlNifEnv *env, ERL_NIF_TERM in, char* out, size_t out_max_length) {
  ErlNifBinary bin;

  if(!enif_inspect_binary(env, in, &bin)) {
    return false;
  }

  memset(out, 0, out_max_length);
  strncpy(out, (char*)bin.data, MIN(bin.size, out_max_length));

  return true;
}

static bool vz_get_color(ErlNifEnv *env, ERL_NIF_TERM map, NVGcolor *color) {
  ERL_NIF_TERM r_term, g_term, b_term, a_term;
  double r, g, b, a;

  if(!(enif_get_map_value(env, map, ATOM_R, &r_term) &&
       enif_get_map_value(env, map, ATOM_G, &g_term) &&
       enif_get_map_value(env, map, ATOM_B, &b_term) &&
       enif_get_map_value(env, map, ATOM_A, &a_term)))
    return false;

  if(!(enif_get_double(env, r_term, &r) &&
       enif_get_double(env, g_term, &g) &&
       enif_get_double(env, b_term, &b) &&
       enif_get_double(env, a_term, &a)))
    return false;

  color->r = r;
  color->g = g;
  color->b = b;
  color->a = a;

  return true;
}

static ERL_NIF_TERM vz_make_color(ErlNifEnv *env, NVGcolor *color) {
  ERL_NIF_TERM map = enif_make_new_map(env);

  enif_make_map_put(env, map, ATOM__STRUCT__, ATOM_COLOR_STRUCT, &map);
  enif_make_map_put(env, map, ATOM_R, enif_make_double(env, color->r), &map);
  enif_make_map_put(env, map, ATOM_G, enif_make_double(env, color->g), &map);
  enif_make_map_put(env, map, ATOM_B, enif_make_double(env, color->b), &map);
  enif_make_map_put(env, map, ATOM_A, enif_make_double(env, color->a), &map);

  return map;
}

static bool vz_get_blend_factor(ERL_NIF_TERM atom, int *factor) {
  if(enif_is_identical(atom, ATOM_ZERO)) *factor = NVG_ZERO;
  else if(enif_is_identical(atom, ATOM_ONE)) *factor = NVG_ONE;
  else if(enif_is_identical(atom, ATOM_SRC_COLOR)) *factor = NVG_SRC_COLOR;
  else if(enif_is_identical(atom, ATOM_ONE_MINUS_SRC_COLOR)) *factor = NVG_ONE_MINUS_SRC_COLOR;
  else if(enif_is_identical(atom, ATOM_DST_COLOR)) *factor = NVG_DST_COLOR;
  else if(enif_is_identical(atom, ATOM_ONE_MINUS_DST_COLOR)) *factor = NVG_ONE_MINUS_DST_COLOR;
  else if(enif_is_identical(atom, ATOM_SRC_ALPHA)) *factor = NVG_SRC_ALPHA;
  else if(enif_is_identical(atom, ATOM_ONE_MINUS_SRC_ALPHA)) *factor = NVG_ONE_MINUS_SRC_ALPHA;
  else if(enif_is_identical(atom, ATOM_DST_ALPHA)) *factor = NVG_DST_ALPHA;
  else if(enif_is_identical(atom, ATOM_ONE_MINUS_DST_ALPHA)) *factor = NVG_ONE_MINUS_DST_ALPHA;
  else if(enif_is_identical(atom, ATOM_SRC_ALPHA_SATURATE)) *factor = NVG_SRC_ALPHA_SATURATE;
  else return false;

  return true;
}

static bool vz_get_winding(ERL_NIF_TERM atom, int *winding) {
  if(enif_is_identical(atom, ATOM_SOLID)) *winding = NVG_SOLID;
  else if(enif_is_identical(atom, ATOM_HOLE)) *winding = NVG_HOLE;
  else if(enif_is_identical(atom, ATOM_CCW)) *winding = NVG_CCW;
  else if(enif_is_identical(atom, ATOM_CW)) *winding = NVG_CW;
  else return false;

  return true;
}

static bool vz_get_line_cap(ERL_NIF_TERM atom, int *cap) {
  if(enif_is_identical(atom, ATOM_BUTT)) *cap = NVG_BUTT;
  else if(enif_is_identical(atom, ATOM_ROUND)) *cap = NVG_ROUND;
  else if(enif_is_identical(atom, ATOM_SQUARE)) *cap = NVG_SQUARE;
  else return false;

  return true;
}

static bool vz_get_line_join(ERL_NIF_TERM atom, int *cap) {
  if(enif_is_identical(atom, ATOM_ROUND)) *cap = NVG_ROUND;
  else if(enif_is_identical(atom, ATOM_BEVEL)) *cap = NVG_BEVEL;
  else if(enif_is_identical(atom, ATOM_MITER)) *cap = NVG_MITER;
  else return false;

  return true;
}

static ERL_NIF_TERM vz_make_matrix_list(ErlNifEnv *env, const float *matrix) {
  ERL_NIF_TERM e1 = enif_make_double(env, matrix[0]);
  ERL_NIF_TERM e2 = enif_make_double(env, matrix[1]);
  ERL_NIF_TERM e3 = enif_make_double(env, matrix[2]);
  ERL_NIF_TERM e4 = enif_make_double(env, matrix[3]);
  ERL_NIF_TERM e5 = enif_make_double(env, matrix[4]);
  ERL_NIF_TERM e6 = enif_make_double(env, matrix[5]);

  return enif_make_list6(env, e1, e2, e3, e4, e5, e6);
}

static bool vz_get_matrix_list(ErlNifEnv *env, ERL_NIF_TERM list, float *matrix) {
  ERL_NIF_TERM head, tail;
  unsigned length, ndx = 0;
  double value;
  int valuei;

  if(!enif_get_list_length(env, list, &length) || length != 6)
    return false;


  while(enif_get_list_cell(env, list, &head, &tail)) {
    list = tail;

    if(!enif_get_double(env, head, &value)) {
      if(enif_get_int(env, head, &valuei))
        value = (double)valuei;
      else return false;
    }

    matrix[ndx++] = (float)value;
  }

  return true;
}

static int vz_handle_create_view_opts(ErlNifEnv *env, ERL_NIF_TERM opts, VZview* vz_view ) {
  ERL_NIF_TERM head, tail;
  const ERL_NIF_TERM *tup_array;
  int tup_arity = 0;
  VZview *parent;

  while(enif_get_list_cell(env, opts, &head, &tail)) {
    opts = tail;

    if(enif_get_tuple(env, head, &tup_arity, &tup_array)) {
      if(tup_arity == 2) {

        if(enif_is_identical(tup_array[0], ATOM_PARENT) &&
           enif_get_resource(env, tup_array[1], vz_view_res, (void**)&parent)) {
        }

        if(enif_is_identical(tup_array[0], ATOM_WIDTH) &&
           !enif_get_int(env, tup_array[1], &vz_view->width))
          return 0;

        if(enif_is_identical(tup_array[0], ATOM_HEIGHT) &&
           !enif_get_int(env, tup_array[1], &vz_view->height))
          return 0;

        if(enif_is_identical(tup_array[0], ATOM_MIN_WIDTH) &&
           !enif_get_int(env, tup_array[1], &vz_view->min_width))
          return 0;

        if(enif_is_identical(tup_array[0], ATOM_MIN_HEIGHT) &&
           !enif_get_int(env, tup_array[1], &vz_view->min_height))
          return 0;

        if(enif_is_identical(tup_array[0], ATOM_RESIZABLE) &&
           enif_is_identical(tup_array[1], ATOM_TRUE))
          vz_view->resizable = true;

        if(enif_is_identical(tup_array[0], ATOM_REDRAW_MODE)) {
          if(enif_is_identical(tup_array[1], ATOM_RM_MANUAL))
            vz_view->redraw_mode = VZ_MANUAL;
          else if(enif_is_identical(tup_array[1], ATOM_RM_INTERVAL))
            vz_view->redraw_mode = VZ_INTERVAL;
          else return 0;
        }

        if(enif_is_identical(tup_array[0], ATOM_FRAME_RATE) &&
           !enif_get_int(env, tup_array[1], &vz_view->frame_rate))
          return 0;

        if(enif_is_identical(tup_array[0], ATOM_TITLE) &&
           !vz_copy_string(env, tup_array[1], vz_view->title, VZ_MAX_STRING_LENGTH))
          return 0;

        if(enif_is_identical(tup_array[0], ATOM_BACKGROUND_COLOR) &&
           !vz_get_color(env, tup_array[1], &vz_view->bg))
          return 0;

        if(enif_is_identical(tup_array[0], ATOM_PIXEL_RATIO) &&
           !enif_get_double(env, tup_array[1], &vz_view->pixel_ratio))
          return 0;

      } else return 0;
    }
    else return 0;
  }

  vz_view->init_width = vz_view->width;
  vz_view->init_height = vz_view->height;

  return 1;
}

static bool vz_handle_image_flags(ErlNifEnv *env, ERL_NIF_TERM list, int *flags) {
  ERL_NIF_TERM head, tail;
  *flags = 0;

  while(enif_get_list_cell(env, list, &head, &tail)) {
    list = tail;

    if(enif_is_identical(head, ATOM_GENERATE_MIPMAPS))
      *flags = *flags | NVG_IMAGE_GENERATE_MIPMAPS;
    else if(enif_is_identical(head, ATOM_REPEAT_X))
      *flags = *flags | NVG_IMAGE_REPEATX;
    else if(enif_is_identical(head, ATOM_REPEAT_Y))
      *flags = *flags | NVG_IMAGE_REPEATY;
    else if(enif_is_identical(head, ATOM_FLIP_Y))
      *flags = *flags | NVG_IMAGE_FLIPY;
    else if(enif_is_identical(head, ATOM_PREMULTIPLIED))
      *flags = *flags | NVG_IMAGE_PREMULTIPLIED;
    else if(enif_is_identical(head, ATOM_NEAREST))
      *flags = *flags | NVG_IMAGE_NEAREST;
    else return false;
  }

  return true;
}

static bool vz_handle_text_align_flags(ErlNifEnv *env, ERL_NIF_TERM list, int *flags) {
  ERL_NIF_TERM head, tail;
  *flags = 0;

  while(enif_get_list_cell(env, list, &head, &tail)) {
    list = tail;

    if(enif_is_identical(head, ATOM_LEFT))
      *flags = *flags | NVG_ALIGN_LEFT;
    else if(enif_is_identical(head, ATOM_CENTER))
      *flags = *flags | NVG_ALIGN_CENTER;
    else if(enif_is_identical(head, ATOM_RIGHT))
      *flags = *flags | NVG_ALIGN_RIGHT;
    else if(enif_is_identical(head, ATOM_TOP))
      *flags = *flags | NVG_ALIGN_TOP;
    else if(enif_is_identical(head, ATOM_MIDDLE))
      *flags = *flags | NVG_ALIGN_MIDDLE;
    else if(enif_is_identical(head, ATOM_BOTTOM))
      *flags = *flags | NVG_ALIGN_BOTTOM;
    else if(enif_is_identical(head, ATOM_BASELINE))
      *flags = *flags | NVG_ALIGN_BASELINE;
    else return false;
  }

  return true;
}


/*
View NIF functions
*/

static ERL_NIF_TERM vz_create_view(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  VZview* vz_view;

  if(!(argc == 1 && enif_is_list(env, argv[0])))
    return BADARG;

  if((vz_view = vz_alloc_view(env)) == NULL)
    return BADARG;

  if(!vz_handle_create_view_opts(env, argv[0], vz_view))
    goto err;

  if(enif_thread_create("vz_view_thread", &vz_view->view_tid, vz_view_thread, vz_view, NULL) != 0)
    goto err;

  return OK(vz_make_resource(env, vz_view));

  err:
    enif_release_resource(vz_view);
    return BADARG;
}

static ERL_NIF_TERM vz_ready(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  VZview *vz_view;

  if(!(argc == 1 &&
       enif_get_resource(env, argv[0], vz_view_res, (void**)&vz_view))) {
    return BADARG;
  }

  enif_mutex_lock(vz_view->lock);
  vz_view->busy = false;
  enif_cond_signal(vz_view->execute_cv);
  enif_mutex_unlock(vz_view->lock);

  return ATOM_OK;
}

static ERL_NIF_TERM vz_redraw(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  VZview *vz_view;

  if(!(argc == 1 &&
       enif_get_resource(env, argv[0], vz_view_res, (void**)&vz_view))) {
    return BADARG;
  }

  enif_mutex_lock(vz_view->lock);
  vz_view->redraw = true;
  enif_mutex_unlock(vz_view->lock);

  return ATOM_OK;
}


VZ_ASYNC_DECL(
  vz_setup_element,
  {
    float *xform;
    double x;
    double y;
    double width;
    double height;
    double scale_x;
    double scale_y;
    double skew_x;
    double skew_y;
    double rotate;
    double alpha;
  },
  {
    nvgTranslate(ctx, args->x, args->y);
    nvgScale(ctx, args->scale_x, args->scale_y);
    nvgTranslate(ctx, args->width / 2.f, args->height / 2.f);
    nvgRotate(ctx, args->rotate);
    nvgTranslate(ctx, -args->width / 2.f, -args->height / 2.f);
    nvgSkewX(ctx, args->skew_x);
    nvgSkewY(ctx, args->skew_y);
    nvgCurrentTransform(ctx, args->xform);
    nvgGlobalAlpha(ctx, args->alpha);
    nvgScissor(ctx, 0.f, 0.f, args->width, args->height);
  },
  {
    if(!(argc == 2 &&
        enif_is_map(env, argv[1]))) {
      return BADARG;
    }

    ERL_NIF_TERM map = argv[1];
    ERL_NIF_TERM value;

    enif_get_map_value(env, map, ATOM_X, &value);
    VZ_GET_NUMBER(env, value, args->x);

    enif_get_map_value(env, map, ATOM_Y, &value);
    VZ_GET_NUMBER(env, value, args->y);

    enif_get_map_value(env, map, ATOM_WIDTH, &value);
    VZ_GET_NUMBER(env, value, args->width);

    enif_get_map_value(env, map, ATOM_HEIGHT, &value);
    VZ_GET_NUMBER(env, value, args->height);

    enif_get_map_value(env, map, ATOM_SCALE_X, &value);
    VZ_GET_NUMBER(env, value, args->scale_x);

    enif_get_map_value(env, map, ATOM_SCALE_Y, &value);
    VZ_GET_NUMBER(env, value, args->scale_y);

    enif_get_map_value(env, map, ATOM_SKEW_X, &value);
    VZ_GET_NUMBER(env, value, args->skew_x);

    enif_get_map_value(env, map, ATOM_SKEW_Y, &value);
    VZ_GET_NUMBER(env, value, args->skew_y);

    enif_get_map_value(env, map, ATOM_ROTATE, &value);
    VZ_GET_NUMBER(env, value, args->rotate);

    enif_get_map_value(env, map, ATOM_ALPHA, &value);
    VZ_GET_NUMBER(env, value, args->alpha);

    enif_get_map_value(env, map, ATOM_XFORM, &value);
    enif_get_resource(env, value, vz_matrix_res, (void**)&args->xform);
  }
);


/*
Drawing NIF functions
*/



VZ_ASYNC_DECL(
  vz_global_composite_operation,
  {
    int comp_op;
  },
  {
    nvgGlobalCompositeOperation(ctx, args->comp_op);
  },
  {
    if(argc != 2) goto err;

    ERL_NIF_TERM atom_op = argv[1];
    if(enif_is_identical(atom_op, ATOM_SOURCE_OVER)) args->comp_op = NVG_SOURCE_OVER;
    else if(enif_is_identical(atom_op, ATOM_SOURCE_IN)) args->comp_op = NVG_SOURCE_IN;
    else if(enif_is_identical(atom_op, ATOM_SOURCE_OUT)) args->comp_op = NVG_SOURCE_OUT;
    else if(enif_is_identical(atom_op, ATOM_ATOP)) args->comp_op = NVG_ATOP;
    else if(enif_is_identical(atom_op, ATOM_DESTINATION_OVER)) args->comp_op = NVG_DESTINATION_OVER;
    else if(enif_is_identical(atom_op, ATOM_DESTINATION_IN)) args->comp_op = NVG_DESTINATION_IN;
    else if(enif_is_identical(atom_op, ATOM_DESTINATION_OUT)) args->comp_op = NVG_DESTINATION_OUT;
    else if(enif_is_identical(atom_op, ATOM_DESTINATION_ATOP)) args->comp_op = NVG_DESTINATION_ATOP;
    else if(enif_is_identical(atom_op, ATOM_LIGHTER)) args->comp_op = NVG_LIGHTER;
    else if(enif_is_identical(atom_op, ATOM_COPY)) args->comp_op = NVG_COPY;
    else if(enif_is_identical(atom_op, ATOM_XOR)) args->comp_op = NVG_XOR;
    else goto err;
  }
);


VZ_ASYNC_DECL(
  vz_global_composite_blend_func,
  {
    int sfactor;
    int dfactor;
  },
  {
    nvgGlobalCompositeBlendFunc(ctx, args->sfactor, args->dfactor);
  },
  {
    if(!(argc == 3 &&
        vz_get_blend_factor(argv[1], &args->sfactor) &&
        vz_get_blend_factor(argv[2], &args->dfactor))) {
      goto err;
    }
  }
);

VZ_ASYNC_DECL(
  vz_global_composite_blend_func_separate,
  {
    int src_rgb;
    int dst_rgb;
    int src_alpha;
    int dst_alpha;
  },
  {
    nvgGlobalCompositeBlendFuncSeparate(ctx, args->src_rgb, args->dst_rgb, args->src_alpha, args->dst_alpha);
  },
  {
    if(!(argc == 5 &&
        vz_get_blend_factor(argv[1], &args->src_rgb) &&
        vz_get_blend_factor(argv[2], &args->dst_rgb) &&
        vz_get_blend_factor(argv[3], &args->src_alpha) &&
        vz_get_blend_factor(argv[4], &args->dst_alpha))) {
      goto err;
    }
  }
);


static ERL_NIF_TERM vz_lerp_rgba(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  double u;
  NVGcolor c1, c2, color;

  if(!(argc == 3 &&
       vz_get_color(env, argv[0], &c1) &&
       vz_get_color(env, argv[1], &c2))) {
    return BADARG;
  }

  VZ_GET_NUMBER_255(env, argv[2], u);

  color = nvgLerpRGBA(c1, c2, u);

  return vz_make_color(env, &color);

  err:
  return BADARG;
}


static ERL_NIF_TERM vz_hsla(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  double h, s, l, a;
  NVGcolor color;

  if(argc != 4) goto err;

  VZ_GET_NUMBER_255(env, argv[0], h);
  VZ_GET_NUMBER_255(env, argv[1], s);
  VZ_GET_NUMBER_255(env, argv[2], l);
  VZ_GET_NUMBER_255(env, argv[3], a);

  color = nvgHSLA(h, s, l, a);

  return vz_make_color(env, &color);

  err:
  return BADARG;
}

VZ_ASYNC_DECL(
  vz_save,
  {
    __EMPTY_STRUCT
  },
  {
    __UNUSED(args);
    nvgSave(ctx);
  },
  {
    // no caller block
  }
);

VZ_ASYNC_DECL(
  vz_restore,
  {
    __EMPTY_STRUCT
  },
  {
    __UNUSED(args);
    nvgRestore(ctx);
  },
  {
    // no caller block
  }
);

VZ_ASYNC_DECL(
  vz_reset,
  {
    __EMPTY_STRUCT
  },
  {
    __UNUSED(args);
    nvgReset(ctx);
  },
  {
    // no caller block
  }
);

VZ_ASYNC_DECL(
  vz_shape_anti_alias,
  {
    bool enable;
  },
  {
    nvgShapeAntiAlias(ctx, args->enable);
  },
  {
    if(argc != 2) goto err;

    ERL_NIF_TERM atom_op = argv[1];
    if(enif_is_identical(atom_op, ATOM_TRUE)) args->enable = true;
    else if(enif_is_identical(atom_op, ATOM_FALSE)) args->enable = false;
    else goto err;
  }
);

VZ_ASYNC_DECL(
  vz_stroke_color,
  {
    NVGcolor color;
  },
  {
    nvgStrokeColor(ctx, args->color);
  },
  {
    if(!(argc == 2 &&
        vz_get_color(env, argv[1], &args->color))) {
      goto err;
    }
  }
);

VZ_ASYNC_DECL(
  vz_stroke_paint,
  {
    NVGpaint paint;
  },
  {
    nvgStrokePaint(ctx, args->paint);
  },
  {
    NVGpaint *paint;

    if(!(argc == 2 &&
        enif_get_resource(env, argv[1], vz_paint_res, (void**)&paint))) {
      goto err;
    }
    args->paint = *paint;
  }
);

VZ_ASYNC_DECL(
  vz_fill_color,
  {
    NVGcolor color;
  },
  {
    nvgFillColor(ctx, args->color);
  },
  {
    if(!(argc == 2 &&
        vz_get_color(env, argv[1], &args->color))) {
      goto err;
    }
  }
);

VZ_ASYNC_DECL(
  vz_fill_paint,
  {
    NVGpaint paint;
  },
  {
    nvgFillPaint(ctx, args->paint);
  },
  {
    NVGpaint *paint;

    if(!(argc == 2 &&
        enif_get_resource(env, argv[1], vz_paint_res, (void**)&paint))) {
      goto err;
    }
    args->paint = *paint;
  }
);

VZ_ASYNC_DECL(
  vz_miter_limit,
  {
    double limit;
  },
  {
    nvgMiterLimit(ctx, args->limit);
  },
  {
    if(argc != 2) goto err;

    VZ_GET_NUMBER(env, argv[1], args->limit);
  }
);

VZ_ASYNC_DECL(
  vz_stroke_width,
  {
    double width;
  },
  {
    nvgStrokeWidth(ctx, args->width);
  },
  {
    if(argc != 2) goto err;

    VZ_GET_NUMBER(env, argv[1], args->width);
  }
);

VZ_ASYNC_DECL(
  vz_line_cap,
  {
    int cap;
  },
  {
    nvgLineCap(ctx, args->cap);
  },
  {
    if(!(argc == 2 &&
        vz_get_line_cap(argv[1], &args->cap))) {
      goto err;
    }
  }
);

VZ_ASYNC_DECL(
  vz_line_join,
  {
    int join;
  },
  {
    nvgLineJoin(ctx, args->join);
  },
  {
    if(!(argc == 2 &&
        vz_get_line_join(argv[1], &args->join))) {
      goto err;
    }
  }
);

VZ_ASYNC_DECL(
  vz_global_alpha,
  {
    double alpha;
  },
  {
    nvgGlobalAlpha(ctx, args->alpha);
  },
  {

    if(argc != 2) goto err;

    VZ_GET_NUMBER_255(env, argv[1], args->alpha);
  }
);

VZ_ASYNC_DECL(
  vz_reset_transform,
  {
    __EMPTY_STRUCT
  },
  {
    __UNUSED(args);
    nvgResetTransform(ctx);
    nvgTransform(ctx, vz_view->xform[0], vz_view->xform[1], vz_view->xform[2], vz_view->xform[3], vz_view->xform[4], vz_view->xform[5]);
  },
  {
    // no caller block
  }
);

VZ_ASYNC_DECL(
  vz_transform,
  {
    float matrix[6];
  },
  {
    nvgTransform(ctx, args->matrix[0], args->matrix[1], args->matrix[2], args->matrix[3], args->matrix[4], args->matrix[5]);
  },
  {
    float *matrix;

    if(!(argc == 2 &&
         enif_get_resource(env, argv[1], vz_matrix_res, (void**)&matrix))) {
      goto err;
    }
    memcpy(args->matrix, matrix, sizeof(float) * 6);
  }
);

VZ_ASYNC_DECL(
  vz_translate,
  {
    double x;
    double y;
  },
  {
    nvgTranslate(ctx, args->x, args->y);
  },
  {
    if(argc != 3) goto err;

    VZ_GET_NUMBER(env, argv[1], args->x);
    VZ_GET_NUMBER(env, argv[2], args->y);
  }
);

VZ_ASYNC_DECL(
  vz_rotate,
  {
    double angle;
  },
  {
    nvgRotate(ctx, args->angle);
  },
  {
    if(argc != 2) goto err;

    VZ_GET_NUMBER(env, argv[1], args->angle);
  }
);

VZ_ASYNC_DECL(
  vz_skew_x,
  {
    double angle;
  },
  {
    nvgSkewX(ctx, args->angle);
  },
  {
    if(argc != 2) goto err;

    VZ_GET_NUMBER(env, argv[1], args->angle);
  }
);

VZ_ASYNC_DECL(
  vz_skew_y,
  {
    double angle;
  },
  {
    nvgSkewY(ctx, args->angle);
  },
  {
    if(argc != 2) goto err;

    VZ_GET_NUMBER(env, argv[1], args->angle);
  }
);

VZ_ASYNC_DECL(
  vz_scale,
  {
    double x;
    double y;
  },
  {
    nvgScale(ctx, args->x, args->y);
  },
  {
    if(argc != 3) goto err;

    VZ_GET_NUMBER(env, argv[1], args->x);
    VZ_GET_NUMBER(env, argv[2], args->y);
  }
);

VZ_ASYNC_DECL(
  vz_current_transform,
  {
    __EMPTY_STRUCT
  },
  {
    __UNUSED(args);
    float *matrix;
    matrix = vz_alloc_matrix();
    nvgCurrentTransform(ctx, matrix);
    VZ_HANDLER_SEND(vz_make_resource(vz_view->msg_env, matrix));
  },
  {
    execute = true;
  }
);

VZ_ASYNC_DECL(
  vz_transform_identity,
  {
    __EMPTY_STRUCT
  },
  {
    __UNUSED(ctx);
    __UNUSED(args);
    float *matrix;
    matrix = vz_alloc_matrix_copy(vz_view->xform);
    VZ_HANDLER_SEND(vz_make_resource(vz_view->msg_env, matrix));
  },
  {
    execute = true;
  }
);

static ERL_NIF_TERM vz_transform_translate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  float *matrix;
  double tx, ty;

  if(argc != 2) goto err;

  VZ_GET_NUMBER(env, argv[0], tx);
  VZ_GET_NUMBER(env, argv[1], ty);

  matrix = vz_alloc_matrix();
  nvgTransformTranslate(matrix, tx, ty);

  return vz_make_resource(env, matrix);

  err:
  return BADARG;
}

static ERL_NIF_TERM vz_transform_scale(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  float *matrix;
  double sx, sy;

  if(argc != 2) goto err;

  VZ_GET_NUMBER(env, argv[0], sx);
  VZ_GET_NUMBER(env, argv[1], sy);

  matrix = vz_alloc_matrix();
  nvgTransformScale(matrix, sx, sy);

  return vz_make_resource(env, matrix);

  err:
  return BADARG;
}

static ERL_NIF_TERM vz_transform_rotate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  float *matrix;
  double a;

  if(argc != 1) goto err;

  VZ_GET_NUMBER(env, argv[0], a);

  matrix = vz_alloc_matrix();
  nvgTransformRotate(matrix, a);

  return vz_make_resource(env, matrix);

  err:
  return BADARG;
}

static ERL_NIF_TERM vz_transform_skew_x(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  float *matrix;
  double a;

  if(argc != 1) goto err;

  VZ_GET_NUMBER(env, argv[0], a);

  matrix = vz_alloc_matrix();
  nvgTransformSkewX(matrix, a);

  return vz_make_resource(env, matrix);

  err:
  return BADARG;
}

static ERL_NIF_TERM vz_transform_skew_y(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  float *matrix;
  double a;

  if(argc != 1) goto err;

  VZ_GET_NUMBER(env, argv[0], a);

  matrix = vz_alloc_matrix();
  nvgTransformSkewY(matrix, a);

  return vz_make_resource(env, matrix);

  err:
  return BADARG;
}

static ERL_NIF_TERM vz_transform_multiply(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  float *src, *dst, *dst_cpy;

  if(!(argc == 2 &&
       enif_get_resource(env, argv[0], vz_matrix_res, (void**)&dst) &&
       enif_get_resource(env, argv[1], vz_matrix_res, (void**)&src))) {
    return BADARG;
  }

  dst_cpy = vz_alloc_matrix_copy(dst);
  nvgTransformMultiply(dst_cpy, src);

  return vz_make_resource(env, dst_cpy);
}

static ERL_NIF_TERM vz_transform_premultiply(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  float *src, *dst, *dst_cpy;

  if(!(argc == 2 &&
       enif_get_resource(env, argv[0], vz_matrix_res, (void**)&dst) &&
       enif_get_resource(env, argv[1], vz_matrix_res, (void**)&src))) {
    return BADARG;
  }

  dst_cpy = vz_alloc_matrix_copy(dst);
  nvgTransformPremultiply(dst_cpy, src);

  return vz_make_resource(env, dst_cpy);
}

static ERL_NIF_TERM vz_transform_inverse(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  float *src, *dst;

  if(!(argc == 1 &&
       enif_get_resource(env, argv[0], vz_matrix_res, (void**)&src))) {
    return BADARG;
  }

  dst = vz_alloc_matrix();
  nvgTransformInverse(dst, src);

  return vz_make_resource(env, dst);
}

static ERL_NIF_TERM vz_transform_point(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  float *matrix, dstx, dsty;
  double srcx, srcy;

  if(!(argc == 3 &&
       enif_get_resource(env, argv[0], vz_matrix_res, (void**)&matrix))) {
    return BADARG;
  }

  VZ_GET_NUMBER(env, argv[1], srcx);
  VZ_GET_NUMBER(env, argv[2], srcy);

  nvgTransformPoint(&dstx, &dsty, matrix, srcx, srcy);

  return enif_make_tuple2(env, enif_make_double(env, dstx), enif_make_double(env, dsty));

  err:
  return BADARG;
}

static ERL_NIF_TERM vz_matrix_to_list(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  float *matrix;

  if(!(argc == 1 &&
       enif_get_resource(env, argv[0], vz_matrix_res, (void**)&matrix))) {
    return BADARG;
  }

  return vz_make_matrix_list(env, matrix);
}

static ERL_NIF_TERM vz_list_to_matrix(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  float *matrix;

  matrix = vz_alloc_matrix();

  if(!(argc == 1 &&
       vz_get_matrix_list(env, argv[0], matrix))) {
    enif_release_resource(matrix);
    return BADARG;
  }

  return vz_make_resource(env, matrix);
}

static ERL_NIF_TERM vz_deg_to_rad(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  double deg;

  if(argc != 1) goto err;

  VZ_GET_NUMBER(env, argv[0], deg);

  return enif_make_double(env, nvgDegToRad(deg));

  err:
  return BADARG;
}

static ERL_NIF_TERM vz_rad_to_deg(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  double rad;

  if(argc != 1) goto err;

  VZ_GET_NUMBER(env, argv[0], rad);

  return enif_make_double(env, nvgRadToDeg(rad));

  err:
  return BADARG;
}

VZ_ASYNC_DECL(
  vz_create_image,
  {
    char file_path[VZ_MAX_STRING_LENGTH];
    int flags;
  },
  {
    int handle;
    VZimage *image;

    handle = nvgCreateImage(ctx, args->file_path, args->flags);
    if(handle == 0) VZ_HANDLER_SEND_BADARG;
    int_array_push(vz_view->res_array, handle);
    image = vz_alloc_image(vz_view, handle);
    VZ_HANDLER_SEND(vz_make_resource(vz_view->msg_env, image));
  },
  {
    if(!(argc == 3 &&
        vz_copy_string(env, argv[1], args->file_path, VZ_MAX_STRING_LENGTH) &&
        vz_handle_image_flags(env, argv[2], &args->flags))) {
      goto err;
    }
    execute = true;
  }
);

VZ_ASYNC_DECL(
  vz_create_image_mem,
  {
    ErlNifBinary bin;
    int flags;
  },
  {
    int handle;
    VZimage *image;

    handle = nvgCreateImageMem(ctx, args->flags, args->bin.data, args->bin.size);
    if(handle == 0) VZ_HANDLER_SEND_BADARG;
    int_array_push(vz_view->res_array, handle);
    image = vz_alloc_image(vz_view, handle);
    VZ_HANDLER_SEND(vz_make_resource(vz_view->msg_env, image));
  },
  {
    if(!(argc == 3 &&
        enif_inspect_binary(env, argv[1], &args->bin) &&
        vz_handle_image_flags(env, argv[2], &args->flags))) {
      goto err;
    }
    execute = true;
  }
);

VZ_ASYNC_DECL(
  vz_create_image_rgba,
  {
    ErlNifBinary bin;
    int flags;
    int w;
    int h;
  },
  {
    int handle;
    VZimage *image;

    handle = nvgCreateImageRGBA(ctx, args->w, args->h, args->flags, args->bin.data);
    if(handle == 0) VZ_HANDLER_SEND_BADARG;
    int_array_push(vz_view->res_array, handle);
    image = vz_alloc_image(vz_view, handle);
    VZ_HANDLER_SEND(vz_make_resource(vz_view->msg_env, image));
  },
  {
    if(!(argc == 5 &&
        enif_inspect_binary(env, argv[1], &args->bin) &&
        enif_get_int(env, argv[2], &args->w) &&
        enif_get_int(env, argv[3], &args->h) &&
        vz_handle_image_flags(env, argv[4], &args->flags))) {
      goto err;
    }
    execute = true;
  }
);

VZ_ASYNC_DECL(
  vz_create_image_bitmap,
  {
    VZbitmap *bm;
    int flags;
  },
  {
    int handle;
    VZimage *image;

    unsigned char *buffer = enif_alloc(args->bm->byte_size);
    memcpy(buffer, args->bm->buffer, args->bm->byte_size);

    handle = nvgCreateImageRGBA(ctx, args->bm->width, args->bm->height, args->flags, buffer);
    if(handle == 0) VZ_HANDLER_SEND_BADARG;
    int_array_push(vz_view->res_array, handle);
    image = vz_alloc_image(vz_view, handle);

    VZ_HANDLER_SEND(vz_make_resource(vz_view->msg_env, image));
  },
  {
    if(!(argc == 3 &&
        enif_get_resource(env, argv[1], vz_bitmap_res, (void**)&args->bm) &&
        vz_handle_image_flags(env, argv[2], &args->flags))) {
      goto err;
    }
    execute = true;
  }
);

VZ_ASYNC_DECL(
  vz_update_image,
  {
    ErlNifBinary bin;
    int handle;
  },
  {
    nvgUpdateImage(ctx, args->handle, args->bin.data);
  },
  {
    VZimage *image;

    if(!(argc == 3 &&
        enif_get_resource(env, argv[1], vz_image_res, (void**)&image) &&
        enif_inspect_binary(env, argv[2], &args->bin))) {
      goto err;
    }
    args->handle = image->handle;
  }
);

VZ_ASYNC_DECL(
  vz_update_image_bitmap,
  {
    VZbitmap *bm;
    int handle;
  },
  {
    nvgUpdateImage(ctx, args->handle, args->bm->buffer);
  },
  {
    VZimage *image;

    if(!(argc == 3 &&
        enif_get_resource(env, argv[1], vz_image_res, (void**)&image) &&
        enif_get_resource(env, argv[2], vz_bitmap_res, (void**)&args->bm))) {
      goto err;
    }
    args->handle = image->handle;
  }
);

VZ_ASYNC_DECL(
  vz_image_size,
  {
    int handle;
  },
  {
    int w;
    int h;
    nvgImageSize(ctx, args->handle, &w, &h);
    VZ_HANDLER_SEND(enif_make_tuple2(vz_view->msg_env,
      enif_make_int(vz_view->msg_env, w), enif_make_int(vz_view->msg_env, h)));
  },
  {
    VZimage *image;

    if(!(argc == 2 &&
        enif_get_resource(env, argv[1], vz_image_res, (void**)&image))) {
      goto err;
    }
    args->handle = image->handle;
    execute = true;
  }
);

VZ_ASYNC_DECL(
  vz_delete_image,
  {
    int handle;
  },
  {
    nvgDeleteImage(ctx, args->handle);
  },
  {
    VZimage *image;

    if(!(argc == 3 &&
        enif_get_resource(env, argv[1], vz_image_res, (void**)&image))) {
      goto err;
    }
    args->handle = image->handle;
  }
);

static ERL_NIF_TERM vz_linear_gradient(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  VZview *vz_view;
  NVGcolor icol, ocol;
  double sx, sy, ex, ey;
  NVGpaint *paint;

  if(!(argc == 7 &&
       enif_get_resource(env, argv[0], vz_view_res, (void**)&vz_view) &&
       vz_get_color(env, argv[5], &icol) &&
       vz_get_color(env, argv[6], &ocol))) {
    return BADARG;
  }

  VZ_GET_NUMBER(env, argv[1], sx);
  VZ_GET_NUMBER(env, argv[2], sy);
  VZ_GET_NUMBER(env, argv[3], ex);
  VZ_GET_NUMBER(env, argv[4], ey);

  paint = vz_alloc_paint(nvgLinearGradient(vz_view->ctx, sx, sy, ex, ey, icol, ocol));

  return vz_make_resource(env, paint);

  err:
  return BADARG;
}

static ERL_NIF_TERM vz_box_gradient(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  VZview *vz_view;
  NVGcolor icol, ocol;
  double x, y, w, h, r, f;
  NVGpaint *paint;

  if(!(argc == 9 &&
       enif_get_resource(env, argv[0], vz_view_res, (void**)&vz_view) &&
       vz_get_color(env, argv[7], &icol) &&
       vz_get_color(env, argv[8], &ocol))) {
    return BADARG;
  }

  VZ_GET_NUMBER(env, argv[1], x);
  VZ_GET_NUMBER(env, argv[2], y);
  VZ_GET_NUMBER(env, argv[3], w);
  VZ_GET_NUMBER(env, argv[4], h);
  VZ_GET_NUMBER(env, argv[5], r);
  VZ_GET_NUMBER(env, argv[6], f);

  paint = vz_alloc_paint(nvgBoxGradient(vz_view->ctx, x, y, w, h, r, f, icol, ocol));

  return vz_make_resource(env, paint);

  err:
  return BADARG;
}

static ERL_NIF_TERM vz_radial_gradient(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  VZview *vz_view;
  NVGcolor icol, ocol;
  double cx, cy, inr, outr;
  NVGpaint *paint;

  if(!(argc == 7 &&
       enif_get_resource(env, argv[0], vz_view_res, (void**)&vz_view) &&
       vz_get_color(env, argv[5], &icol) &&
       vz_get_color(env, argv[6], &ocol))) {
    return BADARG;
  }

  VZ_GET_NUMBER(env, argv[1], cx);
  VZ_GET_NUMBER(env, argv[2], cy);
  VZ_GET_NUMBER(env, argv[3], inr);
  VZ_GET_NUMBER(env, argv[4], outr);

  paint = vz_alloc_paint(nvgRadialGradient(vz_view->ctx, cx, cy, inr, outr, icol, ocol));

  return vz_make_resource(env, paint);

  err:
  return BADARG;
}

static ERL_NIF_TERM vz_image_pattern(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  VZview *vz_view;
  VZimage *image;
  double ox, oy, ex, ey, angle, alpha;

  NVGpaint *paint;

  if(!(argc == 8 &&
       enif_get_resource(env, argv[0], vz_view_res, (void**)&vz_view) &&
       enif_get_resource(env, argv[6], vz_image_res, (void**)&image))) {
    return BADARG;
  }

  VZ_GET_NUMBER(env, argv[1], ox);
  VZ_GET_NUMBER(env, argv[2], oy);
  VZ_GET_NUMBER(env, argv[3], ex);
  VZ_GET_NUMBER(env, argv[4], ey);
  VZ_GET_NUMBER(env, argv[5], angle);
  VZ_GET_NUMBER(env, argv[7], alpha);

  paint = vz_alloc_paint(nvgImagePattern(vz_view->ctx, ox, oy, ex, ey, angle, image->handle, alpha));

  return vz_make_resource(env, paint);

  err:
  return BADARG;
}

VZ_ASYNC_DECL(
  vz_scissor,
  {
    double x;
    double y;
    double w;
    double h;
  },
  {
    nvgScissor(ctx, args->x, args->y, args->w, args->h);
  },
  {
    if(argc != 5) goto err;

    VZ_GET_NUMBER(env, argv[1], args->x);
    VZ_GET_NUMBER(env, argv[2], args->y);
    VZ_GET_NUMBER(env, argv[3], args->w);
    VZ_GET_NUMBER(env, argv[4], args->h);
  }
);

VZ_ASYNC_DECL(
  vz_intersect_scissor,
  {
    double x;
    double y;
    double w;
    double h;
  },
  {
    nvgIntersectScissor(ctx, args->x, args->y, args->w, args->h);
  },
  {
    if(argc != 5) goto err;

    VZ_GET_NUMBER(env, argv[1], args->x);
    VZ_GET_NUMBER(env, argv[2], args->y);
    VZ_GET_NUMBER(env, argv[3], args->w);
    VZ_GET_NUMBER(env, argv[4], args->h);
  }
);

VZ_ASYNC_DECL(
  vz_reset_scissor,
  {
    __EMPTY_STRUCT
  },
  {
    __UNUSED(args);
    nvgResetScissor(ctx);
  },
  {
    // no caller block
  }
);

VZ_ASYNC_DECL(
  vz_begin_path,
  {
    __EMPTY_STRUCT
  },
  {
    __UNUSED(args);
    nvgBeginPath(ctx);
  },
  {
    // no caller block
  }
);

VZ_ASYNC_DECL(
  vz_move_to,
  {
    double x;
    double y;
  },
  {
    nvgMoveTo(ctx, args->x, args->y);
  },
  {
    if(argc != 3) goto err;

    VZ_GET_NUMBER(env, argv[1], args->x);
    VZ_GET_NUMBER(env, argv[2], args->y);
  }
);

VZ_ASYNC_DECL(
  vz_line_to,
  {
    double x;
    double y;
  },
  {
    nvgLineTo(ctx, args->x, args->y);
  },
  {
    if(argc != 3) goto err;

    VZ_GET_NUMBER(env, argv[1], args->x);
    VZ_GET_NUMBER(env, argv[2], args->y);
  }
);

VZ_ASYNC_DECL(
  vz_bezier_to,
  {
    double cx1;
    double cy1;
    double cx2;
    double cy2;
    double x;
    double y;
  },
  {
    nvgBezierTo(ctx, args->cx1, args->cy1, args->cx2, args->cy2, args->x, args->y);
  },
  {
    if(argc != 7) goto err;

    VZ_GET_NUMBER(env, argv[1], args->cx1);
    VZ_GET_NUMBER(env, argv[2], args->cy1);
    VZ_GET_NUMBER(env, argv[3], args->cx2);
    VZ_GET_NUMBER(env, argv[4], args->cy2);
    VZ_GET_NUMBER(env, argv[5], args->x);
    VZ_GET_NUMBER(env, argv[6], args->y);
  }
);

VZ_ASYNC_DECL(
  vz_quad_to,
  {
    double cx;
    double cy;
    double x;
    double y;
  },
  {
    nvgQuadTo(ctx, args->cx, args->cy, args->x, args->y);
  },
  {
    if(argc != 5) goto err;

    VZ_GET_NUMBER(env, argv[1], args->cx);
    VZ_GET_NUMBER(env, argv[2], args->cy);
    VZ_GET_NUMBER(env, argv[3], args->x);
    VZ_GET_NUMBER(env, argv[4], args->y);
  }
);

VZ_ASYNC_DECL(
  vz_arc_to,
  {
    double x1;
    double y1;
    double x2;
    double y2;
    double radius;
  },
  {
    nvgArcTo(ctx, args->x1, args->y1, args->x2, args->y2, args->radius);
  },
  {
    if(argc != 6) goto err;

    VZ_GET_NUMBER(env, argv[1], args->x1);
    VZ_GET_NUMBER(env, argv[2], args->y1);
    VZ_GET_NUMBER(env, argv[3], args->x2);
    VZ_GET_NUMBER(env, argv[4], args->y2);
    VZ_GET_NUMBER(env, argv[5], args->radius);
  }
);

VZ_ASYNC_DECL(
  vz_close_path,
  {
    __EMPTY_STRUCT
  },
  {
    __UNUSED(args);
    nvgClosePath(ctx);
  },
  {
    // no caller block
  }
);

VZ_ASYNC_DECL(
  vz_path_winding,
  {
    int dir;
  },
  {
    __UNUSED(args);
    nvgPathWinding(ctx, args->dir);
  },
  {
    if(!(argc == 2 &&
        vz_get_winding(argv[1], &args->dir))) {
      goto err;
    }
  }
);

VZ_ASYNC_DECL(
  vz_arc,
  {
    double cx;
    double cy;
    double r;
    double a0;
    double a1;
    int dir;
  },
  {
    nvgArc(ctx, args->cx, args->cy, args->r, args->a0, args->a1, args->dir);
  },
  {
    if(!(argc == 7 &&
        vz_get_winding(argv[6], &args->dir))) {
      goto err;
    }

    VZ_GET_NUMBER(env, argv[1], args->cx);
    VZ_GET_NUMBER(env, argv[2], args->cy);
    VZ_GET_NUMBER(env, argv[3], args->r);
    VZ_GET_NUMBER(env, argv[4], args->a0);
    VZ_GET_NUMBER(env, argv[5], args->a1);
  }
);

VZ_ASYNC_DECL(
  vz_rect,
  {
    double x;
    double y;
    double w;
    double h;
  },
  {
    nvgRect(ctx, args->x, args->y, args->w, args->h);
  },
  {
    if(argc != 5) goto err;

    VZ_GET_NUMBER(env, argv[1], args->x);
    VZ_GET_NUMBER(env, argv[2], args->y);
    VZ_GET_NUMBER(env, argv[3], args->w);
    VZ_GET_NUMBER(env, argv[4], args->h);
  }
);

VZ_ASYNC_DECL(
  vz_rounded_rect,
  {
    double x;
    double y;
    double w;
    double h;
    double r;
  },
  {
    nvgRoundedRect(ctx, args->x, args->y, args->w, args->h, args->r);
  },
  {
    if(argc != 6) goto err;

    VZ_GET_NUMBER(env, argv[1], args->x);
    VZ_GET_NUMBER(env, argv[2], args->y);
    VZ_GET_NUMBER(env, argv[3], args->w);
    VZ_GET_NUMBER(env, argv[4], args->h);
    VZ_GET_NUMBER(env, argv[5], args->r);
  }
);

VZ_ASYNC_DECL(
  vz_rounded_rect_varying,
  {
    double x;
    double y;
    double w;
    double h;
    double rad_top_left;
    double rad_top_right;
    double rad_bot_right;
    double rad_bot_left;
  },
  {
    nvgRoundedRectVarying(ctx, args->x, args->y, args->w, args->h, args->rad_top_left, args->rad_top_right, args->rad_bot_right, args->rad_bot_left);
  },
  {
    if(argc != 9) goto err;

    VZ_GET_NUMBER(env, argv[1], args->x);
    VZ_GET_NUMBER(env, argv[2], args->y);
    VZ_GET_NUMBER(env, argv[3], args->w);
    VZ_GET_NUMBER(env, argv[4], args->h);
    VZ_GET_NUMBER(env, argv[5], args->rad_top_left);
    VZ_GET_NUMBER(env, argv[6], args->rad_top_right);
    VZ_GET_NUMBER(env, argv[7], args->rad_bot_right);
    VZ_GET_NUMBER(env, argv[8], args->rad_bot_left);
  }
);

VZ_ASYNC_DECL(
  vz_ellipse,
  {
    double cx;
    double cy;
    double rx;
    double ry;
  },
  {
    nvgEllipse(ctx, args->cx, args->cy, args->rx, args->ry);
  },
  {
    if(argc != 5) goto err;

    VZ_GET_NUMBER(env, argv[1], args->cx);
    VZ_GET_NUMBER(env, argv[2], args->cy);
    VZ_GET_NUMBER(env, argv[3], args->rx);
    VZ_GET_NUMBER(env, argv[4], args->ry);
  }
);

VZ_ASYNC_DECL(
  vz_circle,
  {
    double cx;
    double cy;
    double r;
  },
  {
    nvgCircle(ctx, args->cx, args->cy, args->r);
  },
  {
    if(argc != 4) goto err;

    VZ_GET_NUMBER(env, argv[1], args->cx);
    VZ_GET_NUMBER(env, argv[2], args->cy);
    VZ_GET_NUMBER(env, argv[3], args->r);
  }
);

VZ_ASYNC_DECL(
  vz_fill,
  {
    __EMPTY_STRUCT
  },
  {
    __UNUSED(args);
    nvgFill(ctx);
  },
  {
    // no caller block
  }
);

VZ_ASYNC_DECL(
  vz_stroke,
  {
    __EMPTY_STRUCT
  },
  {
    __UNUSED(args);
    nvgStroke(ctx);
  },
  {
    // no caller block
  }
);

VZ_ASYNC_DECL(
  vz_create_font,
  {
    char file_path[VZ_MAX_STRING_LENGTH];
  },
  {
    VZfont *font;
    int handle;

    if((handle = nvgFindFont(ctx, args->file_path)) < 0) {
      handle = nvgCreateFont(ctx, args->file_path, args->file_path);
    }
    if(handle < 0) VZ_HANDLER_SEND_BADARG;

    font = vz_alloc_font(vz_view, handle, args->file_path);
    VZ_HANDLER_SEND(vz_make_resource(vz_view->msg_env, font));
  },
  {
    if(!(argc == 2 &&
        vz_copy_string(env, argv[1], args->file_path, VZ_MAX_STRING_LENGTH))) {
      goto err;
    }
    execute = true;
  }
);

VZ_ASYNC_DECL(
  vz_find_font,
  {
    char file_path[VZ_MAX_STRING_LENGTH];
  },
  {
    VZfont *font;
    int handle;

    handle = nvgFindFont(ctx, args->file_path);
    if(handle < 0) {
      VZ_HANDLER_SEND(ATOM_NIL);
    }
    else {
      font = vz_alloc_font(vz_view, handle, args->file_path);
      VZ_HANDLER_SEND(vz_make_resource(vz_view->msg_env, font));
    }
  },
  {
    if(!(argc == 2 &&
        vz_copy_string(env, argv[1], args->file_path, VZ_MAX_STRING_LENGTH))) {
      goto err;
    }
    execute = true;
  }
);

VZ_ASYNC_DECL(
  vz_add_fallback_font,
  {
    int base_handle;
    int fallback_handle;
  },
  {
    nvgAddFallbackFontId(ctx, args->base_handle, args->fallback_handle);
  },
  {
    VZfont *base;
    VZfont *fallback;

    if(!(argc == 3 &&
        enif_get_resource(env, argv[1], vz_font_res, (void**)&base) &&
        enif_get_resource(env, argv[2], vz_font_res, (void**)&fallback))) {
      goto err;
    }
    args->base_handle = base->handle;
    args->fallback_handle = fallback->handle;
  }
);

VZ_ASYNC_DECL(
  vz_font_size,
  {
    double size;
  },
  {
    nvgFontSize(ctx, args->size);
  },
  {
    if(argc != 2) goto err;

    VZ_GET_NUMBER(env, argv[1], args->size);
  }
);

VZ_ASYNC_DECL(
  vz_font_blur,
  {
    double blur;
  },
  {
    nvgFontBlur(ctx, args->blur);
  },
  {
    if(argc != 2) goto err;

    VZ_GET_NUMBER(env, argv[1], args->blur);
  }
);

VZ_ASYNC_DECL(
  vz_text_letter_spacing,
  {
    double spacing;
  },
  {
    nvgTextLetterSpacing(ctx, args->spacing);
  },
  {
    if(argc != 2) goto err;

    VZ_GET_NUMBER(env, argv[1], args->spacing);
  }
);

VZ_ASYNC_DECL(
  vz_text_line_height,
  {
    double line_height;
  },
  {
    nvgTextLineHeight(ctx, args->line_height);
  },
  {
    if(argc != 2) goto err;

    VZ_GET_NUMBER(env, argv[1], args->line_height);
  }
);

VZ_ASYNC_DECL(
  vz_text_align,
  {
    int align;
  },
  {
    nvgTextAlign(ctx, args->align);
  },
  {
    if(!(argc == 2 &&
        vz_handle_text_align_flags(env, argv[1], &args->align))) {
      goto err;
    }
  }
);

VZ_ASYNC_DECL(
  vz_font_face,
  {
    int handle;
  },
  {
    nvgFontFaceId(ctx, args->handle);
  },
  {
    VZfont *font;

    if(!(argc == 2 &&
        enif_get_resource(env, argv[1], vz_font_res, (void**)&font))) {
      goto err;
    }

    args->handle = font->handle;
  }
);



VZ_ASYNC_DECL(
  vz_text,
  {
    double x;
    double y;
    char *string;
    char *end;
  },
  {
    double ex;

    ex = nvgText(ctx, args->x, args->y, args->string, args->end);
    enif_free(args->string);
    VZ_HANDLER_SEND(enif_make_double(vz_view->msg_env, ex));
  },
  {
    ErlNifBinary bin;

    if(!(argc == 4 &&
        enif_inspect_binary(env, argv[3], &bin))) {
      return BADARG;
    }

    VZ_GET_NUMBER(env, argv[1], args->x);
    VZ_GET_NUMBER(env, argv[2], args->y);

    args->string = (char*)enif_alloc(bin.size + 1);
    memcpy(args->string, bin.data, bin.size);
    args->string[bin.size] = 0;
    args->end = args->string + bin.size;
    execute = true;
  }
);

VZ_ASYNC_DECL(
  vz_text_box,
  {
    double x;
    double y;
    double break_row_width;
    char *string;
    char *end;
  },
  {
    nvgTextBox(ctx, args->x, args->y, args->break_row_width, args->string, args->end);
    enif_free(args->string);
  },
  {
    ErlNifBinary bin;

    if(!(argc == 4 &&
        enif_inspect_binary(env, argv[4], &bin))) {
      return BADARG;
    }

    VZ_GET_NUMBER(env, argv[1], args->x);
    VZ_GET_NUMBER(env, argv[2], args->y);
    VZ_GET_NUMBER(env, argv[3], args->break_row_width);

    args->string = (char*)enif_alloc(bin.size + 1);
    memcpy(args->string, bin.data, bin.size);
    args->string[bin.size] = 0;
    args->end = args->string + bin.size;
  }
);

VZ_ASYNC_DECL(
  vz_text_bounds,
  {
    double x;
    double y;
    char *string;
    char *end;
  },
  {
    double ex;
    float bounds[4];
    ErlNifEnv *env = vz_view->msg_env;

    ex = nvgTextBounds(ctx, args->x, args->y, args->string, args->end, bounds);
    enif_free(args->string);
    VZ_HANDLER_SEND(enif_make_tuple2(env, enif_make_double(env, ex),
                               enif_make_tuple4(env,
                                enif_make_double(env, bounds[0]),
                                enif_make_double(env, bounds[1]),
                                enif_make_double(env, bounds[2]),
                                enif_make_double(env, bounds[3]))));
  },
  {
    ErlNifBinary bin;

    if(!(argc == 4 &&
        enif_inspect_binary(env, argv[3], &bin))) {
      return BADARG;
    }

    VZ_GET_NUMBER(env, argv[1], args->x);
    VZ_GET_NUMBER(env, argv[2], args->y);

    args->string = (char*)enif_alloc(bin.size + 1);
    memcpy(args->string, bin.data, bin.size);
    args->string[bin.size] = 0;
    args->end = args->string + bin.size;
    execute = true;
  }
);

VZ_ASYNC_DECL(
  vz_text_box_bounds,
  {
    double x;
    double y;
    double break_row_width;
    char *string;
    char *end;
  },
  {
    float bounds[4];
    ErlNifEnv *env = vz_view->msg_env;

    nvgTextBoxBounds(ctx, args->x, args->y, args->break_row_width, args->string, args->end, bounds);
    enif_free(args->string);
    VZ_HANDLER_SEND(enif_make_tuple4(env,
          enif_make_double(env, bounds[0]),
          enif_make_double(env, bounds[1]),
          enif_make_double(env, bounds[2]),
          enif_make_double(env, bounds[3])));
  },
  {
    ErlNifBinary bin;

    if(!(argc == 4 &&
        enif_inspect_binary(env, argv[4], &bin))) {
      return BADARG;
    }

    VZ_GET_NUMBER(env, argv[1], args->x);
    VZ_GET_NUMBER(env, argv[2], args->y);
    VZ_GET_NUMBER(env, argv[3], args->break_row_width);

    args->string = (char*)enif_alloc(bin.size + 1);
    memcpy(args->string, bin.data, bin.size);
    args->string[bin.size] = 0;
    args->end = args->string + bin.size;
    execute = true;
  }
);

VZ_ASYNC_DECL(
  vz_text_glyph_positions,
  {
    double x;
    double y;
    char *string;
    char *end;
  },
  {
    int length;
    NVGglyphPosition positions[4096];
    ErlNifEnv *env = vz_view->msg_env;
    ERL_NIF_TERM *array;
    ERL_NIF_TERM positions_list;

    length = nvgTextGlyphPositions(ctx, args->x, args->y, args->string, args->end, positions, 4096);
    array = (ERL_NIF_TERM*)enif_alloc(length * sizeof(ERL_NIF_TERM));

    for(int i = 0; i < length; ++i) {
      array[i] = enif_make_tuple3(env,
        enif_make_double(env, positions[i].x),
        enif_make_double(env, positions[i].minx),
        enif_make_double(env, positions[i].maxx));
    }
    positions_list = enif_make_list_from_array(env, array, length);

    enif_free(array);
    enif_free(args->string);

    VZ_HANDLER_SEND(positions_list);
  },
  {
    ErlNifBinary bin;

    if(!(argc == 4 &&
        enif_inspect_binary(env, argv[3], &bin))) {
      return BADARG;
    }

    VZ_GET_NUMBER(env, argv[1], args->x);
    VZ_GET_NUMBER(env, argv[2], args->y);

    args->string = (char*)enif_alloc(bin.size + 1);
    memcpy(args->string, bin.data, bin.size);
    args->string[bin.size] = 0;
    args->end = args->string + bin.size;
    execute = true;
  }
);

VZ_ASYNC_DECL(
  vz_text_metrics,
  {
    __EMPTY_STRUCT
  },
  {
    __UNUSED(args);
    float ascender;
    float descender;
    float lineh;
    ErlNifEnv *env = vz_view->msg_env;

    nvgTextMetrics(ctx, &ascender, &descender, &lineh);

    VZ_HANDLER_SEND(enif_make_tuple3(env,
          enif_make_double(env, ascender),
          enif_make_double(env, descender),
          enif_make_double(env, lineh)));
  },
  {
    execute = true;
  }
);

VZ_ASYNC_DECL(
  vz_text_break_lines,
  {
    double break_row_width;
    char *string;
    char *end;
 },
  {
    int length;
    int size;
    ERL_NIF_TERM *array;
    ERL_NIF_TERM rows_list;
    ErlNifBinary row_bin;
    NVGtextRow rows[4096];
    ErlNifEnv *env = vz_view->msg_env;


    length = nvgTextBreakLines(ctx, args->string, args->end, args->break_row_width, rows, 4096);
    array = (ERL_NIF_TERM*)enif_alloc(length * sizeof(ERL_NIF_TERM));

    for(int i=0; i < length; ++i) {
      size = rows[i].end - rows[i].start;
      enif_alloc_binary(size, &row_bin);
      memcpy(row_bin.data, rows[i].start, size);
      array[i] = enif_make_tuple4(env,
        enif_make_binary(env, &row_bin),
        enif_make_double(env, rows[i].width),
        enif_make_double(env, rows[i].minx),
        enif_make_double(env, rows[i].maxx));
    }
    rows_list = enif_make_list_from_array(env, array, length);

    enif_free(args->string);
    enif_free(array);

    VZ_HANDLER_SEND(rows_list);
  },
  {
    ErlNifBinary bin;

    if(!(argc == 3 &&
        enif_inspect_binary(env, argv[2], &bin))) {
      return BADARG;
    }

    VZ_GET_NUMBER(env, argv[1], args->break_row_width);

    args->string = (char*)enif_alloc(bin.size + 1);
    memcpy(args->string, bin.data, bin.size);
    args->string[bin.size] = 0;
    args->end = args->string + bin.size;
    execute = true;
  }
);

static ERL_NIF_TERM vz_create_bitmap(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  unsigned width, height;
  VZbitmap *bm;

  if(!(argc == 2 &&
       enif_get_uint(env, argv[0], &width) &&
       enif_get_uint(env, argv[1], &height))) {
    return BADARG;
  }

  bm = vz_alloc_bitmap(width, height);

  return vz_make_resource(env, bm);
}

static ERL_NIF_TERM vz_bm_size(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  VZbitmap *bm;

  if(!(argc == 1 &&
       enif_get_resource(env, argv[0], vz_bitmap_res, (void**)&bm))) {
    return BADARG;
  }

  return enif_make_uint(env, vz_bitmap_size(bm));
}

static ERL_NIF_TERM vz_bm_put(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  VZbitmap *bm;
  unsigned ndx, r, g, b, a;

  if(!(argc == 6 &&
       enif_get_resource(env, argv[0], vz_bitmap_res, (void**)&bm) &&
       enif_get_uint(env, argv[1], &ndx) &&
       enif_get_uint(env, argv[2], &r) &&
       enif_get_uint(env, argv[3], &g) &&
       enif_get_uint(env, argv[4], &b) &&
       enif_get_uint(env, argv[5], &a))) {
    return BADARG;
  }

  vz_bitmap_put(bm, ndx, r, g, b, a);

  return argv[0];
}

static ERL_NIF_TERM vz_bm_put_bin(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  VZbitmap *bm;
  unsigned ndx;
  ErlNifBinary bin;

  if(!(argc == 3 &&
       enif_get_resource(env, argv[0], vz_bitmap_res, (void**)&bm) &&
       enif_get_uint(env, argv[1], &ndx) &&
       enif_inspect_binary(env, argv[2], &bin))) {
    return BADARG;
  }

  if((bin.size % 4) != 0) return BADARG;

  vz_bitmap_put_bin(bm, ndx, (unsigned char*)bin.data, bin.size);

  return argv[0];
}

static ERL_NIF_TERM vz_send_wakeup_event(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  VZview *vz_view;

  if(!(argc == 1 &&
       enif_get_resource(env, argv[0], vz_view_res, (void**)&vz_view))) {
    return BADARG;
  }
  enif_mutex_lock(vz_view->lock);

#ifdef LINUX
  Display *display = XOpenDisplay(0);
  Window window = puglGetNativeWindow(vz_view->view);
  XExposeEvent event;

  event.type = Expose;
  event.display = display;
  event.window = window;
  event.x = 0;
  event.y = 0;
  event.width = vz_view->width;
  event.height = vz_view->height;
  event.count = 0;

  XSendEvent(display, window, False, ExposureMask, (XEvent*)&event);
  XFlush(display);
#elif defined(WINDOWS)
  HWND hwnd = puglGetNativeWindow(vz_view->view);
  InvalidateRect(hwnd, NULL, FALSE);
#endif

  enif_mutex_unlock(vz_view->lock);

  return ATOM_OK;
}



/*
NIF boiler plate
*/

static int vz_load(ErlNifEnv* env, void** priv_data, ERL_NIF_TERM load_info)
{
  __UNUSED(load_info);

  ErlNifResourceFlags flags = ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER;
  vz_view_res = enif_open_resource_type(env, NULL, "vz_view_res", vz_view_dtor, flags, NULL);
  vz_image_res = enif_open_resource_type(env, NULL, "vz_image_res", NULL, flags, NULL);
  vz_font_res = enif_open_resource_type(env, NULL, "vz_font_res", NULL, flags, NULL);
  vz_paint_res = enif_open_resource_type(env, NULL, "vz_paint_res", NULL, flags, NULL);
  vz_matrix_res = enif_open_resource_type(env, NULL, "vz_matrix_res", NULL, flags, NULL);
  vz_bitmap_res = enif_open_resource_type(env, NULL, "vz_bitmap_res", vz_bitmap_dtor, flags, NULL);

  vz_make_atoms(env);

  return 0;
}


static ErlNifFunc nif_funcs[] =
{
    {"create_view", 1, vz_create_view},
    {"ready", 1, vz_ready},
    {"redraw", 1, vz_redraw},
    {"setup_element", 2, vz_setup_element},
    {"global_composite_operation", 2, vz_global_composite_operation},
    {"global_composite_blend_func", 3, vz_global_composite_blend_func},
    {"global_composite_blend_func_separate", 5, vz_global_composite_blend_func_separate},
    {"lerp_rgba", 3, vz_lerp_rgba},
    {"hsla", 4, vz_hsla},
    {"save", 1, vz_save},
    {"restore", 1, vz_restore},
    {"reset", 1, vz_reset},
    {"shape_anti_alias", 2, vz_shape_anti_alias},
    {"stroke_color", 2, vz_stroke_color},
    {"stroke_paint", 2, vz_stroke_paint},
    {"fill_color", 2, vz_fill_color},
    {"fill_paint", 2, vz_fill_paint},
    {"miter_limit", 2, vz_miter_limit},
    {"stroke_width", 2, vz_stroke_width},
    {"line_cap", 2, vz_line_cap},
    {"line_join", 2, vz_line_join},
    {"global_alpha", 2, vz_global_alpha},
    {"reset_transform", 1, vz_reset_transform},
    {"transform", 2, vz_transform},
    {"translate", 3, vz_translate},
    {"rotate", 2, vz_rotate},
    {"skew_x", 2, vz_skew_x},
    {"skew_y", 2, vz_skew_y},
    {"scale", 3, vz_scale},
    {"current_transform", 1, vz_current_transform},
    {"transform_identity", 1, vz_transform_identity},
    {"transform_translate", 2, vz_transform_translate},
    {"transform_scale", 2, vz_transform_scale},
    {"transform_rotate", 1, vz_transform_rotate},
    {"transform_skew_x", 1, vz_transform_skew_x},
    {"transform_skew_y", 1, vz_transform_skew_y},
    {"transform_multiply", 2, vz_transform_multiply},
    {"transform_premultiply", 2, vz_transform_premultiply},
    {"transform_inverse", 1, vz_transform_inverse},
    {"transform_point", 3, vz_transform_point},
    {"matrix_to_list", 1, vz_matrix_to_list},
    {"list_to_matrix", 1, vz_list_to_matrix},
    {"deg_to_rad", 1, vz_deg_to_rad},
    {"rad_to_deg", 1, vz_rad_to_deg},
    {"create_image", 3, vz_create_image},
    {"create_image_mem", 3, vz_create_image_mem},
    {"create_image_rgba", 5, vz_create_image_rgba},
    {"create_image_bitmap", 3, vz_create_image_bitmap},
    {"update_image", 3, vz_update_image},
    {"update_image_bitmap", 3, vz_update_image_bitmap},
    {"image_size", 2, vz_image_size},
    {"delete_image", 2, vz_delete_image},
    {"linear_gradient", 7, vz_linear_gradient},
    {"box_gradient", 9, vz_box_gradient},
    {"radial_gradient", 7, vz_radial_gradient},
    {"image_pattern", 8, vz_image_pattern},
    {"scissor", 5, vz_scissor},
    {"intersect_scissor", 5, vz_intersect_scissor},
    {"reset_scissor", 1, vz_reset_scissor},
    {"begin_path", 1, vz_begin_path},
    {"move_to", 3, vz_move_to},
    {"line_to", 3, vz_line_to},
    {"bezier_to", 7, vz_bezier_to},
    {"quad_to", 5, vz_quad_to},
    {"arc_to", 6, vz_arc_to},
    {"close_path", 1, vz_close_path},
    {"path_winding", 2, vz_path_winding},
    {"arc", 7, vz_arc},
    {"rect", 5, vz_rect},
    {"rounded_rect", 6, vz_rounded_rect},
    {"rounded_rect_varying", 9, vz_rounded_rect_varying},
    {"ellipse", 5, vz_ellipse},
    {"circle", 4, vz_circle},
    {"fill", 1, vz_fill},
    {"stroke", 1, vz_stroke},
    {"create_font", 2, vz_create_font},
    {"find_font", 2, vz_find_font},
    {"add_fallback_font", 3, vz_add_fallback_font},
    {"font_size", 2, vz_font_size},
    {"font_blur", 2, vz_font_blur},
    {"text_letter_spacing", 2, vz_text_letter_spacing},
    {"text_line_height", 2, vz_text_line_height},
    {"text_align", 2, vz_text_align},
    {"font_face", 2, vz_font_face},
    {"text", 4, vz_text},
    {"text_box", 5, vz_text_box},
    {"text_bounds", 4, vz_text_bounds},
    {"text_box_bounds", 5, vz_text_box_bounds},
    {"text_glyph_positions", 4, vz_text_glyph_positions},
    {"text_metrics", 1, vz_text_metrics},
    {"text_break_lines", 3, vz_text_break_lines},
    {"create_bitmap", 2, vz_create_bitmap},
    {"bitmap_size", 1, vz_bm_size},
    {"bitmap_put", 6, vz_bm_put},
    {"bitmap_put_bin", 3, vz_bm_put_bin},
    {"send_wakeup_event", 1, vz_send_wakeup_event}
};

ERL_NIF_INIT(Elixir.Vizi.NIF, nif_funcs, &vz_load, NULL, NULL, NULL)
