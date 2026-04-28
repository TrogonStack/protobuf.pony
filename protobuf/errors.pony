primitive WireTruncated
  fun label(): String val => "truncated"
  fun message(): String val =>
    "buffer ended before varint was complete"

primitive WireOverflow
  fun label(): String val => "overflow"
  fun message(): String val =>
    "varint exceeds 10 bytes (max for U64)"

primitive WireBadTag
  fun label(): String val => "bad_tag"
  fun message(): String val =>
    "tag has zero field number or unknown wire type"

primitive WireInvalidUtf8
  fun label(): String val => "invalid_utf8"
  fun message(): String val =>
    "string field bytes are not valid UTF-8"

type WireError is
  (WireTruncated | WireOverflow | WireBadTag | WireInvalidUtf8)
