#!/bin/bash

function usage {
	printf "%s [OPTION]... SOURCE... DEST\n" "$0"
	printf " Split or join a file into multiple chunks.\n"
	printf " Multiple SOURCE files will be joined.\n\n"
	printf " Options:\n"
	printf "  -c SIZE      chunk size (Default: 7M, Min: 1K)\n"
}

function size_to_bytes {
	numfmt --from=iec $1
}

readonly BLOCK_SIZE=1K

# TODO: Get from args
CHUNK_SIZE=7M
FILE_SIZE=$(du -L -b filename | awk '{print $1}')

chunk_bytes=$(size_to_bytes $CHUNK_SIZE)

skip=0
while [ $skip -lt $(size_to_bytes $FILE_SIZE) ]; do
	echo $skip
	skip=$(($skip + $chunk_bytes))
done
