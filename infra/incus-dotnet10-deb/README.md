# Incus .NET 10 debパッケージ実行環境

OpenTofuとIncusを使用して、Ubuntu 24.04コンテナを作成します。

この構成では、次の処理を自動化します。

- Incusコンテナの作成
- LAN側macvlanインターフェースの追加
- DHCPまたは固定IPv4アドレスの設定
- .NET 10 Runtimeのインストール
- OpenSSH Serverのインストール
- SSH公開鍵の登録
- GitHub Releaseからdebパッケージを取得
- debパッケージのインストール
- systemdのoneshotサービスによる検証用アプリの実行

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

### 2.1 リポジトリの取得

Ubuntuホストで実行します。

```bash
cd ~
git clone https://github.com/mono-tec/mono-sample-linux-build-lab.git
cd mono-sample-linux-build-lab/infra/incus-dotnet10-deb
```

すでに取得済みの場合は、リポジトリを更新します。

```bash
cd ~/mono-sample-linux-build-lab
git pull
cd infra/incus-dotnet10-deb
```

### 2.2 設定生成スクリプトの準備

実行権限を付与します。

```bash
chmod +x scripts/create-terraform-tfvars.sh
```

## 3. terraform.tfvarsの作成

設定生成スクリプトを実行します。

```bash
./scripts/create-terraform-tfvars.sh
```

対話形式で次の内容を設定します。

- Ubuntuホストの有線LANインターフェース
- IPv4設定方式（DHCPまたは固定IP）
- 固定IPv4アドレスとプレフィックス長
- Windows側で作成したSSH公開鍵
- debパッケージを取得するGitHub Releaseのバージョン

生成結果を確認します。

```bash
cat terraform.tfvars
```

`terraform.tfvars`には環境固有情報が含まれるため、Gitへ登録しません。

## 4. OpenTofuの初期化

```bash
tofu init
```

構成を整形・検証します。

```bash
tofu fmt
tofu validate
```

実行内容を確認します。

```bash
tofu plan
```

## 5. コンテナの作成

```bash
tofu apply
```

確認メッセージが表示されたら、次を入力します。

```text
yes
```

## 6. Cloud-initの完了確認

Ubuntuホストで、Cloud-initの完了を待ちます。

```bash
incus exec ubuntu2404-dotnet10-deb -- \
  cloud-init status --wait
```

次の表示になれば完了です。

```text
status: done
```

コンテナのネットワーク設定を確認します。

```bash
incus exec ubuntu2404-dotnet10-deb -- \
  ip -br address
```

`eth1`に設定されたIPv4アドレスを確認してください。

Cloud-initの処理でエラーが発生した場合は、次のログを確認します。

```bash
incus exec ubuntu2404-dotnet10-deb -- \
  cat /var/log/cloud-init-output.log
```

## 7. WindowsからSSH接続

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

## 8. Windowsから動作確認

以降のコマンドは、WindowsからSSH接続したコンテナ内で実行します。

### 8.1 OSと.NET Runtime

```bash
cat /etc/os-release
dotnet --info
```

### 8.2 debパッケージ

インストール状態を確認します。

```bash
dpkg -l | grep linux-build-lab
```

パッケージによって配置されたファイルを確認します。

```bash
dpkg -L linux-build-lab-sample
```

### 8.3 systemd Unit

登録されたUnitファイルを確認します。

```bash
sudo systemctl cat linux-build-lab-sample.service
```

検証用アプリが、`ubuntu`ユーザーで実行される設定になっていることを確認します。

```ini
User=ubuntu
Group=ubuntu
```

サービスの有効化状態を確認します。

```bash
sudo systemctl is-enabled linux-build-lab-sample.service
```

今回の構成では、Cloud-initから1回だけ起動し、OS起動時の自動実行は有効化していないため、次の表示になります。

```text
disabled
```

サービスの実行状態を確認します。

```bash
sudo systemctl status \
  linux-build-lab-sample.service \
  --no-pager
```

正常に実行された場合は、次のような状態になります。

```text
Active: active (exited)
```

### 8.4 アプリの実行ログ

systemdのJournalへ記録された実行結果を確認します。

```bash
sudo journalctl \
  -u linux-build-lab-sample.service \
  --no-pager
```

次のような.NETアプリの出力が確認できれば成功です。

```text
Linux Build Lab Sample
OS       : Ubuntu 24.04
Architecture: X64
.NET     : .NET 10
Hello from .NET 10 on Linux!
```

### 8.5 debパッケージのインストールログ

GitHub Releaseからの取得と、debパッケージのインストール処理を確認します。

```bash
sudo cat /var/log/linux-build-lab-install.log
```

## 実行の流れ

```text
Ubuntuホスト
  ├─ tofu apply
  ├─ Cloud-init完了確認
  └─ eth1のIPアドレス確認

Windows
  ├─ SSH接続
  ├─ debパッケージ確認
  ├─ systemd Unit確認
  └─ journalctlで実行結果確認
```

## 9. コンテナの削除

Ubuntuホストで実行します。

```bash
tofu destroy
```

確認メッセージが表示されたら、次を入力します。

```text
yes
```

## 再作成時の手順

Cloud-initの変更内容を初回起動から確認する場合は、既存コンテナを削除して再作成します。

```bash
tofu destroy
tofu apply
```

Cloud-initは基本的にインスタンスの初回起動時に実行されます。

既存コンテナのuser-dataを変更しただけでは、`write_files`や`runcmd`が再実行されない場合があります。

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
