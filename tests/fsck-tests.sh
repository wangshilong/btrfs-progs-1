#!/bin/bash
#
# loop through all of our bad images and make sure fsck repairs them properly
#
# It's GPL, same as everything else in this tree.
#

unset top
unset LANG
LANG=C
script_dir=$(dirname $(realpath $0))
top=$(realpath $script_dir/../)
TEST_DEV=${TEST_DEV:-}
TEST_MNT=${TEST_MNT:-$top/tests/mnt}
RESULT="$top/tests/fsck-tests-results.txt"

source $top/tests/common

# Allow child test to use $top and $RESULT
export top
export RESULT
# For custom script needs to verfiy recovery
export TEST_MNT
export LANG

rm -f $RESULT
mkdir -p $TEST_MNT || _fail "unable to create mount point on $TEST_MNT"

# test rely on corrupting blocks tool
check_prereq btrfs-corrupt-block
check_prereq btrfs-image
check_prereq btrfs

# Each dir contains one type of error for btrfsck test.
# Each dir must be one of the following 2 types:
# 1) Only btrfs-image dump
#    Only contains one or several btrfs-image dumps (.img)
#    Each image will be tested by generic test routine
#    (btrfsck --repair and btrfsck).
#    This is for case that btree-healthy images.
# 2) Custom test script
#    This dir contains test.sh which will do custom image
#    generation/check/verification.
#    This is for case btrfs-image can't dump or case needs extra
#    check/verify

for i in $(find $top/tests/fsck-tests -maxdepth 1 -mindepth 1 -type d | sort)
do
	echo "     [TEST]    $(basename $i)"
	cd $i
	if [ -x test.sh ]; then
		# Type 2
		./test.sh
		if [ $? -ne 0 ]; then
			_fail "test failed for case $(basename $i)"
		fi
	else
		# Type 1
		check_all_images `pwd`
	fi
	cd $top
done

if [ -z $TEST_DEV ] || [ -z $TEST_MNT ];then
	echo "     [NOTRUN] extent tree rebuild"
	exit 0
fi

# test whether fsck can rebuild a corrupted extent tree
test_extent_tree_rebuild()
{
	echo "     [TEST]    extent tree rebuild"
	$top/mkfs.btrfs -f $TEST_DEV >> /dev/null 2>&1 || _fail "fail to mkfs"

	run_check mount $TEST_DEV $TEST_MNT
	cp -aR /lib/modules/`uname -r`/ $TEST_MNT 2>&1

	for i in `seq 1 100`;do
		$top/btrfs sub snapshot $TEST_MNT \
			$TEST_MNT/snapaaaaaaa_$i >& /dev/null
	done
	run_check umount $TEST_DEV

	# get extent root bytenr
	extent_root_bytenr=`$top/btrfs-debug-tree -r $TEST_DEV | \
			    grep extent | awk '{print $7}'`
	if [ -z $extent_root_bytenr ];then
		_fail "fail to get extent root bytenr"
	fi

	# corrupt extent root node block
	run_check $top/btrfs-corrupt-block -l $extent_root_bytenr \
		-b 4096 $TEST_DEV

	$top/btrfs check $TEST_DEV >& /dev/null && \
			_fail "btrfs check should detect failure"
	run_check $top/btrfs check --init-extent-tree $TEST_DEV
	run_check $top/btrfs check $TEST_DEV
}

test_extent_tree_rebuild
