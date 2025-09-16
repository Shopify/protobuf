// Optimized arena fusion implementation with compile-time branching
// This file demonstrates a more efficient approach to disabling arena fusion

#ifndef PROTOBUF_OPTIMIZED_H
#define PROTOBUF_OPTIMIZED_H

#include "protobuf.h"
#include "ruby-upb.h"

// Option 1: Inline function with compile-time optimization
// This completely eliminates the fusion code path when disabled

#ifdef DISABLE_ARENA_FUSION

// When fusion is disabled, this becomes a simple inline reference tracking
static inline void Arena_fuse_inline(VALUE _arena, upb_Arena *other) {
  Arena *arena;
  TypedData_Get_Struct(_arena, Arena, &Arena_type, arena);

  VALUE other_arena_rb = ObjectCache_Get(other);
  if (other_arena_rb != Qnil) {
    rb_ary_push(arena->referenced_arenas, other_arena_rb);
  }
}

#else

// When fusion is enabled, inline the actual fusion
static inline void Arena_fuse_inline(VALUE _arena, upb_Arena *other) {
  Arena *arena;
  TypedData_Get_Struct(_arena, Arena, &Arena_type, arena);

  if (!upb_Arena_Fuse(arena->arena, other)) {
    rb_raise(rb_eRuntimeError,
             "Unable to fuse arenas. This should never happen since Ruby does "
             "not use initial blocks");
  }
}

#endif

// Option 2: Macro-based approach (even more efficient, but less type-safe)
#ifdef DISABLE_ARENA_FUSION

#define ARENA_FUSE(arena_val, other_upb) do { \
  Arena *_arena_struct; \
  TypedData_Get_Struct((arena_val), Arena, &Arena_type, _arena_struct); \
  VALUE _other_rb = ObjectCache_Get(other_upb); \
  if (_other_rb != Qnil) { \
    rb_ary_push(_arena_struct->referenced_arenas, _other_rb); \
  } \
} while(0)

#else

#define ARENA_FUSE(arena_val, other_upb) do { \
  Arena *_arena_struct; \
  TypedData_Get_Struct((arena_val), Arena, &Arena_type, _arena_struct); \
  if (!upb_Arena_Fuse(_arena_struct->arena, other_upb)) { \
    rb_raise(rb_eRuntimeError, \
             "Unable to fuse arenas. This should never happen since Ruby does " \
             "not use initial blocks"); \
  } \
} while(0)

#endif

// Option 3: Function pointer approach (runtime configurable)
typedef void (*arena_fuse_fn)(VALUE, upb_Arena*);

extern arena_fuse_fn Arena_fuse_impl;

// Initialize at startup based on environment or compile flag
void Arena_init_fuse_strategy(void);

#endif // PROTOBUF_OPTIMIZED_H