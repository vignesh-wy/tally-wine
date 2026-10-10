#!/bin/zsh
# Show a Mac folder inside Tally as a drive letter.
# Usage: ./map-folder.sh <letter> <folder>     e.g. ./map-folder.sh t ~/TallyData
#        ./map-folder.sh                        list current drives
set -e
source ${0:A:h}/common.sh
D=$WINEPREFIX/dosdevices
[[ -d $D ]] || { echo "No prefix yet. Run ./install-tally.sh first." >&2; exit 1; }
if [[ $# -eq 0 ]]; then for l in $D/?:(N); do echo "${l:t} -> $(readlink $l)"; done; exit; fi
L=${1:l}; F=${2:A}
[[ $L == [d-y] ]] || { echo "Use a letter from d to y (c and z are taken)." >&2; exit 1; }
[[ -d $F ]] || { echo "Folder not found: $F" >&2; exit 1; }
[[ -e $D/$L: || -L $D/$L: ]] && { echo "Drive $L: is already used: $(readlink $D/$L:)" >&2; exit 1; }
ln -s $F $D/$L:
echo "$F is now ${L:u}:\\ in Tally. Restart Tally to see it."
