#include "vz_helpers.h"
#include "vz_resources.h"

#include <string.h>
#include <stdio.h>
#include <stdlib.h>

VZ_ARRAY_DEFINE(VZop)
VZ_ARRAY_DEFINE(VZev)
VZ_ARRAY_DEFINE(VZres)
VZ_ARRAY_DEFINE(double)


ErlNifResourceType *vz_view_res;
VZview* vz_alloc_view(ErlNifEnv* env) {
  VZview* vz_view;

  if((vz_view = enif_alloc_resource(vz_view_res, sizeof(VZview))) == NULL)
    return NULL;

  if((vz_view->lock = enif_mutex_create("vz_thread_mutex")) == NULL) {
    enif_release_resource(vz_view);
    return NULL;
  }

  if((vz_view->execute_cv = enif_cond_create("vz_thread_cond")) == NULL) {
    enif_mutex_destroy(vz_view->lock);
    enif_release_resource(vz_view);
    return NULL;
  }

  VZpriv *priv = (VZpriv*)enif_priv_data(env);

  enif_self(env, &vz_view->view_pid);
  vz_view->op_array = VZop_array_new(256);
  vz_view->ev_array = VZev_array_new(16);
  vz_view->res_array[0] = VZres_array_new(256);
  vz_view->res_array[1] = VZres_array_new(256);
  vz_view->res_ndx = 0;
  vz_view->msg_env = enif_alloc_env();
  vz_view->ev_env = enif_alloc_env();
  vz_view->id = vz_priv_new_view_id(priv);
  vz_view->busy = false;
  vz_view->shutdown = false;
  vz_view->resizable = false;
  vz_view->force_send_events = false;
  vz_view->frame_rate = VZ_VSYNC;
  vz_view->vsync = true;
  vz_view->redraw_mode = VZ_INTERVAL;
  vz_view->width = 800;
  vz_view->height = 600;
  vz_view->init_width = 800;
  vz_view->init_height = 600;
  vz_view->width_factor = 1.0;
  vz_view->height_factor = 1.0;
  vz_view->min_width = 0;
  vz_view->min_height = 0;
  vz_view->pixel_ratio = 1.0;
  vz_view->ctx = NULL;
  vz_view->parent = 0;
  vz_view->bg = nvgRGBA(0,0,0,0);
  memset(vz_view->title, 0, VZ_MAX_STRING_LENGTH);

  return vz_view;
}

void vz_view_dtor(ErlNifEnv *env, void *resource) {
  __UNUSED(env);
  VZview *vz_view = (VZview*)resource;
  if (!vz_view->shutdown) {
    enif_mutex_lock(vz_view->lock);
    vz_view->busy = false;
    vz_view->shutdown = true;
    enif_cond_signal(vz_view->execute_cv);
    enif_mutex_unlock(vz_view->lock);
    enif_thread_join(vz_view->view_tid, NULL);
  }

  enif_mutex_destroy(vz_view->lock);
  enif_cond_destroy(vz_view->execute_cv);
  enif_free_env(vz_view->msg_env);
  enif_free_env(vz_view->ev_env);

  for(unsigned i = 0; i < vz_view->op_array->end_pos; ++i) {
    enif_free(vz_view->op_array->array[i].args);
  }
  VZop_array_free(vz_view->op_array);
  VZev_array_free(vz_view->ev_array);
}

VZpriv* vz_alloc_priv() {
  VZpriv *priv = enif_alloc(sizeof(VZpriv));
  priv->view_id_counter = 0;

  return priv;
}

void vz_free_priv(VZpriv *priv) {
  enif_free(priv);
}

char* vz_priv_new_view_id(VZpriv *priv) {
  char *str = calloc(9, sizeof(char));
  sprintf(str, "vizi-%03d", ++priv->view_id_counter);

  return str;
}


ErlNifResourceType *vz_canvas_res;
VZcanvas* vz_alloc_canvas(VZview *view) {
  VZcanvas* vz_canvas;

  if((vz_canvas = enif_alloc_resource(vz_canvas_res, sizeof(VZcanvas))) == NULL)
    return NULL;

  vz_canvas->view = view;
  vz_canvas->x = 0.0;
  vz_canvas->y = 0.0;
  vz_canvas->width = 0.0;
  vz_canvas->height = 0.0;

  return vz_canvas;
}

ErlNifResourceType *vz_image_res;
VZimage* vz_alloc_image(VZview *view, int handle) {
  VZimage *image;

  if((image = enif_alloc_resource(vz_image_res, sizeof(VZimage))) == NULL)
      return NULL;

  image->view = view;
  image->handle = handle;

  return image;
}

  struct vz_image_dtor_args {
    int handle;
  };
  static void vz_image_dtor_handler(VZview *vz_view, void *void_args) {
    NVGcontext *ctx = vz_view->ctx;
    struct vz_image_dtor_args *args = (struct vz_image_dtor_args*)void_args;
    nvgDeleteImage(ctx, args->handle);
  }


void vz_image_dtor(ErlNifEnv *env, void *resource) {
  VZimage *image = (VZimage*)resource;
  if(!image->view->shutdown) {
    struct vz_image_dtor_args *args = (struct vz_image_dtor_args*)enif_alloc(sizeof(struct vz_image_dtor_args));
    VZop vz_op;
    vz_op.handler = vz_image_dtor_handler;
    vz_op.args = args;
    args->handle = image->handle;
    enif_mutex_lock(image->view->lock);
    VZop_array_push(image->view->op_array, vz_op);
    enif_mutex_unlock(image->view->lock);
  }
}



ErlNifResourceType *vz_font_res;
VZfont* vz_alloc_font(VZview *view, int handle, const char *file_path) {
  VZfont *font;

  if((font = enif_alloc_resource(vz_font_res, sizeof(VZfont))) == NULL)
      return NULL;

  font->view = view;
  font->handle = handle;
  memcpy(font->file_path, file_path, VZ_MAX_STRING_LENGTH);

  return font;
}

ErlNifResourceType *vz_paint_res;
NVGpaint* vz_alloc_paint(NVGpaint src) {
  NVGpaint *dst;

  if((dst = enif_alloc_resource(vz_paint_res, sizeof(NVGpaint))) == NULL)
      return NULL;

  memcpy(dst, &src, sizeof(NVGpaint));

  return dst;
}

ErlNifResourceType *vz_matrix_res;
float* vz_alloc_matrix() {
  return enif_alloc_resource(vz_matrix_res, sizeof(float) * 6);
}

float* vz_alloc_matrix_copy(const float *src) {
  float *dst;

  if((dst = enif_alloc_resource(vz_matrix_res, sizeof(float) * 6)) == NULL)
      return NULL;

  memcpy(dst, src, sizeof(float) * 6);

  return dst;
}

ErlNifResourceType *vz_bitmap_res;
VZbitmap* vz_alloc_bitmap(int width, int height) {
  VZbitmap *bm;

  if((bm = enif_alloc_resource(vz_bitmap_res, sizeof(VZbitmap))) == NULL)
      return NULL;

  bm->buffer = (unsigned char*)enif_alloc(width * height * 4 * sizeof(unsigned char));
  bm->width = width;
  bm->height = height;
  bm->pixel_size = width * height;
  bm->byte_size = bm->pixel_size * 4 * sizeof(unsigned char);

  return bm;
}

void vz_bitmap_dtor(ErlNifEnv *env, void *resource) {
  VZbitmap *bm = (VZbitmap*)resource;
  enif_free(bm->buffer);
}

unsigned vz_bitmap_size(const VZbitmap *bm) {
  return bm->pixel_size;
}

void vz_bitmap_put(VZbitmap *bm, unsigned ndx, unsigned char r, unsigned char g, unsigned char b, unsigned char a) {
  if(ndx < bm->pixel_size) {
    ndx = ndx * 4;
    bm->buffer[ndx]     = r;
    bm->buffer[ndx + 1] = g;
    bm->buffer[ndx + 2] = b;
    bm->buffer[ndx + 3] = a;
  }
}

/*
void vz_bitmap_put(VZbitmap *bm, unsigned ndx, unsigned char r, unsigned char g, unsigned char b, unsigned char a) {
  if(ndx < bm->pixel_size) {
    ndx = ndx * 4;
    bm->buffer[ndx]     = r;
    bm->buffer[ndx + 1] = g;
    bm->buffer[ndx + 2] = b;
    bm->buffer[ndx + 3] = a;
  }
}
*/
void vz_bitmap_put_bin(VZbitmap *bm, unsigned ndx, const unsigned char *rgba, int size) {
  ndx = ndx * 4;
  if((ndx + size) <= bm->byte_size) {
    memcpy(bm->buffer + ndx, rgba, size);
  }
}


ERL_NIF_TERM vz_make_resource(ErlNifEnv* env, void* obj) {
  ERL_NIF_TERM res = enif_make_resource(env, obj);
  enif_release_resource(obj);
  return res;
}

ERL_NIF_TERM vz_make_managed_resource(ErlNifEnv* env, void* obj, VZview *vz_view) {
  ERL_NIF_TERM res = enif_make_resource(env, obj);
  VZres_array_push(vz_view->res_array[vz_view->res_ndx], obj);
  return res;
}

void vz_release_managed_resources(VZview *vz_view) {
  vz_view->res_ndx = vz_view->res_ndx ? 0 : 1;
  VZres_array *a = vz_view->res_array[vz_view->res_ndx];
  for(unsigned i = a->start_pos; i < a->end_pos; ++i) {
    enif_release_resource(a->array[i]);
  }
  VZres_array_clear(a);
}
