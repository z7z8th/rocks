#!/bin/bash

[ ${#@} -lt 1 ] && {
	echo "usage: $0 lua-module-name"
	exit 1
}

PATH=$HOME/.local/openresty/bin:/opt/local/openresty/bin:/usr/local/openresty/bin:$PATH
lmodname=$1
lmoddir=$(dirname "$1")

#resty --errlog-level debug -I . -I $lmoddir -e "require '$lmodname'"
#resty --errlog-level debug -I . -I "${lmoddir}"  --http-conf "lua_shared_dict test 1m;" "${lmodname}"
resty --errlog-level debug -I . -I "${lmoddir}"  --http-conf "lua_shared_dict test 1m;" t/runtests.lua "${lmodname}"
