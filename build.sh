#!/bin/sh
# Build GNU tar 1.34 natively on SCO OpenServer 5.0.7.
#
# Run this script ON the SCO machine, in a writable directory.
#
# Required:
#   GCC 3.4 or later (the SCO native 2.95.3 may also work; we tested with
#       3.4.6 from /asottile/prefix/bin). Set CC and put it on PATH, or
#       override via the GCC env var below.
#   /usr/gnu/bin/{gmake,gtar}, /usr/bin/patch, /bin/{sed,gunzip}
#   bash (SCO ships an older one — used as the configure shell)
#   wget or curl, OR drop tar-1.34.tar.gz next to this script
#
# Output: ./install/bin/tar — a single 460 KB stripped binary.
# Filters: -z (gzip) and -j (bzip2) — both via /bin/{gzip,bzip2}.

set -e

SCRIPT_DIR=`cd \`dirname "$0"\` && pwd`
VERSION=1.34
TARBALL=tar-${VERSION}.tar.gz
SRCDIR=tar-${VERSION}

if [ -n "$GCC" ]; then
    CC="$GCC"
fi
CC="${CC:-gcc}"
export CC

PATH=/usr/gnu/bin:/usr/ccs/bin:/usr/bin:/bin
export PATH

if [ ! -f "$TARBALL" ]; then
    echo "Fetching $TARBALL..."
    if which wget >/dev/null 2>&1; then
        wget --no-check-certificate "https://ftp.gnu.org/gnu/tar/${TARBALL}"
    elif which curl >/dev/null 2>&1; then
        curl -kLO "https://ftp.gnu.org/gnu/tar/${TARBALL}"
    else
        echo "ERROR: no wget or curl. Drop $TARBALL next to this script." >&2
        exit 1
    fi
fi

if [ ! -d "$SRCDIR" ]; then
    echo "Unpacking $TARBALL..."
    /usr/bin/gunzip -c "$TARBALL" | /usr/bin/tar xf -
fi

echo "Applying SCO compatibility patches..."
cd "$SRCDIR"
if [ -f .sco_patched ]; then
    echo "  (already applied — skipping)"
else
    patch -p1 < "$SCRIPT_DIR/patches/tar-${VERSION}-sco.patch"
    touch .sco_patched
fi

# Need bash for the configure script — SCO's /bin/sh chokes on bashisms.
SHELL_BIN=`which bash 2>/dev/null`
if [ -z "$SHELL_BIN" ]; then
    echo "ERROR: bash required (SCO /bin/sh chokes on configure bashisms)." >&2
    exit 1
fi

echo "Configuring..."
# FORCE_UNSAFE_CONFIGURE=1 — refuses-as-root check; fine for SCO sysadmins.
# --without-{lzma,zstd} — those libs aren't on SCO; gzip/bzip2 cover us.
# --with-{gzip,bzip2}= — point at SCO's stock binaries.
FORCE_UNSAFE_CONFIGURE=1 CONFIG_SHELL=$SHELL_BIN $SHELL_BIN configure \
    --prefix="$SCRIPT_DIR/install" \
    --disable-nls \
    --without-lzma \
    --without-zstd \
    --with-gzip=/bin/gzip \
    --with-bzip2=/bin/bzip2 \
    CC="$CC" \
    CFLAGS="-O2 -std=gnu99"

echo "Compiling..."
gmake LIBS="-lsocket -lnsl"

echo "Installing to $SCRIPT_DIR/install/..."
gmake install

echo "Stripping..."
strip "$SCRIPT_DIR/install/bin/tar" 2>/dev/null || true

ls -l "$SCRIPT_DIR/install/bin/tar"
echo
echo "Test it:"
echo "  $SCRIPT_DIR/install/bin/tar --version"
echo "  $SCRIPT_DIR/install/bin/tar tzf some-archive.tar.gz"
echo
echo "To package: gtar czf tar-${VERSION}-sco.tar.gz install"
