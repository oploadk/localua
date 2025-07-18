#!/bin/bash

# Downloads and installs a self-contained Lua and LuaRocks.
# Supports Linux, macOS and MSYS2.
# Copyright (c) Pierre Chapuis, MIT Licensed.
# Latest stable version available at: https://loadk.com/localua.sh
# Maintained at: https://github.com/oploadk/localua

DEFAULT_LUA_V="5.4.8"
DEFAULT_LR_V="3.12.0"

usage () {
    >&2 echo -e "USAGE: $0 output-dir [lua-version] [luarocks-version]\n"
    >&2 echo -n "The first optional argument is the Lua version, "
    >&2 echo -n "the second one is the LuaRocks version. "
    >&2 echo -e "Defaults are Lua $DEFAULT_LUA_V and LuaRocks $DEFAULT_LR_V.\n"
    >&2 echo -n "You can set a custom build directory with environment "
    >&2 echo -e "variable LOCALUA_BUILD_DIRECTORY (not useful in general).\n"
    >&2 echo -e "You can set a custom makefile target with LOCALUA_TARGET.\n"
    >&2 echo -e "You can disable LUA_COMPAT by setting LOCALUA_NO_COMPAT.\n"
    >&2 echo -e "You can skip luarocks by setting LOCALUA_NO_LUAROCKS."
    exit 1
}

# Set output directory, Lua version and LuaRocks version

ODIR="$1"
[ -z "$ODIR" ] && usage

LUA_V="$2"
[ -z "$LUA_V" ] && LUA_V="$DEFAULT_LUA_V"

LUA_SHORTV="$(echo $LUA_V | cut -c 1-3)"
LUA_SRCDIR="lua-${LUA_V}"
if [ "$LUA_V" = "pallene" ]; then
    LUA_SHORTV="5.4"
    LUA_SRCDIR="lua-internals"
fi
LUA_SHORTV2="$(echo $LUA_SHORTV | tr -d '.')"

LR_V="$3"
[ -z "$LR_V" ] && LR_V="$DEFAULT_LR_V"

PALLENE_ROCKSPEC="https://raw.githubusercontent.com/pallene-lang/pallene/master/pallene-dev-1.rockspec"

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
    case "$(uname)" in
        Linux)
            LOCALUA_TARGET="linux";;
        Darwin)
            LOCALUA_TARGET="macosx";;
        MSYS*)
            LOCALUA_TARGET="msys";;
        *)
            LOCALUA_TARGET="posix";;
    esac
fi

download_lua () {
    if [ "$LUA_V" = "pallene" ]; then
        git clone --depth 1 "git@github.com:pallene-lang/lua-internals.git"
    else
        curl "https://www.lua.org/ftp/lua-${LUA_V}.tar.gz" -O
        tar xf "lua-${LUA_V}.tar.gz"
    fi
}

cleanup_luarocks_isolation () {
    # See:
    # https://github.com/oploadk/localua/issues/3
    # https://github.com/oploadk/localua/issues/4

    echo "Cleaning up luarocks isolation..."

    >/dev/null pushd "$ODIR"
        # We must *not* be in the build directory, otherwise
        # it will take its config instead.

        rocks_dir="$("$ODIR/bin/luarocks" config rocks_dir)"
        lr_version="$("$ODIR/bin/luarocks" show luarocks --mversion)"
        lr_bin="$rocks_dir/luarocks/$lr_version/bin/luarocks"
        lr_config_file=$("$ODIR/bin/luarocks" config config_files.system.file)

        if [ ! -x "$lr_bin" ]; then
            >&2 echo -n "Could not cleanup luarocks isolation, "
            >&2 echo "executable $lr_bin not found."
            return 1
        fi

        if [ ! -f "$lr_config_file" ]; then
            >&2 echo -n "Could not cleanup luarocks isolation, "
            >&2 echo "config file $lr_config_file not found."
            return 1
        fi

        # Remove user tree from configuration file.
        sed -e '/name = "user"/d' "$lr_config_file" > "$BDIR/t"
        mv "$BDIR/t" "$lr_config_file"
    >/dev/null popd

    # Rebuild with the *local* Lua to avoid trash in wrapper scripts.
    "$ODIR/bin/lua" "$lr_bin" make --tree="$ODIR"
}

install_ptracer () {
    echo "Installing Pallene Tracer..."
    pushd "$BDIR"
        git clone https://www.github.com/pallene-lang/pallene-tracer --depth 1 --branch 0.5.0a
        pushd pallene-tracer
            make PREFIX="$ODIR" LUA_PREFIX="$ODIR" install
        popd
    popd
}

pushd "$BDIR"
    download_lua
    pushd "$LUA_SRCDIR"
        sed 's#"/usr/local/"#"'"$ODIR"'/"#' "src/luaconf.h" > "$BDIR/t"
        mv "$BDIR/t" "src/luaconf.h"
        if [ ! -z "$LOCALUA_NO_COMPAT" ]; then
            sed 's#-DLUA_COMPAT_5_.##' "src/Makefile" > "$BDIR/t"
            sed 's#-DLUA_COMPAT_ALL##' "$BDIR/t" > "src/Makefile"
        fi

        if [ "$LOCALUA_TARGET" = "msys" ]; then
            >> "src/Makefile" echo
            >> "src/Makefile" echo 'msys:' >> "src/Makefile"
            >> "src/Makefile" echo -ne "\t"
            >> "src/Makefile" echo '$(MAKE) "LUA_A=lua'"$LUA_SHORTV2"'.dll" "LUA_T=lua.exe" \'
            >> "src/Makefile" echo -ne "\t"
            >> "src/Makefile" echo '"AR=$(CC) -shared -Wl,--out-implib,liblua.dll.a -o" "RANLIB=strip --strip-unneeded" \'
            >> "src/Makefile" echo -ne "\t"
            >> "src/Makefile" echo '"SYSCFLAGS=-DLUA_BUILD_AS_DLL -DLUA_USE_POSIX -DLUA_USE_DLOPEN" "SYSLIBS=" "SYSLDFLAGS=-s" lua.exe'
            >> "src/Makefile" echo -ne "\t"
            >> "src/Makefile" echo '$(MAKE) "LUAC_T=luac.exe" luac.exe'

            make -C src "$LOCALUA_TARGET" || exit 1
            make \
                TO_BIN="lua.exe luac.exe lua${LUA_SHORTV2}.dll" \
                TO_LIB="liblua.a liblua.dll.a" \
                INSTALL_TOP="$ODIR" install || exit 1
        else
            make "$LOCALUA_TARGET" || exit 1
            make INSTALL_TOP="$ODIR" install || exit 1
        fi
    popd
    if [ -z "$LOCALUA_NO_LUAROCKS" ]; then
        curl -L "https://luarocks.org/releases/luarocks-${LR_V}.tar.gz" -O
        tar xf "luarocks-${LR_V}.tar.gz"
        pushd "luarocks-${LR_V}"
            ./configure --with-lua="$ODIR" --prefix="$ODIR" \
                        --lua-version="$LUA_SHORTV" \
                        --sysconfdir="$ODIR/etc" --force-config
            make bootstrap
            if [ -z "$LOCALUA_NO_LUAROCKS_ISOLATION_CLEANUP" ]; then
                cleanup_luarocks_isolation
            fi
        popd
        if [ "$LUA_V" = "pallene" ]; then
            install_ptracer
            "$ODIR/bin/luarocks" install "$PALLENE_ROCKSPEC" PTRACER_DIR="$ODIR"
        fi
    fi
popd

# Cleanup

rm -rf "$BDIR"
