import bitio
import options
import streams

type
  ArithmeticCoder = ref object of RootObj
    low: uint
    high: uint
    step: uint
    scale: uint
    buffer: uint32
    bitbuffer: BitStream

  CountBackingStore = ref object of RootObj
    cum_count: array[257, uint32]
    total: uint32
    default: uint32

  ModelOrder1 = ref object of RootObj
    ac: ArithmeticCoder
    cum_count: ptr CountBackingStore
    cum_count_lookback: array[256, CountBackingStore]
    cum_count_current: CountBackingStore
    last_symbol: Option[uint8]

proc newArithmeticCoder(data: seq[uint8] = @[]): ArithmeticCoder =
  new result
  result.bitbuffer = newBitStream(data)
  result.low = 0
  result.high = 0x7FFFFFFF
  result.scale = 0
  result.buffer = 0
  result.step = 0

proc newModelOrder1(data: seq[uint8] = @[]): ModelOrder1 =
  new result
  for i in 0..255:
    result.cum_count_lookback[i] = new CountBackingStore
    for j in 0..256:
      result.cum_count_lookback[i].cum_count[j] = 0
    result.cum_count_lookback[i].cum_count[254] = 1
    result.cum_count_lookback[i].cum_count[256] = 1
    result.cum_count_lookback[i].total = 2
    result.cum_count_lookback[i].default = 0

  result.cum_count_current = new CountBackingStore
  for i in 0..256:
    result.cum_count_current.cum_count[i] = 1
  result.cum_count_current.total = 257
  result.cum_count_current.default = 1

  result.last_symbol = none(uint8)
  result.cum_count = addr result.cum_count_lookback[0]
  result.ac = newArithmeticCoder(data)

proc cumulate_freqencies(model: ModelOrder1, symbol: uint8): (uint8, uint32, uint32, uint32) =
  var ret = 0u8
  var adjusted_symbol = symbol
  if model.cum_count.cum_count[symbol].bool:
    if symbol == 254 and model.cum_count.default == 0:
      ret = 254
  else:
    ret = 254
    adjusted_symbol = 254

  var low_count = 0u32
  var j = 0u32
  while j < adjusted_symbol:
    low_count += model.cum_count.cum_count[j]
    j += 1

  var high_count = low_count + model.cum_count.cum_count[adjusted_symbol]
  var total = model.cum_count.total

  if ret == 254:
    model.cum_count = addr model.cum_count_current

  (ret, low_count, high_count, total)

proc update_model(model: ModelOrder1, symbol: uint8) =
 if symbol == 256:
  model.cum_count.cum_count[256] += 1
  model.cum_count.total += 1
 else:
  if model.last_symbol.isSome:
   model.cum_count = addr model.cum_count_lookback[model.last_symbol.get]
   model.cum_count.cum_count[symbol] += 1
   model.cum_count.total += 1
  model.last_symbol = some(symbol)
  model.cum_count = addr model.cum_count_lookback[symbol]

proc determine_symbol(model: ModelOrder1, value: uint): (uint8, uint32, uint32) =
  var low_count = 0u32
  var symbol = 0u8

  while low_count + model.cum_count.cum_count[symbol] <= value:
    low_count += model.cum_count.cum_count[symbol]
    symbol += 1

  var high_count = low_count + model.cum_count.cum_count[symbol]

  if symbol == 254 and model.cum_count.default == 0:
    model.cum_count = addr model.cum_count_current

  (symbol, low_count, high_count)

const g_FirstQuarter  = 0x20000000u32
const g_Half          = 0x40000000u32
const g_ThirdQuarter  = 0x60000000u32
const g_FourthQuarter = 0x80000000u32

proc decode_target(ac: ArithmeticCoder, total: uint): uint =
  ac.step = ( ac.high - ac.low + 1 ) div total
  return ( ac.buffer - ac.low ) div ac.step

proc decode(ac: ArithmeticCoder, low_count: uint, high_count: uint) =
 ac.high = ac.low + ac.step * high_count - 1
 ac.low = ac.low + ac.step * low_count

 while ( ac.high < g_Half ) or ( ac.low >= g_Half ):
  if ac.high < g_Half:
   ac.low = ac.low * 2
   ac.high = ac.high * 2 + 1
   ac.buffer = 2 * ac.buffer + ac.bitbuffer.read().uint32
  elif ac.low >= g_Half:
   ac.low = 2 * ac.low - g_FourthQuarter
   ac.high = 2 * ac.high - g_FourthQuarter + 1
   ac.buffer = 2 * ac.buffer - g_FourthQuarter + ac.bitbuffer.read().uint32
  ac.scale = 0

 while ( g_FirstQuarter <= ac.low ) and ( ac.high < g_ThirdQuarter ):
  ac.scale += 1
  ac.low = 2 * ac.low - g_Half
  ac.high = 2 * ac.high - g_Half + 1
  ac.buffer = 2 * ac.buffer - g_Half + ac.bitbuffer.read().uint32

proc encode(ac: ArithmeticCoder, low_count: uint32, high_count: uint32, total: uint32) =
  ac.step = ( ac.high - ac.low + 1 ) div total;
  ac.high = ac.low + ac.step * high_count - 1;
  ac.low = ac.low + ac.step * low_count;

  while ac.high < g_Half or ac.low >= g_Half:
    if ac.high < g_Half:
      ac.bitbuffer.write(0);
      ac.low = ac.low * 2;
      ac.high = ac.high * 2 + 1;

      while ac.scale > 0:
        ac.bitbuffer.write(1);
        ac.scale -= 1
    elif ac.low >= g_Half:
      ac.bitbuffer.write(1);
      ac.low = 2 * ac.low - g_FourthQuarter;
      ac.high = 2 * ac.high - g_FourthQuarter + 1;

      while ac.scale > 0:
        ac.bitbuffer.write(0);
        ac.scale -= 1

  while g_FirstQuarter <= ac.low and ac.high < g_ThirdQuarter:
    ac.scale += 1
    ac.low = 2 * ac.low - g_Half
    ac.high = 2 * ac.high - g_Half + 1

proc encode_finish(ac: ArithmeticCoder) =
 if ac.low < g_FirstQuarter:
  ac.bitbuffer.write( 0 );

  for _ in 0u32..ac.scale:
   ac.bitbuffer.write(1);
 else:
  ac.bitbuffer.write( 1 )

 ac.bitbuffer.flush()

proc decode_start(ac: ArithmeticCoder) =
  var i = 0
  while i < 31:
    ac.buffer = (ac.buffer shl 1) or ac.bitbuffer.read()
    inc i

proc decode*(compressed_data: seq[uint8], decompressed_size: uint32): seq[uint8] =
  var model = newModelOrder1(compressed_data)
  model.ac.decode_start()

  while true:
    var default = model.cum_count.default
    var value = model.ac.decode_target(model.cum_count.total)

    let (symbol, low_count, high_count) = model.determine_symbol(value)

    if symbol != 254 or default != 0:
      result.add(symbol)
      if result.len.uint32 >= decompressed_size:
        break

    model.ac.decode(low_count, high_count)

    if symbol != 254 or default != 0:
      model.update_model(symbol)

proc encode*(decompressed_data: seq[uint8]): seq[uint8] =
  var model = newModelOrder1()

  for symbol in decompressed_data:
    block innerloop:
      while true:
        var (ret, low_count, high_count, total) = model.cumulate_freqencies(symbol);
        model.ac.encode(low_count, high_count, total);
        if ret != 254:
          break innerloop
    model.update_model(symbol);

  var pos = model.ac.bitbuffer.string_stream.getPosition()
  while pos == model.ac.bitbuffer.string_stream.getPosition():
    block innerloop:
      while true:
        var (ret, low_count, high_count, total) = model.cumulate_freqencies(0)
        model.ac.encode(low_count, high_count, total)
        if ret != 254:
          break innerloop
    model.update_model(0)

  model.ac.encode_finish()
  model.ac.bitbuffer.string_stream.write(0u8)

  model.ac.bitbuffer.string_stream.setPosition(0)
  var result_string = model.ac.bitbuffer.string_stream.readAll()
  for c in result_string:
    result.add(c.uint8)
