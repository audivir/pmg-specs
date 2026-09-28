# pmg-specs

Package specs for [pmg](https://github.com/audivir/zshsetup/tree/main/pmg), a package manager for
prebuilt binaries in the home directory. `pmg update` downloads them, and `pmg install` finds a spec
here when neither `$PMG_SPECS_DIR` nor `$PMG_HOME/specs` has one.

## Prerequisites

- pmg

## Installation

```bash
python -m pmg update
```

## Usage

Each spec in `specs/` is named after its package. Files a spec needs, like the wrapper script of
micromamba, go into a directory named like the spec (`specs/micromamba/`), which the spec reaches
with `{{ spec_dir }}`.

`schema.json` is the JSON schema of specs, generated with `python -m pmg schema`. Every spec
references it in its first line, so editors and `taplo check` validate the specs.

## License

MIT
