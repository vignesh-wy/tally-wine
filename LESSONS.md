# Wine for TallyPrime on macOS: lessons

What we learnt getting TallyPrime 7.1 to install and run on an Apple Silicon Mac
with Wine 11.19 built from source. `build-wine.sh` applies all of these.

Usage steps are in [README.md](README.md).

## Build lessons

1. **Build x86_64, not arm64.** Tally is an x86 Windows program. On Apple Silicon,
   run configure and make under `arch -x86_64` with `CC="clang -arch x86_64"`. Rosetta must be installed.

2. **Use the new WoW64 mode.** `--enable-archs=i386,x86_64` gives one build that
   runs both 32-bit and 64-bit programs. It needs mingw-w64 (both `i686` and `x86_64` compilers).

3. **Turn off `pipe2`.** Configure finds `pipe2` in the SDK, but it is weak-linked
   and NULL at run time. Wine then segfaults at start (exit 139, in `server_pipe`).
   Fix: pass `ac_cv_func_pipe2=no` to configure.

4. **FreeType is required.** Without it Wine still builds and runs, but dialogs
   have zero size, so the installer window is invisible. Homebrew's FreeType is
   arm64, so the script builds an x86_64 copy from source and points configure at it
   with `FREETYPE_CFLAGS` and `FREETYPE_LIBS`.

5. **Use Homebrew bison.** The bison shipped with macOS is too old for Wine.

6. **gnutls is left out.** `--without-gnutls` means no TLS inside Wine.
   Tally works offline. Licence activation and other online features will likely fail.

7. **Vulkan is left out.** The "built without Vulkan support" message is harmless.

## Run lessons

1. **Library path must go through `arch -e`.** Wine loads FreeType by name, so it
   needs `DYLD_FALLBACK_LIBRARY_PATH`. macOS strips `DYLD_*` variables when a command
   goes through `/usr/bin/arch`. Passing it as `arch -x86_64 -e DYLD_FALLBACK_LIBRARY_PATH=...` works.
   Symptom if missed: "Wine cannot find the FreeType font library".

2. **Skip the Mono/Gecko dialog.** On first start Wine asks to install Mono. That
   dialog can hang prefix creation, which leaves `syswow64` empty. 32-bit programs then
   fail with "could not load kernel32.dll, status c0000135".
   Fix: set `WINEDLLOVERRIDES="mscoree,mshtml="`. `run-wine` does this.

3. **Start with a fresh prefix if a start crashed.** A half-made prefix stays broken. Delete it and let Wine make a new one.

4. **Do not attach a debugger to the Tally installer.** It is packed with VMProtect
   and exits when a debugger attaches. Use `WINEDEBUG=+loaddll,+module` style traces instead.

5. **Stop runaway processes with `wineserver -k`.** A crash can start a chain of
   `winedbg` windows. To prevent it, disable the crash debugger in the prefix:

   ```sh
   run-wine reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\AeDebug' /v Auto /d 0 /f
   ```

6. **The Wine install can be moved.** Wine finds its files relative to `bin/wine`,
   so the packaged folder works from any location.

## Host folders in Tally

- `Z:` is the Mac root. A home folder is `Z:\Users\<name>\...`.
- For a short path, add a drive letter:
  `ln -s ~/TallyData ~/.wine-tally/dosdevices/t:` then use `T:\` in Tally.

## Checks the script makes

- `config.h` has FreeType on and `pipe2` off, before the long build starts.
- Smoke test: a fresh prefix runs `cmd /c ver`, no FreeType error, `syswow64` is filled.
