# lstd: Supposedly reliable POSIX shell list handling -- ugly extensions

# Copyright (c) 2015, Timo Buhrmester
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the serious business enterprises corporation nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL TIMO BUHRMESTER BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

_lstd_curfile='lstd-ext.inc.sh'

# A lot of code just to source one or two files...
_lstd_found=false
_lstd_found_helpers=false
for _lstd_tmp in $(echo "$_lstd_sourced"); do  #zsh...
	if [ "$_lstd_tmp" '=' 'lstd.inc.sh' ]; then
		_lstd_found=true
	elif [ "$_lstd_tmp" '=' 'lstd-ext-helpers.inc.sh' ]; then
		_lstd_found_helpers=true
	fi
done

if ! $_lstd_found; then
	printf '%s: Please source lstd.inc.sh first\n' "$_lstd_curfile" >&2
	exit 1
fi

if ! $_lstd_found_helpers; then
	_lstd_src='lstd-ext-helpers.inc.sh'
	if which "$_lstd_src" 2>/dev/null >/dev/null; then
		target="$_lstd_src"
	else
		for f in '/' '../' './extensions/' '../extensions/'; do
			if [ -f "$f$_lstd_src" ]; then
				_lstd_target="$f$_lstd_src"
				break
			fi
		done
	fi

	if [ -z "$_lstd_target" ]; then
		printf '%s: Could not source %s. Put in $PATH or CWD.\n' \
		    "$_lstd_curfile" "$_lstd_src"
		exit 1
	fi

	#printf '%s: Sourcing %s\n' "$_lstd_curfile" "$_lstd_target"

	_lstd_curfile_bak="$_lstd_curfile"
	. $_lstd_target
	_lstd_curfile="$_lstd_curfile_bak"
fi



# Creates a new list from the result of running find(1)
# This is ugly and not quite as portable as the rest, but useful nonetheless.
# It can also be horribly inefficient and WILL exceed the maximum command
# line length for a lot of results.
#
# It will boil down to the following invocation of find(1):
# find $opts $path $expr -print0
#   $opts is $2 and may be empty
#   $path is $3 and must not be empty
#   $expr is empty if $4 is empty, otherwise it is "( $4 ) -a"
#
list_fromfind()
{
	_lstd_lstnam="$1"
	_lstd_findopts="$2"
	_lstd_findpath="$3"
	_lstd_findexpr="$4"

	[ -n "$_lstd_findexpr" ] && _lstd_findexpr="( $_lstd_findexpr ) -a"

	_lstd_newlst=

	# Translate NUL chars into "$delim"
	_lstd_newlst="'$(find $_lstd_findopts $_lstd_findpath $_lstd_findexpr -print0 | _lstd_repl "'" "'\\\\''" | _lstd_replNUL "' '")'"
	_lstd_newlst="${_lstd_newlst%???}"

	eval "$_lstd_lstnam=\"\$_lstd_newlst\""
	
	return 0
}



# 1: Input to be escaped
_lstd_mklist_ifsish()
{
	_lstd_mk_input="$1"
	_lstd_mk_ifs="$2"


	while _lstd_startswith "$_lstd_mk_input" "$_lstd_mk_ifs" 0; do
		_lstd_mk_input="${_lstd_mk_input#?}"
	done

	_lstd_mk_elem=
	_lstd_mk_inws=false
	while [ ${#_lstd_mk_input} -gt 0 ]; do
		if _lstd_startswith "$_lstd_mk_input" "$_lstd_mk_ifs" begchr; then
			if ! $_lstd_mk_inws; then
				_lstd_mk_inws=true
			fi
		else
			if $_lstd_mk_inws; then
				if [ -n "$_lstd_mk_elem" ]; then
					_lstd_esc "$_lstd_mk_elem"
					printf ' '
					_lstd_mk_elem=
				fi

				_lstd_mk_inws=false
			fi
			_lstd_mk_elem="$_lstd_mk_elem$begchr"
		fi

		_lstd_mk_input="${_lstd_mk_input#?}"
	done

	if [ -n "$_lstd_mk_elem" ]; then
		_lstd_esc "$_lstd_mk_elem"
	fi

	return 0
}

# 1: List name, 2: String
# OR:
# 1: List name, 2: IFS, 3: String
list_fromstr()
{
	_lstd_lstnam="$1"
	_lstd_nifs="$2"
	_lstd_str="$3"

	if [ -z "$_lstd_str" ]; then
		_lstd_str="$_lstd_nifs"
		_lstd_nifs="$(printf ' \t\nx')"; _lstd_nifs="${_lstd_nifs%x}"
	fi

	_lstd_newlst="$(_lstd_mklist_ifsish "$_lstd_str" "$_lstd_nifs")"

	eval "$_lstd_lstnam=\"\$_lstd_newlst\""
}


# 1: List name, 2: First index, 3: Last index, [4: Output variable name (sublist)]
list_slice()
{
	_lstd_lstnam="$1"
	_lstd_sind="$2"
	_lstd_eind="$3"
	_lstd_outvar="$4"
	[ "$_lstd_outvar" '=' '0' ] && _lstd_outvar='_lstd_dummy'

	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	[ "$_lstd_sind" -eq 0 ] && _lstd_sind=$#
	[ "$_lstd_eind" -eq 0 ] && _lstd_eind=$#

	if [ "$_lstd_sind" -gt $# -o "$_lstd_sind" -le 0 ]; then
		#printf 'Illegal start index %s in %s-sized list `%s`\n' \
		#    "$_lstd_sind" $# "$_lstd_lstnam" >&2
		return 1
	fi

	if [ "$_lstd_eind" -gt $# -o "$_lstd_eind" -le 0 ]; then
		#printf 'Illegal end index %s in %s-sized list `%s`\n' \
		#    "$_lstd_eind" "$#-" "$_lstd_lstnam" >&2
		return 1
	fi

	if [ "$_lstd_eind" -lt "$_lstd_sind" ]; then
		#printf "'last_index' (%s) must be >= 'first_index' (%s) " \
		#    "$_lstd_eind" "$_lstd_sind" >&2
		#printf 'to slice %s-sized list `%s`\n' $# "$_lstd_lstnam" >&2
		return 1
	fi


	_lstd_c=1
	_lstd_sublst=
	while [ $# -gt 0 ]; do
		# Put elements between start index and end index into sublist
		[ $_lstd_c -ge "$_lstd_sind" -a $_lstd_c -le "$_lstd_eind" ] \
		    && _lstd_sublst="$_lstd_sublst $(_lstd_esc "$1")"

		_lstd_c=$((_lstd_c+1))
		shift
	done


	if [ -n "$_lstd_outvar" ]; then
		eval "$_lstd_outvar=\"\$_lstd_sublst\""
	else
		printf '%s' "$_lstd_sublst"
	fi

	return 0
}

# 1: List name, 2: Callback function
list_foreach()
{
	# Foreach has a set of unique variable names to cope with the
	# possibility of list_* functions being called from the callback
	# function -- that could otherwise affect the _lstd_ variables
	# in here.  If only ``local'' was POSIX...
	if [ -n "$_lstd_fe_executing" ]; then
		printf 'ERROR: list_foreach() is NOT re-entrant!\n' >&2
		return 1
	fi

	_lstd_fe_lstnam="$1"
	_lstd_fe_action="$2"

	_lstd_fe_executing=1

	eval "_lstd_fe_lstdata=\"\$$_lstd_fe_lstnam\""
	eval "set -- $_lstd_fe_lstdata"

	_lstd_fe_retval=0
	_lstd_fe_c=1
	while [ $# -gt 0 ]; do
		if ! $_lstd_fe_action "$_lstd_fe_lstnam" $_lstd_fe_c "$1"; then
			_lstd_fe_retval=1
		fi

		shift
		_lstd_fe_c=$((_lstd_fe_c+1))
	done

	unset _lstd_fe_executing

	return $_lstd_fe_retval
}

# 1: List name, 2: Decider function, [3: Output variable name]
list_collect()
{
	# Collect has a set of unique variable names reasons stated in _foreach
	if [ -n "$_lstd_cl_executing" ]; then
		printf 'ERROR: list_collect() is NOT re-entrant!\n' >&2
		return 1
	fi

	_lstd_cl_lstnam="$1"
	_lstd_cl_decider="$2"
	_lstd_cl_outvar="$3"
	[ "$_lstd_cl_outvar" '=' '0' ] && _lstd_cl_outvar='_lstd_dummy'

	_lstd_cl_executing=1

	eval "_lstd_cl_lstdata=\"\$$_lstd_cl_lstnam\""
	eval "set -- $_lstd_cl_lstdata"

	_lstd_cl_c=1
	_lstd_cl_sublst=
	while [ $# -gt 0 ]; do
		if $_lstd_cl_decider "$_lstd_cl_lstnam" $_lstd_cl_c "$1"; then
			_lstd_cl_sublst="$_lstd_cl_sublst $(_lstd_esc "$1")"
		fi
		_lstd_cl_c=$((_lstd_cl_c+1))
		shift
	done

	if [ -n "$_lstd_cl_outvar" ]; then
		eval "$_lstd_cl_outvar=\"\$_lstd_cl_sublst\""
	else
		printf '%s' "$_lstd_cl_sublst"
	fi

	unset _lstd_cl_executing

	return 0
}

# removes from the given list
# outputs/assigns the *removed* sublist to stdout/_lstd_rt_outvar
# 1: List name, 2: Decider function, [3: Output variable name]
list_retain()
{
	# Retain has a set of unique variable names reasons stated in _foreach
	if [ -n "$_lstd_rt_executing" ]; then
		printf 'ERROR: list_retain() is NOT re-entrant!\n' >&2
		return 1
	fi

	_lstd_rt_lstnam="$1"
	_lstd_rt_decider="$2"
	_lstd_rt_outvar="$3"
	[ "$_lstd_rt_outvar" '=' '0' ] && _lstd_rt_outvar='_lstd_dummy'

	_lstd_rt_executing=1

	eval "_lstd_rt_lstdata=\"\$$_lstd_rt_lstnam\""
	eval "set -- $_lstd_rt_lstdata"

	_lstd_rt_c=1
	_lstd_rt_newlst=
	_lstd_rt_remlst=
	while [ $# -gt 0 ]; do
		if $_lstd_rt_decider "$_lstd_rt_lstnam" $_lstd_rt_c "$1"; then
			_lstd_rt_newlst="$_lstd_rt_newlst $(_lstd_esc "$1")"
		else
			_lstd_rt_remlst="$_lstd_rt_remlst $(_lstd_esc "$1")"
		fi
		_lstd_rt_c=$((_lstd_rt_c+1))
		shift
	done

	eval "$_lstd_rt_lstnam=\"\$_lstd_rt_newlst\""

	if [ -n "$_lstd_rt_outvar" ]; then
		eval "$_lstd_rt_outvar=\"\$_lstd_rt_remlst\""
	else
		printf '%s' "$_lstd_rt_remlst"
	fi

	unset _lstd_rt_executing

	return 0
}

_lstd_sourced="$_lstd_sourced $_lstd_curfile"
_lstd_curfile=
