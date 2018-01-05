#include "vz_atoms.h"
#include "vz_resources.h"
#include "vz_events.h"

#include "pugl/pugl.h"
#include "pugl/glew.h"
#include "pugl/gl.h"
#include "nanovg.h"
#define NANOVG_GL2_IMPLEMENTATION
#include "nanovg_gl.h"

#include <erl_nif.h>
#include <time.h>
#include <errno.h>

static inline void set_next_time_point(struct timespec* ts, int frame_rate) {
  clock_gettime(CLOCK_MONOTONIC, ts);
  long interval = 1000000000 / frame_rate;
  unsigned long rem = (ts->tv_nsec + interval) % 1000000000;
  if(rem < ts->tv_nsec)
    ts->tv_sec += 1;
  ts->tv_nsec = rem;
}

static inline void sleep_until(const struct timespec *ts) {
  if(clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, ts, NULL) == EINTR)
    sleep_until(ts);
}

static inline void vz_begin_frame(VZview *vz_view) {
  glViewport(0, 0, vz_view->width, vz_view->height);
  glClearColor(vz_view->bg.r, vz_view->bg.g, vz_view->bg.b, vz_view->bg.a);
  glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT|GL_STENCIL_BUFFER_BIT);

  nvgBeginFrame(vz_view->ctx, vz_view->width, vz_view->height, vz_view->pixel_ratio);
  nvgScale(vz_view->ctx, vz_view->width_factor, vz_view->height_factor);
}

static inline void vz_end_frame(VZview *vz_view) {
  nvgEndFrame(vz_view->ctx);
  vz_view->redraw = false;
}

static inline void vz_send_draw(VZview *vz_view) {
  unsigned time = (vz_view->time.tv_sec * 1000) + (vz_view->time.tv_nsec / 1000000);
  ERL_NIF_TERM msg = enif_make_tuple2(vz_view->msg_env, ATOM_DRAW, enif_make_uint(vz_view->msg_env, time));
  enif_send(NULL, &vz_view->view_pid, vz_view->msg_env, msg);
  enif_clear_env(vz_view->msg_env);
}

static inline void vz_run(VZview *vz_view) {
  vz_view->busy = true;
  VZop_array *a = vz_view->op_array;
  do {
    enif_cond_wait(vz_view->execute_cv, vz_view->lock);
    for(unsigned i = a->start_pos; i < a->end_pos; ++i) {
      VZop op = a->array[i];
      op.handler(vz_view, op.args);
    }
    a->start_pos = a->end_pos;
  } while(vz_view->busy);
  for(unsigned i = 0; i < a->end_pos; ++i) {
    free(a->array[i].args);
  }
  VZop_array_clear(a);
}

static inline void vz_send_events(VZview *vz_view) {
  VZev_array *a = vz_view->ev_array;

  if(vz_view->redraw_mode == VZ_INTERVAL) {
    ERL_NIF_TERM update_event = vz_make_update_event_struct(vz_view->msg_env, &vz_view->time);
    VZev_array_push(a, update_event);
  }

  ERL_NIF_TERM events = enif_make_list_from_array(vz_view->msg_env, a->array, a->end_pos - a->start_pos);
  enif_send(NULL, &vz_view->view_pid, vz_view->msg_env, enif_make_tuple2(vz_view->msg_env, ATOM_EVENT, events));
  enif_clear_env(vz_view->msg_env);
  VZev_array_clear(a);
}

static inline void vz_wait_for_frame(VZview *vz_view, PuglView *view, struct timespec *ts) {
  if(vz_view->redraw_mode == VZ_MANUAL) {
    enif_mutex_unlock(vz_view->lock);
    puglWaitForEvent(view);
    enif_mutex_lock(vz_view->lock);
  }
  else {
    enif_mutex_unlock(vz_view->lock);
    sleep_until(ts);
    enif_mutex_lock(vz_view->lock);
    vz_view->time = *ts;
    set_next_time_point(ts, vz_view->frame_rate);
  }
}

void* vz_view_thread(void *p) {
  struct timespec ts;
  VZview *vz_view = (VZview*) p;
  PuglView *view;

  enif_mutex_lock(vz_view->lock);

  set_next_time_point(&ts, vz_view->frame_rate);
  view = puglInit(NULL, NULL);
  vz_view->view = view;

  puglSetHandle(view, vz_view);
  puglSetEventFunc(view, vz_on_event);
  puglInitContextType(view, PUGL_GL);
  if(vz_view->min_width > 0 && vz_view->min_height > 0)
    puglInitWindowMinSize(view, vz_view->min_width, vz_view->min_height);
  puglInitResizable(view, vz_view->resizable);

  if(vz_view->parent)
    puglInitWindowParent(view, vz_view->parent);
  puglInitWindowSize(view, vz_view->width, vz_view->height);
  puglCreateWindow(view, vz_view->title);

  puglEnterContext(view);

  if (!(glewInit() == GLEW_OK &&
        (vz_view->ctx = nvgCreateGL2(NVG_ANTIALIAS|NVG_STENCIL_STROKES))))
    goto shutdown;

  puglLeaveContext(view, false);
  puglShowWindow(view);

  while(!vz_view->shutdown) {
    puglEnterContext(view);
    puglProcessEvents(view);
    vz_send_events(vz_view);
    vz_run(vz_view);
    if(vz_view->shutdown) goto shutdown;
    if(vz_view->redraw_mode == VZ_INTERVAL || vz_view->redraw) {
      vz_begin_frame(vz_view);
      vz_send_draw(vz_view);
      vz_run(vz_view);
      vz_end_frame(vz_view);
    }
    puglLeaveContext(view, true);
    vz_wait_for_frame(vz_view, view, &ts);
  }
  shutdown:
  enif_send(NULL, &vz_view->view_pid, NULL, ATOM_SHUTDOWN);
  if(vz_view->ctx) {
    for(unsigned i = 0; i < vz_view->res_array->end_pos; ++i) {
      nvgDeleteImage(vz_view->ctx, vz_view->res_array->array[i]);
    }
    nvgDeleteGL2(vz_view->ctx);
  }
  if(view)
    puglDestroy(view);

  enif_mutex_unlock(vz_view->lock);
  return NULL;
}