import streams

type
  BitStream* = ref object of RootObj
    string_stream*: StringStream
    buffer*: uint8
    bit_count*: uint8

proc newBitStream*(data: seq[uint8]): BitStream =
  new result
  result.string_stream = newStringStream(cast[string](data))
  result.buffer = 0
  result.bit_count = 0

proc write*(bit_stream: BitStream, bit: uint8) =
 # echo bit
 bit_stream.buffer = (bit_stream.buffer shl 1) or bit
 bit_stream.bit_count += 1

 if bit_stream.bit_count == 8:
  bit_stream.string_stream.write(bit_stream.buffer)
  bit_stream.bit_count = 0

proc flush*(bit_stream: BitStream) =
  while bit_stream.bit_count != 0:
    bit_stream.write(0);

proc read*(bit_stream: BitStream): uint8 =
 if bit_stream.bit_count == 0:
  if not bit_stream.string_stream.atEnd:
   bit_stream.buffer = bit_stream.string_stream.readUint8()
  else:
   bit_stream.buffer = 0;

  bit_stream.bit_count = 8;

 var bit = (bit_stream.buffer shr 7)
 bit_stream.buffer = bit_stream.buffer shl 1
 bit_stream.bit_count -= 1
 return bit