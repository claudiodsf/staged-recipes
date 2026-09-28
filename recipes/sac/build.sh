#!/usr/bin/env bash
set -euo pipefail

# The pre-generated lemon parsers shipped in the tarball (src/eval/expr_parse.c
# and expr_parse_noop.c) declare and define their trace helpers only when
# NDEBUG is not set, while the grammar calls them unconditionally, so they do
# not compile with the -DNDEBUG that the conda-forge compiler activation adds
# to the flags. Upstream builds without NDEBUG as well.
export CPPFLAGS="${CPPFLAGS//-DNDEBUG/}"
export CFLAGS="${CFLAGS//-DNDEBUG/}"

# The X11 headers and libraries come from the conda-forge xorg-* packages, but
# the compiler wrappers do not add ${PREFIX}/include to the search path, so
# AC_PATH_XTRA is pointed at the host prefix explicitly.
./configure \
  --prefix="${PREFIX}" \
  --x-includes="${PREFIX}/include" \
  --x-libraries="${PREFIX}/lib" \
  --enable-optim=2

make -j"${CPU_COUNT}"

make install
