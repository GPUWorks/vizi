#include "vz_helpers.h"
#include "vz_resources.h"
#include "vz_atoms.h"
#include "vz_events.h"
#include "vz_view_thread.h"

#include <string.h>


static ERL_NIF_TERM vz_make_event_state(ErlNifEnv* env, unsigned state) {
  switch(state) {
    case PUGL_MOD_SHIFT:
      return ATOM_SHIFT;
    case PUGL_MOD_CTRL:
      return ATOM_CTRL;
    case PUGL_MOD_ALT:
      return ATOM_ALT;
    case PUGL_MOD_SUPER:
      return ATOM_SUPER;
  }

  return ATOM_NIL;
}

static ERL_NIF_TERM vz_make_special_key(ErlNifEnv* env, unsigned special_key) {
  switch(special_key) {
    case 0:
      return enif_make_uint(env, 0);
    case PUGL_KEY_F1:
      return ATOM_F1;
    case PUGL_KEY_F2:
      return ATOM_F2;
    case PUGL_KEY_F3:
      return ATOM_F3;
    case PUGL_KEY_F4:
      return ATOM_F4;
    case PUGL_KEY_F5:
      return ATOM_F5;
    case PUGL_KEY_F6:
      return ATOM_F6;
    case PUGL_KEY_F7:
      return ATOM_F7;
    case PUGL_KEY_F8:
      return ATOM_F8;
    case PUGL_KEY_F9:
      return ATOM_F9;
    case PUGL_KEY_F10:
      return ATOM_F10;
    case PUGL_KEY_F11:
      return ATOM_F11;
    case PUGL_KEY_F12:
      return ATOM_F12;
    case PUGL_KEY_LEFT:
      return ATOM_LEFT;
    case PUGL_KEY_UP:
      return ATOM_UP;
    case PUGL_KEY_RIGHT:
      return ATOM_RIGHT;
    case PUGL_KEY_DOWN:
      return ATOM_DOWN;
    case PUGL_KEY_PAGE_UP:
      return ATOM_PAGE_UP;
    case PUGL_KEY_PAGE_DOWN:
      return ATOM_PAGE_DOWN;
    case PUGL_KEY_HOME:
      return ATOM_HOME;
    case PUGL_KEY_END:
      return ATOM_END;
    case PUGL_KEY_INSERT:
      return ATOM_INSERT;
    case PUGL_KEY_SHIFT:
      return ATOM_SHIFT;
    case PUGL_KEY_CTRL:
      return ATOM_CTRL;
    case PUGL_KEY_ALT:
      return ATOM_ALT;
    case PUGL_KEY_SUPER:
      return ATOM_SUPER;
  }

  return ATOM_NIL;
}

static ERL_NIF_TERM vz_make_crossing_mode(ErlNifEnv* env, unsigned mode) {
  switch(mode) {
    case PUGL_CROSSING_NORMAL:
      return ATOM_NORMAL;
    case PUGL_CROSSING_GRAB:
      return ATOM_GRAB;
    case PUGL_CROSSING_UNGRAB:
      return ATOM_UNGRAB;
  }

  return ATOM_NIL;
}

static ERL_NIF_TERM vz_make_button_event_struct(ErlNifEnv* env, const PuglEventButton* event, double width_factor, double height_factor) {
  ERL_NIF_TERM map = enif_make_new_map(env);
  ERL_NIF_TERM type = event->type == PUGL_BUTTON_PRESS ? ATOM_BUTTON_PRESS_EVENT_TYPE : ATOM_BUTTON_RELEASE_EVENT_TYPE;

  enif_make_map_put(env, map, ATOM__STRUCT__, ATOM_BUTTON_EVENT, &map);
  enif_make_map_put(env, map, ATOM_CONTEXT, ATOM_NIL, &map);
  enif_make_map_put(env, map, ATOM_TYPE, type, &map);
  enif_make_map_put(env, map, ATOM_TIME, enif_make_uint(env, event->time), &map);
  enif_make_map_put(env, map, ATOM_X, enif_make_double(env, event->x / width_factor), &map);
  enif_make_map_put(env, map, ATOM_Y, enif_make_double(env, event->y / height_factor), &map);
  enif_make_map_put(env, map, ATOM_ABS_X, enif_make_double(env, event->x), &map);
  enif_make_map_put(env, map, ATOM_ABS_Y, enif_make_double(env, event->y), &map);
  enif_make_map_put(env, map, ATOM_X_ROOT, enif_make_double(env, event->x_root), &map);
  enif_make_map_put(env, map, ATOM_Y_ROOT, enif_make_double(env, event->y_root), &map);
  enif_make_map_put(env, map, ATOM_STATE, vz_make_event_state(env, event->state), &map);
  enif_make_map_put(env, map, ATOM_BUTTON, enif_make_uint(env, event->button), &map);

  return map;
}

static ERL_NIF_TERM vz_make_configure_event_struct(ErlNifEnv* env, const PuglEventConfigure* event) {
  ERL_NIF_TERM map = enif_make_new_map(env);

  enif_make_map_put(env, map, ATOM__STRUCT__, ATOM_CONFIGURE_EVENT, &map);
  enif_make_map_put(env, map, ATOM_CONTEXT, ATOM_NIL, &map);
  enif_make_map_put(env, map, ATOM_TYPE, ATOM_CONFIGURE_EVENT_TYPE, &map);
  enif_make_map_put(env, map, ATOM_X, enif_make_double(env, event->x), &map);
  enif_make_map_put(env, map, ATOM_Y, enif_make_double(env, event->y), &map);
  enif_make_map_put(env, map, ATOM_WIDTH, enif_make_double(env, event->width), &map);
  enif_make_map_put(env, map, ATOM_HEIGHT, enif_make_double(env, event->height), &map);

  return map;
}

static ERL_NIF_TERM vz_make_expose_event_struct(ErlNifEnv* env, const PuglEventExpose* event) {
  ERL_NIF_TERM map = enif_make_new_map(env);

  enif_make_map_put(env, map, ATOM__STRUCT__, ATOM_EXPOSE_EVENT, &map);
  enif_make_map_put(env, map, ATOM_CONTEXT, ATOM_NIL, &map);
  enif_make_map_put(env, map, ATOM_TYPE, ATOM_EXPOSE_EVENT_TYPE, &map);
  enif_make_map_put(env, map, ATOM_X, enif_make_double(env, event->x), &map);
  enif_make_map_put(env, map, ATOM_Y, enif_make_double(env, event->y), &map);
  enif_make_map_put(env, map, ATOM_WIDTH, enif_make_double(env, event->width), &map);
  enif_make_map_put(env, map, ATOM_HEIGHT, enif_make_double(env, event->height), &map);
  enif_make_map_put(env, map, ATOM_COUNT, enif_make_int(env, event->count), &map);

  return map;
}

static ERL_NIF_TERM vz_make_close_event_struct(ErlNifEnv* env, const PuglEventClose* event) {
  __UNUSED(event);
  ERL_NIF_TERM map = enif_make_new_map(env);

  enif_make_map_put(env, map, ATOM__STRUCT__, ATOM_CLOSE_EVENT, &map);
  enif_make_map_put(env, map, ATOM_CONTEXT, ATOM_NIL, &map);
  enif_make_map_put(env, map, ATOM_TYPE, ATOM_CLOSE_EVENT_TYPE, &map);

  return map;
}

static ERL_NIF_TERM vz_make_key_event_struct(ErlNifEnv* env, const PuglEventKey* event, double width_factor, double height_factor) {
  ERL_NIF_TERM map = enif_make_new_map(env);
  ERL_NIF_TERM type = event->type == PUGL_KEY_PRESS ? ATOM_KEY_PRESS_EVENT_TYPE : ATOM_KEY_RELEASE_EVENT_TYPE;
  ErlNifBinary bin;
  enif_alloc_binary(8, &bin);
  memcpy(bin.data, event->utf8, 8);

  enif_make_map_put(env, map, ATOM__STRUCT__, ATOM_KEY_EVENT, &map);
  enif_make_map_put(env, map, ATOM_CONTEXT, ATOM_NIL, &map);
  enif_make_map_put(env, map, ATOM_TYPE, type, &map);
  enif_make_map_put(env, map, ATOM_TIME, enif_make_uint(env, event->time), &map);
  enif_make_map_put(env, map, ATOM_X, enif_make_double(env, event->x / width_factor), &map);
  enif_make_map_put(env, map, ATOM_Y, enif_make_double(env, event->y / height_factor), &map);
  enif_make_map_put(env, map, ATOM_ABS_X, enif_make_double(env, event->x), &map);
  enif_make_map_put(env, map, ATOM_ABS_Y, enif_make_double(env, event->y), &map);
  enif_make_map_put(env, map, ATOM_X_ROOT, enif_make_double(env, event->x_root), &map);
  enif_make_map_put(env, map, ATOM_Y_ROOT, enif_make_double(env, event->y_root), &map);
  enif_make_map_put(env, map, ATOM_STATE, vz_make_event_state(env, event->state), &map);
  enif_make_map_put(env, map, ATOM_KEYCODE, enif_make_uint(env, event->keycode), &map);
  enif_make_map_put(env, map, ATOM_CHARACTER, enif_make_uint(env, event->character), &map);
  enif_make_map_put(env, map, ATOM_SPECIAL, vz_make_special_key(env, event->special), &map);
  enif_make_map_put(env, map, ATOM_UTF8, enif_make_binary(env, &bin), &map);
  enif_make_map_put(env, map, ATOM_FILTER, (event->filter ? ATOM_TRUE : ATOM_FALSE), &map);

  return map;
}

static ERL_NIF_TERM vz_make_crossing_event_struct(ErlNifEnv* env, const PuglEventCrossing* event, double width_factor, double height_factor) {
  ERL_NIF_TERM map = enif_make_new_map(env);
  ERL_NIF_TERM type = event->type == PUGL_ENTER_NOTIFY ? ATOM_ENTER_MOTION_EVENT_TYPE : ATOM_LEAVE_MOTION_EVENT_TYPE;

  enif_make_map_put(env, map, ATOM__STRUCT__, ATOM_CROSSING_EVENT, &map);
  enif_make_map_put(env, map, ATOM_CONTEXT, ATOM_NIL, &map);
  enif_make_map_put(env, map, ATOM_TYPE, type, &map);
  enif_make_map_put(env, map, ATOM_TIME, enif_make_uint(env, event->time), &map);
  enif_make_map_put(env, map, ATOM_X, enif_make_double(env, event->x / width_factor), &map);
  enif_make_map_put(env, map, ATOM_Y, enif_make_double(env, event->y / height_factor), &map);
  enif_make_map_put(env, map, ATOM_ABS_X, enif_make_double(env, event->x), &map);
  enif_make_map_put(env, map, ATOM_ABS_Y, enif_make_double(env, event->y), &map);
  enif_make_map_put(env, map, ATOM_X_ROOT, enif_make_double(env, event->x_root), &map);
  enif_make_map_put(env, map, ATOM_Y_ROOT, enif_make_double(env, event->y_root), &map);
  enif_make_map_put(env, map, ATOM_STATE, vz_make_event_state(env, event->state), &map);
  enif_make_map_put(env, map, ATOM_MODE, vz_make_crossing_mode(env, event->mode), &map);

  return map;
}

static ERL_NIF_TERM vz_make_motion_event_struct(ErlNifEnv* env, const PuglEventMotion* event, double width_factor, double height_factor) {
  ERL_NIF_TERM map = enif_make_new_map(env);
  enif_make_map_put(env, map, ATOM__STRUCT__, ATOM_MOTION_EVENT, &map);
  enif_make_map_put(env, map, ATOM_CONTEXT, ATOM_NIL, &map);
  enif_make_map_put(env, map, ATOM_TYPE, ATOM_MOTION_EVENT_TYPE, &map);
  enif_make_map_put(env, map, ATOM_TIME, enif_make_uint(env, event->time), &map);
  enif_make_map_put(env, map, ATOM_X, enif_make_double(env, event->x / width_factor), &map);
  enif_make_map_put(env, map, ATOM_Y, enif_make_double(env, event->y / height_factor), &map);
  enif_make_map_put(env, map, ATOM_ABS_X, enif_make_double(env, event->x), &map);
  enif_make_map_put(env, map, ATOM_ABS_Y, enif_make_double(env, event->y), &map);
  enif_make_map_put(env, map, ATOM_X_ROOT, enif_make_double(env, event->x_root), &map);
  enif_make_map_put(env, map, ATOM_Y_ROOT, enif_make_double(env, event->y_root), &map);
  enif_make_map_put(env, map, ATOM_STATE, vz_make_event_state(env, event->state), &map);
  enif_make_map_put(env, map, ATOM_IS_HINT, (event->is_hint ? ATOM_TRUE : ATOM_FALSE), &map);
  enif_make_map_put(env, map, ATOM_FOCUS, (event->focus ? ATOM_TRUE : ATOM_FALSE), &map);

  return map;
}

static ERL_NIF_TERM vz_make_scroll_event_struct(ErlNifEnv* env, const PuglEventScroll* event, double width_factor, double height_factor) {
  ERL_NIF_TERM map = enif_make_new_map(env);

  enif_make_map_put(env, map, ATOM__STRUCT__, ATOM_SCROLL_EVENT, &map);
  enif_make_map_put(env, map, ATOM_CONTEXT, ATOM_NIL, &map);
  enif_make_map_put(env, map, ATOM_TYPE, ATOM_SCROLL_EVENT_TYPE, &map);
  enif_make_map_put(env, map, ATOM_TIME, enif_make_uint(env, event->time), &map);
  enif_make_map_put(env, map, ATOM_X, enif_make_double(env, event->x / width_factor), &map);
  enif_make_map_put(env, map, ATOM_Y, enif_make_double(env, event->y / height_factor), &map);
  enif_make_map_put(env, map, ATOM_ABS_X, enif_make_double(env, event->x), &map);
  enif_make_map_put(env, map, ATOM_ABS_Y, enif_make_double(env, event->y), &map);
  enif_make_map_put(env, map, ATOM_X_ROOT, enif_make_double(env, event->x_root), &map);
  enif_make_map_put(env, map, ATOM_Y_ROOT, enif_make_double(env, event->y_root), &map);
  enif_make_map_put(env, map, ATOM_STATE, vz_make_event_state(env, event->state), &map);
  enif_make_map_put(env, map, ATOM_DX, enif_make_double(env, event->dx), &map);
  enif_make_map_put(env, map, ATOM_DY, enif_make_double(env, event->dy), &map);

  return map;
}

static ERL_NIF_TERM vz_make_focus_event_struct(ErlNifEnv* env, const PuglEventFocus* event) {
  ERL_NIF_TERM map = enif_make_new_map(env);
  ERL_NIF_TERM type = event->type == PUGL_FOCUS_IN ? ATOM_FOCUS_IN_EVENT_TYPE : ATOM_FOCUS_OUT_EVENT_TYPE;

  enif_make_map_put(env, map, ATOM__STRUCT__, ATOM_FOCUS_EVENT, &map);
  enif_make_map_put(env, map, ATOM_CONTEXT, ATOM_NIL, &map);
  enif_make_map_put(env, map, ATOM_TYPE, type, &map);
  enif_make_map_put(env, map, ATOM_GRAB, (event->grab ? ATOM_TRUE : ATOM_FALSE), &map);

  return map;
}

static ERL_NIF_TERM vz_make_event_struct(ErlNifEnv* env, const PuglEvent* event, double width_factor, double height_factor) {
  switch(event->type) {
    case PUGL_BUTTON_PRESS:
    case PUGL_BUTTON_RELEASE:
      return vz_make_button_event_struct(env, &event->button, width_factor, height_factor);
    case PUGL_CONFIGURE:
      return vz_make_configure_event_struct(env, &event->configure);
    case PUGL_EXPOSE:
      return vz_make_expose_event_struct(env, &event->expose);
   case PUGL_CLOSE:
      return vz_make_close_event_struct(env, &event->close);
    case PUGL_KEY_PRESS:
    case PUGL_KEY_RELEASE:
      return vz_make_key_event_struct(env, &event->key, width_factor, height_factor);
    case PUGL_ENTER_NOTIFY:
    case PUGL_LEAVE_NOTIFY:
      return vz_make_crossing_event_struct(env, &event->crossing, width_factor, height_factor);
    case PUGL_MOTION_NOTIFY:
      return vz_make_motion_event_struct(env, &event->motion, width_factor, height_factor);
    case PUGL_SCROLL:
      return vz_make_scroll_event_struct(env, &event->scroll, width_factor, height_factor);
    case PUGL_FOCUS_IN:
    case PUGL_FOCUS_OUT:
      return vz_make_focus_event_struct(env, &event->focus);
    case PUGL_NOTHING:
    default:
      return ATOM_NIL;
  };
}

void vz_on_event(PuglView* view, const PuglEvent* event) {
  VZview* vz_view = (VZview*)puglGetHandle(view);
  if(event->type) {
    switch(event->type) {
      case PUGL_CONFIGURE: {
        const PuglEventConfigure *configure = &event->configure;
        vz_view->width = (int)configure->width;
        vz_view->height = (int)configure->height;
        vz_view->width_factor = configure->width / (double)vz_view->init_width;
        vz_view->height_factor = configure->height / (double)vz_view->init_height;
        ERL_NIF_TERM configure_struct = vz_make_configure_event_struct(vz_view->ev_env, configure);
        VZev_array_push(vz_view->ev_array, configure_struct);
        vz_draw(vz_view);
        break;
      }
      case PUGL_EXPOSE:
        vz_draw(vz_view);
        break;
      case PUGL_CLOSE:
        vz_view->shutdown = true;
        break;
      default: {
        ERL_NIF_TERM event_struct = vz_make_event_struct(vz_view->ev_env, event, vz_view->width_factor, vz_view->height_factor);
        VZev_array_push(vz_view->ev_array, event_struct);
      }
    }
  }
}
