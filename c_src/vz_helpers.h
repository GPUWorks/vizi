#ifndef VZ_HELPERS_H_INCLUDED
#define VZ_HELPERS_H_INCLUDED

#include <stdio.h>


#define OK(msg) enif_make_tuple2(env, ATOM_OK, msg)
#define BADARG enif_make_badarg(env)
#define __UNUSED(v) ((void)(v))
#define LOG(fmt, ...) do { fprintf(stderr, fmt, __VA_ARGS__); } while (0)

#ifndef MIN
#    define MIN(a, b) (((a) < (b)) ? (a) : (b))
#endif

#ifndef MAX
#    define MAX(a, b) (((a) > (b)) ? (a) : (b))
#endif

#define VZ_ASYNC_DECL(decl, fields_block, handler_block, caller_block)                        \
  struct decl ## _args fields_block;                                                          \
  static void decl ## _handler(VZview *vz_view, void *void_args) {                            \
    NVGcontext *ctx = vz_view->ctx;                                                           \
    struct decl ## _args *args = (struct decl ## _args*)void_args;                            \
    do handler_block while(0);                                                                \
  }                                                                                           \
  static ERL_NIF_TERM decl(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {             \
    struct decl ## _args *args = (struct decl ## _args*)malloc(sizeof(struct decl ## _args)); \
    bool execute = false;                                                                     \
    VZview *vz_view;                                                                          \
    VZop vz_op;                                                                               \
    vz_op.handler = decl ## _handler;                                                         \
    vz_op.args = args;                                                                        \
    ERL_NIF_TERM ret = argv[0];                                                               \
    if(!enif_get_resource(env, argv[0], vz_view_res, (void**)&vz_view)) {                     \
      goto err;                                                                               \
    }                                                                                         \
    do caller_block while(0);                                                                 \
    enif_mutex_lock(vz_view->lock);                                                           \
    VZop_array_push(vz_view->op_array, vz_op);                                                \
    if(execute) {                                                                             \
      enif_cond_signal(vz_view->execute_cv);                                                  \
      enif_mutex_unlock(vz_view->lock);                                                       \
      return ATOM_OK;                                                                         \
    }                                                                                         \
    else {                                                                                    \
      enif_mutex_unlock(vz_view->lock);                                                       \
      return ret;                                                                             \
    }                                                                                         \
    err:                                                                                      \
    free(args);                                                                               \
    return BADARG;                                                                            \
  }                                                                                           \

#define VZ_GET_NUMBER(env, term, value)     \
  if(!enif_get_double(env, term, &value)) { \
    int valuei;                             \
    if(enif_get_int(env, term, &valuei))    \
      value = (double)valuei;               \
    else goto err;                          \
  }                                         \

#define VZ_GET_NUMBER_255(env, term, value) \
if(!enif_get_double(env, term, &value)) {   \
  int valuei;                               \
  if(enif_get_int(env, term, &valuei))      \
    value = (double)valuei / 255.0;         \
  else goto err;                            \
}                                           \

#define VZ_HANDLER_SEND(msg)                                                                                    \
  do {                                                                                                          \
    enif_send(NULL, &vz_view->view_pid, vz_view->msg_env, enif_make_tuple2(vz_view->msg_env, ATOM_REPLY, msg)); \
    enif_clear_env(vz_view->msg_env);                                                                           \
  } while(0)                                                                                                    \

#define VZ_HANDLER_SEND_BADARG    \
  do {                            \
    VZ_HANDLER_SEND(ATOM_BADARG); \
    return;                       \
  } while(0)                      \

#define VZ_ARRAY_DECLARE(type)                            \
typedef struct type##_array {                             \
  type *array;                                            \
  unsigned start_pos, end_pos, size;                      \
} type##_array;                                           \
type##_array* type##_array_new(unsigned initial_size);    \
void type##_array_push(type##_array *array, type value);  \
void type##_array_clear(type##_array *array);             \
void type##_array_free(type##_array *array);              \



#define VZ_ARRAY_DEFINE(type)                                                 \
type##_array* type##_array_new(unsigned initial_size) {                       \
  type##_array *array = (type##_array*)malloc(sizeof(type##_array));          \
  array->array = (type*)malloc(initial_size * sizeof(type));                  \
  array->start_pos = 0;                                                       \
  array->end_pos = 0;                                                         \
  array->size = initial_size;                                                 \
  return array;                                                               \
}                                                                             \
void type##_array_push(type##_array *array, type value) {                     \
  if(array->end_pos == array->size) {                                         \
    array->size *= 2;                                                         \
    array->array = (type*)realloc(array->array, array->size * sizeof(type));  \
  }                                                                           \
  array->array[array->end_pos++] = value;                                     \
}                                                                             \
void type##_array_clear(type##_array *array) {                                \
  array->start_pos = 0;                                                       \
  array->end_pos = 0;                                                         \
}                                                                             \
void type##_array_free(type##_array *array) {                                 \
  free(array->array);                                                         \
  free(array);                                                                \
}                                                                             \

#endif