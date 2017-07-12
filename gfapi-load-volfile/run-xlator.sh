#!/bin/sh
#
#

usage()
{
	echo 'run-xlator.sh <type/function.'
	echo
	echo 'Example: ./run-xlator.sh performance/md-cache'
}

fail()
{
	echo "${@}" > /dev/stderr
	exit 1
}

if [ -z "${1}" -o "$1}" = '-h' -o "${1}" = '--help' ]
then
	usage
	exit 0
fi

# test to see if the test app exists
if [ ! -e 'gfapi-load-volfile' ]
then
	make || fail 'failed to compile gfapi-load-volfile'
fi

# check if valgrind is installed
if ! valgrind -h > /dev/null
then
	fail 'valgrind is not available'
fi

XLATOR_DIR=$(echo /usr/lib*/glusterfs/*/xlator)
XLATOR="${1}"
XLATOR_SO="${XLATOR_DIR}/${XLATOR}.so"

# check if the xlator exists
if [ ! -e "${XLATOR_SO}" ]
then
	fail "xlator ${XLATOR} does not exist under ${XLATOR_DIR}"
fi

# build a .vol file
TMPFILE=$(mktemp)
cat << EOF > ${TMPFILE}
volume sink
    type debug/sink
    option an-option-is-required yes
end-volume

volume $(basename ${XLATOR})
    type ${XLATOR}
    subvolumes sink
end-volume
EOF


# run through valgrind
VALGRIND_LOG=$(sed 's,/,_,g' <<< "${XLATOR}").$(date +%s).log
valgrind --fullpath-after= --leak-check=full --show-leak-kinds=all --log-file=${VALGRIND_LOG} ./gfapi-load-volfile ${TMPFILE}
RET=${?}

# cleanup the generated .vol file
rm -f ${TMPFILE}

# post process the valgrind log, strip (random) addresses and counters
sed -r -i \
    -e 's/==[0-9]+==/==..==/g' \
    -e 's/at 0x[A-F0-9]+:/at 0x..+/g' \
    -e 's/by 0x[A-F0-9]+:/by 0x../g' \
    -e 's/in loss record [0-9]+ of [0-9]+/in loss record X of Y/g' \
    -i ${VALGRIND_LOG}

echo "valgrind log saved in ${VALGRIND_LOG}"

exit ${RET}
