[简体中文](README.md) · [繁體中文](README.zh-TW.md) · **English** · [日本語](README.ja.md)

# Rebocap Wine compatibility patch

Makes the Windows ReboCap client recognize the RebornBodyCap USB receiver under Wine
(Bottles, plain Wine or another Wine front end): green status light, live tracker readings,
both firmware versions shown, no error pop-ups.

> Wine only. On real Windows the device enumerates natively and this patch is **not** needed.

> [!TIP]
> Rebocap now has an **official Linux version** that uses the receiver directly, with no Wine and no patch.
> In most cases use the official Linux version. This patch is for when you still want to run the Windows
> version in Wine. To play VRChat with full-body tracking through WiVRn (no SteamVR) on Linux, see
> [TW527E/rebocap-linux-wivrn-fbt](https://github.com/TW527E/rebocap-linux-wivrn-fbt).

This repository is a fork of [zhangxichang/rebocap-wine](https://github.com/zhangxichang/rebocap-wine).
It adds **SERIALCOMM registration** (see "How it works"). Without it, Rebocap keeps reporting `-3` in some
Wine setups even though the device enumerates.

## Files

```
setupapi.dll                  the only patch file used at run time (build output, see "Building from source")
rebocap-wine-install.sh       install script (run on the Linux side)
rebocap-wine-uninstall.sh     uninstall script
README.md                     this document
```

There is no prebuilt `setupapi.dll` yet. Build it first; it needs only Zig and takes a few seconds.

## Requirements

- Receiver: USB `248a:8002` (RebornBodyCap / RebornRX).
- The prefix has the `dosdevices/com34` template (Bottles' Wine template includes it; USB serial ports use COM33 and up).
- **Your Linux user can read and write the receiver's serial port** (`/dev/ttyACM*`, usually `root:uucp 0660`).
  Without access the patch works (no more `-3`) but the port fails to open and the log repeats
  `-2 IO连接错误` (I/O connection error). See "Serial port permissions".
- Bottles (Flatpak) needs device access (for example `flatpak override --user --device=all com.usebottles.bottles`),
  or Wine cannot see `/dev/ttyACM*`.
- The patch affects only the Wine prefix it is placed in.

## Serial port permissions (required)

After the app enumerates the device, it opens `/dev/ttyACM*` (through the `com34` mapping) as your Linux user.
Without permission the status light stays off and `rebocap.log` keeps repeating `-2 IO连接错误`.

Fix it one of two ways:

**Option A: add your user to the `uucp` group (standard; log in again afterwards)**

```bash
sudo usermod -aG uucp "$USER"   # usually the dialout group on Debian/Ubuntu
# takes effect after you log out and back in
```

**Option B: a udev rule (no new login needed)**

```bash
echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="248a", ATTRS{idProduct}=="8002", MODE="0666"' | \
  sudo tee /etc/udev/rules.d/99-rebocap.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
# replug the receiver once
```

Check (read and write access is enough, for example mode `0666`, or your user is in `uucp`):

```bash
ls -l /dev/ttyACM*
```

## Install

1. Build `setupapi.dll` (see "Building from source"). You get `zig-out/bin/setupapi.dll`.

2. Put `setupapi.dll` and the two scripts next to `rebocap.exe`, for example:

   ```
   <prefix>/drive_c/Program Files (x86)/Rebocap/
   ```

3. Make the scripts executable and run the installer:

   ```bash
   cd "<prefix>/drive_c/Program Files (x86)/Rebocap"
   chmod +x rebocap-wine-install.sh rebocap-wine-uninstall.sh
   ./rebocap-wine-install.sh
   ```

   The script finds the prefix and wine itself. If it cannot, pass them:
   `./rebocap-wine-install.sh --prefix <prefix> --wine <wine executable>`.

4. The installer does three things: locates and checks the environment, deletes `KnownDLLs\setupapi`,
   and sets `HKCU\Software\Wine\DllOverrides\setupapi = native,builtin`.

5. **When it takes effect (important)**: the Wine session must restart.

   - Close every program in the prefix and start again (recommended), or
   - run `WINEPREFIX="<prefix>" <wine dir>/wineserver -k` to end the session now
     (this force-closes every program in the bottle).

   Until the session restarts, running programs (and wineserver) keep the old settings.

## Daily use

Start `rebocap.exe` any way you like (Bottles shortcut, `bottles-cli run`, plain `wine`).
The installer is not involved in starting the app and does not tie you to a front end.

> [!WARNING]
> **Do not update tracker or receiver firmware under Wine.** A failure halfway through can leave the device unusable.
> Update firmware with the official Linux version or on Windows.

## Ports and USB replugging

- The patch makes sure the port name (`PortName`) exists in the real registry: the key is created the first
  time the device registry key is opened, with `COM34` as the default (idempotent; an existing value is kept).
- In the prefix, `COM34` maps to the real USB serial port (`dosdevices/com34`).
- **Replugging**: after the receiver is replugged, the kernel may renumber the serial node
  (ttyACM0, ACM1, …) and the `com34` link can point to nothing. Restarting the app does not fix that:

  - point `com34` at the current `ttyACM*` again (fix the `dosdevices/com34` symlink), then start the app;
  - more robust: point it at a stable path such as `/dev/serial/by-id/usb-JXQ_Ltd__Co_RebornBodyCap_RebornRX-if00`;
  - whether trackers are switched on does not affect "connected / green / firmware", only live readings.

## Acceptance checks

1. No `-3` at all in `rebocap.log`.
2. Green "connected" status, no pop-ups.
3. Live readings once the trackers are switched on.
4. The settings page shows the tracker and receiver firmware versions (for example `v_15 / v_7`).

## Troubleshooting

Log: `<Rebocap>/log/rebocap.log` (look for `-3` and `finish update device info`).

Check the registry (replace `<prefix>` and `<wine>`):

```bash
# should report that the setupapi value is not found
WINEPREFIX="<prefix>" "<wine>" reg query \
  "HKLM\System\CurrentControlSet\Control\Session Manager\KnownDLLs" /v setupapi

# should show native,builtin
WINEPREFIX="<prefix>" "<wine>" reg query \
  "HKCU\Software\Wine\DllOverrides" /v setupapi
```

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| No green light, `rebocap.log` fills with `-3` | DllOverrides not in effect | Check the registry; make sure the session restarted (close programs or `wineserver -k`) |
| Same | KnownDLLs entry not deleted | Run the installer again; the query must come back empty |
| Same, registry is correct | SERIALCOMM not registered (upstream patch) | Use a `setupapi.dll` built from this fork |
| Nothing changes at all | `setupapi.dll` is not next to `rebocap.exe` | Move it, rerun the installer, restart the session |
| Green but no readings | Trackers are off | Switch the trackers on (connection, light and firmware don't need them; readings do) |
| No green light, log repeats `-2 IO连接错误` | No serial port permission | See "Serial port permissions" |
| Not recognized after replugging | `com34` points to nothing | Point `com34` at the current `ttyACM*` / restart the prefix, then start the app |

Start with `WINEDEBUG=+debugstr` to see the patch's `[rebocap-wine] ...` debug output.

## Uninstall

```bash
./rebocap-wine-uninstall.sh
```

The script restores `KnownDLLs\setupapi = "setupapi.dll"`, deletes `DllOverrides\setupapi` and the
`REBORNRX` device key created at run time. Again, **the session must restart**.
To remove everything, also delete `setupapi.dll`, the two scripts and this README.

## How it works (short)

- **Enumeration layer (fake)**: the patch is a `setupapi.dll` of the same name, placed in the app folder so it
  loads before the system one. It implements 7 `SetupDi*` functions that return verified device data
  (Ports class GUID, instance ID `USB\VID_248A&PID_8002\REBORNRX`, device properties and so on).
  The other ~610 exports are link-time forwarders to the system DLL; the patch contains none of their code.
- **SERIALCOMM registration** (added in this fork): a separate thread in the app polls
  `HKLM\HARDWARE\DEVICEMAP\SERIALCOMM` and accepts only COM ports listed there. Ports mapped by hand in
  `dosdevices/comN` are not registered by Wine's mountmgr, so without this key the app reports `-3` even when
  SetupDi enumeration succeeds. The first time the Ports class is enumerated, the patch creates the key with
  `REG_OPTION_VOLATILE` and writes `\Device\USBSER000 = <PortName>` (it disappears when the session ends;
  `reg.exe` cannot create subkeys under a volatile key, so the patch has to write it).
- **Debugging**: every function the patch handles logs `[rebocap-wine] ...` through `OutputDebugStringA`;
  view it with `WINEDEBUG=+debugstr`.
- **Data layer (real)**: `SetupDiOpenDevRegKey` returns a **real** registry key, and the app reads `PortName`
  through the real `advapi32`. Once the port is open, data goes through Wine's real serial port.
- **Deployment**: one extra DLL and two registry settings (KnownDLLs / DllOverrides). No system files are
  modified and nothing is hooked; deleting the file and running the uninstaller reverts everything.

## Building from source

- Toolchain: Zig 0.16 (cross-compilation built in, no mingw needed)
- Build:

  ```bash
  zig build --release      # output: zig-out/bin/setupapi.dll
  ```

- The build runs `scripts/gen_def.zig`, which reads `system-setupapi.dll` in the repository root
  (Wine's builtin, a build input) and generates the export list of "7 implementations + 610 forwarders"
  for the linker.
- Layout:

  ```
  src/lib.zig           the 7 overriding functions (enumeration layer)
  src/constants.zig     verified values (GUID / device ID / property strings)
  src/util.zig          UTF-16, GUID, probe protocol helpers
  src/reg.zig           real registry key: create / self-heal PortName / read
  src/forward.zig       run-time forwarding helper (other arguments go to the system DLL)
  src/win32.zig         hand-written Win32 bindings (no cImport)
  scripts/gen_def.zig   export list generator (runs at build time)
  system-setupapi.dll   Wine builtin (build input, not the patch)
  ```

- The patch is `zig-out/bin/setupapi.dll`. **Do not copy the Wine builtin from the repository root into the
  bottle**: it is only a build input and contains none of the patch logic.
- When you switch Wine runners, replace `system-setupapi.dll` with the new runner's
  `lib/wine/x86_64-windows/setupapi.dll` and run `zig build --release` again.

## Related projects

| Project | Purpose |
| --- | --- |
| [TW527E/rebocap-linux-wivrn-fbt](https://github.com/TW527E/rebocap-linux-wivrn-fbt) | Complete guide and launcher for Linux + WiVRn + VRChat full-body tracking |
| [TW527E/rebocap-linux-compat](https://github.com/TW527E/rebocap-linux-compat) | `bridge.exe`: turns Rebocap's named pipe into TCP inside Wine |
| [TW527E/rebocap-wivrn-bridge](https://github.com/TW527E/rebocap-wivrn-bridge) | CLI that sends Rebocap's trackers into WiVRn through SolarXR |

## License note

`system-setupapi.dll` in the repository root comes from Wine (`lib/wine/x86_64-windows/setupapi.dll`) and is
licensed LGPL-2.1-or-later (https://wiki.winehq.org/Licensing).
