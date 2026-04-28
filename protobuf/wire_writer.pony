class ref WireWriter
  // Field is iso so done() can return iso^. _take/_give swap the iso out
  // because accessing iso through `this` (ref) aliases as tag.
  var _buf: Array[U8] iso

  new ref create(initial_capacity: USize = 64) =>
    _buf = recover iso Array[U8](initial_capacity) end

  fun ref _take(): Array[U8] iso^ =>
    _buf = recover iso Array[U8] end

  fun ref _give(buf: Array[U8] iso) =>
    _buf = consume buf

  fun ref write_varint(v: U64) =>
    _give(Varint.push_into(_take(), v))

  fun ref write_tag(t: Tag) =>
    write_varint(t.encoded_value())

  fun ref write_fixed32(v: U32) =>
    _give(LE.push_u32_le(_take(), v))

  fun ref write_fixed64(v: U64) =>
    _give(LE.push_u64_le(_take(), v))

  fun ref write_len_delim(payload: Array[U8] box) =>
    // Array.append takes a non-sendable ReadSeq, which iso can't accept via
    // auto-recovery — iterate by index so push(U8) auto-recovers cleanly.
    let n = payload.size()
    write_varint(n.u64())
    let buf = _take()
    var i: USize = 0
    while i < n do
      try buf.push(payload(i)?) end
      i = i + 1
    end
    _give(consume buf)

  fun ref write_string(s: String box) =>
    // String.array() requires val receiver; iterate by byte index instead so
    // a box-cap caller doesn't have to recover/clone the String to write it.
    let n = s.size()
    write_varint(n.u64())
    let buf = _take()
    var i: USize = 0
    while i < n do
      try buf.push(s(i)?) end
      i = i + 1
    end
    _give(consume buf)

  fun ref write_string_field(field_number: U32, s: String box) =>
    // Proto3 implicit presence: empty strings are not emitted.
    if s.size() > 0 then
      write_tag(Tag(field_number, WireLenDelim))
      write_string(s)
    end

  // Pony reserves `consume` as a keyword and rejects it as a method name.
  fun ref done(): Array[U8] iso^ =>
    _take()
