# Incus AIエージェント実行環境

OpenTofuとIncusを使用して、OpenCodeを実行するUbuntu 24.04コンテナを作成します。

この構成では、次の処理を自動化します。

- Incusコンテナの作成
- CPU・メモリ上限の設定
- LAN側macvlanインターフェースの追加
- DHCPまたは固定IPv4アドレスの設定
- OpenSSH Serverのインストール
- SSH公開鍵の登録
- Git、curl、jqのインストール
- OpenCodeのインストール
- さくらのAI Engine接続設定の作成
- OpenCode用作業ディレクトリの作成

OpenCodeは、さくらのAI Engineが提供するOpenAI互換APIへ接続します。

本サンプルでは、基盤モデル無償プランで利用できる次のモデルを対象にします。

- `gpt-oss-120b`
- `llm-jp-3.1-8x13b-instruct4`

## 今回作成する構成

```text
Windows PC
  │
  │ SSH公開鍵認証
  ▼
物理LAN
  │
  ▼
Ubuntuホスト
  ├─ OpenTofu
  ├─ Incus
  └─ Ubuntu 24.04コンテナ
       ├─ OpenSSH Server
       ├─ Git
       ├─ curl
       ├─ jq
       ├─ OpenCode
       ├─ さくらのAI Engine接続設定
       └─ OpenCode作業ディレクトリ
```

Incusコンテナには、2つのネットワークインターフェースを持たせます。

```text
eth0
  └─ Incus内部ネットワーク
     パッケージ取得やAPI接続に使用

eth1
  └─ macvlanで物理LANへ接続
     WindowsからのSSH接続に使用
```

## この構成の目的

OpenCodeをUbuntuホストへ直接インストールせず、Incusコンテナ内へ分離します。

これにより、次のような運用を想定しています。

- AIエージェントの作業環境をホストOSから分離する
- 検証終了後にコンテナを破棄する
- OpenTofuから同じ環境を再作成する
- AIごとに導入ツールや認証情報を分ける
- 将来的に仕様作成、実装、テスト、レビュー環境を分割する

## 1．Windows側の準備

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

## 2．さくらのAI Engine側の準備

さくらのAI Engineを利用できる状態にし、アカウントトークンを発行します。

本サンプルでは、基盤モデル無償プランを使用します。

設定生成スクリプトの実行時に、発行したアカウントトークンを入力します。

アカウントトークンは、次のファイルや設定へ保存されます。

```text
terraform.tfvars
terraform.tfstate
Incusコンテナのcloud-init設定
/home/ubuntu/.config/opencode/opencode.json
```

検証専用環境で利用し、トークンをGitへ登録しないでください。

## 3．Linux側の準備

### 3.1 リポジトリの取得

Ubuntuホストで実行します。

```bash
cd ~

git clone \
  https://github.com/mono-tec/mono-sample-linux-build-lab.git

cd \
  mono-sample-linux-build-lab/infra/incus-sakura-ai-agent
```

すでに取得済みの場合は更新します。

```bash
cd ~/mono-sample-linux-build-lab

git pull

cd infra/incus-sakura-ai-agent
```

### 3.2 設定生成スクリプトの準備

```bash
chmod +x scripts/create-terraform-tfvars.sh
```

## 4．terraform.tfvarsの作成

設定生成スクリプトを実行します。

```bash
./scripts/create-terraform-tfvars.sh
```

対話形式で次の内容を設定します。

- Incusコンテナ名
- 仮想CPU数
- メモリ上限
- Ubuntuホストの物理LANインターフェース
- IPv4設定方式
  - DHCP
  - 固定IPv4アドレス
- 固定IPv4アドレスとプレフィックス長
- Windows側で作成したSSH公開鍵
- さくらのAI Engine Base URL
- さくらのAI Engineアカウントトークン
- 使用するモデル
- OpenCode作業ディレクトリ

生成されたファイルの権限を確認します。

```bash
ls -l terraform.tfvars
```

次のように、実行ユーザーだけが読み書きできる状態になっていることを確認します。

```text
-rw------- ... terraform.tfvars
```

`terraform.tfvars`にはAPIトークンが含まれるため、ファイル内容を画面へ表示しないでください。

また、Gitへ登録しないでください。

## 5．OpenTofuの初期化と構成確認

次の順番で実行します。

```bash
tofu init
tofu fmt
tofu validate
tofu plan
```

`plan`では、主に次の内容を確認します。

- Ubuntu 24.04コンテナが作成される
- CPU・メモリ上限が設定される
- macvlanのLAN側NICが追加される
- cloud-initの設定が渡される

APIトークンは`sensitive`変数として定義していますが、OpenTofuのstateには保存されます。

`tofu plan`やログをブログへ掲載する場合は、秘密情報が含まれていないことを確認してください。

## 6．コンテナの作成

```bash
tofu apply
```

確認メッセージが表示されたら、内容を確認して`yes`を入力します。

## 7．cloud-initの完了確認

コンテナ名が初期値の場合は、次を実行します。

```bash
incus exec ubuntu2404-sakura-ai-agent -- \
  cloud-init status --wait
```

次の表示になれば完了です。

```text
status: done
```

コンテナ名を変更した場合は、設定した名前へ読み替えてください。

## 8．Ubuntuホストから構築結果を確認

### 8.1 コンテナ一覧

```bash
incus list
```

### 8.2 ネットワーク設定

```bash
incus exec ubuntu2404-sakura-ai-agent -- \
  ip -br address
```

`eth1`に設定されたIPv4アドレスを確認します。

### 8.3 cloud-initログ

```bash
incus exec ubuntu2404-sakura-ai-agent -- \
  cat /var/log/cloud-init-output.log
```

### 8.4 OpenCodeインストールログ

```bash
incus exec ubuntu2404-sakura-ai-agent -- \
  cat /var/log/opencode-install.log
```

### 8.5 OpenCodeのバージョン

```bash
incus exec ubuntu2404-sakura-ai-agent -- \
  sudo -u ubuntu \
  HOME=/home/ubuntu \
  /usr/local/bin/opencode --version
```

または、シンボリックリンクを確認します。

```bash
incus exec ubuntu2404-sakura-ai-agent -- \
  ls -l /usr/local/bin/opencode
```

### 8.6 OpenCode設定

APIトークンを表示しないように、設定項目だけを確認します。

```bash
incus exec ubuntu2404-sakura-ai-agent -- \
  sudo -u ubuntu \
  jq \
    '{
      model: .model,
      provider_name: .provider.sakura.name,
      base_url: .provider.sakura.options.baseURL,
      api_key: "***MASKED***"
    }' \
    /home/ubuntu/.config/opencode/opencode.json
```

次のような内容が確認できれば設定完了です。

```json
{
  "model": "sakura/gpt-oss-120b",
  "provider_name": "Sakura AI Engine",
  "base_url": "https://api.ai.sakura.ad.jp/v1",
  "api_key": "***MASKED***"
}
```

### 8.7 作業ディレクトリ

```bash
incus exec ubuntu2404-sakura-ai-agent -- \
  ls -ld /home/ubuntu/workspace
```

所有者が`ubuntu`になっていることを確認します。

```text
drwxr-xr-x ... ubuntu ubuntu ... /home/ubuntu/workspace
```

## 9．WindowsからSSH接続

Windows PowerShellから、`eth1`へ設定されたIPv4アドレスを指定して接続します。

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

## 10．WindowsからOpenCode環境を確認

以降のコマンドは、WindowsからSSH接続したコンテナ内で実行します。

### 10.1 OS

```bash
cat /etc/os-release
```

### 10.2 Git

```bash
git --version
```

### 10.3 OpenCode

```bash
which opencode
opencode --version
```

### 10.4 作業ディレクトリ

```bash
cd ~/workspace
pwd
```

次のパスが表示されます。

```text
/home/ubuntu/workspace
```

## 11．さくらのAI Engineへの接続確認

cloud-initでは、無料リクエストを消費しないように、APIへの問い合わせを実行していません。

コンテナ構築後に、手動で1回だけ接続を確認します。

作業ディレクトリへ移動します。

```bash
cd ~/workspace
```

OpenCodeを起動します。

```bash
opencode
```

起動後、例えば次のような読み取り専用の指示を入力します。

```text
現在のディレクトリを確認し、
ファイルを変更せずに簡潔に説明してください。
```

正常に応答が返れば、OpenCodeからさくらのAI Engineへ接続できています。

この操作では、さくらのAI EngineのAPIリクエストを使用します。

## 12．モデルの切り替え

使用モデルは`terraform.tfvars`の次の値で指定します。

```hcl
sakura_ai_model = "gpt-oss-120b"
```

日本語モデルを使用する場合は、次へ変更します。

```hcl
sakura_ai_model = "llm-jp-3.1-8x13b-instruct4"
```

cloud-initの設定を初回起動から再確認する場合は、コンテナを破棄して再作成します。

```bash
tofu destroy
tofu apply
```

## 13．実行の流れ

```text
Ubuntuホスト
  ├─ 設定生成スクリプトを実行
  ├─ terraform.tfvarsを作成
  ├─ tofu apply
  ├─ Incusコンテナを作成
  └─ cloud-init完了確認

cloud-init
  ├─ OpenSSH Serverを導入
  ├─ Git、curl、jqを導入
  ├─ SSH公開鍵を登録
  ├─ LAN側NICを設定
  ├─ OpenCodeを導入
  ├─ さくらのAI Engine接続設定を作成
  └─ 作業ディレクトリを作成

Windows
  ├─ SSH接続
  ├─ OpenCodeの導入結果を確認
  ├─ 設定内容を確認
  └─ AI Engineへの接続を手動確認
```

## 14．コンテナの削除

```bash
tofu destroy
```

確認メッセージが表示されたら、内容を確認して`yes`を入力します。

## 15．再作成時の手順

cloud-initの変更内容を初回起動から確認する場合は、既存コンテナを削除して再作成します。

```bash
tofu destroy
tofu apply
```

cloud-initは基本的にインスタンスの初回起動時に実行されます。

既存コンテナのuser-dataを変更しただけでは、`write_files`や`runcmd`が再実行されない場合があります。

## 16．秘密情報の削除

検証終了後、必要に応じてコンテナを削除します。

```bash
tofu destroy
```

ローカルに保存したAPIトークンやstateも不要であれば削除します。

```bash
rm -f \
  terraform.tfvars \
  terraform.tfstate \
  terraform.tfstate.backup
```

`.terraform/`も不要であれば削除できます。

```bash
rm -rf .terraform
```

## 17．Gitへ登録するファイル

登録するもの：

```text
.gitignore
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
*.tfplan
```

## 今後の検証

今回作成するのは、AIエージェント用コンテナの最小構成です。

今後は、次のような検証を予定しています。

```text
テーマを提示
  ↓
要件整理
  ↓
概念設計
  ↓
基本設計
  ↓
実装計画
  ↓
コード作成
  ↓
テスト
  ↓
結果報告
```

さらに、将来的には役割ごとにIncusコンテナを分ける構成も検討します。

```text
仕様作成用AIコンテナ
実装用AIコンテナ
テスト用AIコンテナ
レビュー用AIコンテナ
```

OpenTofuとcloud-initで、各コンテナへ導入するツール、認証情報、CPU・メモリ、ネットワーク設定を分けることで、AIエージェントごとの作業範囲を環境側から制限できる構成を目指します。
