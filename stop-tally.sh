#!/bin/zsh
# Force stop Tally and everything else in the Wine prefix. Use when it hangs.
source ${0:A:h}/common.sh
if [[ $(uname -m) == arm64 ]]; then arch -x86_64 $WINE_HOME/bin/wineserver -k; else $WINE_HOME/bin/wineserver -k; fi
echo "Stopped."
