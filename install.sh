#!/bin/sh

INSTALL_DIR="$HOME/.local/bin"

Install (){
	mkdir -p $INSTALL_DIR
	cp z.lua "$INSTALL_DIR/z"
	cp uz.lua "$INSTALL_DIR/uz"
	chmod 0755 "$INSTALL_DIR/z"
	chmod 0755 "$INSTALL_DIR/uz"
	exit
}

Uninstall (){
	rm -f "$INSTALL_DIR/z"
	rm -f "$INSTALL_DIR/uz"
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
