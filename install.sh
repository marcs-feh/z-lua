#!/bin/sh

install_dir="$HOME/.local/bin"
lua_shebang="#!/usr/bin/env luajit"

Install (){
	mkdir -p $install_dir
	cp z.lua "$install_dir/z"
	cp uz.lua "$install_dir/uz"
	chmod 0755 "$install_dir/z"
	chmod 0755 "$install_dir/uz"
	sed -e "s,---SHEBANG---,$lua_shebang," "$install_dir/z" -i
	sed -e "s,---SHEBANG---,$lua_shebang," "$install_dir/uz" -i
	exit
}

Uninstall (){
	rm -f "$install_dir/z"
	rm -f "$install_dir/uz"
	exit
}

Help(){
	printf "Options:\n\ti\tinstall\n\tu\tuninstall\n"
	exit
}

[ -z "$1" ] && Help

for arg in $@; do
	case $arg in
		'i') Install ;;
		'u') Uninstall ;;
		*)   Help ;;
	esac
done
