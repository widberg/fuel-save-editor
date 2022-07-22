# FUEL Save Editor

Save editor for Asobo's FUEL

<sup>This repository is a relative of the main [FMTK repository](https://github.com/widberg/fmtk).</sup>

## Tutorial

The following command will unpack `FUEL_SAVE_V14.sav` to `FUEL_SAVE_V14.sav.bin`.

```sh
fse -o=u
```

The following command will pack `FUEL_SAVE_V14.sav.bin` to `FUEL_SAVE_V14.sav`.

```sh
fse -o=p
```

For more options see the help section.

The extracted `.bin` file can be edited with 010 Editor using the template on the [Asobo Save Game File Format Specification FMTK Wiki entry](https://github.com/widberg/fmtk/wiki/Asobo-Save-Game-File-Format-Specification). Once most of the fields are known, I may add a json export option and/or a GUI editor. More details about the compression used for the save files is available on the [Asobo Arithmetic Coding Compression FMTK Wiki entry](https://github.com/widberg/fmtk/wiki/Asobo-Arithmetic-Coding-Compression).

## Help

```plaintext
Usage:
  fse [REQUIRED,optional-params]
Options:
  -h, --help                                                   print this cligen-erated help
  --help-syntax                                                advanced:
                                                               prepend,plurals,..
  -o=, --operation=       Operation  REQUIRED                  operation `[pack|unpack]`
  -s=, --save_file_path=  string     "FUEL_SAVE_V14.sav"       path to the save file
  -b=, --bin_file_path=   string     "FUEL_SAVE_V14.sav.bin"   path to the bin file
  -v, --verbose           bool       false                     enable extra output
```
