FROM debian:bookworm-slim

ARG VERSION=1.20.0
ARG PREFIX=/w64devkit
ARG BINUTILS_VERSION=2.40
ARG BUSYBOX_VERSION=FRP-5181-g5c1a3b00e
ARG CTAGS_VERSION=6.0.0
ARG EXPAT_VERSION=2.5.0
ARG GCC_VERSION=13.2.0
ARG GDB_VERSION=13.1
ARG GMP_VERSION=6.2.1
ARG LIBICONV_VERSION=1.17
ARG MAKE_VERSION=4.4
ARG MINGW_VERSION=11.0.1
ARG MPC_VERSION=1.2.1
ARG MPFR_VERSION=4.1.0
ARG NASM_VERSION=2.15.05
ARG PDCURSES_VERSION=3.9
ARG CPPCHECK_VERSION=2.10
ARG VIM_VERSION=9.0

RUN apt-get update && apt-get install --yes --no-install-recommends \
  build-essential curl libgmp-dev libmpc-dev libmpfr-dev m4 zip

# Download, verify, and unpack

RUN curl --insecure --location --remote-name-all --remote-header-name \
    https://downloads.sourceforge.net/project/mingw-w64/mingw-w64/mingw-w64-release/mingw-w64-v$MINGW_VERSION.tar.bz2
COPY src/SHA256SUMS $PREFIX/src/
RUN tar xjf mingw-w64-v$MINGW_VERSION.tar.bz2

ARG ARCH=x86_64-w64-mingw32

ENV PATH="/bootstrap/bin:${PATH}"

WORKDIR /x-mingw-crt
RUN /mingw-w64-v$MINGW_VERSION/mingw-w64-crt/configure \
        --prefix=/bootstrap/$ARCH \
        --with-sysroot=/bootstrap/$ARCH \
        --host=$ARCH \
        --with-default-msvcrt=msvcrt-os \
        --disable-dependency-tracking \
        --disable-lib32 \
        --enable-lib64 \
        CFLAGS="-O2" \
        LDFLAGS="-s" \
 && make -j$(nproc) \
 && make install

WORKDIR /mingw-crt
RUN /mingw-w64-v$MINGW_VERSION/mingw-w64-crt/configure \
        --prefix=$PREFIX/$ARCH \
        --with-sysroot=$PREFIX/$ARCH \
        --host=$ARCH \
        --with-default-msvcrt=msvcrt-os \
        --disable-dependency-tracking \
        --disable-lib32 \
        --enable-lib64 \
        CFLAGS="-O2" \
        LDFLAGS="-s" \
 && make -j$(nproc) \
 && make install

# Pack up a release

WORKDIR /
ENV PREFIX=${PREFIX}
CMD zip -q9Xr - $PREFIX
