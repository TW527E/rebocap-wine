[简体中文](README.md) · [繁體中文](README.zh-TW.md) · [English](README.en.md) · **日本語**

# Rebocap Wine 互換パッチ

Windows 版 ReboCap クライアントが Wine（Bottles／素の Wine／その他の Wine フロントエンド）上で
RebornBodyCap USB レシーバーを認識できるようにします。ステータスが緑になり、トラッカーの値がリアルタイムに届き、
2 つのファームウェアバージョンが表示され、エラーのポップアップも出ません。

> Wine 専用です。本物の Windows ではデバイスが最初から列挙されるので、このパッチは**不要**です。

> [!TIP]
> Rebocap には**公式 Linux 版**が出ており、Wine もこのパッチも使わずにレシーバーを直接扱えます。
> 基本的には公式 Linux 版をおすすめします。このパッチは、Windows 版をあえて Wine で動かしたい場合向けです。
> Linux で WiVRn（SteamVR なし）を使って VRChat のフルボディトラッキングをしたい場合は
> [TW527E/rebocap-linux-wivrn-fbt](https://github.com/TW527E/rebocap-linux-wivrn-fbt) を参照してください。

このリポジトリは [zhangxichang/rebocap-wine](https://github.com/zhangxichang/rebocap-wine) のフォークで、
**SERIALCOMM への登録**（「仕組み」を参照）を追加しています。これがないと、一部の Wine 環境ではデバイスが列挙されても
Rebocap が `-3` を出し続けます。

## 配布ファイル

```
setupapi.dll                  実行時に使う唯一のパッチファイル（ビルド成果物。「ソースからビルド」を参照）
rebocap-wine-install.sh       インストールスクリプト（Linux 側で実行）
rebocap-wine-uninstall.sh     アンインストールスクリプト
README.md                     この説明
```

ビルド済みの `setupapi.dll` はまだ配布していません。先にビルドしてください（必要なのは Zig だけで、数秒で終わります）。

## 前提条件

- レシーバー：USB `248a:8002`（RebornBodyCap／RebornRX）
- prefix に `dosdevices/com34` のテンプレートがあること（Bottles の Wine テンプレートには含まれています。USB シリアルポートは COM33 以降を使います）
- **Linux ユーザーがレシーバーのシリアルポートを読み書きできること**（`/dev/ttyACM*`、通常は `root:uucp 0660`）。
  権限がないと、パッチ自体は効いていても（`-3` は出なくなる）ポートを開けず、ログに `-2 IO连接错误`（I/O 接続エラー）が繰り返し出ます。
  対処は「シリアルポートの権限」を参照してください。
- Bottles（Flatpak）にはデバイスへのアクセス権が必要です（例：`flatpak override --user --device=all com.usebottles.bottles`）。ないと Wine から `/dev/ttyACM*` が見えません。
- パッチは配置した Wine prefix にだけ影響し、ほかのプログラムには影響しません。

## シリアルポートの権限（必須）

アプリはデバイスを列挙したあと、現在の Linux ユーザーで `/dev/ttyACM*`（`com34` 経由）を開きます。
権限が足りないと、ステータスが緑にならず、`rebocap.log` に `-2 IO连接错误` が繰り返し出ます。

対処方法は次のどちらかです。

**方法 A：ユーザーを `uucp` グループに追加する（標準的な方法。再ログインが必要）**

```bash
sudo usermod -aG uucp "$USER"   # Debian/Ubuntu 系では通常 dialout グループ
# デスクトップからログアウトして再ログインすると有効になります
```

**方法 B：udev ルール（再ログイン不要）**

```bash
echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="248a", ATTRS{idProduct}=="8002", MODE="0666"' | \
  sudo tee /etc/udev/rules.d/99-rebocap.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
# レシーバーを一度抜き差しすると有効になります
```

確認方法（読み書きできれば OK。たとえば権限が `0666`、またはユーザーが `uucp` グループに入っている）：

```bash
ls -l /dev/ttyACM*
```

## インストール

1. `setupapi.dll` をビルドします（「ソースからビルド」を参照）。`zig-out/bin/setupapi.dll` ができます。

2. `setupapi.dll` と 2 つのスクリプトを `rebocap.exe` と同じフォルダに置きます。例：

   ```
   <prefix>/drive_c/Program Files (x86)/Rebocap/
   ```

3. 実行権限を付けてインストールスクリプトを実行します。

   ```bash
   cd "<prefix>/drive_c/Program Files (x86)/Rebocap"
   chmod +x rebocap-wine-install.sh rebocap-wine-uninstall.sh
   ./rebocap-wine-install.sh
   ```

   prefix と wine は自動で探します。見つからない場合は指定できます：
   `./rebocap-wine-install.sh --prefix <prefix> --wine <wine 実行ファイル>`

4. インストールスクリプトがするのは 3 つだけです：環境を見つけて確認する、`KnownDLLs\setupapi` を削除する、
   `HKCU\Software\Wine\DllOverrides\setupapi = native,builtin` を設定する。

5. **反映のタイミング（重要）**：Wine セッションの再起動が必要です。

   - その prefix のプログラムをすべて閉じてから起動し直す（おすすめ）
   - または `WINEPREFIX="<prefix>" <wine のフォルダ>/wineserver -k` でセッションをすぐ終了する
     （ボトル内のプログラムがすべて強制終了されます）

   レジストリに書き込んだだけでセッションを再起動しないと、実行中のプログラム（と wineserver）は古い設定のままです。

## 普段の使い方

`rebocap.exe` は好きな方法で起動してください（Bottles のショートカット、`bottles-cli run`、素の `wine` など）。
インストールスクリプトは起動には関わらず、フロントエンドも制限しません。

> [!WARNING]
> **Wine 上でトラッカーやレシーバーのファームウェアを更新しないでください。** 途中で失敗するとデバイスが使えなくなるおそれがあります。
> ファームウェアの更新は公式 Linux 版か Windows 版で行ってください。

## ポートと USB の抜き差し

- ポート名（`PortName`）は、パッチが本物のレジストリに必ず存在するようにします。デバイスのレジストリキーを初めて開いたときに自動で作成し、
  既定値として `COM34` を書き込みます（冪等です。既存の値は上書きしません）。
- その prefix では `COM34` が実際の USB シリアルポート（`dosdevices/com34`）に対応します。
- **抜き差しの注意**：レシーバーを抜き差しすると、カーネルのシリアルノードの番号が変わることがあり（ttyACM0／ACM1…）、
  `com34` のリンク先がなくなる場合があります。アプリを再起動しても直らないので、次のようにします。

  - `com34` を現在の `ttyACM*` に向け直してから（`dosdevices/com34` のシンボリックリンクを修正）、アプリを起動する
  - より確実なのは、変わらないパスに向けることです。例：`/dev/serial/by-id/usb-JXQ_Ltd__Co_RebornBodyCap_RebornRX-if00`
  - トラッカーの電源は「接続済み／緑／ファームウェア」には影響せず、リアルタイムの値が届くかどうかにだけ影響します。

## 動作確認の基準

1. `rebocap.log` に `-3` が一つもない
2. ステータスが緑の「接続済み」で、ポップアップが出ない
3. トラッカーの電源を入れるとリアルタイムの値が届く
4. 設定画面にトラッカーとレシーバーのファームウェアバージョンが表示される（例：`v_15 / v_7`）

## トラブルシューティング

ログの場所：`<Rebocap>/log/rebocap.log`（`-3` と `finish update device info` に注目）

レジストリの確認（`<prefix>` と `<wine>` は実際の値に置き換えてください）：

```bash
# setupapi の値が見つからないと表示されれば正常
WINEPREFIX="<prefix>" "<wine>" reg query \
  "HKLM\System\CurrentControlSet\Control\Session Manager\KnownDLLs" /v setupapi

# native,builtin と表示されれば正常
WINEPREFIX="<prefix>" "<wine>" reg query \
  "HKCU\Software\Wine\DllOverrides" /v setupapi
```

| 症状 | 考えられる原因 | 対処 |
| --- | --- | --- |
| 緑にならず、`rebocap.log` に `-3` が出続ける | DllOverrides が効いていない | レジストリを確認。セッションを再起動したか確認（プログラムを閉じる、または `wineserver -k`） |
| 同上 | KnownDLLs が削除されていない | インストールスクリプトを再実行。問い合わせ結果が空になることを確認 |
| 同上、レジストリは正しい | SERIALCOMM が登録されていない（元のパッチを使っている） | このフォークでビルドした `setupapi.dll` を使う |
| まったく変化がない | `setupapi.dll` が `rebocap.exe` と同じフォルダにない | 正しい場所に置き、インストールスクリプトを再実行してセッションを再起動 |
| 緑だが値が来ない | トラッカーの電源が入っていない | トラッカーの電源を入れる（接続・緑・ファームウェアには不要、値には必要） |
| 緑にならず、ログに `-2 IO连接错误` が繰り返し出る | シリアルポートの権限不足 | 「シリアルポートの権限」を参照 |
| 抜き差し後に認識しない | `com34` のリンク先がない | `com34` を現在の `ttyACM*` に向け直す／prefix を再起動してからアプリを起動 |

`WINEDEBUG=+debugstr` を付けて起動すると、パッチが出力する `[rebocap-wine] ...` のデバッグメッセージを確認できます。

## アンインストール

```bash
./rebocap-wine-uninstall.sh
```

スクリプトは `KnownDLLs\setupapi = "setupapi.dll"` を元に戻し、`DllOverrides\setupapi` と、
実行時に作られたデバイスキー `REBORNRX` を削除します。こちらも**セッションの再起動**で反映されます。
完全に取り除くには、`setupapi.dll`、2 つのスクリプト、この README を手動で削除してください。

## 仕組み（概要）

- **列挙層（偽物）**：パッチは同名の `setupapi.dll` です（アプリのフォルダに置くと、システム版より先に読み込まれます）。
  7 つの `SetupDi*` 関数をパッチが実装し、検証済みのデバイス情報（Ports クラスの GUID、
  インスタンス ID `USB\VID_248A&PID_8002\REBORNRX`、デバイスプロパティなど）を返します。
  残りの約 610 個のエクスポートはリンク時の「転送エントリ」でシステム版に渡し、パッチにはそのコードを含みません。
- **SERIALCOMM への登録**（このフォークで追加）：アプリは別スレッドで `HKLM\HARDWARE\DEVICEMAP\SERIALCOMM` をポーリングし、
  そこに載っている COM ポートだけを受け付けます。`dosdevices/comN` に手動で割り当てたポートは Wine の mountmgr が登録しないため、
  このキーがないと SetupDi の列挙が成功しても `-3` になります。パッチは Ports クラスを初めて列挙するときに
  `REG_OPTION_VOLATILE` でこのキーを作成し、`\Device\USBSER000 = <PortName>` を書き込みます（セッション終了で自動的に消えます。
  `reg.exe` は揮発性キーの下にサブキーを作れないため、パッチが書き込む必要があります）。
- **デバッグ**：パッチが引き受ける各関数は `OutputDebugStringA` で `[rebocap-wine] ...` を出力します。
  `WINEDEBUG=+debugstr` で確認できます。
- **データ層（本物）**：`SetupDiOpenDevRegKey` は**本物**のレジストリキーを返し、アプリは本物の `advapi32` で
  `PortName` を読みます。ポートを開いたあとは Wine の本物のシリアルポートを通るので、データはすべて本物です。
- **配置**：DLL を 1 つ追加し、レジストリ設定を 2 か所（KnownDLLs／DllOverrides）変えるだけです。
  システムファイルは変更せず、関数のフックもしません。ファイルを消してアンインストールスクリプトを実行すれば完全に元に戻ります。

## ソースからビルド

- ツールチェーン：Zig 0.16（クロスコンパイル内蔵。mingw は不要）
- ビルド：

  ```bash
  zig build --release      # 成果物：zig-out/bin/setupapi.dll
  ```

- ビルド時に `scripts/gen_def.zig` が自動で実行され、リポジトリ直下の `system-setupapi.dll`
  （Wine 組み込み版。ビルドの入力）を読み込んで、「実装 7 個＋転送 610 個」のエクスポート一覧をリンカーに渡します。
- ディレクトリ構成：

  ```
  src/lib.zig           7 つの上書き関数（列挙層）
  src/constants.zig     検証済みの値（GUID／デバイス ID／プロパティ文字列）
  src/util.zig          UTF-16、GUID、プローブプロトコルなどのユーティリティ
  src/reg.zig           本物のレジストリキー：作成／PortName の自動修復／読み取り
  src/forward.zig       実行時の転送ヘルパー（その他の引数→システム版）
  src/win32.zig         手書きの Win32 バインディング（cImport なし）
  scripts/gen_def.zig   エクスポート一覧の生成（ビルド時に実行）
  system-setupapi.dll   Wine 組み込み版（ビルドの入力。パッチではありません）
  ```

- パッチは `zig-out/bin/setupapi.dll` です。**リポジトリ直下の Wine 組み込み版をパッチとしてボトルにコピーしないでください**
  （ビルドの材料にすぎず、パッチの処理は入っていません）。
- Wine の runner を変えるときは、新しい runner の `lib/wine/x86_64-windows/setupapi.dll` で
  リポジトリ直下の `system-setupapi.dll` を置き換え、`zig build --release` し直してください。

## 関連プロジェクト

| プロジェクト | 用途 |
| --- | --- |
| [TW527E/rebocap-linux-wivrn-fbt](https://github.com/TW527E/rebocap-linux-wivrn-fbt) | Linux + WiVRn + VRChat フルボディトラッキングの手順書と起動スクリプト |
| [TW527E/rebocap-linux-compat](https://github.com/TW527E/rebocap-linux-compat) | `bridge.exe`：Wine 内で Rebocap の名前付きパイプを TCP に変換 |
| [TW527E/rebocap-wivrn-bridge](https://github.com/TW527E/rebocap-wivrn-bridge) | Rebocap のトラッカーを SolarXR 経由で WiVRn に送る CLI |

## ライセンス

リポジトリ直下の `system-setupapi.dll` は Wine（`lib/wine/x86_64-windows/setupapi.dll`）由来で、
ライセンスは LGPL-2.1-or-later です（https://wiki.winehq.org/Licensing）。
