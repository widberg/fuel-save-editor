import arithmeticcoder
import binaryparse
import crc32
import streams

createParser(SaveGameData):
  lu32: compressed_size
  lu32: decompressed_size
  lu8: compressed_data[compressed_size - 8]
  lu8: _[199996 - compressed_size - 1]
  lu8: version

createParser(SaveGame):
  lu32: xlive_header_size
  lu32: xlive_crc32
  lu8: save_game_data[199996]
  lu32: crc32

proc pack(save_file_path: string, bin_file_path: string, verbose: bool): int =
  var save_file_stream = newFileStream(save_file_path, fmWrite)
  if isNil(save_file_stream):
    echo "Cannot open save file for writing"
    return 1

  var bin_file_stream = newFileStream(bin_file_path, fmRead)
  if isNil(bin_file_stream):
    echo "Cannot open bin file for reading"
    return 1

  var decompressed_data = newSeq[uint8]()
  while not bin_file_stream.atEnd:
    decompressed_data.add(bin_file_stream.readUint8())

  var compressed_data = encode(decompressed_data)

  var save_game_data: typeGetter(SaveGameData) = (
    compressed_size: compressed_data.len.uint32 + 8u32,
    decompressed_size: decompressed_data.len.uint32,
    compressed_data: compressed_data,
    _: newSeq[uint8](199996 - (compressed_data.len + 8) - 1),
    version: 61.uint8
  )
  if verbose:
    echo "--- save_game_data ---"
    echo "compressed_size   =", save_game_data.compressed_size
    echo "decompressed_size =", save_game_data.decompressed_size
    echo "version           =", save_game_data.version

  var save_game_data_string_stream = newStringStream()
  SaveGameData.put(save_game_data_string_stream, save_game_data)
  var save_game_data_seq = newSeq[uint8]()
  save_game_data_string_stream.setPosition(0)
  while not save_game_data_string_stream.atEnd:
    save_game_data_seq.add(save_game_data_string_stream.readUint8())

  let calculated_crc32 = crc32(save_game_data_seq)
  var save_game: typeGetter(SaveGame) = (
    xlive_header_size: 4.uint32,
    xlive_crc32: calculated_crc32,
    save_game_data: save_game_data_seq,
    crc32: calculated_crc32
  )

  if verbose:
    echo "--- save_game ---"
    echo "xlive_header_size =", save_game.xlive_header_size
    echo "xlive_crc32       =", save_game.xlive_crc32
    echo "crc32             =", save_game.crc32
    echo "calculated crc32  =", calculated_crc32

  SaveGame.put(save_file_stream, save_game)

  0

proc unpack(save_file_path: string, bin_file_path: string, verbose: bool): int =
  var save_file_stream = newFileStream(save_file_path, fmRead)
  if isNil(save_file_stream):
    echo "Cannot open save file for reading"
    return 1

  var bin_file_stream = newFileStream(bin_file_path, fmWrite)
  if isNil(bin_file_stream):
    echo "Cannot open bin file for writing"
    return 1

  let save_game = SaveGame.get(save_file_stream)
  let calculated_crc32 = crc32(save_game.saveGameData)

  if verbose:
    echo "--- save_game ---"
    echo "xlive_header_size =", save_game.xlive_header_size
    echo "xlive_crc32       =", save_game.xlive_crc32
    echo "crc32             =", save_game.crc32
    echo "calculated crc32  =", calculated_crc32

  if save_game.xlive_header_size != 4:
    echo "Warning: xlive_header_size mismatch; save may be corupted!"

  if save_game.xlive_crc32 != save_game.crc32 or
    save_game.xlive_crc32 != calculated_crc32 or
    save_game.crc32 != calculated_crc32:
    echo "Warning: checksum failed; save may be corupted!"

  let save_game_data = SaveGameData.get(newStringStream(cast[string](save_game.saveGameData)))
  if verbose:
    echo "--- save_game_data ---"
    echo "compressed_size   =", save_game_data.compressed_size
    echo "decompressed_size =", save_game_data.decompressed_size
    echo "version           =", save_game_data.version

  if save_game_data.version != 61:
    echo "Warning: version mismatch; save may be corupted!"

  var decompressed_data = decode(save_game_data.compressed_data, save_game_data.decompressed_size)

  bin_file_stream.write(cast[string](decompressed_data))

  0

type
  Operation {.pure.} = enum
    pack, unpack

proc fse(operation: Operation, save_file_path = "FUEL_SAVE_V14.sav",
    bin_file_path = "FUEL_SAVE_V14.sav.bin", verbose: bool = false): int =
  case operation
  of Operation.pack: pack(save_file_path, bin_file_path, verbose)
  of Operation.unpack: unpack(save_file_path, bin_file_path, verbose)

import cligen; include cligen/mergeCfgEnv;
const nimbleFile = staticRead "../fse.nimble"
clCfg.version = nimbleFile.fromNimble "version"
dispatch fse,
  short={
    "version" : 'V'},
  help={
    "operation" : "operation `[pack|unpack]`",
    "save_file_path" : "path to the save file",
    "bin_file_path" : "path to the bin file",
    "verbose": "enable extra output"}
