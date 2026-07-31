# Incus USBカメラ実行環境

OpenTofuとIncusを使用して、Ubuntu 24.04コンテナを作成します。

この構成では、次の処理を自動化します。

- Incusコンテナの作成
- LAN側macvlanインターフェースの追加
- DHCPまたは固定IPv4アドレスの設定
- UbuntuホストのUSBカメラをコンテナへ割り当て
- .NET 10 Runtimeのインストール
- OpenSSH Serverのインストール
- SSH公開鍵の登録
- GitHub Releaseからカメラ用debパッケージを取得
- debパッケージのインストール
- systemdのoneshotサービスによる静止画撮影
- JPEGファイルの保存

## 1. Windows側の準備

### 1.1 リポジトリの取得

Windows PowerShellで実行します。

```powershell
cd <作業フォルダ>

git clone https://github.com/mono-tec/mono-sample-linux-build-lab.git
cd mono-sample-linux-build-lab
```

すでに取得済みの場合は更新します。

```powershell
git pull
```

### 1.2 SSH鍵の作成

リポジトリルートから、付属のPowerShellスクリプトを実行します。

```powershell
pwsh -File .\scripts\windows\create-ssh-key.ps1
```

作成された公開鍵を確認します。

```powershell
Get-Content $env:USERPROFILE\.ssh\mono-linux-build-lab.pub
```

秘密鍵はWindows端末内で管理し、Gitへ登録しないでください。

## 2. Linux側の準備

### 2.1 USBカメラの接続確認

UbuntuホストへUSBカメラを接続します。

```bash
lsusb
ls -l /dev/video*
ls -l /dev/v4l/by-id/
```

本サンプルでは、映像取得用デバイスとして`/dev/video0`を使用します。

### 2.2 リポジトリの取得

Ubuntuホストで実行します。

```bash
cd ~
git clone https://github.com/mono-tec/mono-sample-linux-build-lab.git
cd mono-sample-linux-build-lab/infra/incus-usb-camera
```

すでに取得済みの場合は更新します。

```bash
cd ~/mono-sample-linux-build-lab
git pull
cd infra/incus-usb-camera
```

### 2.3 設定生成スクリプトの準備

```bash
chmod +x scripts/create-terraform-tfvars.sh
```

## 3. terraform.tfvarsの作成

```bash
./scripts/create-terraform-tfvars.sh
```

対話形式で次の内容を設定します。

- Ubuntuホストの有線LANインターフェース
- IPv4設定方式（DHCPまたは固定IP）
- 固定IPv4アドレスとプレフィックス長
- Windows側で作成したSSH公開鍵
- Ubuntuホスト側のカメラデバイス
- コンテナ内のカメラデバイス
- `video`グループのGID
- カメラデバイスのアクセス権限
- debパッケージを取得するGitHub Releaseのバージョン
- 取得するdebパッケージ名

生成結果を確認します。

```bash
cat terraform.tfvars
```

`terraform.tfvars`には環境固有情報が含まれるため、Gitへ登録しません。

## 4. OpenTofuの初期化

```bash
tofu init
tofu fmt
tofu validate
tofu plan
```

`plan`では、USBカメラのデバイス設定が含まれていることを確認します。

```text
camera0
type   = unix-char
source = /dev/video0
path   = /dev/video0
gid    = 44
mode   = 0660
```

## 5. コンテナの作成

```bash
tofu apply
```

確認メッセージが表示されたら、`yes`を入力します。

## 6. Cloud-initの完了確認

```bash
incus exec ubuntu2404-usb-camera -- \
  cloud-init status --wait
```

次の表示になれば完了です。

```text
status: done
```

ネットワーク設定を確認します。

```bash
incus exec ubuntu2404-usb-camera -- \
  ip -br address
```

`eth1`に設定されたIPv4アドレスを確認してください。

Cloud-init全体のログを確認します。

```bash
incus exec ubuntu2404-usb-camera -- \
  cat /var/log/cloud-init-output.log
```

カメラ用debパッケージの取得・インストールログを確認します。

```bash
incus exec ubuntu2404-usb-camera -- \
  cat /var/log/linux-build-lab-camera-install.log
```

## 7. Ubuntuホストから自動構築結果を確認

### 7.1 USBカメラデバイス

```bash
incus exec ubuntu2404-usb-camera -- \
  ls -l /dev/video0
```

次のように、所有グループが`video`になっていることを確認します。

```text
crw-rw---- 1 root video ... /dev/video0
```

### 7.2 ubuntuユーザーのグループ

```bash
incus exec ubuntu2404-usb-camera -- \
  id ubuntu
```

`video`グループが含まれていることを確認します。

```text
groups=...,44(video)
```

### 7.3 debパッケージ

```bash
incus exec ubuntu2404-usb-camera -- \
  dpkg -l | grep linux-build-lab-camera
```

```bash
incus exec ubuntu2404-usb-camera -- \
  dpkg -L linux-build-lab-camera
```

### 7.4 systemdサービス

```bash
incus exec ubuntu2404-usb-camera -- \
  systemctl status \
    linux-build-lab-camera.service \
    --no-pager
```

正常に実行された場合は、次のような状態になります。

```text
Active: active (exited)
```

登録されたUnitファイルを確認します。

```bash
incus exec ubuntu2404-usb-camera -- \
  systemctl cat linux-build-lab-camera.service
```

次の設定が含まれていることを確認します。

```ini
User=ubuntu
Group=ubuntu
SupplementaryGroups=video
StateDirectory=linux-build-lab-camera
```

### 7.5 実行ログ

```bash
incus exec ubuntu2404-usb-camera -- \
  journalctl \
    -u linux-build-lab-camera.service \
    --no-pager
```

次のような出力が確認できれば成功です。

```text
Linux Build Lab Camera Sample
Device   : /dev/video0
Output   : /var/lib/linux-build-lab-camera/capture.jpg
[SUCCESS] JPEGファイルを作成しました。
```

### 7.6 撮影画像

```bash
incus exec ubuntu2404-usb-camera -- \
  ls -lh /var/lib/linux-build-lab-camera/capture.jpg
```

```bash
incus exec ubuntu2404-usb-camera -- \
  file /var/lib/linux-build-lab-camera/capture.jpg
```

正常な場合は、次のように表示されます。

```text
JPEG image data
```

## 8. WindowsからSSH接続

Windows PowerShellから、`eth1`に設定されたIPv4アドレスを指定して接続します。

```powershell
ssh `
  -o IdentitiesOnly=yes `
  -i $env:USERPROFILE\.ssh\mono-linux-build-lab `
  ubuntu@192.168.xxx.xxx
```

初回接続時には、ホスト鍵の確認が表示されます。

```text
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

接続先が正しいことを確認して、`yes`を入力します。

## 9. Windowsから動作確認

以降のコマンドは、WindowsからSSH接続したコンテナ内で実行します。

### 9.1 OSと.NET Runtime

```bash
cat /etc/os-release
dotnet --info
```

### 9.2 USBカメラとユーザー権限

```bash
ls -l /dev/video0
id
```

`/dev/video0`の所有グループが`video`であり、ログインユーザーが`video`グループへ所属していることを確認します。

### 9.3 debパッケージ

```bash
dpkg -l | grep linux-build-lab-camera
dpkg -L linux-build-lab-camera
```

### 9.4 systemd Unit

```bash
sudo systemctl cat linux-build-lab-camera.service
sudo systemctl is-enabled linux-build-lab-camera.service
```

今回の構成では、Cloud-initから1回だけ起動し、OS起動時の自動実行は有効化していないため、次の表示になります。

```text
disabled
```

サービスの実行状態を確認します。

```bash
sudo systemctl status \
  linux-build-lab-camera.service \
  --no-pager
```

### 9.5 実行ログ

```bash
sudo journalctl \
  -u linux-build-lab-camera.service \
  --no-pager
```

### 9.6 撮影画像

```bash
ls -lh /var/lib/linux-build-lab-camera/capture.jpg
file /var/lib/linux-build-lab-camera/capture.jpg
```

## 10. 再撮影

oneshotサービスを再実行する場合は、いったん停止してから起動します。

```bash
sudo systemctl stop linux-build-lab-camera.service
sudo systemctl start linux-build-lab-camera.service
```

ログと撮影時刻を確認します。

```bash
sudo journalctl \
  -u linux-build-lab-camera.service \
  --no-pager

ls -lh \
  --time-style=long-iso \
  /var/lib/linux-build-lab-camera/capture.jpg
```

## 実行の流れ

```text
Ubuntuホスト
  ├─ USBカメラを接続
  ├─ tofu apply
  ├─ Incusコンテナを作成
  ├─ /dev/video0をコンテナへ割り当て
  ├─ Cloud-init完了確認
  └─ eth1のIPアドレス確認

Cloud-init
  ├─ .NET 10 Runtimeを導入
  ├─ OpenSSH Serverを導入
  ├─ ubuntuユーザーをvideoグループへ追加
  ├─ カメラ用debパッケージを取得
  ├─ debパッケージをインストール
  └─ systemd oneshotで静止画を撮影

Windows
  ├─ SSH接続
  ├─ USBカメラの権限確認
  ├─ debパッケージ確認
  ├─ systemd Unit確認
  ├─ Journal確認
  └─ JPEGファイル確認
```

## 11. コンテナの削除

```bash
tofu destroy
```

確認メッセージが表示されたら、`yes`を入力します。

## 再作成時の手順

Cloud-initの変更内容を初回起動から確認する場合は、既存コンテナを削除して再作成します。

```bash
tofu destroy
tofu apply
```

Cloud-initは基本的にインスタンスの初回起動時に実行されます。既存コンテナのuser-dataを変更しただけでは、`write_files`や`runcmd`が再実行されない場合があります。

## Gitへ登録するファイル

登録するもの：

```text
.terraform.lock.hcl
cloud-init.yaml.tftpl
main.tf
outputs.tf
terraform.tfvars.example
variables.tf
scripts/create-terraform-tfvars.sh
README.md
```

登録しないもの：

```text
.terraform/
terraform.tfvars
terraform.tfstate
terraform.tfstate.*
```
