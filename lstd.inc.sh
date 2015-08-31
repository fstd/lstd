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

# Replaces every occurence of ' in the supplied argument with '\'' (4 chars),
# then encloses the result in single quotes and prints it to standard output

# 1: Input to be escaped
_lstd_esc()
{
	_lstd_ce_input="$1"

	# Credits to Edgar Fuss for the approach
	printf "'"
	while :; do
		case "$_lstd_ce_input" in
			\'*) printf "'\\\\''"              ;; # '\''
			 ?*) printf '%c' "$_lstd_ce_input" ;;
			 "") break                         ;;
		esac
		_lstd_ce_input="${_lstd_ce_input#?}"
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
	_lstd_index="$2"
	_lstd_insnum="$3"
	shift 3

	if [ -z "$_lstd_insnum" ] || [ "$_lstd_insnum" -gt $# ]; then
		_lstd_insnum=$#
	fi

	_lstd_in_c=0
	while [ $_lstd_in_c -lt $_lstd_insnum ]; do
		if ! _lstd_insert_one "$_lstd_lstnam" "$_lstd_index" "$1"; then
			return 1
		fi

		# If adding at the end using pseudo-index 0, don't increment
		# the index but just leave it as 0, so we keep adding at the end
		# Otherwise, increment the index because we'd reverse the order
		# of new elements if we didn't.
		[ $_lstd_index -gt 0 ] && _lstd_index=$((_lstd_index+1))
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
	_lstd_io_lstnam="$1"
	_lstd_io_index="$2"
	_lstd_io_elem="$(_lstd_esc "$3")"

	eval "_lstd_io_lstdata=\"\$$_lstd_io_lstnam\""
	eval "set -- $_lstd_io_lstdata"

	# Index 0 means insert *after* the last element, hence $(($#+1))
	[ "$_lstd_io_index" -eq 0 ] && _lstd_io_index=$(($#+1))

	if [ "$_lstd_io_index" -gt $(($#+1)) -o "$_lstd_io_index" -le 0 ]; then
		#printf 'Cannot insert at index %s into %s-sized list `%s`\n' \
		#    "$_lstd_io_index" $# "$_lstd_io_lstnam" >&2
		return 1
	fi

	_lstd_io_c=1
	_lstd_io_inserted=false
	_lstd_io_newlst=
	while [ $# -gt 0 ]; do
		if [ $_lstd_io_c -eq "$_lstd_io_index" ]; then
			_lstd_io_newlst="$_lstd_io_newlst $_lstd_io_elem"
			_lstd_io_inserted=true
		fi
		_lstd_io_newlst="$_lstd_io_newlst $(_lstd_esc "$1")"
		_lstd_io_c=$((_lstd_io_c+1))
		shift
	done

	# If we have nothing inserted yet, we insert after the last element.
	if ! $_lstd_io_inserted; then
		_lstd_io_newlst="$_lstd_io_newlst $_lstd_io_elem"
	fi

	eval "$_lstd_io_lstnam=\"\$_lstd_io_newlst\""

	return 0
}

# this could be implemented in terms of list_remove+list_insert
# 1: List name, 2: Index to replace, 3: Element, [4: Output variable name]
list_replace()
{
	_lstd_lstnam="$1"
	_lstd_index="$2"
	_lstd_elem="$(_lstd_esc "$3")"
	_lstd_outvar="$4"
	[ "$_lstd_outvar" '=' '0' ] && _lstd_outvar='_lstd_dummy'

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
	[ "$_lstd_outvar" '=' '0' ] && _lstd_outvar='_lstd_dummy'

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
	[ "$_lstd_outvar" '=' '0' ] && _lstd_outvar='_lstd_dummy'

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
	[ "$_lstd_outvar" '=' '0' ] && _lstd_outvar='_lstd_dummy'

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

# 1: List name, 2...: Elements
list_set()
{
	_lstd_lstnam="$1"
	shift

	eval "$_lstd_lstnam="
	list_add_back "$_lstd_lstnam" '' "$@"
}

# 1: List name, 2: Element to find, [3: Output variable name]
list_find()
{
	_lstd_lstnam="$1"
	_lstd_str="$2"
	_lstd_outvar="$3"
	[ "$_lstd_outvar" '=' '0' ] && _lstd_outvar='_lstd_dummy'

	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	_lstd_c=1
	while [ $# -gt 0 ]; do
		if [ "$1" '=' "$_lstd_str" ]; then
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

