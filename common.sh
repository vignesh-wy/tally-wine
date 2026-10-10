# Shared settings for the Tally scripts. Sourced, not run.
HERE=${0:A:h}
# Folder that holds run-wine: a local build, or an unpacked wine-tally.tar.gz.
WINE_HOME=${WINE_HOME:-$HERE/dist/wine-tally}
export WINEPREFIX=${WINEPREFIX:-$HOME/.wine-tally}
TALLY_EXE='C:\Program Files\TallyPrime\tally.exe'
TALLY_FILE="$WINEPREFIX/drive_c/Program Files/TallyPrime/tally.exe"

if [[ ! -x $WINE_HOME/run-wine ]]; then
  echo "run-wine not found in $WINE_HOME. Build first (./build-wine.sh) or set WINE_HOME." >&2
  exit 1
fi
wine() { "$WINE_HOME/run-wine" "$@"; }
