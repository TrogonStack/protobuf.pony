# Changelog

## Unreleased

### Features

- Wire codec (`Varint`, `ZigZag`, `Tag`, `WireType`), framing + scalar
  codecs (`WireReader`, `WireWriter`, `Scalar`, `LE`), UTF-8 validator,
  typed `WireError` union. 54 tests including property-based roundtrips
  for every protobuf scalar and fuzz tests on the readers.
