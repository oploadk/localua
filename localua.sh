#!/bin/bash

# Downloads and installs a self-contained Lua and LuaRocks on Linux and macOS.
# Copyright (c) 2015-2017 Pierre Chapuis, MIT Licensed.
# Original at: https://github.com/catwell/localua

DEFAULT_LUA_V="5.3.4"
DEFAULT_LR_V="2.4.2"

usage () {
    >&2 echo -e "USAGE: $0 output-dir [lua-version] [luarocks-version]\n"
    >&2 echo -n "The first optional argument is the Lua version, "
    >&2 echo -n "the second one is the LuaRocks version. "
    >&2 echo -e "Defaults are Lua $DEFAULT_LUA_V and LuaRocks $DEFAULT_LR_V.\n"
    >&2 echo -n "You can set a custom build directory with environment "
    >&2 echo -e "variable LOCALUA_BUILD_DIRECTORY (not useful in general).\n"
    >&2 echo -e "You can set a custom makefile target with LOCALUA_TARGET."
    exit 1
}

# Set output directory, Lua version and LuaRocks version

ODIR="$1"
[ -z "$ODIR" ] && usage

LUA_V="$2"
[ -z "$LUA_V" ] && LUA_V="$DEFAULT_LUA_V"

LUA_SHORTV="$(echo $LUA_V | cut -c 1-3)"

LR_V="$3"
[ -z "$LR_V" ] && LR_V="$DEFAULT_LR_V"

# Set build directory

BDIR="$LOCALUA_BUILD_DIRECTORY"
[ -z "$BDIR" ] && BDIR="$(mktemp -d /tmp/localua-XXXXXX)"

# Create output directory and get absolute path

mkdir -p "$ODIR"
>/dev/null pushd "$ODIR"
    ODIR="$(pwd)"
>/dev/null popd

# Download, unpack and build Lua and LuaRocks

if [ -z "$LOCALUA_TARGET" ]; then
    LOCALUA_TARGET="posix"
    [ "$(uname)" = "Linux" ] && LOCALUA_TARGET="linux"
fi

pushd "$BDIR"
    wget "http://www.lua.org/ftp/lua-${LUA_V}.tar.gz"
    tar xf "lua-${LUA_V}.tar.gz"
    pushd "lua-${LUA_V}"
        sed 's#"/usr/local/"#"'"$ODIR"'/"#' "src/luaconf.h" > "$BDIR/t"
        mv "$BDIR/t" "src/luaconf.h"
        make "$LOCALUA_TARGET"
        make INSTALL_TOP="$ODIR" install
    popd
    wget "http://luarocks.org/releases/luarocks-${LR_V}.tar.gz"
    tar xf "luarocks-${LR_V}.tar.gz"
    pushd "luarocks-${LR_V}"
        ./configure --with-lua="$ODIR" --prefix="$ODIR" \
                    --lua-version="$LUA_SHORTV" \
                    --sysconfdir="$ODIR/luarocks" --force-config
        make bootstrap
    popd
popd

# Cleanup

rm -rf "$BDIR"
