#include "vz_atoms.h"
#include "vz_helpers.h"
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

#ifdef VZ_LOG_TIMING
// Lifted from: https://gist.github.com/diabloneo/9619917
void timespec_diff(struct timespec *start, struct timespec *stop, struct timespec *result) {
    if ((stop->tv_nsec - start->tv_nsec) < 0) {
        result->tv_sec = stop->tv_sec - start->tv_sec - 1;
        result->tv_nsec = stop->tv_nsec - start->tv_nsec + 1000000000;
    } else {
        result->tv_sec = stop->tv_sec - start->tv_sec;
        result->tv_nsec = stop->tv_nsec - start->tv_nsec;
    }

    return;
}
#endif

#if defined(LINUX) || defined(MACOS)
static inline void set_next_time_point(struct timespec* ts, int frame_rate) {
  clock_gettime(CLOCK_MONOTONIC, ts);
  long interval = 1000000000 / frame_rate;
  unsigned long rem = (ts->tv_nsec + interval) % 1000000000;
  if(rem < ts->tv_nsec)
    ts->tv_sec += 1;
  ts->tv_nsec = rem;
}
#elif defined(WINDOWS)
static inline void set_next_time_point(ULARGE_INTEGER* ts, int frame_rate) {
	FILETIME ft;
	GetSystemTimeAsFileTime(&ft);
	long interval = 10000000 / frame_rate;
	ts->LowPart = ft.dwLowDateTime;
	ts->HighPart = ft.dwHighDateTime;
	ts->QuadPart += interval;
}
#endif

#if defined(LINUX) || defined(MACOS)
static inline void sleep_until(struct timespec *ts) {
  if(clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, ts, NULL) == EINTR) {
    sleep_until(ts);
  }
}
#elif defined(WINDOWS)
// Slightly modified version lifted from: https://gist.github.com/Youka/4153f12cf2e17a77314c
static inline void sleep_until(ULARGE_INTEGER *ts) {
	/* Declarations */
	HANDLE timer;	/* Timer handle */
	LARGE_INTEGER li;	/* Time defintion */
						/* Create timer */
	if (!(timer = CreateWaitableTimer(NULL, TRUE, NULL)))
		return;
	/* Set timer properties */
	li.QuadPart = ts->QuadPart;
	if (!SetWaitableTimer(timer, &li, 0, NULL, NULL, FALSE)) {
		CloseHandle(timer);
		return;
	}
	/* Start & wait for timer */
	WaitForSingleObject(timer, INFINITE);
	/* Clean resources */
	CloseHandle(timer);
}
#endif

static inline void vz_begin_frame(VZview *vz_view) {
  glViewport(0, 0, vz_view->width, vz_view->height);
  glClearColor(vz_view->bg.r, vz_view->bg.g, vz_view->bg.b, vz_view->bg.a);
  glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT|GL_STENCIL_BUFFER_BIT);

  nvgBeginFrame(vz_view->ctx, vz_view->width, vz_view->height, vz_view->pixel_ratio);
  nvgScale(vz_view->ctx, vz_view->width_factor, vz_view->height_factor);
}

static inline void vz_end_frame(VZview *vz_view) {
  nvgEndFrame(vz_view->ctx);
}

static inline void vz_send_draw(VZview *vz_view) {
  unsigned time = 0;//(vz_view->time.tv_sec * 1000) + (vz_view->time.tv_nsec / 1000000);
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

  if(a->end_pos > 0 || vz_view->force_send_events) {
    ERL_NIF_TERM events = enif_make_list_from_array(vz_view->ev_env, a->array, a->end_pos - a->start_pos);
    enif_send(NULL, &vz_view->view_pid, vz_view->ev_env, enif_make_tuple2(vz_view->ev_env, ATOM_EVENT, events));
    enif_clear_env(vz_view->ev_env);
    VZev_array_clear(a);
    vz_view->force_send_events = false;
  }
}

#if defined(LINUX) || defined(MACOS)
static inline void vz_wait_for_frame(VZview *vz_view, PuglView *view, struct timespec *ts) {
#elif defined(WINDOWS)
static inline void vz_wait_for_frame(VZview *vz_view, PuglView *view, ULARGE_INTEGER *ts) {
#endif
  if(vz_view->redraw_mode == VZ_MANUAL) {
    enif_mutex_unlock(vz_view->lock);
    puglWaitForEvent(view);
    enif_mutex_lock(vz_view->lock);
  }
  else {
    enif_mutex_unlock(vz_view->lock);
    sleep_until(ts);
    enif_mutex_lock(vz_view->lock);
    //vz_view->time = *ts;
    set_next_time_point(ts, vz_view->frame_rate);
  }
}

void* vz_view_thread(void *p) {
#if defined(LINUX) || defined(MACOS)
  struct timespec ts;
#elif defined(WINDOWS)
	ULARGE_INTEGER ts;
#endif

  VZview *vz_view = (VZview*) p;
  PuglView *view;

#ifdef VZ_LOG_TIMING
  struct timespec ts1, ts2, tsdiff;
  int num_frames = 120;
  double_array *timings = double_array_new(num_frames);
  double avg;
#endif

  enif_mutex_lock(vz_view->lock);
  set_next_time_point(&ts, vz_view->frame_rate);

  view = puglInit(NULL, NULL);
  puglSetHandle(view, vz_view);
  puglSetEventFunc(view, vz_on_event);
  puglInitContextType(view, PUGL_GL);
  puglInitWindowMinSize(view, vz_view->min_width, vz_view->min_height);
  puglInitResizable(view, vz_view->resizable);
  puglInitWindowParent(view, vz_view->parent);
  puglInitWindowSize(view, vz_view->width, vz_view->height);
  puglCreateWindow(view, vz_view->title);

  puglEnterContext(view);
  if (!(glewInit() == GLEW_OK &&
        (vz_view->ctx = nvgCreateGL2(NVG_ANTIALIAS|NVG_STENCIL_STROKES))))
    goto shutdown;
  puglLeaveContext(view, false);

  puglShowWindow(view);
  vz_view->view = view;

  while(!vz_view->shutdown) {
#ifdef VZ_LOG_TIMING
	  clock_gettime(CLOCK_MONOTONIC, &ts1);
#endif

    puglProcessEvents(view);
    vz_send_events(vz_view);
    if (vz_view->redraw_mode == VZ_INTERVAL)
      puglPostRedisplay(view);

#ifdef VZ_LOG_TIMING
    clock_gettime(CLOCK_MONOTONIC, &ts2);
    timespec_diff(&ts1, &ts2, &tsdiff);
    double_array_push(timings, tsdiff.tv_nsec / 1000000.0);
    if(timings->end_pos == num_frames) {
      avg = 0.0;
      for(unsigned i = 0; i < num_frames; ++i) {
        avg += timings->array[i];
      }
      double_array_clear(timings);
      avg /= (double)num_frames;
      printf("average of %d frames: %.3f ms\r\n", num_frames, avg);
    }
#endif
    vz_release_managed_resources(vz_view);
    vz_wait_for_frame(vz_view, view, &ts);
  }
  shutdown:
  enif_send(NULL, &vz_view->view_pid, NULL, ATOM_SHUTDOWN);
  if(vz_view->ctx) {
    nvgDeleteGL2(vz_view->ctx);
  }
  if(view)
    puglDestroy(view);

#ifdef VZ_LOG_TIMING
  double_array_free(timings);
#endif

  enif_mutex_unlock(vz_view->lock);
  return NULL;
}

void vz_draw(VZview *vz_view) {
  vz_begin_frame(vz_view);
  vz_send_draw(vz_view);
  vz_run(vz_view);
  vz_end_frame(vz_view);
}
