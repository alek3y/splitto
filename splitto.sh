#!/bin/bash

chunk_size=7M		# Default value
readonly BLOCK_SIZE=1K
verbose=0

IFS=$'\n'		# Ensure arrays are split with a newline

function usage {
	printf "%s [OPTION]... SOURCE... DEST\n" "$0"
	printf " Split or join a file into multiple chunks.\n"
	printf " Multiple SOURCE files will be joined.\n\n"
	printf " Options:\n"
	printf "  -c SIZE          chunk size (Default: 7M, Min: 1K)\n"
	printf "  -v, --verbose    explain what is being done\n"
}

function size_to_bytes {
	numfmt --from=iec $1
}

function error {
	printf "%s: %s\n" "$0" "$@" >&2
}

function log {
	if [[ $verbose -eq 1 ]]; then
		printf "%s\n" "$@"
	fi
}

files=()
while [[ $# -gt 0 ]]; do
	case $1 in
		-c)
			if [[ -z "$2" ]]; then
				error "missing required parameter"
				exit 1
			fi

			chunk_size="$2"
			shift
			;;
		-v | --verbose)
			verbose=1
			;;
		-*)
			usage
			exit 1
			;;
		*)
			files+=($1)		# Last in the list is the output file
			;;
	esac
	shift
done

# At least source and destination files are needed
if [[ ${#files[@]} -lt 2 ]]; then
	error "missing positional parameter"
	exit 1
fi

# Abort if the destination exists
destination_file="${files[-1]}"
if [[ -f "$destination_file" ]]; then
	error "destination file already exists"
	exit 1
fi

# Sort naturally the source files, as the chunk number is the
# only part that differs, and exclude the destination file
source_files=($(printf "%s\n" ${files[@]::${#files[@]}-1} | sort -V))

# Check if source files are valid
for file in ${source_files[@]}; do
	if [[ ! -f $file ]]; then
		error "source file '$file' does not exist"
		exit 1
	fi
done

# Join on multiple source files
if [[ ${#files[@]} -gt 2 ]]; then
	for file in ${source_files[@]}; do
		log "adding chunk '$file' to file '$destination_file'.."
		dd if="$file" bs=$(size_to_bytes $BLOCK_SIZE) status=none >> $destination_file
	done
	log "source files have been joined successfully"

# Split on one source file
else

	# TODO: Get file size (bytes), convert chunk_size to bytes
	FILE_SIZE=$(du -L -b filename | awk '{print $1}')
	chunk_bytes=$(size_to_bytes $CHUNK_SIZE)
	skip=0
	while [ $skip -lt $(size_to_bytes $FILE_SIZE) ]; do
		echo $skip
		skip=$(($skip + $chunk_bytes))
	done
fi

exit 0
