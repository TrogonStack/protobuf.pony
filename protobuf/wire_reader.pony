class ref WireReader
  let _buf: Array[U8] val
  var _pos: USize

  new ref create(buf: Array[U8] val, offset: USize = 0) =>
    _buf = buf
    _pos = offset

  fun box at_end(): Bool =>
    _pos >= _buf.size()

  fun box position(): USize =>
    _pos

  fun ref read_varint(): (U64 | WireError) =>
    match Varint.decode(_buf, _pos)
    | let d: VarintDecoded =>
      _pos = _pos + d.bytes_read
      d.value
    | let e: WireError => e
    end

  fun ref read_tag(): (Tag | WireError) =>
    match TagCodec.decode(_buf, _pos)
    | let d: TagDecoded =>
      _pos = _pos + d.bytes_read
      d.tag_value
    | let e: WireError => e
    end

  fun ref read_fixed32(): (U32 | WireError) =>
    match LE.u32_from_le_bytes(_buf, _pos)
    | let v: U32 =>
      _pos = _pos + 4
      v
    | let e: WireError => e
    end

  fun ref read_fixed64(): (U64 | WireError) =>
    match LE.u64_from_le_bytes(_buf, _pos)
    | let v: U64 =>
      _pos = _pos + 8
      v
    | let e: WireError => e
    end

  fun ref read_len_delim(): (Array[U8] val | WireError) =>
    match read_varint()
    | let n: U64 =>
      let len = n.usize()
      if (_buf.size() - _pos) < len then return WireTruncated end
      let buf_local: Array[U8] val = _buf
      let pos_local: USize = _pos
      _pos = _pos + len
      recover val
        let a = Array[U8](len)
        var i: USize = 0
        while i < len do
          try a.push(buf_local(pos_local + i)?) end
          i = i + 1
        end
        a
      end
    | let e: WireError => e
    end

  fun ref read_string(): (String val | WireError) =>
    match read_len_delim()
    | let bytes: Array[U8] val =>
      if not _Utf8Check(bytes) then return WireInvalidUtf8 end
      recover val String.from_array(bytes) end
    | let e: WireError => e
    end

  fun ref skip(wt: WireType): (None | WireError) =>
    match wt
    | WireVarint =>
      match read_varint()
      | let _: U64 => None
      | let e: WireError => e
      end
    | WireFixed64 =>
      if (_buf.size() - _pos) < 8 then
        WireTruncated
      else
        _pos = _pos + 8
        None
      end
    | WireFixed32 =>
      if (_buf.size() - _pos) < 4 then
        WireTruncated
      else
        _pos = _pos + 4
        None
      end
    | WireLenDelim =>
      match read_varint()
      | let n: U64 =>
        let len = n.usize()
        if (_buf.size() - _pos) < len then
          WireTruncated
        else
          _pos = _pos + len
          None
        end
      | let e: WireError => e
      end
    end

primitive _Utf8DecodeStep
  // Returns (width, codepoint, min_cp) for the UTF-8 sequence starting at i,
  // or errors if the lead byte is invalid, the sequence is truncated, or any
  // continuation byte lacks the 10xxxxxx prefix.
  fun apply(buf: Array[U8] box, i: USize): (USize, U32, U32) ? =>
    let n = buf.size()
    let b = buf(i)?
    if b < 0x80 then
      (1, b.u32(), 0)
    elseif (b and 0xE0) == 0xC0 then
      if (i + 2) > n then error end
      let c1 = buf(i + 1)?
      if (c1 and 0xC0) != 0x80 then error end
      let cp = ((b.u32() and 0x1F) << 6) or (c1.u32() and 0x3F)
      (2, cp, 0x80)
    elseif (b and 0xF0) == 0xE0 then
      if (i + 3) > n then error end
      let c1 = buf(i + 1)?
      let c2 = buf(i + 2)?
      if ((c1 and 0xC0) != 0x80) or ((c2 and 0xC0) != 0x80) then error end
      let cp = ((b.u32() and 0x0F) << 12) or
        ((c1.u32() and 0x3F) << 6) or
        (c2.u32() and 0x3F)
      (3, cp, 0x800)
    elseif (b and 0xF8) == 0xF0 then
      if (i + 4) > n then error end
      let c1 = buf(i + 1)?
      let c2 = buf(i + 2)?
      let c3 = buf(i + 3)?
      if ((c1 and 0xC0) != 0x80) or
        ((c2 and 0xC0) != 0x80) or
        ((c3 and 0xC0) != 0x80) then error end
      let cp = ((b.u32() and 0x07) << 18) or
        ((c1.u32() and 0x3F) << 12) or
        ((c2.u32() and 0x3F) << 6) or
        (c3.u32() and 0x3F)
      (4, cp, 0x10000)
    else
      error
    end

primitive _Utf8Check
  fun apply(buf: Array[U8] box): Bool =>
    var i: USize = 0
    let n = buf.size()
    while i < n do
      try
        (let width, let cp, let min_cp) = _Utf8DecodeStep(buf, i)?
        if cp < min_cp then return false end
        if (cp >= 0xD800) and (cp <= 0xDFFF) then return false end
        if cp > 0x10FFFF then return false end
        i = i + width
      else
        return false
      end
    end
    true
