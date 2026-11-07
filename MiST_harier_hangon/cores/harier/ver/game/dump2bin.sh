#!/bin/bash -e

DUMP=dump.bin
DELETE=

main() {
	parse_args "$@"
	if [ -n "$DELETE" ]; then
		delete_parts
		return
	fi
	require_input_file
	split_into_parts
	run_core_specific_script
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--delete) DELETE=1;;
			*) DUMP="$1";;
		esac
		shift
	done
}

require_input_file() {
	if [ ! -e "$DUMP" ]; then
		echo "Cannot find $DUMP"
		return 1
	fi
}

split_into_parts() {
	rm -f roadram.bin
	dd if="$DUMP" of=roadram.bin bs=64 count=64 skip=0
	jtutil drop1    < roadram.bin > roadram_hi.bin
	jtutil drop1 -l < roadram.bin > roadram_lo.bin
	
	rm -f objram.bin
	dd if="$DUMP" of=objram.bin bs=64 count=64 skip=64
	jtutil drop1    < objram.bin > objram_hi.bin
	jtutil drop1 -l < objram.bin > objram_lo.bin
	
	rm -f pal.bin
	dd if="$DUMP" of=pal.bin bs=64 count=64 skip=128
	jtutil drop1    < pal.bin > pal_hi.bin
	jtutil drop1 -l < pal.bin > pal_lo.bin
	
	
	make_rest
}

delete_parts() {
	rm -f roadram.bin
	rm -f roadram_hi.bin roadram_lo.bin
	
	rm -f objram.bin
	rm -f objram_hi.bin objram_lo.bin
	
	rm -f pal.bin
	rm -f pal_hi.bin pal_lo.bin
	
	
	rm -f rest.bin
	run_core_specific_script --delete
}

make_rest() {
	dd if="$DUMP" of=rest.bin bs=64 skip=192
}

run_core_specific_script() {
	local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	for path in $script_path/. $script_path/..; do
		if [ -x $path/rest2bin.sh ]; then
			echo $path/rest2bin.sh
			$path/rest2bin.sh "$@"
			return
		fi
	done
}

main "$@"
