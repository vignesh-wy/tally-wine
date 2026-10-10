#!/bin/bash
# Build an x86_64 Wine for macOS that can run TallyPrime.
# Works on Apple Silicon (through Rosetta) and on Intel Macs.
# See LESSONS.md for why each option is here.
#
# Usage: ./build-wine.sh            build + package + smoke test
#        SKIP_SMOKE=1 ./build-wine.sh
#
# Needs: Xcode command line tools, Homebrew bison and mingw-w64,
#        Rosetta 2 on Apple Silicon.
set -euo pipefail

WINE_REPO=${WINE_REPO:-https://gitlab.winehq.org/wine/wine.git}
WINE_REF=${WINE_REF:-wine-11.19}          # tag or branch
WORK=${WORK:-$PWD/work}                   # sources and build output
DIST=${DIST:-$PWD/dist/wine-tally}        # final package folder
JOBS=${JOBS:-$(sysctl -n hw.ncpu)}

FT_VER=2.14.3
FT_SHA=36bc4f1cc413335368ee656c42afca65c5a3987e8768cc28cf11ba775e785a5f
FT_URLS="https://downloads.sourceforge.net/project/freetype/freetype2/$FT_VER/freetype-$FT_VER.tar.xz
https://download.savannah.gnu.org/releases/freetype/freetype-$FT_VER.tar.xz"

SRC=$WORK/wine
BUILD=$WORK/build
DEPS=$WORK/deps

# On Apple Silicon everything must run as x86_64.
if [ "$(uname -m)" = arm64 ]; then X86="arch -x86_64"; else X86=""; fi
CC_X86="clang -arch x86_64"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

check_tools() {
  log "Checking tools"
  command -v brew >/dev/null || die "Homebrew is missing"
  export PATH="$(brew --prefix bison)/bin:$PATH"   # system bison is too old
  bison --version | head -1
  for t in clang i686-w64-mingw32-gcc x86_64-w64-mingw32-gcc; do
    command -v $t >/dev/null || die "$t is missing (brew install bison mingw-w64)"
  done
  if [ -n "$X86" ]; then
    $X86 /usr/bin/true 2>/dev/null || die "Rosetta is missing (softwareupdate --install-rosetta --agree-to-license)"
  fi
}

build_freetype() {
  if [ -f "$DEPS/lib/libfreetype.6.dylib" ]; then log "FreeType already built"; return; fi
  log "Building FreeType $FT_VER for x86_64"
  mkdir -p "$DEPS/src"
  local tar=$DEPS/src/freetype-$FT_VER.tar.xz url
  if [ ! -f "$tar" ]; then
    for url in $FT_URLS; do curl -fL --retry 3 -o "$tar" "$url" && break; done
  fi
  echo "$FT_SHA  $tar" | shasum -a 256 -c -
  rm -rf "$DEPS/src/freetype-$FT_VER"
  tar -xf "$tar" -C "$DEPS/src"
  ( cd "$DEPS/src/freetype-$FT_VER"
    $X86 ./configure --prefix="$DEPS" CC="$CC_X86" \
      --without-png --without-brotli --without-harfbuzz --without-bzip2
    $X86 make -j"$JOBS"
    $X86 make install )
}

fetch_wine() {
  if [ -d "$SRC/.git" ]; then log "Wine source already present"; return; fi
  log "Cloning Wine $WINE_REF"
  git clone --depth 1 --branch "$WINE_REF" "$WINE_REPO" "$SRC"
}

build_wine() {
  log "Configuring Wine"
  mkdir -p "$BUILD"
  cd "$BUILD"
  # --enable-archs      : new WoW64, one build runs 32-bit and 64-bit apps
  # ac_cv_func_pipe2=no : pipe2 is weak-linked and NULL at run time -> segfault
  # FREETYPE_*          : without FreeType, dialogs are invisible
  # --without-gnutls    : no x86_64 gnutls here (no TLS inside Wine)
  # -O2 without -g      : keeps the package small
  $X86 "$SRC/configure" \
    --prefix="$DIST" \
    --enable-archs=i386,x86_64 \
    CC="$CC_X86" \
    CFLAGS="-O2" CROSSCFLAGS="-O2" \
    --without-gnutls \
    ac_cv_func_pipe2=no \
    FREETYPE_CFLAGS="-I$DEPS/include/freetype2" \
    FREETYPE_LIBS="-L$DEPS/lib -lfreetype"

  grep -q '^#define SONAME_LIBFREETYPE' include/config.h || die "FreeType was not picked up by configure"
  grep -q '^#define HAVE_PIPE2' include/config.h && die "pipe2 is still enabled"

  log "Building Wine with $JOBS jobs"
  $X86 make -j"$JOBS"
}

package() {
  log "Installing into $DIST"
  rm -rf "$DIST"
  cd "$BUILD"
  $X86 make install-lib -j"$JOBS"
  cp "$DEPS/lib/libfreetype.6.dylib" "$DIST/lib/"

  # Launcher. macOS strips DYLD_* vars passed through /usr/bin/arch,
  # so the library path is given with "arch -e".
  cat > "$DIST/run-wine" <<'EOF'
#!/bin/zsh
# Usage: run-wine <program.exe> [args]     e.g. run-wine tally_setup.exe
H=${0:A:h}
export WINEPREFIX=${WINEPREFIX:-$HOME/.wine-tally}
# Skip the Mono/Gecko install dialog. It hangs the first start.
export WINEDLLOVERRIDES=${WINEDLLOVERRIDES:-"mscoree,mshtml="}
L=$H/lib:/usr/lib
if [[ $(uname -m) == arm64 ]]; then
  exec arch -x86_64 -e DYLD_FALLBACK_LIBRARY_PATH=$L $H/bin/wine "$@"
else
  DYLD_FALLBACK_LIBRARY_PATH=$L exec $H/bin/wine "$@"
fi
EOF
  chmod +x "$DIST/run-wine"
  echo "$WINE_REF" > "$DIST/WINE_VERSION"

  log "Creating archive"
  tar -czf "$DIST.tar.gz" -C "$(dirname "$DIST")" "$(basename "$DIST")"
  ls -lh "$DIST.tar.gz"
}

smoke_test() {
  log "Smoke test: fresh prefix, run cmd /c ver"
  local pfx=$WORK/smoke-prefix out=$WORK/smoke.log pid n=0
  rm -rf "$pfx"
  WINEPREFIX=$pfx "$DIST/run-wine" cmd /c ver >"$out" 2>&1 &
  pid=$!
  while kill -0 $pid 2>/dev/null; do
    sleep 5; n=$((n+5))
    if [ $n -ge 900 ]; then kill $pid; cat "$out"; die "smoke test hung"; fi
  done
  wait $pid || { cat "$out"; die "wine exited with an error"; }
  WINEPREFIX=$pfx $X86 "$DIST/bin/wineserver" -k 2>/dev/null || true
  cat "$out"
  grep -q "Microsoft Windows" "$out" || die "wine did not run cmd"
  grep -qi "freetype" "$out" && die "FreeType did not load"
  [ -n "$(ls "$pfx/drive_c/windows/syswow64" 2>/dev/null)" ] || die "syswow64 is empty, 32-bit apps will not start"
  rm -rf "$pfx"
  log "Smoke test passed"
}

check_tools
build_freetype
fetch_wine
build_wine
package
[ -n "${SKIP_SMOKE:-}" ] || smoke_test
log "Done: $DIST.tar.gz"
