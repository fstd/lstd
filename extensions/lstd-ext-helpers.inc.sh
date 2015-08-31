# lstd: Supposedly reliable POSIX shell list handling -- nonessential helpers

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

_lstd_curfile='lstd-ext-helpers.inc.sh'

# This file contains functions that are NOT essential for
# the default list implementation lstd.inc.sh
#
# The extensions (lstd-ext.inc.sh) will need it, though


# Put the first character of $1 into the variable named by $2
# Returns successfully, unless the string does not have a first
# character, i.e. is empty.
_lstd_firstchar()
{
	_lstd_ehfc_str="$1"
	_lstd_ehfc_chr="$2"
	
	[ -z "$_lstd_ehfc_str" ] && return 1

	_lstd_ehfc_str="$(printf '%cx' "$_lstd_ehfc_str")"
	_lstd_ehfc_str="${_lstd_ehfc_str%x}"

	eval "$_lstd_ehfc_chr=\"\$_lstd_ehfc_str\""

	return 0
}

# Put the last character of $1 into the variable named by $2
# Returns successfully, unless the string does not have a last
# character, i.e. is empty.
_lstd_lastchar()
{
	_lstd_ehlc_str="$1"
	_lstd_ehlc_chr="$2"
	
	[ -z "$_lstd_ehlc_str" ] && return 1

	while [ "${#_lstd_ehlc_str}" -gt 1 ]; do
		_lstd_ehlc_str="${_lstd_ehlc_str#?}"
	done

	eval "$_lstd_ehlc_chr=\"\$_lstd_ehlc_str\""

	return 0
}

# Returns successfully if the last character of $1 is in the set
# of characters in $2, i.e. if $1 ends in [$2] (think regexp)
# By definition, the empty string ends in nothing, and nothing ends
# in the (nonexisting) characters in an empty set.  I.e. if $1 and/or
# $2 are empty, we return failure.
_lstd_endsin()
{
	_lstd_ehei_str="$1"
	_lstd_ehei_chrs="$2"
	
	[ -z "$_lstd_ehei_str" ] && return 1
	[ -z "$_lstd_ehei_chrs" ] && return 1

	_lstd_lastchar "$_lstd_ehei_str" _lstd_ehei_endchr

	while [ "${#_lstd_ehei_chrs}" -gt 0 ]; do
		_lstd_firstchar "$_lstd_ehei_chrs" _lstd_ehei_first

		if [ "x$_lstd_ehei_first" '=' "x$_lstd_ehei_endchr" ]; then
			return 0
		fi

		_lstd_ehei_chrs="${_lstd_ehei_chrs#?}"
	done

	return 1
}

# Returns successfully if the first character of $1 is in the set
# of characters in $2, i.e. if $1 starts with [$2] (think regexp)
# By definition, the empty string starts with nothing, and nothing
# starts with the (nonexisting) characters in an empty set.  I.e.
# if $1 and/or $2 are empty, we return failure.
_lstd_startswith()
{
	_lstd_ehsw_str="$1"
	_lstd_ehsw_chrs="$2"
	_lstd_ehsw_outvar="$3"
	[ "$_lstd_ehsw_outvar" '=' '0' ] && _lstd_ehsw_outvar='_lstd_dummy'
	
	[ -z "$_lstd_ehsw_str" ] && return 1
	[ -z "$_lstd_ehsw_chrs" ] && return 1

	_lstd_firstchar "$_lstd_ehsw_str" _lstd_ehsw_begchr

	eval "$_lstd_ehsw_outvar=\"\$_lstd_ehsw_begchr\""
	while [ "${#_lstd_ehsw_chrs}" -gt 0 ]; do
		_lstd_firstchar "$_lstd_ehsw_chrs" _lstd_ehsw_first

		if [ "x$_lstd_ehsw_first" '=' "x$_lstd_ehsw_begchr" ]; then
			return 0
		fi

		_lstd_ehsw_chrs="${_lstd_ehsw_chrs#?}"
	done

	return 1
}

# Produces any character except NUL
# Output goes via a variable in order to cope with the problems associated
# with command substitution (eating trailing newlines)
#
# 1: Character value (numeric), 2: Output variable name
_lstd_getchr()
{
	_lstd_ehgc_chrnum="$1"
	_lstd_ehgc_outvar="$2"
	[ -z "$2" ] && _lstd_ehgc_outvar='_lstd_dummy'

	_lstd_ehgc_chr="$(printf "$(printf '\\%o' "$_lstd_ehgc_chrnum")x")"
	_lstd_ehgc_chr="${_lstd_ehgc_chr%x}"
	eval "$_lstd_ehgc_outvar=\"\$_lstd_ehgc_chr\""
}


# Regexp that matches NUL bytes
# For some(*) reason, [^$(printf '\1')-$(printf '\377')] does NOT work
# (*) probably usage of 'char' rather than 'unsigned char'
#
_lstd_NULpat="[^$(printf '\1')-$(printf '\177')$(printf '\200')-$(printf '\377')]"

# These are just wrappers around sed(1), should(TM) be safe for binary data
_lstd_replNUL()
{
	_lstd_repl "$_lstd_NULpat" "$1"
}

_lstd_repl()
{
	env -i LANG=C LC_CTYPE=C sed "s/$1/$2/g"
}


# No args
_lstd_test_kshish_ifs()
{
	case "x$_lstd_kshish_ifs" in
		xtrue|xfalse) return ;;
	esac

	_lstd_ehtk_oldifs="$IFS"
	_lstd_dummy='foox'
	IFS='x'
	set -- $_lstd_dummy
	IFS="$_lstd_ehtk_oldifs"
	
	if [ $# -eq 2 ]; then
		_lstd_kshish_ifs=true
	else
		_lstd_kshish_ifs=false
	fi
}



_lstd_sourced="$_lstd_sourced $_lstd_curfile"
_lstd_curfile=
