#!/usr/bin/bash
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License, Version 1.0 only
# (the "License").  You may not use this file except in compliance
# with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#
#
# Copyright 2017 OmniTI Computer Consulting, Inc.  All rights reserved.
# Copyright 2017 OmniOS Community Edition (OmniOSce) Association.
# Use is subject to license terms.
#
# Load support functions
. ../../lib/functions.sh

PROG=openssl
VER=1.0.2p
VERHUMAN=$VER
PKG=library/security/openssl # Package name (without prefix)
SUMMARY="$PROG - A toolkit for Secure Sockets Layer (SSL v2/v3) and Transport Layer (TLS v1) protocols and general purpose cryptographic library"
DESC="$SUMMARY"

DEPENDS_IPS="SUNWcs system/library system/library/gcc-5-runtime library/zlib"
BUILD_DEPENDS_IPS="$DEPENDS_IPS developer/sunstudio12.1"

# Generic configure optons for both 32 and 64bit variants
OPENSSL_CONFIG_OPTS="
		--pk11-libname=/usr/lib/libpkcs11.so.1 
		shared
		threads
		zlib
		enable-ssl2"

# Configure options specific to a 32bit build
OPENSSL_CONFIG_32_OPTS=""

# Configure options specific to a 64bit build
OPENSSL_CONFIG_64_OPTS="enable-ec_nistp_64_gcc_128"

NO_PARALLEL_MAKE=1

make_prog() {
    [ -n "$NO_PARALLEL_MAKE" ] && MAKE_JOBS=
    logmsg "--- make"
    # This will setup the internal runpath of libssl and libcrypto
    logcmd $MAKE $MAKE_JOBS SHARED_LDFLAGS="$SHARED_LDFLAGS" || \
        logerr "--- Make failed"
}

configure32() {
    if isalist | egrep -s sparc; then
      SSLPLAT=solaris-sparcv8-cc
    else
      SSLPLAT=solaris-x86-gcc
    fi
    logmsg "--- Configure (32-bit) $SSLPLAT"
    logcmd ./Configure $SSLPLAT --prefix=$PREFIX \
	${OPENSSL_CONFIG_OPTS} \
	${OPENSSL_CONFIG_32_OPTS} \
        || logerr "Failed to run configure"
    SHARED_LDFLAGS="-shared -Wl,-z,text"
}

configure64() {
    if [ -n "`isalist | grep sparc`" ]; then
      SSLPLAT=solaris64-sparcv9-cc
    else
      SSLPLAT=solaris64-x86_64-gcc
    fi
    logmsg "--- Configure (64-bit) $SSLPLAT"
    logcmd ./Configure $SSLPLAT --prefix=$PREFIX \
	${OPENSSL_CONFIG_OPTS} \
	${OPENSSL_CONFIG_64_OPTS} \
        || logerr "Failed to run configure"
    SHARED_LDFLAGS="-m64 -shared -Wl,-z,text"
}

make_install() {
    logmsg "--- make install"
    logcmd make INSTALL_PREFIX=$DESTDIR install ||
        logerr "Failed to make install"
}

install_pkcs11()
{
    logmsg "--- installing pkcs11 engine"
    pushd $SRCDIR/pkcs11 > /dev/null
    find . | cpio -pvmud $TMPDIR/$BUILDDIR/crypto/engine/
    popd > /dev/null
}

# Turn the letter component of the version into a number for IPS versioning
ord26() {
    local ASCII=$(printf '%d' "'$1")
    ASCII=$((ASCII - 64))
    [[ $ASCII -gt 32 ]] && ASCII=$((ASCII - 32))
    echo $ASCII
}

save_function make_package make_package_orig
make_package() {
    if [[ -n "`echo $VER | grep [a-z]`" ]]; then
        NUMVER=${VER::$((${#VER} -1))}
        ALPHAVER=${VER:$((${#VER} -1))}
        VER=${NUMVER}.$(ord26 ${ALPHAVER})
    fi

    make_package_orig
}

# Move installed libs from /usr/lib to /lib
move_libs() {
    logmsg "Relocating libs from usr/lib to lib"
    logcmd mv $DESTDIR/usr/lib/64 $DESTDIR/usr/lib/amd64
    logcmd mkdir -p $DESTDIR/lib/amd64
    logcmd mv $DESTDIR/usr/lib/lib* $DESTDIR/lib/ ||
        logerr "Failed to move libs (32-bit)"
    logcmd mv $DESTDIR/usr/lib/amd64/lib* $DESTDIR/lib/amd64/ ||
        logerr "Failed to move libs (64-bit)"
}

######################################################################

init

### Openssl 1.0.x build
download_source $PROG $PROG $VER
patch_source
install_pkcs11
prep_build
build
run_testsuite
move_libs

make_lintlibs crypto /lib /usr/include "openssl/!(ssl*|*tls*).h"
make_lintlibs ssl /lib /usr/include "openssl/{ssl,*tls}*.h"
make_isa_stub
make_package
clean_up

