# TallyPrime on macOS with Wine

Build a Wine that runs TallyPrime on a Mac, then install and run Tally with it.
Why each build option is needed: see [LESSONS.md](LESSONS.md).

## Files

| File | Purpose |
|---|---|
| `build-wine.sh` | Clone public Wine, build it, package `dist/wine-tally.tar.gz`. |
| `.github/workflows/build-wine.yml` | Same build on GitHub. Manual trigger. |
| `install-tally.sh` | Create the Wine prefix and run the Tally installer. |
| `run-tally.sh` | Start Tally. |
| `map-folder.sh` | Show a Mac folder in Tally as a drive letter. |
| `stop-tally.sh` | Force stop Tally when it hangs. |
| `common.sh` | Shared settings for the Tally scripts. |

## Quick path with make

```sh
make deps                                  # build tools, once
make build                                 # build Wine (long)
make install SETUP=~/Downloads/tally_setup.exe
make run
make map LETTER=t FOLDER=~/TallyData
```

`make` alone lists all commands. The steps below show the same thing with the scripts.

## Step 1: get Wine

Pick one.

**Build on this Mac**

```sh
brew install bison mingw-w64
softwareupdate --install-rosetta --agree-to-license   # Apple Silicon only, once
./build-wine.sh
```

Wine lands in `dist/wine-tally/`. The Tally scripts find it there.

**Use the GitHub build**

1. GitHub → Actions → "Build Wine for Tally (macOS)" → Run workflow.
2. Download the artifact and unpack it:

```sh
mkdir -p dist && tar -xzf wine-tally.tar.gz -C dist
xattr -dr com.apple.quarantine dist/wine-tally
```

## Step 2: install Tally

Download `tally_setup.exe` from the Tally website, then:

```sh
./install-tally.sh ~/Downloads/tally_setup.exe
```

Finish the steps in the installer window. Keep the default install folder.

## Step 3: run Tally

```sh
./run-tally.sh
```

## Step 4: use Mac folders in Tally

Tally sees the whole Mac under `Z:`. A home folder is `Z:\Users\<name>\...`.

For a short path, map a drive letter:

```sh
./map-folder.sh t ~/TallyData     # ~/TallyData becomes T:\
./map-folder.sh                   # list drives
```

In Tally, set the company data path to `T:\data`.

## If something goes wrong

| Problem | Do this |
|---|---|
| Tally hangs or will not close | `./stop-tally.sh` |
| First start crashed and Tally will not start again | Delete `~/.wine-tally`, run `./install-tally.sh` again |
| "Wine cannot find the FreeType font library" | Start Wine only through `run-wine` or these scripts |
| "built without Vulkan support" | Ignore it |
| Licence activation or other online features fail | Expected. This build has no TLS (see LESSONS.md) |

## Settings

| Variable | Default | Meaning |
|---|---|---|
| `WINE_HOME` | `./dist/wine-tally` | Folder that holds `run-wine` |
| `WINEPREFIX` | `~/.wine-tally` | Where Windows files and Tally are installed |
| `WINE_REF` | `wine-11.19` | Wine tag or branch that `build-wine.sh` builds |
