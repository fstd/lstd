# lstd: Supposedly reliable POSIX shell list handling -- list implementation

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

_lstd_ver_maj=0
_lstd_ver_min=0
_lstd_ver_pat=0

# We claim the _lstd_* name space (variables and functions)
# We provide our public interface in the list_* function name space
# We don't touch anything beyond that, or if we do (like for IFS), we make sure
#   to restore the original value when we're done.

# See README for documentation of these functions.

# For READING this script, :%s/_lstd_//g is suggested

# The recurring idiom
#   eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"
# is unreadable gibberish for "initialize the positional parameters from the
# list that has the name stored in $_lstd_lstnam


# This is still work in progress

_lstd_TAB="$(printf '\t')"
_lstd_NL="$(printf '\nx')"; _lstd_NL="${_lstd_NL%x}"


# Replaces every occurence of ' in the supplied argument with '\'' (4 chars),
# then encloses the result in single quotes and prints it to standard output

# 1: Input to be escaped
_lstd_esc()
{
	_lstd_input="$1"

	# Credits to Edgar Fuss for the approach
	printf "'"
	while :; do
		case "$_lstd_input" in
			\'*) printf "'\\\\''"           ;; # '\''
			 ?*) printf '%c' "$_lstd_input" ;;
			 "") break                      ;;
		esac
		_lstd_input="${_lstd_input#?}"
	done
	printf "'"
}

# 1: List name, 2: Max. amount (empty=all), 3...: Elements
list_add_back()
{
	_lstd_lstnam="$1"
	_lstd_insnum="$2" # may be empty
	shift 2

	list_insert "$_lstd_lstnam" 0 "$_lstd_insnum" "$@"
}

# 1: List name, 2: Max. amount (empty=all), 3...: Elements
list_add_front()
{
	_lstd_lstnam="$1"
	_lstd_insnum="$2" # may be empty
	shift 2

	list_insert "$_lstd_lstnam" 1 "$_lstd_insnum" "$@"
}

# 1: List name, 2: Start index, 3: Max. amount (empty=all), 4...: Elements
list_insert()
{
	_lstd_lstnam="$1"
	_lstd_in_idx="$2" # unique name because calling _lstd_insert_one
	_lstd_in_max="$3" # number of elements to add (add all if empty)
	shift 3

	if [ -z "$_lstd_in_max" ] || [ "$_lstd_in_max" -gt $# ]; then
		_lstd_in_max=$#
	fi

	_lstd_in_c=0
	while [ $_lstd_in_c -lt $_lstd_in_max ]; do
		if ! _lstd_insert_one "$_lstd_lstnam" "$_lstd_in_idx" "$1"; then
			return 1
		fi

		# If adding at the end using pseudo-index 0, don't increment
		# the index but just leave it as 0, so we keep adding at the end
		# Otherwise, increment the index because we'd reverse the order
		# of new elements if we didn't.
		[ $_lstd_in_idx -gt 0 ] && _lstd_in_idx=$((_lstd_in_idx+1))
		shift
		_lstd_in_c=$((_lstd_in_c+1))
	done

	return 0
}

# list_insert's backend, inserts one element into a list. We need this to be
# a separate function to enable list_insert to accept multiple elements at once
# 1: List name, 2: Start index, 3: Element
_lstd_insert_one()
{
	_lstd_lstnam="$1"
	_lstd_index="$2"
	_lstd_elem="$(_lstd_esc "$3")"

	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	# Index 0 means insert *after* the last element, hence $(($#+1))
	[ "$_lstd_index" -eq 0 ] && _lstd_index=$(($#+1))

	if [ "$_lstd_index" -gt $(($#+1)) -o "$_lstd_index" -le 0 ]; then
		#printf 'Cannot insert at index %s into %s-sized list `%s`\n' \
		#    "$_lstd_index" $# "$_lstd_lstnam" >&2
		return 1
	fi

	_lstd_c=1
	_lstd_inserted=false
	_lstd_newlst=
	while [ $# -gt 0 ]; do
		if [ $_lstd_c -eq "$_lstd_index" ]; then
			_lstd_newlst="$_lstd_newlst $_lstd_elem"
			_lstd_inserted=true
		fi
		_lstd_newlst="$_lstd_newlst $(_lstd_esc "$1")"
		_lstd_c=$((_lstd_c+1))
		shift
	done

	# If we have nothing inserted yet, we insert after the last element.
	if ! $_lstd_inserted; then
		_lstd_newlst="$_lstd_newlst $_lstd_elem"
	fi

	eval "$_lstd_lstnam=\"\$_lstd_newlst\""

	return 0
}

# 1: List name, 2: Index to replace, 3: Element, [4: Output variable name]
list_replace()
{
	_lstd_lstnam="$1"
	_lstd_index="$2"
	_lstd_elem="$(_lstd_esc "$3")"
	_lstd_outvar="$4"
	[ "$_lstd_outvar" = '0' ] && _lstd_outvar='_lstd_dummy'

	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	[ "$_lstd_index" -eq 0 ] && _lstd_index=$#

	if [ "$_lstd_index" -gt $# -o "$_lstd_index" -le 0 ]; then
		#printf 'Cannot replace index %s in %s-sized list `%s`\n' \
		#    "$_lstd_index" $# "$_lstd_lstnam" >&2
		return 1
	fi

	_lstd_c=1
	_lstd_relem=
	_lstd_newlst=
	while [ $# -gt 0 ]; do
		if [ $_lstd_c -eq "$_lstd_index" ]; then
			_lstd_relem="$1"
			_lstd_newlst="$_lstd_newlst $_lstd_elem"
		else
			_lstd_newlst="$_lstd_newlst $(_lstd_esc "$1")"
		fi
		_lstd_c=$((_lstd_c+1))
		shift
	done

	eval "$_lstd_lstnam=\"\$_lstd_newlst\""

	if [ -n "$_lstd_outvar" ]; then
		eval "$_lstd_outvar=\"\$_lstd_relem\""
	else
		printf '%s' "$_lstd_relem"
	fi

	return 0
}

# 1: List name, [2: Output variable name]
list_front()
{
	list_get "$1" 1 "$2"
}

# 1: List name, [2: Output variable name]
list_back()
{
	list_get "$1" 0 "$2"
}

# 1: List name, 2: Index to get, [3: Output variable name]
list_get()
{
	_lstd_lstnam="$1"
	_lstd_index="$2"
	_lstd_outvar="$3"
	[ "$_lstd_outvar" = '0' ] && _lstd_outvar='_lstd_dummy'

	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	[ "$_lstd_index" -eq 0 ] && _lstd_index=$#

	if [ "$_lstd_index" -gt $# -o "$_lstd_index" -le 0 ]; then
		#printf 'No element no. %s in %s-sized list `%s`\n' \
		#    "$_lstd_index" $# "$_lstd_lstnam" >&2
		return 1
	fi

	_lstd_elem=
	eval "${_lstd_outvar:-_lstd_elem}=\$$_lstd_index"

	[ -z "$_lstd_outvar" ] && printf '%s' "$_lstd_elem"

	return 0
}

# 1: List name, [2: Output variable name]
list_count()
{
	_lstd_lstnam="$1"
	_lstd_outvar="$2"
	[ "$_lstd_outvar" = '0' ] && _lstd_outvar='_lstd_dummy'

	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	_lstd_cnt=
	eval "${_lstd_outvar:-_lstd_cnt}=$#"

	[ -z "$_lstd_outvar" ] && printf '%s' "$_lstd_cnt"

	return 0
}


# 1: List name
list_dump()
{
	_lstd_lstnam="$1"

	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	_lstd_c=1
	_lstd_tot=$#
	while [ $# -gt 0 ]; do
		printf '%s[%s/%s]: `%s`\n' \
		    "$_lstd_lstnam" "$_lstd_c" "$_lstd_tot" "$1" >&2

		shift
		_lstd_c=$((_lstd_c+1))
	done

	[ $_lstd_c -eq 1 ] && printf 'List `%s` is empty.\n' "$_lstd_lstnam" >&2

	return 0
}

# 1: List name, 2: Index to remove, [3: Output variable name]
list_remove()
{
	_lstd_lstnam="$1"
	_lstd_index="$2"
	_lstd_outvar="$3"
	[ "$_lstd_outvar" = '0' ] && _lstd_outvar='_lstd_dummy'

	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	[ "$_lstd_index" -eq 0 ] && _lstd_index=$#

	if [ "$_lstd_index" -gt $# -o "$_lstd_index" -le 0 ]; then
		#printf 'Cannot remove index %s from %s-sized list `%s`\n' \
		#    "$_lstd_index" $# "$_lstd_lstnam" >&2
		return 1
	fi

	_lstd_c=1
	_lstd_elem=
	_lstd_newlst=
	while [ $# -gt 0 ]; do
		if [ $_lstd_c -ne "$_lstd_index" ]; then
			_lstd_newlst="$_lstd_newlst $(_lstd_esc "$1")"
		else
			_lstd_elem="$1"
		fi
		_lstd_c=$((_lstd_c+1))
		shift
	done

	eval "$_lstd_lstnam=\"\$_lstd_newlst\""

	if [ -n "$_lstd_outvar" ]; then
		eval "$_lstd_outvar=\"\$_lstd_elem\""
	else
		printf '%s' "$_lstd_elem"
	fi

	return 0
}


# 1: List name, [2: Output variable name]
list_pop_front()
{
	list_remove "$1" 1 "$2"
}

# 1: List name, [2: Output variable name]
list_pop_back()
{
	list_remove "$1" 0 "$2"
}

# 1: List name, 2: First index, 3: Last index, [4: Output variable name (sublist)]
list_slice()
{
	_lstd_lstnam="$1"
	_lstd_sind="$2"
	_lstd_eind="$3"
	_lstd_outvar="$4"
	[ "$_lstd_outvar" = '0' ] && _lstd_outvar='_lstd_dummy'

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
	[ "$_lstd_cl_outvar" = '0' ] && _lstd_cl_outvar='_lstd_dummy'

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
	[ "$_lstd_rt_outvar" = '0' ] && _lstd_rt_outvar='_lstd_dummy'

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

# 1: List name, 2...: Elements
list_set()
{
	_lstd_lstnam="$1"
	shift

	eval "$_lstd_lstnam="
	list_add_back "$_lstd_lstnam" '' "$@"
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

	# Tests for ksh-ish non-whitespace-IFS behavior; sets _lstd_kshish_ifs 
	# accordingly.  We need to know this because ksh and bourne-ish shells
	# have different behavior when it comes to trailing delimiter char.
	# I.e. with IFS='x', 'foox' is considered TWO fields by ksh, but ONE
	# fields by bourne-ish shells.  Likewise, 'fooxxx' is FOUR fields in
	# ksh, but THREE fields in bourne-like shells.  I.e. what bourne
	# shells do is trim off one (and only one) trailing delimiter character,
	# if present.
	_lstd_test_kshish_ifs

	_lstd_oldifs="$IFS"
	IFS="$_lstd_nifs"
	set -- $_lstd_str
	IFS="$_lstd_oldifs"

	_lstd_subtr=0
	if $_lstd_kshish_ifs && endsin "$_lstd_str" "$_lstd_nifs"; then
		if ! endsin "$_lstd_str" "$_lstd_TAB $_lstd_NL"; then
			_lstd_subtr=1 #We're ksh-ish and have trailing nonWS-IFS
		fi
	fi

	eval "$_lstd_lstnam="
	list_add_back "$_lstd_lstnam" "$(($#-$_lstd_subtr))" "$@"
}

# 1: List name, 2: Element to find, [3: Output variable name]
list_find()
{
	_lstd_lstnam="$1"
	_lstd_str="$2"
	_lstd_outvar="$3"
	[ "$_lstd_outvar" = '0' ] && _lstd_outvar='_lstd_dummy'

	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	_lstd_c=1
	while [ $# -gt 0 ]; do
		if [ "$1" = "$2" ]; then
			break
		fi

		shift
		_lstd_c=$((_lstd_c+1))
	done

	if [ $# -eq 0 ]; then
		#printf 'Did not find element in list `%s`\n' \
		#    "$_lstd_lstnam" >&2
		return 1
	fi

	if [ -n "$_lstd_outvar" ]; then
		eval "$_lstd_outvar=$_lstd_c"
	else
		printf '%s' "$_lstd_c"
	fi

	return 0
}

# [1: Output varname (maj), 2: Output varname (min), 3: Output varname (pat)]
list_version()
{
	_lstd_outvar_maj="$1"
	_lstd_outvar_min="$2"
	_lstd_outvar_pat="$3"

	if [ -z "$_lstd_outvar_maj" ]; then
		printf '%s.%s.%s' \
		    "$_lstd_ver_maj" "$_lstd_ver_min" "$_lstd_ver_pat"
	fi

	[ -n "$_lstd_outvar_maj" ] && eval "$_lstd_outvar_maj=$_lstd_ver_maj"
	[ -n "$_lstd_outvar_min" ] && eval "$_lstd_outvar_min=$_lstd_ver_min"
	[ -n "$_lstd_outvar_pat" ] && eval "$_lstd_outvar_pat=$_lstd_ver_pat"

	return 0
}

# No args
_lstd_test_kshish_ifs()
{
	case "x$_lstd_kshish_ifs" in
		xtrue|xfalse) return ;;
	esac

	_lstd_oldifs="$IFS"
	_lstd_dummy='foox'
	IFS='x'
	set -- $_lstd_dummy
	IFS="$_lstd_oldifs"
	
	if [ $# -eq 2 ]; then
		_lstd_kshish_ifs=true
	else
		_lstd_kshish_ifs=false
	fi
}
