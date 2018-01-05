#ifndef VZ_EVENTS_H_INCLUDED
#define VZ_EVENTS_H_INCLUDED

#include "pugl/pugl.h"

#include <erl_nif.h>
#include <time.h>


void vz_on_event(PuglView* view, const PuglEvent* event);

#endif