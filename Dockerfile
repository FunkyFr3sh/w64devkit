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
    https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.xz \
    https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz \
    https://ftp.gnu.org/gnu/gdb/gdb-$GDB_VERSION.tar.xz \
    https://fossies.org/linux/www/expat-$EXPAT_VERSION.tar.xz \
    https://ftp.gnu.org/gnu/gmp/gmp-$GMP_VERSION.tar.xz \
    https://ftp.gnu.org/gnu/mpc/mpc-$MPC_VERSION.tar.gz \
    https://ftp.gnu.org/gnu/mpfr/mpfr-$MPFR_VERSION.tar.xz \
    https://ftp.gnu.org/gnu/make/make-$MAKE_VERSION.tar.gz \
    https://ftp.gnu.org/gnu/libiconv/libiconv-$LIBICONV_VERSION.tar.gz \
    https://frippery.org/files/busybox/busybox-w32-$BUSYBOX_VERSION.tgz \
    http://ftp.vim.org/pub/vim/unix/vim-$VIM_VERSION.tar.bz2 \
    https://www.nasm.us/pub/nasm/releasebuilds/$NASM_VERSION/nasm-$NASM_VERSION.tar.xz \
    https://github.com/universal-ctags/ctags/archive/refs/tags/v$CTAGS_VERSION.tar.gz \
    https://downloads.sourceforge.net/project/mingw-w64/mingw-w64/mingw-w64-release/mingw-w64-v$MINGW_VERSION.tar.bz2 \
    https://downloads.sourceforge.net/project/pdcurses/pdcurses/$PDCURSES_VERSION/PDCurses-$PDCURSES_VERSION.tar.gz \
    https://github.com/danmar/cppcheck/archive/$CPPCHECK_VERSION.tar.gz
COPY src/SHA256SUMS $PREFIX/src/
RUN sha256sum -c $PREFIX/src/SHA256SUMS \
 && tar xJf binutils-$BINUTILS_VERSION.tar.xz \
 && tar xzf busybox-w32-$BUSYBOX_VERSION.tgz \
 && tar xzf ctags-$CTAGS_VERSION.tar.gz \
 && tar xJf gcc-$GCC_VERSION.tar.xz \
 && tar xJf gdb-$GDB_VERSION.tar.xz \
 && tar xJf expat-$EXPAT_VERSION.tar.xz \
 && tar xzf libiconv-$LIBICONV_VERSION.tar.gz \
 && tar xJf gmp-$GMP_VERSION.tar.xz \
 && tar xzf mpc-$MPC_VERSION.tar.gz \
 && tar xJf mpfr-$MPFR_VERSION.tar.xz \
 && tar xzf make-$MAKE_VERSION.tar.gz \
 && tar xjf mingw-w64-v$MINGW_VERSION.tar.bz2 \
 && tar xzf PDCurses-$PDCURSES_VERSION.tar.gz \
 && tar xJf nasm-$NASM_VERSION.tar.xz \
 && tar xjf vim-$VIM_VERSION.tar.bz2 \
 && tar xzf cppcheck-$CPPCHECK_VERSION.tar.gz
COPY src/w64devkit.c src/w64devkit.ico \
     src/alias.c src/debugbreak.c src/pkg-config.c \
     $PREFIX/src/

ARG ARCH=x86_64-w64-mingw32

# Fixes i686 Windows XP regression
# https://sourceforge.net/p/mingw-w64/bugs/821/
RUN sed -i /OpenThreadToken/d /mingw-w64-v$MINGW_VERSION/mingw-w64-crt/lib32/kernel32.def

WORKDIR /x-mingw-headers
RUN /mingw-w64-v$MINGW_VERSION/mingw-w64-headers/configure \
        --prefix=/bootstrap/$ARCH \
        --host=$ARCH \
        --with-default-msvcrt=msvcrt-os \
 && make -j$(nproc) \
 && make install

WORKDIR /bootstrap
RUN ln -s $ARCH mingw

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
        CFLAGS="-Os" \
        LDFLAGS="-s" \
 && make -j$(nproc) \
 && make install

WORKDIR /x-winpthreads
RUN /mingw-w64-v$MINGW_VERSION/mingw-w64-libraries/winpthreads/configure \
        --prefix=/bootstrap/$ARCH \
        --with-sysroot=/bootstrap/$ARCH \
        --host=$ARCH \
        --enable-static \
        --disable-shared \
        CFLAGS="-Os" \
        LDFLAGS="-s" \
 && make -j$(nproc) \
 && make install

WORKDIR /x-gcc
RUN make -j$(nproc) \
 && make install

# Cross-compile GCC

WORKDIR /mingw-headers
RUN /mingw-w64-v$MINGW_VERSION/mingw-w64-headers/configure \
        --prefix=$PREFIX/$ARCH \
        --host=$ARCH \
        --with-default-msvcrt=msvcrt-os \
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
        CFLAGS="-Os" \
        LDFLAGS="-s" \
 && make -j$(nproc) \
 && make install

WORKDIR /winpthreads
RUN /mingw-w64-v$MINGW_VERSION/mingw-w64-libraries/winpthreads/configure \
        --prefix=$PREFIX/$ARCH \
        --with-sysroot=$PREFIX/$ARCH \
        --host=$ARCH \
        --enable-static \
        --disable-shared \
        CFLAGS="-Os" \
        LDFLAGS="-s" \
 && make -j$(nproc) \
 && make install

# Pack up a release

WORKDIR /
ENV PREFIX=${PREFIX}
CMD zip -q9Xr - $PREFIX
