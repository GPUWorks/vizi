#ifndef VZ_EVENTS_H_INCLUDED
#define VZ_EVENTS_H_INCLUDED

#include "pugl/pugl.h"

#include <erl_nif.h>
#include <time.h>


ERL_NIF_TERM vz_make_update_event_struct(ErlNifEnv* env, struct timespec *ts);
ERL_NIF_TERM vz_make_event_struct(ErlNifEnv* env, const PuglEvent* event, double width_factor, double height_factor);
void vz_on_event(PuglView* view, const PuglEvent* event);

#endif