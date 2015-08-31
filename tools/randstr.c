/* SYNOPSIS: ./randstr <min byte val> <max byte val> <len>
 * Creates files with horrible filenames in the current working directory
 * <numfiles> is the number of files to create, default: 1
 * <fnlength> is the length of the filenames to create, default: 32
 * The created files have names that may contain ANY character, except
 * NUL (\0) and SLASH (/).
 */

#define _BSD_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <errno.h>

#include <sys/time.h>
#include <time.h>
#include <unistd.h>


int
main(int argc, char **argv)
{
	struct timeval tv;
	unsigned seed;

	int mbv = 1;
	int Mbv = 255;
	size_t mlen = 0;
	size_t Mlen = 128;

	if (argc < 5) {
		fprintf(stderr, "usage: %s <min length> <max length> "
		    "<min byte val> <max byte val> <length>\n", argv[0]);
		exit(1);
	}

	mlen = strtoul(argv[1], NULL, 0);
	Mlen = strtoul(argv[2], NULL, 0);
	mbv = strtoul(argv[3], NULL, 0);
	Mbv = strtoul(argv[4], NULL, 0);

	/* seed random(3) (not rand(3)) with milliseconds since midnight */
	gettimeofday(&tv, NULL);
	seed = (unsigned)tv.tv_sec;
	seed %= (60*60*24); //seconds since midnight
	seed *= 1000;
	seed += (unsigned)(tv.tv_usec/1000);
	srandom(seed);

	size_t len = random() % (Mlen-mlen+1) + mlen;
	for (size_t i = 0; i < len; i++) {
		if (random() % 5 == 0) {
			switch (random() % 4) {
			case 0: putchar(' '); break;
			case 1: putchar('\t'); break;	
			case 2: putchar('\n'); break;
			case 3: putchar('\r'); break;
			}
		} else
			putchar(random() % (Mbv-mbv+1) + mbv);
	}

	return 0;
}
