#!/bin/bash -e

ARCH=$1
ROOT_DIR=$2
INSTALL_DIR=$3

CMAKE_VER="3.28.1"

case $(uname -s) in
    Linux*) ;;
    *) echo "Not running on a Linux system, aborting..."; exit 4;;
esac

case $ARCH in
    x86_64) ;;
    aarch64);;
    *) echo "Invalid architecture $ARCH, aborting..."; exit 5;;
esac

mkdir -p $ROOT_DIR/openblas/build_$ARCH

echo
echo " ======== Installing cbdeps ========"
echo

mkdir -p .tools
if [ ! -f $ROOT_DIR/.tools/cbdep ]; then
    curl -o $ROOT_DIR/.tools/cbdep http://packages.couchbase.com/cbdep.$(uname -s | tr "[:upper:]" "[:lower:]")-$(uname -m)
    chmod +x $ROOT_DIR/.tools/cbdep
fi

CMAKE="$ROOT_DIR/.tools/cmake-${CMAKE_VER}/bin/cmake"
if [ ! -f ${CMAKE} ]; then
    $ROOT_DIR/.tools/cbdep install -d .tools cmake ${CMAKE_VER}
fi

echo
echo "====  Building Linux binary ==="
echo

pushd $ROOT_DIR/openblas/build_$ARCH > /dev/null
if [ "$ARCH" == "x86_64" ]; then 
    $CMAKE \
    -DCMAKE_C_COMPILER=/opt/gcc-13.2.0/bin/gcc \
    -DBUILD_WITHOUT_LAPACK=0 \
    -DNOFORTRAN=1 \
    -DDYNAMIC_ARCH=1 \
    -DBUILD_LAPACK_DEPRECATED=0 \
    -DDYNAMIC_LIST="EXCAVATOR;HASWELL;ZEN;SKYLAKEX;COOPERLAKE;SAPPHIRERAPIDS" \
    -DBUILD_WITHOUT_CBLAS=1 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -S ..
 else
    $CMAKE \
    -DCMAKE_C_COMPILER=/opt/gcc-13.2.0/bin/gcc \
    -DBUILD_WITHOUT_LAPACK=0 \
    -DNOFORTRAN=1 \
    -DDYNAMIC_ARCH=0 \
    -DTARGET=ARMV8 \
    -DBUILD_LAPACK_DEPRECATED=0 \
    -DBUILD_WITHOUT_CBLAS=1 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -S ..
 fi

make -j$(nproc) install