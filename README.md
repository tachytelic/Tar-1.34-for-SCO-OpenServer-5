# GNU tar 1.34 for SCO OpenServer 5

A working build of [GNU tar 1.34](https://www.gnu.org/software/tar/) for
**SCO OpenServer 5.0.7**. Single ~460 KB statically-linkable binary —
`-z` (gzip) and `-j` (bzip2) work through SCO's stock `/bin/gzip` and
`/bin/bzip2`. Drop-in replacement for `tar` when you want one-line
extraction of `.tar.gz` and `.tar.bz2` archives instead of piping
`gunzip|tar`.

```
$ tar --version
tar (GNU tar) 1.34

$ tar xzf python-3.6.15-sco.tar.gz   # one-step extract — works
$ tar tjf bundle.tar.bz2             # also works
```

## Why ship this?

SCO 5.0.7's stock `/usr/bin/tar` is solid but predates the convention of
`-z` and `-j` filters. Untarring `.tar.gz` releases on a fresh SCO box
needs the universal `gunzip -c x.tar.gz | tar xf -` pipe. That's fine
once you know it, but a single-binary GNU tar is friendlier — particularly
when you're walking someone through a fresh-install bootstrap.

## Install

> **Fresh SCO box?** Install [curl with TLS](https://github.com/tachytelic/curl-7.88.1-for-SCO-OpenServer-5)
> first. That's the only file that needs to be transferred to the box via
> `scp`; after that, every release on tachytelic/* (including this
> one) fetches over HTTPS from GitHub. See its README for the full
> bootstrap chain.

The release tarball is **~420 KB**. Fetch it directly on the SCO box and
extract with the stock tooling — this one is a chicken-and-egg case
(you don't have `gtar` yet), so we use `gunzip | /usr/bin/tar`:

```sh
# On the SCO box:
curl -LO https://github.com/tachytelic/Tar-1.34-for-SCO-OpenServer-5/releases/download/v1.0.0/tar-1.34-sco.tar.gz
gunzip -c tar-1.34-sco.tar.gz | /usr/bin/tar xf -
mv install /usr/local/tar-1.34
ln -s /usr/local/tar-1.34/bin/tar /usr/local/bin/gtar
gtar --version       # → tar (GNU tar) 1.34
```

Use it as `gtar` if you want to keep SCO's stock `/usr/bin/tar` for the
boot scripts and SCO `custom`-format expectations. Or symlink it as
`/usr/local/bin/tar` and put `/usr/local/bin` ahead of `/usr/bin` on
your `PATH` if you want it to be the default.

## What works

| Feature | Status |
|---|---|
| `-x`, `-c`, `-t`, `-r`, `-u` (extract / create / list / append / update) | ✅ |
| `-z` (gzip via `/bin/gzip`) | ✅ |
| `-j` (bzip2 via `/bin/bzip2`) | ✅ |
| `-Z` (compress via `/usr/bin/compress`) | ✅ |
| GNU long options (`--exclude`, `--strip-components`, `--keep-old-files`, …) | ✅ |
| Long file names (POSIX 1003.1-2001) | ✅ |
| Symlinks, hard links, sparse files | ✅ |
| Remote tape (`-f host:archive`) | builds, untested |

## What doesn't

| | |
|---|---|
| `--xattrs` / extended attributes | irrelevant on SCO |
| ACLs | irrelevant on SCO |
| `-J` / `--xz` | disabled — `liblzma` not on SCO |
| `--zstd` | disabled — `libzstd` not on SCO |
| `--checkpoint=N --checkpoint-action=wait=SIGNAL` | partly — SCO has no `sigwait()`, so we stub `cop_wait` to `pause()`. Still wakes on the signal, just less precise about *which* signal it caught. |

## Building from source

This is a **native build** on SCO, the same pattern as the python/curl/lua
builds in this repo's siblings.

### Requirements

- **GCC 3.4 or later** somewhere on the SCO box, with C99 support. The
  SCO-shipped GCC 2.95.3 may also work (no C99-specific features are
  used by tar 1.34), but we tested with 3.4.6.
- `/usr/gnu/bin/{gmake,gtar}`, `/usr/bin/patch`
- **bash** — SCO's stock `/bin/sh` is strict Bourne and chokes on
  configure bashisms. Stock SCO ships bash 3.1.x at `/usr/bin/bash`,
  which is fine.

### Build

```sh
cd tar-sco
./build.sh
```

Or with a non-default GCC:

```sh
GCC=/path/to/gcc-3.4 ./build.sh
```

Downloads `tar-1.34.tar.gz` from gnu.org, applies
`patches/tar-1.34-sco.patch`, configures with `--without-lzma --without-zstd
--with-gzip=/bin/gzip --with-bzip2=/bin/bzip2`, builds, installs to
`./install/`, strips. ~3 minutes on the typical SCO hardware these run on.

### What the patches do

`patches/tar-1.34-sco.patch` is a 2-hunk, ~20-line unified diff:

1. **`gnu/getprogname.c`** — gnulib's `getprogname` shim has no SCO 5
   branch (the existing `__SCO_VERSION__` branch is for OpenServer 6 /
   UnixWare and uses `/proc/<pid>/cmdline` which SCO 5 doesn't expose).
   Replace the unconditional `#error` for unrecognised OSes with a
   `return "?";` fallback. Affects only the prefix on tar's own error
   messages.
2. **`src/checkpoint.c`** — `sigwait()` isn't in SCO's libc (no POSIX
   threading). The only call site is the `cop_wait` checkpoint action,
   which we replace with `pause()`. Wakes on any signal rather than a
   specific one — fine for the "sleep until poked" semantic this code
   actually wants.

The build also passes `LIBS="-lsocket -lnsl"` for `gethostbyname`
(used by `librtape` for `tar -f host:path` remote-tape support — the
stock SCO link doesn't pull these libs in by default).

## Repository layout

```
patches/
  tar-1.34-sco.patch        2 patches, ~20 lines

build.sh                    Native-build script (run on SCO)
LICENSE                     MIT (covers patches + build script only)
README.md                   This file
```

The prebuilt 420 KB tarball ships via the **[Releases](../../releases)**
page, not via clone bloat.

## License

GNU tar is © Free Software Foundation, distributed under [GPLv3+](https://www.gnu.org/licenses/gpl-3.0.html).
The prebuilt binary is unmodified upstream tar 1.34 with the patches in
this repo applied.

The patches and build script in this repo are released under the MIT
license — see [LICENSE](LICENSE).

## See also

- [curl-7.88.1 for SCO](https://github.com/tachytelic/curl-7.88.1-for-SCO-OpenServer-5)
  — the natural first-install on a fresh SCO box; brings HTTPS + the CA
  bundle.
- [Python 3.6.15 for SCO](https://github.com/tachytelic/Python-3.6.15-for-SCO-OpenServer-5),
  [Lua 5.4.7 for SCO](https://github.com/tachytelic/Lua-5.4.7-for-SCO-OpenServer-5),
  [rsync 3.2.7 for SCO](https://github.com/tachytelic/rsync-3.2.7-for-SCO-OpenServer-5)
  — sibling builds.
- [More SCO OpenServer 5 binaries](https://tachytelic.net/2017/07/sco-openserver-5-binaries/)
  — bash, lzop, wget, … plus notes on running these systems day to day.
