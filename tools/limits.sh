#!/bin/sh

#NetBSD frozen 7.99.20 i386
#  ash (NetBSD 7.99.20 sh)
#    268435456 okay  #then: printf: Could not allocate formatted output buffer
#  GNU bash, version 4.3.39(1)-release (i486--netbsdelf)
#    8388608 okay   #then: limits.sh: xrealloc: subst.c:687: cannot allocate 33554560 bytes (201371648 bytes allocated)
#  ksh (NetBSD 7.99.20 ksh)
#    131072 okay     #then: limits.sh[47]: printf: Argument list too long
#  posh
#    131072 okay #limits.sh:58: printf: Argument list too long
#  zsh
#    268435456 okay #manually interrupted, total memory hog


#FreeBSD stealthcell 10.2-PRERELEASE amd64
# ash
#  536870912 okay #then limits.sh: Out of space
# bash
#  268435456 okay #interrupted manually, total CPU and memory hog


#Linux 3.10.75 x86_64
#  dash (Debian dash 0.5.7-3)
#    1073741824 okay #then: limits.sh: Variable length wrong 2 (0 vs 2147483648)
#  GNU bash, version 4.2.37(1)-release (x86_64-pc-linux-gnu)
#    268435456 okay  #(after a LONG time and 3G+ memory usage). interrupted manually
#  zsh 4.3.17 (x86_64-unknown-linux-gnu)
#    268435456 okay  #(after a LONG time and 2G+ memory usage). interrupted manually
#  posh 0.10.2
#    65536 okay #limits.sh:41: printf: Argument list too long
#  pdksh  40.9.20120630-7
#    65536 okay #limits.sh[41]: printf: Argument list too long

Bomb()
{
	printf '%s: %s\n' "$0" "$1" >&2
	exit 1
}

tmp="$(mktemp /tmp/limits.XXXXXX)"
trap "rm -f '$tmp'" EXIT
trap "exit 1" INT TERM QUIT

bs=$((64*1024))
blocks=1
dd if=/dev/urandom bs=$bs count=$blocks 2>/dev/null \
    | tr -c 'a-zA-Z0-9 ' 'a-zA-Z0-9 a-zA-Z0-9 a-zA-Z0-9 a-d' >$tmp

niter=1

set -e
while true; do
	c=0
	var=
	len=$((bs*blocks*niter))
	var="$(while [ $c -lt $niter ]; do
		cat $tmp
		c=$((c+1))
	done)"

	if [ ${#var} -ne $len ]; then
		Bomb "Variable length wrong 1 (${#var} vs $len)"
	fi

	nc=$(printf '%s' "$var" | wc -c)
	if [ $nc -ne $len ]; then
		Bomb "Variable length wrong 2 ($nc vs $len)"
	fi

	printf 'len %s okay\n' "$len" >&2
	niter=$((niter*2))
done

echo "Okay"
exit 0
