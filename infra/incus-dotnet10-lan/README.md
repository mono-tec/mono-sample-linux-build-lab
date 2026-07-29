# Incus .NET 10 LAN環境

OpenTofuとIncusを使用して、Ubuntu 24.04コンテナを作成します。

この構成では、次の処理を自動化します。

- Incusコンテナの作成
- LAN側macvlanインターフェースの追加
- DHCPまたは固定IPv4アドレスの設定
- .NET 10 Runtimeのインストール
- OpenSSH Serverのインストール
- SSH公開鍵の登録
- GitHub Releaseから検証用アプリを取得
- 検証用アプリの実行

## 1. リポジトリの取得

```bash
cd ~
git clone https://github.com/mono-tec/mono-sample-linux-build-lab.git
cd mono-sample-linux-build-lab/infra/incus-dotnet10-lan
```

既に取得済みの場合は更新します。

```bash
git pull
```

## 2. SSH鍵の作成

Windows PowerShellで実行します。

```powershell
ssh-keygen `
  -t ed25519 `
  -f $env:USERPROFILE\.ssh\mono-linux-build-lab `
  -C mono-linux-build-lab
```

公開鍵を確認します。

```powershell
Get-Content $env:USERPROFILE\.ssh\mono-linux-build-lab.pub
```

秘密鍵はWindows端末内で管理し、Gitへ登録しないでください。

## 3. terraform.tfvarsの作成

設定生成スクリプトへ実行権限を付与します。

```bash
chmod +x scripts/create-terraform-tfvars.sh
```

スクリプトを実行します。

```bash
./scripts/create-terraform-tfvars.sh
```

対話形式で次の内容を設定します。

- Ubuntuホストの有線LANインターフェース
- IPv4設定方式（DHCPまたは固定IP）
- 固定IPv4アドレスとプレフィックス長
- Windows側で作成したSSH公開鍵
- 検証用アプリのReleaseバージョン

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

```bash
incus exec ubuntu2404-dotnet10-lan -- \
  cloud-init status --wait
```

次の表示になれば完了です。

```text
status: done
```

## 7. 動作確認

ネットワーク設定を確認します。

```bash
incus exec ubuntu2404-dotnet10-lan -- \
  ip -br address
```

SSHサービスを確認します。

```bash
incus exec ubuntu2404-dotnet10-lan -- \
  systemctl is-active ssh
```

公開鍵の登録を確認します。

```bash
incus exec ubuntu2404-dotnet10-lan -- \
  cat /home/ubuntu/.ssh/authorized_keys
```

検証用アプリの実行結果を確認します。

```bash
incus exec ubuntu2404-dotnet10-lan -- \
  cat /var/log/linux-build-lab-sample.log
```

## 8. WindowsからSSH接続

`eth1`に設定されたIPv4アドレスを指定します。

```powershell
ssh `
  -o IdentitiesOnly=yes `
  -i $env:USERPROFILE\.ssh\mono-linux-build-lab `
  ubuntu@192.168.xxx.xxx
```

初回接続時にはホスト鍵の確認が表示されます。

```text
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

接続先が正しいことを確認して、`yes`を入力します。

## 9. コンテナの削除

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

Cloud-initは基本的にインスタンスの初回起動時に実行されます。既存コンテナへuser-dataを変更しただけでは、`write_files`や`runcmd`が再実行されない場合があります。

## Gitへ登録するファイル

登録するもの：

```text
.terraform.lock.hcl
cloud-init.yaml
main.tf
outputs.tf
terraform.tfvars.example
variables.tf
scripts/create-terraform-tfvars.sh
```

登録しないもの：

```text
.terraform/
terraform.tfvars
terraform.tfstate
terraform.tfstate.*
```
