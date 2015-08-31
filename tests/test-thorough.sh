#!/bin/sh
#set -x

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

funx='list_set list_add_back list_add_front list_insert list_replace list_front list_back list_get list_count list_remove list_pop_front list_pop_back list_find'
funx_ext='list_slice list_foreach list_collect list_retain list_fromstr'

Complain()
{
	printf '%s: %s\n' "$0" "$1" >&2
}

test_func()
{
	fn="$1"
	shift

	test_$fn "$@"
	ret=$?

	if [ $ret -eq 2 ]; then
		#printf 'TEST_MISSING: %s\n' "$fn" >&2
		return 0
	elif [ $ret -ne 0 ]; then
		printf 'FAILURE: %s\n' "$fn" >&2
		return 1
	else
		printf 'OKAY: %s\n' "$fn" >&2
		return 0
	fi
}

randstr=
Main()
{
	mode="$1"
	if [ -n "$mode" ]; then
		randstr='randstr'
		if ! which $randstr >/dev/null 2>/dev/null; then
			if ! [ -x "./tools/randstr" ]; then
				printf 'Build the randstr tool first (cc -std=c99 -o randstr randstr.c)\n' >&2
				exit 1
			fi

			randstr="./tools/randstr"
		fi

		RandomElems "$mode"
	fi
	retval=0
	#for f in $funx; do
	for f in $(echo "$funx"); do #command subst is a zsh workaround
		if ! test_func $f; then
			retval=1
		fi
	done

	echo "Basic tests done" >&2

	for f in $(echo "$funx_ext"); do #command subst is a zsh workaround
		if ! test_func $f; then
			retval=1
		fi
	done

	echo "Extension tests done" >&2

	if [ $retval -ne 0 ]; then
		printf 'Failure report (%s, mode %s):\n' "$(date)" "$mode"
		for f in 1 2 3 4 5 6 7 8 9; do
			printf 'Elem %s:\n' "$f"
			eval "orig=\"\$elem$f\""
			printf '%s' "$orig" | hexdump -C >&2
		done
		printf 'Environment:\n'
		env >&2
		printf 'Set:\n'
		set >&2
		printf 'End of failure report\n'

	fi

	return $retval
}

BS='\'
NL="$(printf '\nx')"; NL="${NL%?}"
TAB="$(printf '\t')"
SQ="'"
DQ='"'
C1="$(printf '\1')"

elem1=" foo bar "
elem2=" $TAB${BS}foo$C1 ${SQ}b$DQa${NL}r$NL$NL$NL"
elem3=''
elem4='\'
elem5="*"
elem6="$TAB$TAB$TAB"
elem7="$NL$NL$NL"
elem8="$SQ"
elem9="$DQ"


RandomElems()
{
	mode="$1"

	rsmin=32
	rsmax=126
	printf 'Randomizing mode %s\n' "$mode" >&2
	if [ "$mode" -eq 1 ]; then
		rsmin=1
		rsmax=126
	elif [ "$mode" -eq 2 ]; then
		rsmin=32
		rsmax=255
	elif [ "$mode" -eq 3 ]; then
		rsmin=1
		rsmax=255
	fi
	
	for f in 1 2 3 4 5 6 7 8 9; do
		e="$($randstr 0 128 "$rsmin" "$rsmax"; echo x)"
		e="${e%x}"

		eval "elem$f=\"\$e\""
	done
}


test_list_set()
{
	lst=

	list_set lst ''
	[ "$(list_count lst)" '=' '1' ] || { Complain "List \`$ls\` count should be 1 but isn't"; return 1; }

	eval "set -- $lst"
	[ $# -eq 1 ] || { Complain "\$# wrong for 1-empty-element list: $#"; return 1; }
	[ "x$1" '=' 'x' ] || { Complain "Put in \`\` but got out \`$1\`"; return 1; }

	list_set lst "foo '" 'bar' "' baz"
	[ "$(list_count lst)" '=' '3' ] || { Complain "List \`$ls\` count should be 3 but isn't"; return 1; }

	eval "set -- $lst"
	[ $# -eq 3 ] || { Complain "\$# wrong for 3-element list: $#"; return 1; }
	[ "x$1" '=' "xfoo '" ] || { Complain "Put in \`foo '\` but got out \`$1\`"; return 1; }
	[ "x$2" '=' "xbar"   ] || { Complain "Put in \`bar\` but got out \`$2\`"; return 1; }
	[ "x$3" '=' "x' baz" ] || { Complain "Put in \`' baz\` but got out \`$3\`"; return 1; }

	list_set lst
	[ "$(list_count lst)" '=' '0' ] || { Complain "List \`$ls\` count should be 0 but isn't"; return 1; }
	eval "set -- $lst"
	[ $# -eq 0 ] || { Complain "\$# wrong for empty list: $#"; return 1; }

	list_set lst "$elem1" "$elem2" "$elem3" "$elem4" "$elem5" "$elem6" "$elem7" "$elem8" "$elem9" 
	[ "$(list_count lst)" '=' '9' ] || { Complain "List \`$ls\` count should be 9 but isn't"; return 1; }

	eval "set -- $lst"

	c=1
	while [ $# -gt 0 ]; do
		eval "orig=\"\$elem$c\""
		[ "x$1" '=' "x$orig" ] || { Complain "Put in \`$orig\` but got out \`$1\`"; return 1; }
		shift
		c=$((c+1))
	done
}


test_list_add_back()
{
	lst=

	list_add_back lst '' "$elem1" "$elem2" "$elem3"
	list_add_back lst '' "$elem4"
	list_add_back lst 2 "$elem5" "$elem6" "$elem7" # 7 should be discarded because amount=2
	list_add_back lst 0 "$elem7" "$elem8" # nothing should be added because amount=0
	list_add_back lst 42 "$elem7" "$elem8"
	list_add_back lst 1 "$elem9"

	eval "set -- $lst"

	c=1
	while [ $# -gt 0 ]; do
		eval "orig=\"\$elem$c\""
		[ "x$1" '=' "x$orig" ] || { Complain "Put in \`$orig\` but got out \`$1\`"; return 1; }
		shift
		c=$((c+1))
	done

	return 0
}

test_list_add_front()
{
	lst=
	list_add_front lst '' "$elem3" "$elem2" "$elem1"
	list_add_front lst '' "$elem4"
	list_add_front lst 2 "$elem6" "$elem5" "$elem7" # 7 should be discarded because amount=2
	list_add_front lst 0 "$elem7" "$elem8" # nothing should be added because amount=0
	list_add_front lst 42 "$elem8" "$elem7"
	list_add_front lst 1 "$elem9"

	eval "set -- $lst"

	c=9
	while [ $# -gt 0 ]; do
		eval "orig=\"\$elem$c\""
		[ "x$1" '=' "x$orig" ] || { Complain "Put in \`$orig\` but got out \`$1\`"; return 1; }
		shift
		c=$((c-1))
	done

	return 0
}

test_list_insert()
{
	list_set lst "$elem1" "$elem3" "$elem4" "$elem8"

	list_insert lst 2 1 "$elem2" "$elem8" "$elem9" #8 and 9 should be ignored because amount=1
	list_insert lst 5 42 "$elem5" "$elem6"
	list_insert lst 7 '' "$elem7"
	list_insert lst 0 1 "$elem9" "$elem6" "$elem6" #6 and 6 should be ignored because amount=1

	c=1
	while [ $# -gt 0 ]; do
		eval "orig=\"\$elem$c\""
		[ "x$1" '=' "x$orig" ] || { Complain "Put in \`$orig\` but got out \`$1\`"; return 1; }
		shift
		c=$((c+1))
	done

	return 0
}

test_list_replace()
{
	list_set lst "$elem9" "$elem2" "$elem3" "$elem4" "$elem5" "$elem6" "$elem7" "$elem8" "$elem1"

	s=2
	e=8

	while [ $s -lt $e ]; do
		eval "es=\"\$elem$s\""
		eval "ee=\"\$elem$e\""

		list_replace lst $s "$ee" old
		[ "x$old" '=' "x$es" ] || { Complain "Replace gave us \`$old\` when we expected \`$es\`"; return 1; }

		list_replace lst $e "$es" old
		[ "x$old" '=' "x$ee" ] || { Complain "Replace gave us \`$old\` when we expected \`$ee\`"; return 1; }

		s=$((s+1))
		e=$((e-1))
	done

	eval "set -- $lst"

	c=9
	while [ $# -gt 0 ]; do
		eval "orig=\"\$elem$c\""
		[ "x$1" '=' "x$orig" ] || { Complain "Put in \`$orig\` but got out \`$1\`"; return 1; }
		shift
		c=$((c-1))
	done

	return 0
}

test_list_front()
{
	list_set lst "$elem1" "$elem2" "$elem3" "$elem4" "$elem5" "$elem6" "$elem7" "$elem8" "$elem9"

	c=1
	while [ $c -le 9 ]; do
		eval "orig=\"\$elem$c\""
		list_front lst out

		[ "x$out" '=' "x$orig" ] || { Complain "Put in \`$orig\` but got out \`$out\`"; return 1; }

		list_count lst cnt
		list_pop_front lst 0
		list_count lst ncnt

		[ $((cnt)) -eq $((ncnt+1)) ] || { Complain "list_pop_front failed"; return 1; }

		c=$((c+1))
	done
	return 0
}

test_list_back()
{
	list_set lst "$elem1" "$elem2" "$elem3" "$elem4" "$elem5" "$elem6" "$elem7" "$elem8" "$elem9"

	c=9
	while [ $c -ge 1 ]; do
		eval "orig=\"\$elem$c\""
		list_back lst out

		[ "x$out" '=' "x$orig" ] || { Complain "Put in \`$orig\` but got out \`$out\`"; return 1; }

		list_count lst cnt
		list_pop_back lst 0
		list_count lst ncnt

		[ $((cnt)) -eq $((ncnt+1)) ] || { Complain "list_pop_back failed"; return 1; }

		c=$((c-1))
	done
	return 0
}

test_list_get()
{
	list_set lst "$elem1" "$elem2" "$elem3" "$elem4" "$elem5" "$elem6" "$elem7" "$elem8" "$elem9"

	c=1
	while [ $c -le 9 ]; do
		eval "orig=\"\$elem$c\""
		list_get lst $c out

		[ "x$out" '=' "x$orig" ] || { Complain "Put in \`$orig\` but got out \`$out\`"; return 1; }

		c=$((c+1))
	done

	return 0
}

test_list_count()
{
	list_set lst
	[ $(list_count lst) '=' '0' ] || { Complain "List \`$ls\` count should be 0 but isn't"; return 1; }
	eval "set -- $lst"
	[ $# '=' '0' ] || { Complain "\$# count should be 0 but isn't"; return 1; }

	list_set lst 'a' 'b' 'c'
	[ $(list_count lst) '=' '3' ] || { Complain "List \`$ls\` count should be 3 but isn't"; return 1; }
	eval "set -- $lst"
	[ $# '=' '3' ] || { Complain "\$# count should be 0 but isn't"; return 1; }

	list_set lst "$elem1" "$elem2" "$elem3" "$elem4" "$elem5" "$elem6" "$elem7" "$elem8" "$elem9"
	[ $(list_count lst) '=' '9' ] || { Complain "List \`$ls\` count should be 9 but isn't"; return 1; }
	eval "set -- $lst"
	[ $# '=' '9' ] || { Complain "\$# count should be 0 but isn't"; return 1; }

	return 0
}

test_list_remove()
{
	list_set lst "$elem1" "$elem1" "$elem2" "$elem3" "$elem3" "$elem4" "$elem5" "$elem5" "$elem5" "$elem6" "$elem7" "$elem8" "$elem9" "$elem9" "$elem7"
	
	list_remove lst 1 out
	[ "x$out" '=' "x$elem1" ] || { Complain "Put in \`$elem1\` but got out \`$out\` 1"; return 1; }

	list_remove lst 0 out #removes the tail
	[ "x$out" '=' "x$elem7" ] || { Complain "Put in \`$elem7\` but got out \`$out\` 2"; return 1; }

	list_remove lst 4 out
	[ "x$out" '=' "x$elem3" ] || { Complain "Put in \`$elem3\` but got out \`$out\` 3"; return 1; }

	list_remove lst 5 out
	[ "x$out" '=' "x$elem5" ] || { Complain "Put in \`$elem5\` but got out \`$out\` 4"; return 1; }

	list_remove lst 6 out
	[ "x$out" '=' "x$elem5" ] || { Complain "Put in \`$elem5\` but got out \`$out\` 5"; return 1; }

	list_remove lst 9 out
	[ "x$out" '=' "x$elem9" ] || { Complain "Put in \`$elem9\` but got out \`$out\` 6"; return 1; }

	c=1
	while [ $c -le 9 ]; do
		eval "orig=\"\$elem$c\""
		list_get lst $c out

		[ "x$out" '=' "x$orig" ] || { Complain "Put in \`$orig\` but got out \`$out\` 7.$c"; return 1; }

		c=$((c+1))
	done

	return 0
}

test_list_pop_front()
{
	list_set lst "$elem1" "$elem2" "$elem3" "$elem4" "$elem5" "$elem6" "$elem7" "$elem8" "$elem9"
	c=1
	while list_pop_front lst out; do
		[ $c -le 9 ] || { Complain "Getting too many elements back"; return 1; }
		eval "orig=\"\$elem$c\""

		[ "x$out" '=' "x$orig" ] || { Complain "Put in \`$orig\` but got out \`$out\` $c"; return 1; }

		c=$((c+1))
	done

	[ $c -eq 10 ] || { Complain "Didn't get everything back (c: $c)"; return 1; }

	return 0
}

test_list_pop_back()
{
	list_set lst "$elem1" "$elem2" "$elem3" "$elem4" "$elem5" "$elem6" "$elem7" "$elem8" "$elem9"
	c=9
	while list_pop_back lst out; do
		[ $c -gt 0 ] || { Complain "Getting too many elements back"; return 1; }

		eval "orig=\"\$elem$c\""

		[ "x$out" '=' "x$orig" ] || { Complain "Put in \`$orig\` but got out \`$out\`"; return 1; }

		c=$((c-1))
	done

	[ $c -eq 0 ] || { Complain "Didn't get everything back (c: $c)"; return 1; }

	return 0
}

test_list_find()
{
	list_set lst "$elem1" "$elem2" "$elem3" "$elem4" "$elem5" "$elem6" "$elem7" "$elem8" "$elem9"

	c=1
	si=1
	while [ $c -le 9 ]; do
		eval "orig=\"\$elem$c\""

		if ! list_find lst $si "$orig" out; then
			Complain "Did not find \`$orig\` in list"
			return 1
		fi

		while ! [ "x$out" '=' "x$c" ]; do
			si=$((out+1))
			if ! list_find lst $si "$orig" out; then
				Complain "Did not find (the right) \`$orig\` in list"
				return 1
			fi
		done

		c=$((c+1))
	done

	return 0
}

test_list_slice()
{
	list_set lst "$elem1" "$elem2" "$elem3" "$elem4" "$elem5" "$elem6" "$elem7" "$elem8" "$elem9"

	for si in 1 2 4; do
		for ei in 4 0 6 9; do  # 0 means 'end' and hence 9 for this list
			realei=$ei
			if [ $ei -eq 0 ]; then
				realei=9
			fi
			nelem=$((realei-si+1))
			list_slice lst $si $ei sublst || { Complain "Cannot slice from $si to $ei"; return 1; }

			[ "$(list_count sublst)" -eq $nelem ] || { Complain "Sublist $si-$ei ought to have $nelem elems but doesn't"; return 1; }

			c=$si
			while list_pop_front sublst out; do
				[ $c -le $realei ] || { Complain "Too many elements in sublist $si-$ei"; return 1; }
				eval "orig=\"\$elem$c\""

				[ "x$out" '=' "x$orig" ] || { Complain "Found \`$out\` in sublist when we expected \`$orig\`"; return 1; }
				c=$((c+1))
			done

			[ $c -eq $((realei+1)) ] || { Complain "Too few elements in sublist $si-$ei"; return 1; }

			sublst=
		done
	done

	return 0
}

expind=

foreach_callback()
{
	lst="$1"
	ind="$2"
	str="$3"

	[ "$lst" '=' "lst" ] || { Complain "callback called with wrong list name '$lst'"; return 1; }
	[ "$ind" -eq "$expind" ] || { Complain "callback called with index $ind but we expected $expind"; return 1; }

	eval "orig=\"\$elem$ind\""

	[ "x$str" '=' "x$orig" ] || { Complain "callback called with wrong data element"; return 1; }

	expind=$((expind+1))

	return 0
}

test_list_foreach()
{
	list_set lst "$elem1" "$elem2" "$elem3" "$elem4" "$elem5" "$elem6" "$elem7" "$elem8" "$elem9"

	expind=1
	list_foreach lst foreach_callback || { Complain "foreach failed"; return 1; }

	[ "$expind" '=' '10' ] || { Complain "Callback called $((expind-1)) times, which is wrong"; return 1; }

	return 0
}

collect_decide()
{
	lst="$1"
	ind="$2"
	str="$3"

	[ "$lst" '=' "lst" ] || { Complain "callback called with wrong list name '$lst'"; return 1; }
	[ "$ind" -eq "$expind" ] || { Complain "callback called with index $ind but we expected $expind"; return 1; }

	eval "orig=\"\$elem$ind\""

	[ "x$str" '=' "x$orig" ] || { Complain "callback called with wrong data element"; return 1; }

	expind=$((expind+1))

	ret=1
	if [ "$((ind/2))" -eq "$(((ind+1)/2))" ]; then
		ret=0  #collect all elements with even indices
	fi

	return $ret #returning 0 means 'collect', 1 means 'ignore'
}

test_list_collect()
{
	list_set lst "$elem1" "$elem2" "$elem3" "$elem4" "$elem5" "$elem6" "$elem7" "$elem8" "$elem9"

	expind=1
	list_collect lst collect_decide sublst || { Complain "collect failed"; return 1; }

	[ "$expind" '=' '10' ] || { Complain "collect decider called $((expind-1)) times, which is wrong"; return 1; }

	c=1
	oi=2
	while list_pop_front sublst out; do
		[ $c -le 4 ] || { Complain "Too many elements in collected sublist"; return 1; }
		eval "orig=\"\$elem$oi\""

		[ "x$out" '=' "x$orig" ] || { Complain "Found \`$out\` in sublist when we expected \`$orig\`"; return 1; }
		c=$((c+1))
		oi=$((oi+2))
	done

	[ $c -eq 5 ] || { Complain "Too few elements in collected sublist"; return 1; }

	return 0
}

retain_decide()
{
	lst="$1"
	ind="$2"
	str="$3"

	[ "$lst" '=' "lst" ] || { Complain "callback called with wrong list name '$lst'"; return 1; }
	[ "$ind" -eq "$expind" ] || { Complain "callback called with index $ind but we expected $expind"; return 1; }

	eval "orig=\"\$elem$ind\""

	[ "x$str" '=' "x$orig" ] || { Complain "callback called with wrong data element"; return 1; }

	expind=$((expind+1))

	ret=0
	if [ "$((ind/2))" -eq "$(((ind+1)/2))" ]; then
		ret=1  #retain all elements with odd indices
	fi

	return $ret #returning 0 means 'retain', 1 means 'discard'
}

test_list_retain()
{
	list_set lst "$elem1" "$elem2" "$elem3" "$elem4" "$elem5" "$elem6" "$elem7" "$elem8" "$elem9"

	expind=1
	list_retain lst retain_decide remlst || { Complain "retain failed"; return 1; }

	[ "$expind" '=' '10' ] || { Complain "retain decider called $((expind-1)) times, which is wrong"; return 1; }

	c=1
	oi=1
	while list_pop_front lst out; do
		[ $c -le 5 ] || { Complain "Too many elements in retained sublist"; return 1; }
		eval "orig=\"\$elem$oi\""

		[ "x$out" '=' "x$orig" ] || { Complain "Found \`$out\` in sublist when we expected \`$orig\`"; return 1; }
		c=$((c+1))
		oi=$((oi+2))
	done

	[ $c -eq 6 ] || { Complain "Too few elements in retained sublist"; return 1; }

	c=1
	oi=2
	while list_pop_front remlst out; do
		[ $c -le 4 ] || { Complain "Too many elements in removed sublist"; return 1; }
		eval "orig=\"\$elem$oi\""

		[ "x$out" '=' "x$orig" ] || { Complain "Found \`$out\` in removed sublist when we expected \`$orig\`"; return 1; }
		c=$((c+1))
		oi=$((oi+2))
	done

	[ $c -eq 5 ] || { Complain "Too few elements in removed sublist"; return 1; }

	return 0
}

test_list_fromstr()
{
	ls='foo bar baz'
	list_fromstr lst "$ls"
	eval "set -- $lst"
	[ $# -eq 3 ] || { Complain "List \`$ls\` has $# elements but should have 3"; return 1; }
	[ "x$1" '=' 'xfoo' ] && [ "x$2" '=' 'xbar' ] && [ "x$3" '=' 'xbaz' ] || { Complain "List \`$ls\` data elements wrong"; return 1; }
	
	ls="foo 'bar baz'"
	list_fromstr lst "$ls"
	eval "set -- $lst"
	[ $# -eq 3 ] || { Complain "List \`$ls\` has $# elements but should have 3"; return 1; } # NOT quote aware
	[ "x$1" '=' 'xfoo' ] && [ "x$2" '=' "x'bar" ] && [ "x$3" '=' "xbaz'" ] || { Complain "List \`$ls\` data elements wrong"; return 1; }
	
	ls=''
	list_fromstr lst "$ls"
	eval "set -- $lst"
	[ $# -eq 0 ] || { Complain "List \`$ls\` has $# elements but should have 0"; return 1; }
	
	ls='$(uname)' #should not expand
	list_fromstr lst "$ls"
	eval "set -- $lst"
	[ $# -eq 1 ] || { Complain "List \`$ls\` has $# elements but should have 1"; return 1; }
	[ "x$1" '=' 'x$(uname)' ] || { Complain "List \`$ls\` data elements wrong"; return 1; }
	
	ls='*' #should not expand
	list_fromstr lst "$ls"
	eval "set -- $lst"
	[ $# -eq 1 ] || { Complain "List \`$ls\` has $# elements but should have 1"; return 1; }
	[ "x$1" '=' 'x*' ] || { Complain "List \`$ls\` data elements wrong"; return 1; }
	
	ls='""'
	list_fromstr lst "$ls"
	eval "set -- $lst"
	[ $# -eq 1 ] || { Complain "List \`$ls\` has $# elements but should have 1"; return 1; }
	[ "x$1" '=' 'x""' ] || { Complain "List \`$ls\` data elements wrong"; return 1; }
	
	ls="$NL$TAB   x  $NL $TAB $TAB $NL$NL"
	list_fromstr lst "$ls"
	eval "set -- $lst"
	[ $# -eq 1 ] || { Complain "List \`$ls\` has $# elements but should have 1"; return 1; }
	[ "x$1" '=' 'xx' ] || { Complain "List \`$ls\` data elements wrong"; return 1; }
	
	ls="xfooxbar bazxwotx"
	list_fromstr lst 'x' "$ls"
	eval "set -- $lst"
	[ $# -eq 3 ] || { Complain "List \`$ls\` has $# elements but should have 3"; return 1; }
	[ "x$1" '=' 'xfoo' ] && [ "x$2" '=' 'xbar baz' ] && [ "x$3" '=' 'xwot' ] || { Complain "List \`$ls\` data elements wrong"; return 1; }
	
	ls="xxxfooxxxbar bazxwotxx"
	list_fromstr lst 'x' "$ls"
	eval "set -- $lst"
	[ $# -eq 3 ] || { Complain "List \`$ls\` has $# elements but should have 3"; return 1; }
	[ "x$1" '=' 'xfoo' ] && [ "x$2" '=' 'xbar baz' ] && [ "x$3" '=' 'xwot' ] || { Complain "List \`$ls\` data elements wrong"; return 1; }

	ls="xfoo 'baz x bar' hm"
	list_fromstr lst 'x' "$ls"
	eval "set -- $lst"
	[ $# -eq 2 ] || { Complain "List \`$ls\` has $# elements but should have 2"; return 1; }
	[ "x$1" '=' "xfoo 'baz " ] && [ "x$2" '=' "x bar' hm" ] || { Complain "List \`$ls\` data elements wrong"; return 1; }


	return 0
}

Main "$@"

exit $?
