[简体中文](README.md) · **繁體中文** · [English](README.en.md) · [日本語](README.ja.md)

# Rebocap Wine 相容補丁

讓 Windows 版 ReboCap 用戶端在 Wine（Bottles／原生 Wine／其他 Wine 前端）下認得
RebornBodyCap USB 接收器：介面亮綠燈、追蹤器有即時讀數、顯示兩個韌體版本、不跳任何彈窗。

> 只適用於 Wine。在真正的 Windows 上，裝置本來就能列舉出來，**不需要**這個補丁。

> [!TIP]
> Rebocap 已經推出**官方 Linux 版**，可以直接使用接收器，不需要 Wine，也不需要這個補丁。
> 大部分情況建議直接用官方 Linux 版；這個補丁適合還想在 Wine 裡跑 Windows 版的情況。
> 想在 Linux 上用 WiVRn（不用 SteamVR）玩 VRChat 全身追蹤，請看
> [TW527E/rebocap-linux-wivrn-fbt](https://github.com/TW527E/rebocap-linux-wivrn-fbt)。

本 repo fork 自 [zhangxichang/rebocap-wine](https://github.com/zhangxichang/rebocap-wine)，
在原版之外加上 **SERIALCOMM 登記**（見「原理」一節）。少了它，Rebocap 在部分 Wine 環境裡即使列舉到裝置，也會一直報 `-3`。

## 交付檔案

```
setupapi.dll                  執行時唯一的補丁檔（建置產物，見「從原始碼建置」）
rebocap-wine-install.sh       安裝腳本（在 Linux 這邊執行）
rebocap-wine-uninstall.sh     解除安裝腳本
README.md                     本說明
```

本 repo 目前沒有提供編譯好的 `setupapi.dll`，需要先自行建置（只需要 Zig，幾秒鐘就好）。

## 前置條件

- 接收器：USB `248a:8002`（RebornBodyCap／RebornRX）；
- prefix 裡有 `dosdevices/com34` 範本（Bottles 的 Wine 範本內建；USB 序列埠固定用 COM33 以後的編號）；
- **Linux 使用者對接收器的序列埠有讀寫權限**（`/dev/ttyACM*`，權限通常是 `root:uucp 0660`）。
  沒有權限時：補丁已經生效（不再報 `-3`），但打不開序列埠，log 會一直重複 `-2 IO连接错误`；
  修正方式見「序列埠權限」一節。
- Bottles（Flatpak）要給它裝置存取權限（例如 `flatpak override --user --device=all com.usebottles.bottles`），不然 Wine 看不到 `/dev/ttyACM*`。
- 補丁只影響放置它的那個 wine prefix，不影響其他程式。

## 序列埠權限（必要）

程式列舉到裝置之後，要用目前的 Linux 使用者開啟 `/dev/ttyACM*`（透過 `com34` 對應）。
權限不夠時的症狀：介面不亮綠燈、`rebocap.log` 一直重複出現 `-2 IO连接错误`。

兩種修正方式（擇一）：

**方式 A：把使用者加進 `uucp` 群組（標準做法，需要重新登入）**

```bash
sudo usermod -aG uucp "$USER"   # Debian/Ubuntu 系通常是 dialout 群組
# 登出再重新登入桌面工作階段後生效
```

**方式 B：udev 規則（不用重新登入）**

```bash
echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="248a", ATTRS{idProduct}=="8002", MODE="0666"' | \
  sudo tee /etc/udev/rules.d/99-rebocap.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
# 拔插一次接收器後生效
```

自我檢查（能讀寫就好，例如權限是 `0666`，或你的使用者已經在 `uucp` 群組）：

```bash
ls -l /dev/ttyACM*
```

## 安裝

1. 建置 `setupapi.dll`（見「從原始碼建置」），會得到 `zig-out/bin/setupapi.dll`。

2. 把 `setupapi.dll` 和兩個腳本放到 `rebocap.exe` 所在的資料夾，例如：

   ```
   <prefix>/drive_c/Program Files (x86)/Rebocap/
   ```

3. 加上執行權限並執行安裝腳本：

   ```bash
   cd "<prefix>/drive_c/Program Files (x86)/Rebocap"
   chmod +x rebocap-wine-install.sh rebocap-wine-uninstall.sh
   ./rebocap-wine-install.sh
   ```

   腳本會自動找出 prefix 和 wine；找不到時可以手動指定：
   `./rebocap-wine-install.sh --prefix <prefix> --wine <wine 執行檔>`。

4. 安裝腳本只做三件事：找出並檢查環境、刪除 `KnownDLLs\setupapi`、
   設定 `HKCU\Software\Wine\DllOverrides\setupapi = native,builtin`。

5. **什麼時候生效（重要）**：要重啟 wine 工作階段——

   - 關掉這個 prefix 裡所有程式後重新啟動（建議）；
   - 或執行 `WINEPREFIX="<prefix>" <wine 資料夾>/wineserver -k` 立刻結束工作階段
     （注意：會強制關掉 bottle 裡所有程式）。

   只寫入登錄檔、沒有重啟工作階段的話，正在執行的程式（和 wineserver）還是用舊設定。

## 日常使用

用你習慣的方式啟動 `rebocap.exe` 就好（Bottles 捷徑、`bottles-cli run`、原生 `wine` 都可以）。
安裝腳本跟啟動無關，也不限制你用哪個前端。

> [!WARNING]
> **不要在 Wine 裡更新追蹤器或接收器的韌體。** 更新到一半出錯可能讓裝置無法使用。
> 需要更新韌體時，請用官方 Linux 版或 Windows 版。

## 序列埠與 USB 插拔

- 連接埠名稱（`PortName`）由補丁確保存在真實的登錄檔裡：第一次開啟裝置登錄機碼時自動建立；
  預設寫入 `COM34`（冪等：已經有值就不覆寫）。
- `COM34` 在這個 prefix 裡對應到真實的 USB 序列埠（`dosdevices/com34`）。
- **重新插拔要注意**：接收器重新插拔後，核心的序列埠節點會重新編號（ttyACM0／ACM1…），
  `com34` 的對應可能失效；這時光重開程式沒用，需要：

  - 把 `com34` 重新指到目前的 `ttyACM*`（也就是修正 `dosdevices/com34` 的符號連結），再啟動程式；
  - 更穩的做法是指到不會變的路徑，例如 `/dev/serial/by-id/usb-JXQ_Ltd__Co_RebornBodyCap_RebornRX-if00`；
  - 追蹤器開不開機不影響「已連線／綠燈／韌體」，只影響有沒有即時讀數。

## 驗收標準

1. `rebocap.log` 裡完全沒有 `-3`；
2. 介面亮綠燈顯示「已連線」，沒有彈窗；
3. 追蹤器開機後有即時讀數；
4. 設定頁顯示追蹤器與接收器的韌體版本（例如 `v_15 / v_7`）。

## 疑難排解

log 位置：`<Rebocap>/log/rebocap.log`（注意 `-3` 和 `finish update device info`）。

自我檢查登錄檔（`<prefix>` 和 `<wine>` 換成實際的值）：

```bash
# 應該顯示找不到 setupapi 值
WINEPREFIX="<prefix>" "<wine>" reg query \
  "HKLM\System\CurrentControlSet\Control\Session Manager\KnownDLLs" /v setupapi

# 應該顯示 native,builtin
WINEPREFIX="<prefix>" "<wine>" reg query \
  "HKCU\Software\Wine\DllOverrides" /v setupapi
```

| 症狀 | 可能原因 | 處理方式 |
| --- | --- | --- |
| 介面不亮綠燈、`rebocap.log` 一直出現 `-3` | DllOverrides 沒生效 | 檢查登錄檔；確認已經重啟工作階段（關掉程式或 `wineserver -k`） |
| 同上 | KnownDLLs 沒刪掉 | 重跑安裝腳本；確認查詢結果是空的 |
| 同上，登錄檔都正確 | 沒有登記 SERIALCOMM（用的是原版補丁） | 改用本 fork 建置的 `setupapi.dll` |
| 完全沒變化 | `setupapi.dll` 不在 `rebocap.exe` 同一個資料夾 | 放對位置後重跑安裝腳本並重啟工作階段 |
| 有綠燈但沒有讀數 | 追蹤器沒開機 | 打開追蹤器（連線／綠燈／韌體不需要它，讀數需要） |
| 介面不亮綠燈、log 一直重複 `-2 IO连接错误` | 序列埠權限不足 | 見「序列埠權限」一節 |
| 重新插拔後認不到 | `com34` 對應失效 | 把 `com34` 指到目前的 `ttyACM*`／重啟 prefix 後再啟動程式 |

用 `WINEDEBUG=+debugstr` 啟動，可以看到補丁輸出的 `[rebocap-wine] ...` 除錯訊息。

## 解除安裝

```bash
./rebocap-wine-uninstall.sh
```

腳本會還原 `KnownDLLs\setupapi = "setupapi.dll"`、刪除 `DllOverrides\setupapi`，
並刪除執行時建立的裝置機碼 `REBORNRX`；一樣**要重啟工作階段**才會生效。
要完全移除的話，再手動刪掉 `setupapi.dll`、兩個腳本和這份 README 就好。

## 原理（簡要）

- **列舉層（假的）**：補丁提供一個同名的 `setupapi.dll`（放在程式資料夾，會比系統版本優先載入）。
  其中 7 個 `SetupDi*` 函式由補丁實作，回傳已驗證過的裝置參數（Ports 類別 GUID、
  實例 ID `USB\VID_248A&PID_8002\REBORNRX`、裝置屬性等）；
  其餘約 610 個匯出函式透過連結時的「轉送項目」交給系統原版，補丁不包含它們的程式碼。
- **SERIALCOMM 登記**（本 fork 新增）：程式另外有一個執行緒在輪詢 `HKLM\HARDWARE\DEVICEMAP\SERIALCOMM`，
  只接受裡面列出的 COM 埠。手動對應到 `dosdevices/comN` 的埠不會被 Wine 的 mountmgr 登記，
  這個機碼不存在時，即使 SetupDi 列舉成功也會報 `-3`。補丁在第一次列舉 Ports 類別時，用
  `REG_OPTION_VOLATILE` 建立這個機碼並寫入 `\Device\USBSER000 = <PortName>`（工作階段結束後自動消失；
  `reg.exe` 無法在揮發性機碼底下建立子機碼，所以只能由補丁寫入）。
- **除錯**：補丁接管的每個函式都會用 `OutputDebugStringA` 輸出 `[rebocap-wine] ...`，
  可用 `WINEDEBUG=+debugstr` 查看。
- **資料層（真的）**：`SetupDiOpenDevRegKey` 回傳**真實**的登錄機碼，程式透過真正的 `advapi32`
  讀出 `PortName`；開啟埠之後走的是真實的 Wine 序列埠，資料完全是真的。
- **部署**：只新增一個 DLL，加上兩處登錄檔設定（KnownDLLs／DllOverrides）；
  不修改系統檔案、不 hook 任何函式；刪掉檔案再跑解除安裝腳本就能完全還原。

## 從原始碼建置

- 工具鏈：Zig 0.16（內建交叉編譯，不需要安裝 mingw）
- 建置：

  ```bash
  zig build --release      # 產物：zig-out/bin/setupapi.dll
  ```

- 建置時會自動執行 `scripts/gen_def.zig`：讀取 repo 根目錄的 `system-setupapi.dll`
  （Wine 內建版本，作為建置輸入），產生「7 個實作 + 610 條轉送」的匯出清單交給連結器。
- 資料夾說明：

  ```
  src/lib.zig           7 個覆寫函式（列舉層）
  src/constants.zig     已驗證的數值表（GUID／裝置 ID／屬性字串）
  src/util.zig          UTF-16、GUID、探測協定等工具
  src/reg.zig           真實登錄機碼：建立／自動修復 PortName／讀取
  src/forward.zig       執行時轉送輔助（其餘參數→系統原版）
  src/win32.zig         手寫的 Win32 綁定（不用 cImport）
  scripts/gen_def.zig   匯出清單產生器（建置時執行）
  system-setupapi.dll   Wine 內建版本（建置輸入；是原料，不是補丁產物）
  ```

- 建置產物是 `zig-out/bin/setupapi.dll`——**不要把 repo 根目錄的 Wine 內建版本當成補丁複製進 bottle**
  （它只是建置原料，沒有任何代理邏輯）。
- 換 Wine runner 時：用新 runner 的 `lib/wine/x86_64-windows/setupapi.dll`
  取代 repo 根目錄的 `system-setupapi.dll`，再重新 `zig build --release` 就好。

## 相關專案

| 專案 | 用途 |
| --- | --- |
| [TW527E/rebocap-linux-wivrn-fbt](https://github.com/TW527E/rebocap-linux-wivrn-fbt) | Linux + WiVRn + VRChat 全身追蹤的完整教學與啟動腳本 |
| [TW527E/rebocap-linux-compat](https://github.com/TW527E/rebocap-linux-compat) | `bridge.exe`：在 Wine 裡把 Rebocap 的 named pipe 轉成 TCP |
| [TW527E/rebocap-wivrn-bridge](https://github.com/TW527E/rebocap-wivrn-bridge) | 把 Rebocap 的追蹤器透過 SolarXR 送進 WiVRn 的 CLI |

## 授權說明

repo 根目錄的 `system-setupapi.dll` 來自 Wine
（`lib/wine/x86_64-windows/setupapi.dll`），授權為 LGPL-2.1-or-later
（https://wiki.winehq.org/Licensing）。
