#!/bin/zsh
# Install TallyPrime into the Wine prefix.
# Usage: ./install-tally.sh [path/to/tally_setup.exe]
set -e
source ${0:A:h}/common.sh
SETUP=${1:-$HOME/Downloads/tally_setup.exe}
[[ -f $SETUP ]] || { echo "Installer not found: $SETUP" >&2; exit 1; }

if [[ ! -d $WINEPREFIX/drive_c ]]; then
  echo "Creating prefix $WINEPREFIX"
  wine wineboot -i
  # Turn off the crash debugger. A crash can otherwise start a chain of winedbg windows.
  for view in /reg:64 /reg:32; do
    wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\AeDebug' /v Auto /d 0 /f $view >/dev/null
    wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\AeDebug' /v Debugger /d '' /f $view >/dev/null
  done
fi

echo "Starting the installer. Finish the steps in its window."
wine "$SETUP"
[[ -f $TALLY_FILE ]] && echo "Installed. Start it with ./run-tally.sh" || echo "tally.exe not found yet. Was the install finished?"
