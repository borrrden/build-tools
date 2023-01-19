#!/bin/bash -ex

INSTALL_DIR=$1
ROOT_DIR=$2
PLATFORM=$3

OPENSSL_VER=3.0.7-2
cd "${ROOT_DIR}"
cbdep --platform ${PLATFORM} install -d cbdeps openssl ${OPENSSL_VER}

cd erlang

JIT_OPTIONS="--enable-jit"

case "$PLATFORM" in
    macosx)
        export MACOSX_DEPLOYMENT_TARGET=10.10
        ulimit -u 1024

        # JIT is broken in v24 on arm and causes segfaults under rosetta in
        # v24 and v25, so we explicitly disable it everywhere problems occur
        # (see CBD-4513)
        JIT_OPTIONS="--disable-jit"
        if [ "25" = $(printf "25\n$(cat OTP_VERSION)" | sort -n | head -1) ]; then
            if [ "$(arch)" = "arm64" ]; then
                # JIT's ok on arm in v25+, so we can enable it there
                JIT_OPTIONS="--enable-jit"
            fi
        fi
        ;;
    *)
    # Arg.. you got to hate autoconf and trying to get something
    # as simple as $ORIGIN passed down to the linker ;)
    # the crypto module in Erlang use openssl for crypto routines,
    # and it is installed in
    #  ${INSTALL_DIR}/lib/erlang/lib/crypto-4.6.5/priv/lib/crypto.so
    # so we need to tell the runtime linker how to find libssl.so
    # at runtime (which is located in ${INSTALL_DIR}/..
    # We could of course do this by adding /opt/couchbase/lib,
    # but that would break "non-root" installation (and people
    # trying to build the sw themselves and run from a dev dir).
    SSL_RPATH=--with-ssl-rpath="\$$\ORIGIN/../../../../.."
    ;;
esac

./configure --prefix="$INSTALL_DIR" \
      --enable-smp-support \
      --disable-hipe \
      --disable-fp-exceptions \
      --without-javac \
      --without-et \
      --without-debugger \
      --without-megaco \
      --with-ssl="${ROOT_DIR}/cbdeps/openssl-${OPENSSL_VER}" \
      $SSL_RPATH \
      $JIT_OPTIONS \
      CFLAGS="-fno-strict-aliasing -O3 -ggdb3"

make -j4
make install

# Prune wxWidgets - we needed this available for building observer
# but not needed at runtime
rm -rf ${INSTALL_DIR}/lib/erlang/lib/wx-*

# Set rpaths
ERTS_DIR=$(echo ${INSTALL_DIR}/lib/erlang/erts-*)
# On MacOS, set up the RPath for the crypto plugin to find our custom OpenSSL
if [ "${PLATFORM}" = "macosx" ]; then
    CRYPTO_DIR=$(echo ${INSTALL_DIR}/lib/erlang/lib/crypto-*)
    install_name_tool -add_rpath @loader_path/../../../../.. \
        ${CRYPTO_DIR}/priv/lib/crypto.so
    install_name_tool -add_rpath @loader_path/../../.. \
        ${ERTS_DIR}/bin/beam.smp
elif [ "${PLATFORM}" = "linux" ]; then
    patchelf --set-rpath '$ORIGIN/../../..' ${ERTS_DIR}/bin/beam.smp
fi

# For whatever reason, the special characters in this filename make
# Jenkins throw a fit (UI warnings about "There are resources Jenkins
# was not able to dispose automatically"), so let's just delete it.
rm -rf lib/ssh/test/ssh_sftp_SUITE_data/sftp_tar_test_data_*
