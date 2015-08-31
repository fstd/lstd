#!/bin/sh
# lstd: Supposedly reliable POSIX shell list handling -- automated test script

# Copyright (c) 2015, Timo Buhrmester
# All rights reserved.


# This is still work in progress


trace=false
if [ "x$1" = "x-x" ]; then
	shift
	trace=true
	set -x
fi

Bomb()
{
	printf 'ERROR: %s\n' "$1" >&2
	exit 1
}

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

	[ -z "$target" ] && Bomb "Could not source $src. Put in \$PATH or CWD."
	printf '%s: Sourcing %s\n' "$0" "$target"
	. $target
done

TAB="$(printf '\t')"
NL='
'

# Our test list
lst=

# Sanity check, verify that operations that are supposed to fail do indeed fail
[ $(list_count lst) -eq 0 ] || Bomb "Empty list count not zero"
list_pop_front lst 0 && Bomb "Failed to fail to pop front from an empty list"
list_pop_back lst 0 && Bomb "Failed to fail to pop front from an empty list"
list_front lst 0 && Bomb "Failed to fail to look at the front of an empty list"
list_back lst 0 && Bomb "Failed to fail to look at the back of an empty list"
for i in -42 -1 0 1 42; do
	list_get lst $i 0 \
	    && Bomb "Failed to fail to get index $i from an empty list"
done

for i in -42 -1 0 1 42; do
	list_remove lst $i 0 \
	    && Bomb "Failed to fail to drop ind $i from empty list"
done

list_slice lst 1 0 0 && Bomb "Failed to fail to slice empty list"


# A few elements for our test list
s1="list head"
s2="  2nd list element "
s3="elem ' with ' single ' quotes"
s4="$NL$NL${TAB}lotsa${TAB}newlines and${NL}tabs here.$TAB$NL$NL"
s5='$(uname) will not expand'
s6='$TAB will not expand'
s7="this is	 why we  can't have \"nice\"things\""
# s7 has control characters, not shown on github but this is actually:
#s7="^C^Athis is^I why we ^F^[ can't have \"nice\"things\"^E"
smax=7

# Initialize the test list
list_set lst "$s3" "$s4" "$s5" || Bomb "Failed to list_set three elements"
list_add_front lst '' "$s1" "$s2" || Bomb "Failed to list_add_front two elements"
list_add_back lst '' "$s6" "$s7" || Bomb "Failed to list_set two elements"

[ $(list_count lst) -eq $smax ] || Bomb "$smax-element list count not $smax"

# Exercise list_get
for i in $(seq 1 $smax); do
	list_get lst $i elem || Bomb "Failed to get index $i"
	eval "orig=\$s$i"
	[ "$elem" = "$orig" ] || Bomb "Put in '$orig' but got out '$elem'!"
done

# Exercise list_front and list_back
list_front lst elem || Bomb "Failed to look at the front"
[ "$elem" = "$s1" ] || Bomb "Put in '$orig' but got out '$elem'!"
list_back lst elem || Bomb "Failed to look at the back"
[ "$elem" = "$s7" ] || Bomb "Put in '$orig' but got out '$elem'!"

lstcpy="$lst"

# Exercise list_pop_front
for i in $(seq 1 $smax); do
	list_pop_front lst elem || Bomb "Failed to pop front"
	eval "orig=\$s$i"
	[ "$elem" = "$orig" ] || Bomb "Put in '$orig' but popped out '$elem'!"
done

[ $(list_count lst) -eq 0 ] || Bomb "Count not 0 after popping it empty"

lst="$lstcpy"

# Exercise list_pop_back
for i in $(seq $smax -1 1); do
	list_pop_back lst elem || Bomb "Failed to pop front"
	eval "orig=\$s$i"
	[ "$elem" = "$orig" ] || Bomb "Put in '$orig' but popped out '$elem'!"
done

[ $(list_count lst) -eq 0 ] || Bomb "Count not 0 after popping it empty"


# XXX add more tests


printf 'Found nothing to complain about\n' >&2

exit 0
