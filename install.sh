#!/bin/sh

install_dir="$HOME/.local/bin"
lua_shebang="#!/usr/bin/env luajit"

Run(){ echo "$@"; "$@"; }

Install (){
	Run mkdir -p "$install_dir"
	Run cp z.lua "$install_dir/z"
	Run chmod 0755 "$install_dir/z"
	Run sed -e "s,---SHEBANG---,$lua_shebang," "$install_dir/z" -i
	exit
}

Uninstall (){
	Run rm -f "$install_dir/z"
	exit
}

Help(){
	echo "Options:"
	echo "    Install Dir = $install_dir"
	echo "    Lua Shebang = $lua_shebang"
	echo "Commands:"
	echo "    i -> install"
	echo "    u -> uninstall"
	exit
}

[ -z "$1" ] && Help

for arg in $@; do
	case $arg in
		'i') Install;;
		'u') Uninstall;;
		*)   Help;;
	esac
done
