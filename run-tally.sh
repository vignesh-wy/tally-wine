#!/bin/zsh
# Start TallyPrime.
set -e
source ${0:A:h}/common.sh
[[ -f $TALLY_FILE ]] || { echo "Tally is not installed. Run ./install-tally.sh first." >&2; exit 1; }
wine "$TALLY_EXE" "$@"
