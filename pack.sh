#!/bin/bash

if (( $(./deps/readies/bin/platform --os) == macosx )); then
	export PATH=$PATH:$HOME/Library/Python/2.7/bin

	realpath() {
    	[[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
	}
fi

pack() {
	local artifact="$1"
	local branch="$2"

	# local packfile=$PACKAGE_NAME.{os}-$OS_VERSION-{architecture}.$branch.zip
	local ARCH=$(./deps/readies/bin/platform --arch)
	local OS=$(./deps/readies/bin/platform --os)
	# local OSNICK=${OS_VERSION}
	local OSNICK=$(./deps/readies/bin/platform --osnick)
	local packfile=$PACKAGE_NAME.$OS-$OSNICK-$ARCH.$branch.zip

	local packer=$(mktemp "${TMPDIR:-/tmp}"/pack.XXXXXXX)
	cat <<- EOF > $packer
		cd $ROOT
		ramp pack $GEARS -m ramp.yml -o $packfile | tail -1
	EOF

	cd $CPYTHON_PREFIX

	export LC_ALL=C.UTF-8
	export LANG=C.UTF-8
	
	packname=`pipenv run bash $packer`
	cd $ROOT
	[[ -f $packer ]] && rm -f $packer
	if [[ -z $packname ]]; then
		echo Failed to pack $artifact
		exit 1
	fi
	
	mv $packname artifacts/$artifact/
	packname="artifacts/$artifact/$packname"
	echo Created $packname
}

set -e

if ! command -v redis-server > /dev/null; then
	echo Cannot find redis-server. Aborting.
	exit 1
fi

export ROOT=`git rev-parse --show-toplevel`
CPYTHON_PREFIX=${CPYTHON_PREFIX:-/opt/redislabs/lib/modules/python3}
[[ -z $1 ]] && echo Nothing to pack. Aborting. && exit 1
[[ ! -f $1 ]] && echo $1 does not exist. Aborting. && exit 1
GEARS=$(realpath $1)

PACKAGE_NAME=${PACKAGE_NAME:-redisgears}
BRANCH=${CIRCLE_BRANCH:-`git rev-parse --abbrev-ref HEAD`}
BRANCH=${BRANCH//[^A-Za-z0-9._-]/_}
OS_VERSION=${OS_VERSION:-generic}

export PYTHONWARNINGS=ignore

cd $ROOT
mkdir -p artifacts/snapshot artifacts/release

pack release "{semantic_version}"
RELEASE=$packname

pack snapshot "$BRANCH"
SNAPSHOT=$packname

if [[ ! -d $CPYTHON_PREFIX ]]; then
	echo $CPYTHON_PREFIX does not exist
	exit 1
fi

stem=$(basename $RELEASE | sed -e "s/^$PACKAGE_NAME\.\(.*\)\.zip/\1/")
TAR=$PACKAGE_NAME-dependencies.$stem.tgz
TAR_PATH=$(realpath artifacts/release/$TAR)
cd $CPYTHON_PREFIX/
tar pczf $TAR_PATH --transform "s,^./,$CPYTHON_PREFIX/," ./ 2> /dev/null
cd - > /dev/null
echo Created artifacts/release/$TAR

stem=$(basename $SNAPSHOT | sed -e "s/^$PACKAGE_NAME\.\(.*\)\.zip/\1/")
TAR1=$PACKAGE_NAME-dependencies.$stem.tgz
cp artifacts/release/$TAR artifacts/snapshot/$TAR1
echo Created artifacts/snapshot/$TAR1
