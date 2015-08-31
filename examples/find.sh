#!/bin/sh

# A lot of code just to source two files -- but we want to be able to run
# the examples and tests whether or not lstd is in $PATH or not
for src in 'lstd.inc.sh' 'lstd-ext.inc.sh'; do
	target=
	if which "$src" 2>/dev/null >/dev/null; then
		target="$src"
	else
		for f in './' '../' './extensions/' '../extensions/'; do
			if [ -f "$f$src" ]; then
				target="$f$src"
				break
			fi
		done
	fi

	[ -z "$target" ] && { printf 'Could not source `%s`. Put in $PATH or CWD.\n' "$src" >&2; exit 1; }
	. $target
done


mylist=
list_fromfind mylist '' "$@"

list_dump mylist
