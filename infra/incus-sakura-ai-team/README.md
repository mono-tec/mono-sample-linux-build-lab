# Incus AIエージェントチーム実行環境

OpenTofuとIncusを使用して、役割と導入機能を変更可能なAIエージェント用Ubuntu 24.04コンテナを作成します。

コンテナ数、役割、CPU、メモリ、導入機能は、`terraform.tfvars`の`agents`マップで指定します。

初期設定では、次の2つのコンテナを作成します。

```text
agent01
  ├─ role: design
  ├─ OpenCode
  ├─ Git
  ├─ curl
  ├─ jq
  └─ さくらのAI Engine接続設定

agent02
  ├─ role: build
  ├─ OpenCode
  ├─ Git
  ├─ curl
  ├─ jq
  ├─ さくらのAI Engine接続設定
  └─ .NET 10 SDK
```

コンテナ名と役割は固定ではありません。

`terraform.tfvars`を変更することで、役割の変更、コンテナ数の増減、役割ごとの導入機能の変更ができます。

OpenCodeは、さくらのAI Engineが提供するOpenAI互換APIへ接続します。


## リポジトリ構成

本ディレクトリは、次の構成で管理します。

```text
incus-sakura-ai-team/
├─ hello-dotnet/
│  ├─ request.md
│  └─ prompts/
│     ├─ design.md
│     └─ build.md
├─ scripts/
│  ├─ create-experiment.sh
│  └─ create-terraform-tfvars.sh
├─ .gitignore
├─ .terraform.lock.hcl
├─ cloud-init.yaml.tftpl
├─ main.tf
├─ outputs.tf
├─ README.md
├─ terraform.tfvars.example
└─ variables.tf
```

`hello-dotnet/`には、最初の手動検証で使用する公開可能な依頼内容と、役割別の実行指示を保存します。

```text
request.md
  開発要求、技術条件、成果物、完了条件

prompts/design.md
  設計担当エージェントへの実行指示

prompts/build.md
  実装担当エージェントへの実行指示
```

これらは検証用の原本です。実行時は共有検証領域へコピーし、原本を直接編集しません。

## 今回作成する構成

```text
Ubuntuホスト
  ├─ OpenTofu
  ├─ Incus
  ├─ /home/ubuntu/ai-agent-team
  │    └─ experiments
  │         ├─ experiment-001
  │         ├─ experiment-002
  │         └─ experiment-003
  │
  ├─ agent01
  │    ├─ role: design
  │    ├─ OpenCode
  │    ├─ Git
  │    ├─ curl
  │    ├─ jq
  │    ├─ さくらのAI Engine接続設定
  │    └─ /workspace
  │
  └─ agent02
       ├─ role: build
       ├─ OpenCode
       ├─ Git
       ├─ curl
       ├─ jq
       ├─ さくらのAI Engine接続設定
       ├─ .NET 10 SDK
       └─ /workspace
```

Ubuntuホスト上の次のディレクトリを、すべてのAIエージェントへ共有します。

```text
/home/ubuntu/ai-agent-team
```

コンテナ内では、次のパスとして参照します。

```text
/workspace
```

コンテナの操作は、Ubuntuホストから`incus exec`を使用して行います。

この構成では、次の機能を使用しません。

- macvlanによる物理LAN接続
- コンテナへの固定IPv4アドレス設定
- WindowsからのSSH接続
- SSH公開鍵の登録

各コンテナは、Incusの`default`プロファイルを使用して外部ネットワークへ接続し、パッケージ取得とさくらのAI EngineへのAPI接続を行います。

## この構成の目的

AIエージェントの開発作業を、役割別のIncusコンテナへ分離します。

最初の検証では、次の2役を使用します。

```text
設計担当
  概要要求を読み、
  概念設計書、基本設計書、
  実装計画書、テスト計画書を作成する

実装担当
  先行工程の設計成果物を読み、
  .NET 10アプリケーションの実装とテストを行う
```

この構成により、次を確認します。

- OpenTofuから複数のAIエージェント用コンテナを一括作成できること
- `terraform.tfvars`でコンテナ数と役割を変更できること
- コンテナごとに導入ツールを変更できること
- 設計担当の成果物を共有領域経由で実装担当へ受け渡せること
- AIエージェントの工程をUbuntuホストから順番に実行できること
- コンテナを使い回し、検証ごとに作業領域を分けられること
- 検証終了後に環境をまとめて破棄・再作成できること

## 役割別の環境構築

AIエージェントの定義は、`terraform.tfvars`の`agents`マップへ記述します。

```hcl
agents = {
  agent01 = {
    instance_name      = "ubuntu2404-sakura-agent-01"
    role               = "design"
    cpu_count          = 1
    memory_limit       = "2GiB"
    install_dotnet_sdk = false
  }

  agent02 = {
    instance_name      = "ubuntu2404-sakura-agent-02"
    role               = "build"
    cpu_count          = 2
    memory_limit       = "4GiB"
    install_dotnet_sdk = true
  }
}
```

各項目の意味は次のとおりです。

```text
マップキー
  OpenTofu内部でエージェントを識別する名前

instance_name
  Incusコンテナ名

role
  AIエージェントへ割り当てる役割

cpu_count
  仮想CPU数

memory_limit
  メモリ上限

install_dotnet_sdk
  .NET 10 SDKを導入するか
```

役割名と導入機能は分離されています。

例えば、テスト担当へ.NET 10 SDKを導入することもできます。

```hcl
agent03 = {
  instance_name      = "ubuntu2404-sakura-agent-03"
  role               = "test"
  cpu_count          = 2
  memory_limit       = "4GiB"
  install_dotnet_sdk = true
}
```

cloud-initテンプレートでは、機能フラグに応じて必要なセットアップスクリプトだけを生成・実行します。

```text
全エージェント共通
  └─ install-opencode.sh

install_dotnet_sdk = true
  └─ install-dotnet10.sh
```

これにより、将来エージェントを次の4役へ分割する場合にも、同じ仕組みを利用できます。

```text
design
build
test
review
```

## 1．さくらのAI Engine側の準備

さくらのAI Engineを利用できる状態にし、アカウントトークンを発行します。

本サンプルでは、基盤モデル無償プランを使用します。

`terraform.tfvars`の作成時に、発行したアカウントトークンを設定します。

アカウントトークンは、次のファイルや設定へ保存されます。

```text
terraform.tfvars
terraform.tfstate
Incusコンテナのcloud-init設定
/home/ubuntu/.config/opencode/opencode.json
```

検証専用環境で利用し、トークンをGitへ登録しないでください。

## 2．Linux側の準備

### 2.1 リポジトリの取得

Ubuntuホストで実行します。

```bash
cd ~

git clone \
  https://github.com/mono-tec/mono-sample-linux-build-lab.git

cd \
  mono-sample-linux-build-lab/infra/incus-sakura-ai-team
```

すでに取得済みの場合は更新します。

```bash
cd ~/mono-sample-linux-build-lab

git pull

cd infra/incus-sakura-ai-team
```

## 3．terraform.tfvarsの作成

設定生成スクリプトへ実行権限を付与します。

```bash
chmod +x \
  scripts/create-terraform-tfvars.sh
```

設定生成スクリプトを実行します。

```bash
./scripts/create-terraform-tfvars.sh
```

対話形式で、次の内容を設定します。

- AIエージェント01のコンテナ名
- AIエージェント01の役割
- AIエージェント01の仮想CPU数
- AIエージェント01のメモリ上限
- AIエージェント01へ.NET 10 SDKを導入するか
- AIエージェント02のコンテナ名
- AIエージェント02の役割
- AIエージェント02の仮想CPU数
- AIエージェント02のメモリ上限
- AIエージェント02へ.NET 10 SDKを導入するか
- さくらのAI Engine Base URL
- さくらのAI Engineアカウントトークン
- 使用するモデル
- Ubuntuホスト上の共有作業領域
- コンテナ内の共有マウント先

入力内容を確認し、問題がなければ`Y`を入力します。

スクリプトは、プロジェクトルートへ次のファイルを作成します。

```text
terraform.tfvars
```

ファイルの権限は、自動的に`600`へ設定されます。

```bash
ls -l terraform.tfvars
```

次のように、実行ユーザーだけが読み書きできる状態になっていることを確認します。

```text
-rw------- ... terraform.tfvars
```

`terraform.tfvars`には、さくらのAI Engineアカウントトークンが含まれます。

次の点に注意してください。

- Gitへ登録しないこと
- 内容を不用意に画面へ表示しないこと
- 外部へ共有しないこと

`terraform.tfvars.example`は、生成される設定形式の公開例として使用します。

実際の`terraform.tfvars`作成には、`scripts/create-terraform-tfvars.sh`を使用します。

## 4．共有検証ディレクトリの準備

Ubuntuホスト上に、AIエージェント間で共有する検証ディレクトリを作成します。

検証ディレクトリの作成には、`scripts/create-experiment.sh`を使用します。

### 4.1 実行権限の付与

初回のみ、スクリプトへ実行権限を付与します。

```bash
chmod +x   scripts/create-experiment.sh
```

### 4.2 最初の検証ディレクトリの作成

検証IDを引数として指定します。

```bash
./scripts/create-experiment.sh   experiment-001
```

スクリプトは、リポジトリ内の`hello-dotnet/`を検証用テンプレートとして使用します。

次の処理を自動で実行します。

- `/home/ubuntu/ai-agent-team/experiments`の作成
- 指定した検証IDのディレクトリ作成
- `hello-dotnet/request.md`のコピー
- `hello-dotnet/prompts/`のコピー
- AIエージェント用成果物ディレクトリの作成
- ホスト側とコンテナ側のパス表示

作成後のホスト側ディレクトリは次のとおりです。

```text
/home/ubuntu/ai-agent-team/
└─ experiments/
   └─ experiment-001/
      ├─ request.md
      ├─ prompts/
      │  ├─ design.md
      │  └─ build.md
      ├─ documents/
      ├─ src/
      ├─ tests/
      ├─ reports/
      ├─ logs/
      └─ status/
```

各コンテナからは、次のパスで参照できます。

```text
/workspace/experiments/experiment-001
```

`request.md`と`prompts/`は、公開用の原本からコピーしたものです。

設計書、ソースコード、テストコード、実行結果は、コピー先の検証ディレクトリへ保存します。

### 4.3 引数を指定しなかった場合

検証IDを指定せずに実行すると、使用方法が表示されます。

```bash
./scripts/create-experiment.sh
```

表示例：

```text
Usage: ./scripts/create-experiment.sh <experiment-id>
Example: ./scripts/create-experiment.sh experiment-001
```

### 4.4 同じ検証IDを指定した場合

既存成果物を上書きしないため、同じ検証IDがすでに存在する場合はエラーで終了します。

```text
[ERROR] Experiment already exists.
[ERROR] Path: /home/ubuntu/ai-agent-team/experiments/experiment-001
```

新しい検証IDを指定して再実行してください。

```bash
./scripts/create-experiment.sh   experiment-002
```

## 5．OpenTofuの初期化と構成確認

次の順番で実行します。

```bash
tofu init
tofu fmt
tofu validate
tofu plan
```

`plan`では、主に次の内容を確認します。

- `agents`マップに定義した数のUbuntu 24.04コンテナが作成される
- 各コンテナ名が正しい
- 各エージェントの役割がcloud-initへ渡される
- CPU・メモリ上限がエージェントごとに設定される
- 全コンテナへOpenCodeが導入される
- `install_dotnet_sdk = true`のコンテナだけへ.NET 10 SDKが導入される
- Ubuntuホスト上の検証領域が各コンテナの`/workspace`へ割り当てられる

アカウントトークンは`sensitive`変数として定義していますが、OpenTofuのstateには保存されます。

`tofu plan`やログを外部へ掲載する場合は、秘密情報が含まれていないことを確認してください。

## 6．コンテナの作成

```bash
tofu apply
```

確認メッセージが表示されたら、内容を確認して`yes`を入力します。

初期設定では、1回の`tofu apply`で2つのコンテナが作成されます。

`agents`マップへ要素を追加した場合は、定義した数のコンテナが作成されます。

## 7．cloud-initの完了確認

コンテナ名が初期値の場合は、次を実行します。

```bash
incus exec ubuntu2404-sakura-agent-01 -- \
  cloud-init status --wait

incus exec ubuntu2404-sakura-agent-02 -- \
  cloud-init status --wait
```

それぞれ次の表示になれば完了です。

```text
status: done
```

コンテナ名を変更した場合は、設定した名前へ読み替えてください。

## 8．Ubuntuホストから構築結果を確認

### 8.1 コンテナ一覧

```bash
incus list
```

`agents`マップへ定義したコンテナが表示されることを確認します。

### 8.2 AIエージェント01の役割確認

```bash
incus exec ubuntu2404-sakura-agent-01 -- \
  cat /etc/ai-agent/role
```

初期設定での想定結果：

```text
design
```

### 8.3 AIエージェント02の役割確認

```bash
incus exec ubuntu2404-sakura-agent-02 -- \
  cat /etc/ai-agent/role
```

初期設定での想定結果：

```text
build
```

役割情報は共有領域ではなく、各コンテナ固有の次のファイルへ保存されます。

```text
/etc/ai-agent/role
```

### 8.4 cloud-initログ

AIエージェント01：

```bash
incus exec ubuntu2404-sakura-agent-01 -- \
  cat /var/log/cloud-init-output.log
```

AIエージェント02：

```bash
incus exec ubuntu2404-sakura-agent-02 -- \
  cat /var/log/cloud-init-output.log
```

### 8.5 OpenCodeインストールログ

AIエージェント01：

```bash
incus exec ubuntu2404-sakura-agent-01 -- \
  cat /var/log/opencode-install.log
```

AIエージェント02：

```bash
incus exec ubuntu2404-sakura-agent-02 -- \
  cat /var/log/opencode-install.log
```

### 8.6 OpenCodeのバージョン

AIエージェント01：

```bash
incus exec ubuntu2404-sakura-agent-01 -- \
  runuser -u ubuntu -- \
  env HOME=/home/ubuntu \
  /usr/local/bin/opencode --version
```

AIエージェント02：

```bash
incus exec ubuntu2404-sakura-agent-02 -- \
  runuser -u ubuntu -- \
  env HOME=/home/ubuntu \
  /usr/local/bin/opencode --version
```

### 8.7 OpenCode設定

アカウントトークンを表示しないように、設定項目だけを確認します。

AIエージェント01：

```bash
incus exec ubuntu2404-sakura-agent-01 -- \
  runuser -u ubuntu -- \
  jq \
    '{
      model: .model,
      provider_name: .provider.sakura.name,
      base_url: .provider.sakura.options.baseURL,
      api_key: "***MASKED***"
    }' \
    /home/ubuntu/.config/opencode/opencode.json
```

AIエージェント02：

```bash
incus exec ubuntu2404-sakura-agent-02 -- \
  runuser -u ubuntu -- \
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
  "model": "sakura/preview/Kimi-K2.6",
  "provider_name": "Sakura AI Engine",
  "base_url": "https://api.ai.sakura.ad.jp/v1",
  "api_key": "***MASKED***"
}
```

### 8.8 共有検証領域の確認

AIエージェント01：

```bash
incus exec ubuntu2404-sakura-agent-01 -- \
  ls -la /workspace/experiments
```

AIエージェント02：

```bash
incus exec ubuntu2404-sakura-agent-02 -- \
  ls -la /workspace/experiments
```

どちらのコンテナからも、同じ検証ディレクトリが表示されることを確認します。

```text
experiment-001
```

### 8.9 AIエージェント01の.NET確認

初期設定では、AIエージェント01へ.NET SDKを導入しません。

```bash
incus exec ubuntu2404-sakura-agent-01 -- \
  bash -lc \
  'command -v dotnet || echo "dotnet is not installed"'
```

想定結果：

```text
dotnet is not installed
```

### 8.10 AIエージェント02の.NET確認

```bash
incus exec ubuntu2404-sakura-agent-02 -- \
  dotnet --version
```

`10.x.x`が表示されれば完了です。

インストールログも確認できます。

```bash
incus exec ubuntu2404-sakura-agent-02 -- \
  cat /var/log/dotnet10-install.log
```

## 9．最初の手動検証

最初の1回は、設計担当と実装担当を手動で順番に実行します。

### 9.1 設計担当の実行

```bash
incus exec ubuntu2404-sakura-agent-01 -- \
  runuser -u ubuntu -- \
  bash -lc '
    cd /workspace/experiments/experiment-001

    opencode run \
      --model sakura/preview/Kimi-K2.6 \
      "$(cat prompts/design.md)"
  '
```

設計担当は、`request.md`を確認し、次の成果物を作成します。

```text
documents/
├─ concept-design.md
├─ basic-specification.md
├─ implementation-plan.md
└─ test-plan.md

reports/
└─ design-result.md
```

作成後、Ubuntuホスト側から成果物を確認します。

```bash
find \
  ~/ai-agent-team/experiments/experiment-001/documents \
  ~/ai-agent-team/experiments/experiment-001/reports \
  -maxdepth 2 \
  -type f \
  -print
```

### 9.2 実装担当の実行

設計成果物を確認した後、実装担当を実行します。

```bash
incus exec ubuntu2404-sakura-agent-02 -- \
  runuser -u ubuntu -- \
  bash -lc '
    cd /workspace/experiments/experiment-001

    opencode run \
      --model sakura/preview/Kimi-K2.6 \
      "$(cat prompts/build.md)"
  '
```

実装担当は、`request.md`と`documents/`配下の設計成果物を確認し、実装、ビルド、テスト、自己レビュー、結果報告を行います。

最終的に、主に次の成果物が作成されます。

```text
src/
tests/
reports/
├─ build-result.md
├─ test-result.md
└─ final-report.md

README.md
```

設計変更が必要な場合は、次のファイルも作成されます。

```text
reports/design-change-request.md
```

### 9.3 手動検証で確認する内容

最初の手動検証では、次を確認します。

- 設計担当が実装を行わず、設計成果物だけを作成すること
- 設計成果物を実装担当が参照できること
- 実装担当が`.NET 10`アプリケーションを作成できること
- `dotnet build`が成功すること
- `dotnet test`が成功すること
- 失敗や未解決事項が報告書へ記録されること
- 2つのエージェントが同じ共有検証領域を使用できること

最初の手動検証で流れを確認した後、2回目以降の実行をホスト側スクリプトで自動化します。

## 10．さくらのAI Engineへの接続確認

cloud-initでは、無料リクエストを消費しないように、APIへの問い合わせを実行していません。

コンテナ構築後に、各コンテナで手動確認します。

### 10.1 AIエージェント01

```bash
incus exec ubuntu2404-sakura-agent-01 -- \
  runuser -u ubuntu -- \
  bash -lc '
    cd /workspace/experiments/experiment-001
    opencode run \
      --model sakura/preview/Kimi-K2.6 \
      "日本語で接続成功とだけ返してください。"
  '
```

### 10.2 AIエージェント02

```bash
incus exec ubuntu2404-sakura-agent-02 -- \
  runuser -u ubuntu -- \
  bash -lc '
    cd /workspace/experiments/experiment-001
    opencode run \
      --model sakura/preview/Kimi-K2.6 \
      "日本語で接続成功とだけ返してください。"
  '
```

正常に応答が返れば、OpenCodeからさくらのAI Engineへ接続できています。

この操作では、さくらのAI EngineのAPIリクエストを使用します。

## 11．モデルの切り替え

使用モデルは`terraform.tfvars`の値で指定します。

```hcl
sakura_ai_model = "preview/Kimi-K2.6"
```

モデルを変更し、cloud-initの設定を初回起動から再確認する場合は、コンテナを破棄して再作成します。

```bash
tofu destroy
tofu apply
```

## 12．検証ディレクトリの追加

AIエージェント用コンテナは使い回し、検証ごとに新しいディレクトリを作成します。

2回目の検証では、次を実行します。

```bash
./scripts/create-experiment.sh   experiment-002
```

3回目以降も、検証IDを変更して繰り返します。

```bash
./scripts/create-experiment.sh   experiment-003
```

コンテナ側では、次のパスとして参照できます。

```text
/workspace/experiments/experiment-002
/workspace/experiments/experiment-003
```

検証ディレクトリを追加しても、コンテナの再作成は不要です。

既存の検証結果を保持したまま、別の検証を追加できます。

## 13．実行の流れ

```text
Ubuntuホスト
  ├─ terraform.tfvarsを作成
  ├─ create-experiment.shを実行
  ├─ hello-dotnetを検証領域へコピー
  ├─ 共有検証領域を作成
  ├─ tofu apply
  ├─ agentsマップに定義したコンテナを作成
  └─ 各コンテナのcloud-init完了を確認

agent01
  ├─ role: design
  ├─ OpenCodeを導入
  ├─ さくらのAI Engine接続設定を作成
  ├─ /etc/ai-agent/roleへ役割を記録
  └─ /workspaceから共有検証領域を参照

agent02
  ├─ role: build
  ├─ OpenCodeを導入
  ├─ さくらのAI Engine接続設定を作成
  ├─ .NET 10 SDKを導入
  ├─ /etc/ai-agent/roleへ役割を記録
  └─ /workspaceから共有検証領域を参照
```

検証ごとの実行フローは次のとおりです。

```text
request.mdを作成
  ↓
設計担当エージェントを実行
  ↓
documentsへ設計成果物を保存
  ↓
実装担当エージェントを実行
  ↓
src・tests・reportsへ成果物を保存
  ↓
利用量と結果を記録
  ↓
次のexperimentを作成
```

## 14．コンテナの削除

```bash
tofu destroy
```

確認メッセージが表示されたら、内容を確認して`yes`を入力します。

同じOpenTofu構成で管理されているコンテナは、まとめて削除されます。

ホスト側の検証成果物は、`experiment_root`として別管理しているため、`tofu destroy`では削除されません。

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

ローカルに保存したアカウントトークンやstateも不要であれば削除します。

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

共有検証領域には成果物が残るため、不要になった検証だけを個別に削除します。

```bash
rm -rf \
  ~/ai-agent-team/experiments/experiment-001
```

## 17．Gitへ登録するファイル

登録するもの：

```text
hello-dotnet/
├─ request.md
└─ prompts/
   ├─ design.md
   └─ build.md

scripts/
├─ create-experiment.sh
└─ create-terraform-tfvars.sh

.gitignore
.terraform.lock.hcl
cloud-init.yaml.tftpl
main.tf
outputs.tf
terraform.tfvars.example
variables.tf
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

ホスト上の検証成果物をGit管理する場合は、公開可能な情報だけが含まれていることを確認してください。

## 18．今後の検証

最初は、次の2コンテナを順番に実行します。

```text
概要要求
  ↓
設計担当エージェント
  ├─ 概念設計
  ├─ 基本設計
  ├─ 実装計画
  └─ テスト計画
  ↓
共有検証領域
  ↓
実装担当エージェント
  ├─ コード作成
  ├─ ビルド
  ├─ 単体テスト
  └─ 結果報告
```

2コンテナ間の成果物受け渡しを確認した後、Ubuntuホストへ工程制御スクリプトを追加します。

将来は、`terraform.tfvars`の`agents`マップへ要素を追加し、次の4役へ拡張します。

```text
design
build
test
review
```

OpenTofuコードを変更せず、エージェント定義の追加だけでコンテナ数を増やせる構成を目指します。
