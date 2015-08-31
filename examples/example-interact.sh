#!/bin/sh
# lstd: Supposedly reliable POSIX shell list handling -- interactive test script

# Copyright (c) 2015, Timo Buhrmester
# All rights reserved.


# This is still work in progress

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

	[ -z "$target" ] && { printf "Could not source $src. Put in \$PATH or CWD.\n" >&2; exit 1; }
	. $target
done


cmds="set insert replace add_back add_front front back get count dump"
cmds="$cmds remove pop_front pop_back slice foreach collect retain fromstr"

Help()
{
	printf 'Set the current list with "list <name>"\n'
	printf 'Valid commands operating on the current list are: %s\n' "$cmds"
	printf 'Quote-aware field splitting is done on the lines entered here\n'
	printf '\n'
	printf 'The entered commands will just call the respective list_*\n'
	printf 'function.  i.e. `insert "" 5 foobar` causes a call\n'
	printf 'like `list_insert "$currentlist" "" 5 foobar`\n'
	printf '\n'
	printf 'An example session:\n'
	printf 'list mylist  #switch to list `mylist`\n'
	printf 'fromstr "foo bar baz"  # initialize from string literal\n'
	printf 'add_back "" "tail element"  # add element (see README)\n'
	printf 'front # look at the head element\n'
	printf 'back # look at the head element\n'
	printf 'slice 2 3 sublist  # create sublist containing elements 2, 3\n'
	printf 'list sublist  # switch to the newly created sublist\n'
	printf 'dump # look at it\n'
	printf 'pop_front # pop it\n'
	printf 'pop_front # pop it empty\n'
	printf 'list mylist #switch back to `mylist`\n'
	printf 'dump # look at it\n'


}

lstnam=default
list_dump "$lstnam"
echo 'Try "help"'

TAB="$(printf '\t')"

while read -r cmd rest; do
	e=
	case "$cmd" in
	q|quit) break ;;
	help) Help ;;
	list) args="${rest%%#*}"
	      while :; do
	        case "$args" in
	          *$TAB|*' ') args="${args%?}" ;;
	          *) break ;;
	        esac
	      done
	      lstnam="$args" ;;
	?*) args="${rest%%#*}"
	    while :; do
	      case "$args" in
	        *$TAB|*' ') args="${args%?}" ;;
	        *) break ;;
	      esac
	    done

	    eval "set -- $args";
	    if list_$cmd "$lstnam" "$@"; then
	        echo
	        case "$cmd" in
	            dump|front|back|get|count|foreach|collect|slice) ;;
	            *) echo "List '$lstnam' is now:"; list_dump "$lstnam" ;;
	        esac
	    else
	        echo "$cmd failed"
	    fi ;;
	*) : ;;
	esac
done
