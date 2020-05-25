#!/bin/bash
# SuiteSparse (g2o dependency)

if [[ $DO_CLEAR == "ON" ]]; then
  rm -rf "$WORK_DIR/suitesparse"
  # nothing relly cleans this properly if changing TARGET_ARCHITECTURE
  # make clean is definitely not enough, only the following helps...
  rm -rf "$SRC_DIR/suitesparse" && git submodule update "$SRC_DIR/suitesparse"
fi

cd "$SRC_DIR/suitesparse"
SUITESPARSE_FLAGS=(
  CUDA=no
  AUTOCC=no
  CFOPENMP=\"\"
  JOBS=$NPROC
  "INSTALL=\"$INSTALL_PREFIX\""
)
if [[ $SUITESPARSE_CF ]]; then
  SUITESPARSE_FLAGS+=("CF=$SUITESPARSE_CF")
fi

if [ -z $IOS_CROSS_COMPILING_HACKS ]; then
  make metisinstall "${SUITESPARSE_FLAGS[@]}"
fi

# Metis: Apache 2
# AMD, CAMD, COLAMD, CCOLAMD: BSD
# BTF, CXSparse: LGPL
# KLU: LGPL (dependency?)
# CHOLMOD: GPL-licensed, must skip
cd SuiteSparse_config
make static install "${SUITESPARSE_FLAGS[@]}"
cp libsuitesparseconfig.a "$INSTALL_PREFIX/lib"

if [ $ANDROID_CROSS_COMPILING_HACKS ]; then
  # the easiest way to get rid of "soname" suffixes for Android
  python "$ROOT_DIR/scripts/android/drop_library_soname_suffixes.py" "$INSTALL_PREFIX/lib"
fi
cd ..

for lib in AMD BTF CAMD CCOLAMD COLAMD CXSparse; do
  cd $lib
  LDFLAGS="$LDFLAGS -L$INSTALL_PREFIX/lib" make static install "${SUITESPARSE_FLAGS[@]}"
  cp Lib/*.a "$INSTALL_PREFIX/lib"
  if [ $ANDROID_CROSS_COMPILING_HACKS ]; then
    python "$ROOT_DIR/scripts/android/drop_library_soname_suffixes.py" "$INSTALL_PREFIX/lib"
  fi
  cd ..
done

if [ $IOS_CROSS_COMPILING_HACKS ]; then
  # Fix dynamic library paths for iOS.
  cd $INSTALL_PREFIX/lib
  config=$(find . | cut -c3- | grep "libsuitesparseconfig\.\d\.\d\.\d\.dylib")
  # All the libs link to the config lib.
  for short_lib in amd btf camd ccolamd colamd cxsparse; do
    lib=$(find . | cut -c3- | grep "lib$short_lib\.\d\.\d\.\d\.dylib")
    install_name_tool -id @rpath/$lib $lib
    install_name_tool -add_rpath @rpath/. $lib
    install_name_tool -change "$(pwd)/$config" @rpath/$config $lib
  done
  # Also change paths of the config lib.
  install_name_tool -id @rpath/$config $config
  install_name_tool -add_rpath @rpath/. $config

  # Leave only one of either .dylib or .a. LGPL code should be used as shared libraries.
  for short_lib in amd camd ccolamd colamd; do
    find . | grep $short_lib | grep dylib | xargs rm
  done
  rm libbtf.a
  rm libcxsparse.a
  rm libsuitesparseconfig.a
fi