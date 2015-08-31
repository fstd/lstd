#!/bin/sh

ec=0

#for f in sh dash bash posh ksh pdksh zsh; do
for f in sh dash bash posh ksh pdksh mksh; do
	if ! which $f 2>/dev/null >/dev/null; then
		echo "Shell '$f' not found" >&2
		continue
	fi

	echo "Trying '$f'" >&2
	if $f "$@"; then
		echo "Shell '$f' success" >&2
	else
		echo "Shell '$f' failure" >&2
		ec=1
	fi
done

exit $ec
