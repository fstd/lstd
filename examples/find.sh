#!/bin/sh

for src in 'lstd.inc.sh' 'lstd-ext.inc.sh'; do
	target="$(which "$src" 2>/dev/null)"
	if [ -z "$target" ]; then
		for f in './' '../' './extensions/' '../extensions/'; do
			if [ -f "$f$src" ]; then
				target="$f$src"
				break
			fi
		done
	fi

	[ -z "$target" ] && { printf "Could not source $src. Put in \$PATH or CWD.\n" >&2; exit 1; }
	#printf '%s: Sourcing %s\n' "$0" "$target"
	. $target
done


mylist=
list_fromfind mylist '' "$@"

list_dump mylist
