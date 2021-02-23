#!/bin/bash

[ ${#@} -lt 1 ] && {
	echo "usage: $0 lua-module-path"
	exit 1
}

PATH=$HOME/.local/openresty/bin:/opt/local/openresty/bin:/usr/local/openresty/bin:$PATH
lmodpath=$1
lmoddir=$(dirname "$1")

export LUA_PATH="${LUA_PATH}${lmoddir}/?.lua;;"
echo "LUA_PATH: $LUA_PATH"
luajit "$lmodpath"
