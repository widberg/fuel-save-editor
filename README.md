# FUEL Save Editor

Save editor for Asobo's FUEL

<sup>This repository is a relative of the main [FMTK repository](https://github.com/widberg/fmtk).</sup>

## Tutorial

The following command will unpack `FUEL_SAVE_V14.sav` to `FUEL_SAVE_V14.sav.json`.

```sh
fse -o=u
```

The following command will pack `FUEL_SAVE_V14.sav.json` to `FUEL_SAVE_V14.sav`.

```sh
fse -o=p
```

For more options see the help section.

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
  -j=, --json_file_path=  string     "FUEL_SAVE_V14.sav.json"  path to the json file
  -v, --verbose           bool       false                     enable extra output
```
