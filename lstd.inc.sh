#!/bin/sh

# lstd: Supposedly robust POSIX shell list handling
# (C) 2015, Timo Buhrmester
# This is still work in progress
# <BSD license here>

# We claim the _lstd_* name space (variables and functions)
# We provide our public interface in the list_* function name space
# We don't touch anything beyond that, or if we do (like for IFS), we make sure
#   to restore the original value when we're done.

# See README for documentation of these functions.

# For READING this script, :%s/_lstd_//g is suggested

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

list_add_back()
{
	_lstd_lstnam="$1"
	shift

	list_insert "$_lstd_lstnam" 0 "$@"
}

list_add_front()
{
	_lstd_lstnam="$1"
	shift

	list_insert "$_lstd_lstnam" 1 "$@"
}

list_insert()
{
	_lstd_lstnam="$1"
	_lstd_index="$2"
	shift 2

	while [ $# -gt 0 ]; do
		_lstd_insert_one "$_lstd_lstnam" "$_lstd_index" "$1"
		[ $_lstd_index -gt 0 ] && _lstd_index=$((_lstd_index+1))
		shift
	done
}

#list_insert's backend
_lstd_insert_one()
{
	_lstd_lstnam="$1"
	_lstd_index="$2"
	_lstd_elem="$(_lstd_esc "$3")"

	_lstd_newlst=
	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	[ "$_lstd_index" -eq 0 ] && _lstd_index=$(($#+1))

	if [ "$_lstd_index" -gt $(($#+1)) -o "$_lstd_index" -le 0 ]; then
		printf 'Cannot insert at index %s into %s-sized list `%s`' \
		    "$_lstd_index" $# "$_lstd_lstnam" >&2
		return 1;
	fi

	_lstd_c=1
	_lstd_inserted=false
	while [ $# -gt 0 ]; do
		if [ $_lstd_c -eq "$_lstd_index" ]; then
			_lstd_newlst="$_lstd_newlst $_lstd_elem"
			_lstd_inserted=true
		fi
		_lstd_newlst="$_lstd_newlst $(_lstd_esc "$1")"
		_lstd_c=$((_lstd_c+1))
		shift
	done

	if ! $_lstd_inserted; then
		_lstd_newlst="$_lstd_newlst $_lstd_elem"
	fi

	eval "$_lstd_lstnam=\"\$_lstd_newlst\""

	return 0
}

list_replace()
{
	_lstd_lstnam="$1"
	_lstd_index="$2"
	_lstd_elem="$(_lstd_esc "$3")"
	_lstd_outvar="$4"
	[ "$_lstd_outvar" = '0' ] && _lstd_outvar='_lstd_dummy'

	_lstd_newlst=
	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	[ "$_lstd_index" -eq 0 ] && _lstd_index=$#

	if [ "$_lstd_index" -gt $# -o "$_lstd_index" -le 0 ]; then
		printf 'Cannot replace index %s in %s-sized list `%s`' \
		    "$_lstd_index" $# "$_lstd_lstnam" >&2
		return 1;
	fi

	_lstd_c=1
	_lstd_relem=
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

list_front()
{
	list_get "$1" 1 "$2"
}

list_back()
{
	list_get "$1" 0 "$2"
}

list_get()
{
	_lstd_lstnam="$1"
	_lstd_index="$2"
	_lstd_outvar="$3"
	[ "$_lstd_outvar" = '0' ] && _lstd_outvar='_lstd_dummy'

	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	[ "$_lstd_index" -eq 0 ] && _lstd_index=$#
	if [ "$_lstd_index" -gt $# -o "$_lstd_index" -le 0 ]; then
		printf 'No element no. %s in %s-sized list `%s`\n' \
		    "$_lstd_index" $# "$_lstd_lstnam" >&2
		return 1
	fi


	_lstd_elem=
	eval "${_lstd_outvar:-_lstd_elem}=\$$_lstd_index"

	[ -z "$_lstd_outvar" ] && printf '%s' "$_lstd_elem"

	return 0
}

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

list_remove()
{
	_lstd_lstnam="$1"
	_lstd_index="$2"
	_lstd_outvar="$3"
	[ "$_lstd_outvar" = '0' ] && _lstd_outvar='_lstd_dummy'

	_lstd_newlst=
	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	[ "$_lstd_index" -eq 0 ] && _lstd_index=$#

	if [ "$_lstd_index" -gt $# -o "$_lstd_index" -le 0 ]; then
		printf 'Cannot remove index %s from %s-sized list `%s`\n' \
		    "$_lstd_index" $# "$_lstd_lstnam" >&2
		return 1
	fi

	_lstd_c=1
	_lstd_elem=
	while [ $# -gt 0 ]; do
		if [ $_lstd_c -ne "$_lstd_index" ]; then
			_lstd_newlst="$_lstd_newlst $(_lstd_esc "$1")"
		else
			_lstd_elem="$(_lstd_esc "$1")"
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


list_pop_front()
{
	list_remove "$1" 1 "$2"
}

list_pop_back()
{
	list_remove "$1" 0 "$2"
}

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
		printf 'Illegal start index %s in %s-sized list `%s`' \
		    "$_lstd_sind" $# "$_lstd_lstnam" >&2
		return 1
	fi

	if [ "$_lstd_eind" -gt $# -o "$_lstd_eind" -le 0 ]; then
		printf 'Illegal end index %s in %s-sized list `%s`' \
		    "$_lstd_eind" "$#-" "$_lstd_lstnam" >&2
		return 1
	fi


	if [ "$_lstd_eind" -lt "$_lstd_sind" ]; then
		printf "'last_index' (%s) must be >= 'first_index' (%s) " \
		    "$_lstd_eind" "$_lstd_sind" >&2
		printf 'for slicing %s-sized list `%s`\n' $# "$_lstd_lstnam" >&2

		return 1
	fi


	_lstd_c=1
	_lstd_sublst=
	while [ $# -gt 0 ]; do
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

list_foreach()
{
	_lstd_lstnam="$1"
	_lstd_action="$2"

	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	while [ $# -gt 0 ]; do
		$_lstd_action "$1"
		shift
	done

	return 0
}

list_collect()
{
	_lstd_lstnam="$1"
	_lstd_decider="$2"
	_lstd_outvar="$3"
	[ "$_lstd_outvar" = '0' ] && _lstd_outvar='_lstd_dummy'

	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	_lstd_c=1
	_lstd_sublst=
	while [ $# -gt 0 ]; do
		if $_lstd_decider "$1"; then
			_lstd_sublst="$_lstd_sublst $(_lstd_esc "$1")"
		fi
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

# removes from the given list
# outputs/assigns the *removed* sublist to stdout/_lstd_outvar
list_retain()
{
	_lstd_lstnam="$1"
	_lstd_decider="$2"
	_lstd_outvar="$3"
	[ "$_lstd_outvar" = '0' ] && _lstd_outvar='_lstd_dummy'

	eval "_lstd_lstdata=\"\$$_lstd_lstnam\""; eval "set -- $_lstd_lstdata"

	_lstd_c=1
	_lstd_newlst=
	_lstd_remlst=
	while [ $# -gt 0 ]; do
		if $_lstd_decider "$1"; then
			_lstd_newlst="$_lstd_newlst $(_lstd_esc "$1")"
		else
			_lstd_remlst="$_lstd_remlst $(_lstd_esc "$1")"
		fi
		_lstd_c=$((_lstd_c+1))
		shift
	done

	eval "$_lstd_lstnam=\"\$_lstd_newlst\""

	if [ -n "$_lstd_outvar" ]; then
		eval "$_lstd_outvar=\"\$_lstd_remlst\""
	else
		printf '%s' "$_lstd_remlst"
	fi

	return 0
}

list_set()
{
	_lstd_lstnam="$1"
	shift

	eval "$_lstd_lstnam="
	list_add_back "$_lstd_lstnam" "$@"
}

list_fromstr()
{
	_lstd_lstnam="$1"
	_lstd_nifs="$2"
	_lstd_str="$3"

	if [ -z "$_lstd_str" ]; then
		_lstd_str="$_lstd_nifs"
		_lstd_nifs="$(printf ' \t\nx')"; _lstd_nifs="${_lstd_nifs%x}"
	fi

	_lstd_oldifs="$IFS"
	IFS="$_lstd_nifs"

	set -- $_lstd_str
	IFS="$_lstd_oldifs"

	eval "$_lstd_lstnam="
	list_add_back "$_lstd_lstnam" "$@"
}
