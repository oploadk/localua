# localua.sh

localua.sh is a Bash script to download and install a self-contained Lua and
LuaRocks on Linux, macOS and MSYS2.

It supports Lua 5.1 to 5.4. It does *not* officially support other operating
systems or environments, and it does *not* support LuaJIT.

Run the script without arguments to see how to use it.

## But I just want to type `lua` and `luarocks`!

Say you store your local Lua environment in `.lua` in your project, just add
`.lua/bin` at the beginning of your `$PATH`. This will only work from the root
directory of the project though... but you can also add `../.lua/bin` etc if
you want!

## MSYS2 dependencies

Before running the script, install `base-devel`, `gcc` and `unzip`.

## Alternatives

If this does not fit your needs, check out:

- [hererocks](https://github.com/mpeterv/hererocks), in Python
- [luawinmulti](https://github.com/Tieske/luawinmulti), on Windows

Similar tools for other languages:

- [lonesnake](https://github.com/pwalch/lonesnake) for Python
- [rye](https://github.com/mitsuhiko/rye) for Python

## Copyright

- Copyright (c) Pierre Chapuis
