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

# Apparently this is the *only way* to `ceil` :c
function divide_ceil {
	printf "%s\n" $((($1 + $2 - 1) / $2))
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

source_files=($(printf "%s\n" ${files[@]::${#files[@]}-1}))		# Exclude last file
destination_file="${files[-1]}"
block_bytes=$(size_to_bytes $BLOCK_SIZE)

# Check if source files are valid
for file in ${source_files[@]}; do
	if [[ ! -f $file ]]; then
		error "source file '$file' does not exist"
		exit 1
	fi
done

# Join on multiple source files
if [[ ${#files[@]} -gt 2 ]]; then
	if [[ -f "$destination_file" ]]; then
		error "destination file already exists"
		exit 1
	fi

	for file in ${source_files[@]}; do
		log "adding chunk '$file' to file '$destination_file'.."
		dd if="$file" bs=$block_bytes status=none >> $destination_file
	done

	log "source files have been joined successfully"

# Split on one source file
else
	file_bytes=$(du -Lb ${source_files[0]} | awk '{print $1}')
	chunk_bytes=$(size_to_bytes $chunk_size)
	parts_count=$(divide_ceil $file_bytes $chunk_bytes)

	# NOTE: If `chunk_bytes` is too small, it kinda bugs (https://i.imgur.com/1kasu3Z.png)
	blocks_count=$(divide_ceil $chunk_bytes $block_bytes)

	# Check if any part already exists and compute the names
	parts=()
	for i in $(seq -w 1 $parts_count); do
		part_name="${destination_file}.part$i"

		if [[ -f "$part_name" ]]; then
			error "destination files already exist"
			exit 1
		fi

		parts+=($part_name)
	done

	log "splitting file of $file_bytes bytes into $parts_count parts of $chunk_bytes bytes"

	offset=0
	for part in ${parts[@]}; do
		log "creating part '$part'.."
		dd if="${source_files[0]}" of="$part" bs=$block_bytes skip=$offset count=$blocks_count status=none

		offset=$(($offset + $blocks_count))
	done

	log "destination files have been written successfully"
fi

exit 0
