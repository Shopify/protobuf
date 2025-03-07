#include <stdlib.h>
#include <string.h>

#include "field_cache.h"

static VALUE cFieldCache = Qnil;

struct FieldCache {
  upb_MessageDef *msgdef;
  ID* field_names; // as Symbols
  size_t size;
};

typedef struct FieldCache FieldCache;

size_t FieldCache_memsize(const void* self) {
  FieldCache* cache = (FieldCache*) self;

  return sizeof(FieldCache) + (cache->size * sizeof(VALUE));
}

static void FieldCache_free(void *_self) {
  FieldCache *self = (FieldCache*)_self;

  if(self->size > 0 && self->field_names != NULL) {
    xfree(self->field_names);
  }

  xfree(self);
}

static const rb_data_type_t FieldCache_type = {
  "Google::Protobuf::FieldCache",
  {NULL, FieldCache_free, FieldCache_memsize},
  .flags = RUBY_TYPED_FREE_IMMEDIATELY, // I don't _think_ RUBY_TYPED_WB_PROTECTED is necessary here since we're not modifying any Ruby objects.
};

// Meant to be initialized from C only.
VALUE FieldCache_init_rb(upb_MessageDef* msgdef) {
  VALUE argv[] = {};
  VALUE field_cache_rb = rb_class_new_instance(0, argv, cFieldCache);

  FieldCache* cache = ruby_to_FieldCache(field_cache_rb);

  cache->msgdef = msgdef;
  cache->size = upb_MessageDef_FieldCount(msgdef);
  cache->field_names = ALLOC_N(ID, cache->size);

  upb_FieldDef* f;

  for (int i = 0; i < cache->size; i++) {
    f = upb_MessageDef_Field(msgdef, i);
    cache->field_names[i] = rb_intern(upb_FieldDef_Name(f));
  }

  return field_cache_rb;
}

FieldCache* ruby_to_FieldCache(VALUE field_cache_rb) {
  FieldCache* cache;
  TypedData_Get_Struct(field_cache_rb, FieldCache, &FieldCache_type, cache);
  return cache;
}

static VALUE FieldCache_alloc(VALUE klass) {
  FieldCache* cache = ALLOC(FieldCache);

  return TypedData_Wrap_Struct(klass, &FieldCache_type, cache);
}

int FieldCache_index_for_ID(FieldCache *cache, ID field_name) {
  for (int i = 0; i < cache->size; i++) {
    if (cache->field_names[i] == field_name) {
      return i;
    }
  }

  return -1;
}

upb_FieldDef* FieldCache_field_for_ID(FieldCache *cache, ID field_name) {
  int index = FieldCache_index_for_ID(cache, field_name);

  if (index == -1) {
    return NULL;
  } else {
    return upb_MessageDef_Field(cache->msgdef, index);
  }
}

static void FieldCache_define_class(VALUE klass) {
  rb_define_alloc_func(cFieldCache, FieldCache_alloc);
}

void FieldCache_register(VALUE protobuf) {
  cFieldCache = rb_define_class_under(protobuf, "FieldCache", rb_cObject);

  FieldCache_define_class(cFieldCache);
  rb_gc_register_address(&cFieldCache);
}
