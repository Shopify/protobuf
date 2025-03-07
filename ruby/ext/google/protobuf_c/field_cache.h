// Created by: Dave Benvenuti

#ifndef RUBY_PROTOBUF_FIELD_CACHE_H_
#define RUBY_PROTOBUF_FIELD_CACHE_H_

#include <ruby.h>
#include "ruby-upb.h"

struct FieldCache;
typedef struct FieldCache FieldCache;

FieldCache* ruby_to_FieldCache(VALUE field_cache_rb);
VALUE FieldCache_init_rb(upb_MessageDef* msgdef);
void FieldCache_register(VALUE protobuf);
int FieldCache_index_for_ID(FieldCache *cache, ID field_name);
upb_FieldDef* FieldCache_field_for_ID(FieldCache *cache, ID field_name);

#endif // RUBY_PROTOBUF_FIELD_CACHE_H_
