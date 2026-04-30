# Changelog

## 0.1.0 - 2026-04-28

### Features

- **Varint codec** — `Varint` encodes/decodes unsigned varints;
  `ZigZag` handles sint32/sint64 zig-zag encoding.
- **Tag codec** — `Tag` and `TagCodec` encode/decode field-number + wire-type
  pairs; `TagDecoded` carries the result.
- **Wire types** — `WireType` union (`WireVarint`, `WireFixed64`,
  `WireLenDelim`, `WireFixed32`) with `WireTypeFromValue` dispatcher.
- **Scalar codec** — `Scalar` covers all proto3 scalar types (bool,
  int32/64, uint32/64, sint32/64, fixed32/64, sfixed32/64, float, double,
  string, bytes), mapping each to its correct wire encoding.
- **Little-endian framing** — `LE` reads/writes 32- and 64-bit fixed values.
- **Streaming reader/writer** — `WireReader` and `WireWriter` provide
  sequential encode/decode over `Array[U8]` buffers.
- **UTF-8 validator** — rejects invalid byte sequences before they reach
  string fields.
- **Typed errors** — `WireError` union (`WireTruncated`, `WireOverflow`,
  `WireBadTag`, `WireInvalidUtf8`) gives callers precise failure reasons.
- 54 tests including property-based roundtrips for every scalar type and
  fuzz tests confirming arbitrary bytes never panic the readers.
