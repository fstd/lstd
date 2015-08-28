#!/bin/sh
# lstd: Supposedly reliable POSIX shell list handling -- some example snippets

# Copyright (c) 2015, Timo Buhrmester
# All rights reserved.


# This is still work in progress


. ./lstd.inc.sh

list_version maj min pat
echo "lstd version $maj.$min.$pat"

# Create a list named 'mylist' from direct specification of the elements:
list_set mylist "head element" "another element" "3rd element"

# Add another element at the end of `mylist`
list_add_back mylist "4th element"

# Create a list named 'argv' of the arguments passed to this shell script
list_set argv "$@"

# Let's make a copy of it
argv_copy="$argv"

# Iterate over our `argv` array, popping it empty.
while list_pop_front argv elem; do
	printf 'List element: `%s`\n' "$elem"
done

# Or, non-destructively iterate over it (after restoring our copy)
argv="$argv_copy"
list_count argv count
c=1
while [ $c -le $count ]; do
	list_get argv $c elem
	printf 'List element: `%s`\n' "$elem"
	c=$((c+1))
done

# Or, ``foreach'' it, using a callback function.  In one go, we demonstrate
# how this can be used to change elements while iterating
callback()
{
	listname="$1"
	index="$2"
	elem="$3"

	printf 'List `%s` index %s: `%s` - mangling!\n' "$listname" "$index" "$elem"

	# We can replace elements from here, provided we touch only elements
	# with index <= $index.  The trailing 0 supresses the output (which
	# would be the element that got replaced)
	list_replace "$listname" "$index" "foo $elem bar" 0
}

list_foreach argv callback

# Dump the list to see how it was mangled by the callback
list_dump argv
