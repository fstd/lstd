/* SYNOPSIS: ./garbfile [<numfiles>] [<fnlength>]
 * Creates files with horrible filenames in the current working directory
 * <numfiles> is the number of files to create, default: 1
 * <fnlength> is the length of the filenames to create, default: 32
 * The created files have names that may contain ANY character, except
 * NUL (\0) and SLASH (/).
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <errno.h>

#include <time.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>


void
garbage(unsigned char *dest, size_t len)
{
	while (len--) {
		int c;
		do {
			c = random()%256u;
		} while (c == 0 || c == '/');
		*dest++ = c;
	}
}

int
main(int argc, char **argv)
{
	struct timeval tv;
	unsigned seed;

	size_t numfiles = 1;
	size_t filenamelen = 32;

	unsigned char fbuf[4096];

	if (argc >= 2) {
		if (strcmp(argv[1], "-h") == 0) {
			fprintf(stderr, "usage: %s [<number of files>] "
			    "[<filename length>]\n", argv[0]);
			exit(1);
		}
			
		numfiles = strtoul(argv[1], NULL, 0);
	}

	if (argc >= 3)
		filenamelen = strtoul(argv[2], NULL, 0);
	
	if (filenamelen >= sizeof fbuf)
		filenamelen = sizeof fbuf - 1;

	/* seed random(2) (not rand(3)) with milliseconds since midnight */
	gettimeofday(&tv, NULL);
	seed = (unsigned)tv.tv_sec;
	seed %= (60*60*24); //seconds since midnight
	seed *= 1000;
	seed += (unsigned)(tv.tv_usec/1000);
	srandom(seed);

	for (size_t i = 0; i < numfiles; i++) {
		garbage(fbuf, filenamelen);
		fbuf[filenamelen] = '\0';

		errno = 0;
		int fd = open((const char *)fbuf, O_RDONLY);
		if (fd != -1) {
			//fprintf(stderr, "filename exists\n");
			close(fd);
			i--; // try again
			continue;
		}

		fd = open((const char *)fbuf, O_WRONLY|O_CREAT, 0644);
		if (fd < 0) {
			perror("open");
			fprintf(stderr, "filename was:");
			for (size_t x = 0; x < sizeof fbuf; x++) {
				fprintf(stderr, " %02hhx", fbuf[x]);
			}
			exit(1);
		}

		errno=0;
		if (close(fd) != 0)
			perror("close");
	}

	return 0;
}
