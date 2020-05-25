#!/bin/bash
#
# Usage:
#   1) Build all this library suite on the host architecture (slow, deletes previous build):
#     ./scripts/build.bash
#   2) Build all dependencies for different architecture:
#     See `scripts/android/build.sh` and `scripts/ios/build.sh`.
#   3) (Re-)build only specific libraries:
#     ./scripts/build.bash eigen theia
#       will build first `eigen` then `theia`, without deleting
#       other builds.
set -e

: "${TARGET_ARCHITECTURE:=host}"
: "${BUILD_VISUALIZATIONS:=ON}"
: "${CMAKE:=cmake}"
: "${CC:=clang}"
: "${CXX:=clang++}"
: "${USE_SLAM:=ON}"
: "${DO_CLEAR:=ON}"
: "${NPROC:=4}"
# on non-iOS platforms, pass -- -j X to set the number of thread used
# which speeds up the build. There is also a -j flag in newer CMake versions,
# see https://stackoverflow.com/a/50883555/1426569
: "${CMAKE_MAKE_FLAGS:=-- -j$NPROC}"

export CC
export CXX

ROOT_DIR=`pwd`
BUILD_DIR=$ROOT_DIR/build/$TARGET_ARCHITECTURE
WORK_DIR=$BUILD_DIR/work
SRC_DIR=$ROOT_DIR
SCRIPT_DIR=$ROOT_DIR/scripts/components

INSTALL_PREFIX=$BUILD_DIR

if [ "$#" -ge 1 ]; then
  for LIB in "$@"; do
    BUILD_SCRIPT=$(find $SCRIPT_DIR | grep "$LIB" | head -n 1)
    if [ ! -z "$BUILD_SCRIPT" ]; then
      echo "Building: $BUILD_SCRIPT"
      source "$BUILD_SCRIPT"
    else
      echo "No matching build script for: $LIB"
    fi
  done
  exit 0
fi

echo "Building all dependencies."

set -x

if [[ $DO_CLEAR == "ON" ]]; then
  # first clear (forget about "make clean", won't work)
  for submodule in suitesparse g2o; do
    echo "nuking $submodule"
    rm -rf "$submodule"
    git submodule update "$submodule"
  done
  rm -rf "$INSTALL_PREFIX" # purge CMake build directories
fi

source $SCRIPT_DIR/eigen.sh
source $SCRIPT_DIR/theia.sh

if [[ $USE_SLAM == "ON" ]]; then
  source $SCRIPT_DIR/yaml-cpp.sh
  if [ -z $IOS_CROSS_COMPILING_HACKS ]; then
    # iOS uses Accelerate framework instead.
    source $SCRIPT_DIR/openblas.sh
  fi
  cd $ROOT_DIR
  source $SCRIPT_DIR/suitesparse.sh
  source $SCRIPT_DIR/g2o.sh
fi

if [[ $OPENCV_DIR ]]; then
  echo "using OpenCV in $OPENCV_DIR"
else
  source $SCRIPT_DIR/opencv.sh
fi

if [[ $USE_SLAM == "ON" ]]; then
  source $SCRIPT_DIR/dbow2.sh
  if [[ $BUILD_VISUALIZATIONS == "ON" ]]; then
    source $SCRIPT_DIR/pangolin.sh
  fi
fi