# Incus PostgreSQL 17 Lab

OpenTofuとIncusを使用して、Ubuntu 24.04コンテナ上へPostgreSQL 17検証環境を作成します。

この構成では、次の処理を自動化します。

- Incusコンテナの作成
- LAN側macvlanインターフェースの追加
- DHCPまたは固定IPv4アドレスの設定
- PostgreSQL 17のインストール
- PostgreSQL管理ユーザー`postgres`への暫定パスワード設定
- PostgreSQLの外部接続設定
- Windows PC / DBeaverからの接続確認
- 固定IP使用時のpgTAP Lab用`config.env`生成
- 必要に応じたDBバックアップの復元
- 必要に応じたpgTAP / PLC接続試験
- 検証終了後のコンテナ削除

このREADMEは、ブログ本文では省略している実行コマンドや確認手順をまとめたものです。
実際に環境を構築する場合は、このREADMEを上から順番に実行してください。

---

## 構成

```text
Windows PC / DBeaver
        │
        │ TCP 5432
        ▼
      LAN
        │
        ▼
Ubuntuホスト
├─ OpenTofu
├─ Incus
├─ samples/pgtap-incus-lab
│    └─ config.env
└─ Ubuntu 24.04 container
     └─ PostgreSQL 17
          ├─ 管理ユーザー: postgres
          └─ 初期DB: postgres
```

IncusコンテナのLAN側NICには、他のLinux Build Labと同様に`macvlan`を使用します。

Cloud-initを利用するため、Incusイメージには次を使用します。

```text
images:ubuntu/24.04/cloud
```

---

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

### 1.2 DBeaverの準備

Windows PCから接続確認する場合は、DBeaverなどのPostgreSQLクライアントを使用します。

DBeaverそのものの導入や基本操作は、既存の記事を参照してください。

https://zenn.dev/mono_tec/articles/keyence_plc_db_dbeaver_setup

---

## 2. Linux側の準備

### 2.1 リポジトリの取得

Ubuntuホストで実行します。

```bash
cd ~

git clone https://github.com/mono-tec/mono-sample-linux-build-lab.git
cd mono-sample-linux-build-lab/infra/incus-postgresql
```

すでに取得済みの場合は更新します。

```bash
cd ~/mono-sample-linux-build-lab
git pull
cd infra/incus-postgresql
```

### 2.2 設定生成スクリプトの準備

```bash
chmod +x scripts/create-terraform-tfvars.sh
```

pgTAP Lab用スクリプトを使用する場合は、あわせて実行権限を付与します。

```bash
chmod +x ../../samples/pgtap-incus-lab/scripts/*.sh
```

---

## 3. terraform.tfvarsの作成

```bash
./scripts/create-terraform-tfvars.sh
```

対話形式で次の内容を設定します。

- UbuntuホストのLANインターフェース
- IPv4設定方式（DHCPまたは固定IP）
- 固定IPv4アドレスとプレフィックス長
- PostgreSQL管理ユーザー`postgres`の暫定パスワード

DB名や案件用DBユーザーは初期構築時には作成しません。

必要なDBは、環境作成後にDBeaverから作成するか、`pg_restore`でバックアップを復元して使用します。

### 3.1 固定IP使用時のconfig.env生成

IPv4設定方式で`static`を選択した場合は、入力した固定IPアドレスを使用して次のファイルも自動生成します。

```text
samples/pgtap-incus-lab/config.env
```

生成例：

```bash
DB_HOST=192.168.10.200
DB_PORT=5432
DB_USER=postgres
```

このファイルは`restore.sh`や`test.sh`などのサンプルスクリプトから参照します。

DHCPを選択した場合はIPアドレスが事前に確定しないため、`config.env`は自動生成しません。
必要に応じて`config.env.example`をコピーし、取得したIPアドレスを設定してください。

### 3.2 生成結果の確認

```bash
cat terraform.tfvars
```

固定IPを選択した場合は、次も確認します。

```bash
cat ../../samples/pgtap-incus-lab/config.env
```

`terraform.tfvars`には`postgres`管理ユーザーのパスワードなど、環境固有情報が含まれるためGitへ登録しません。

`config.env`も環境固有のIPアドレスを含むためGitへ登録しません。

---

## 4. OpenTofuの初期化

```bash
tofu init
tofu fmt
tofu validate
tofu plan
```

`plan`では、次の内容が意図した設定になっていることを確認します。

- Incusコンテナ名
- Cloud-init対応Ubuntu 24.04イメージ
- LAN側macvlan設定
- DHCPまたは固定IPv4設定
- PostgreSQL検証環境用のCloud-init設定

問題がなければ、コンテナを作成します。

---

## 5. コンテナの作成

```bash
tofu apply
```

確認メッセージが表示されたら、`yes`を入力します。

OpenTofuからIncusコンテナが作成され、Cloud-initによってPostgreSQL 17が導入されます。

固定IPを指定した場合、OpenTofuの出力例は次のようになります。

```text
dbeaver_connection = {
  "database" = "postgres"
  "host" = "192.168.10.200"
  "port" = 5432
  "username" = "postgres"
}
instance_name = "ubuntu2404-postgresql17-lab"
```

---

## 6. Cloud-initの完了確認

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  cloud-init status --wait
```

次の表示になれば完了です。

```text
status: done
```

ネットワーク設定を確認します。

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  ip -br address
```

`eth1`に設定されたIPv4アドレスを確認してください。

Cloud-init全体のログを確認する場合は、次を実行します。

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  cat /var/log/cloud-init-output.log
```

PostgreSQL Lab用のセットアップログも確認できます。

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  cat /var/log/postgresql-lab-setup.log
```

---

## 7. Ubuntuホストから自動構築結果を確認

### 7.1 PostgreSQLサービス

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  systemctl is-active postgresql
```

次のように表示されれば起動しています。

```text
active
```

### 7.2 PostgreSQLバージョン

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  psql --version
```

PostgreSQL 17系が表示されることを確認します。

### 7.3 PostgreSQLクラスタ

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  pg_lsclusters
```

作成されたクラスタが`online`になっていることを確認します。

### 7.4 LAN側IPv4アドレス

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  ip -4 -br address show eth1
```

Windows PCやPLCから接続するときは、ここで表示されたIPv4アドレスを使用します。

### 7.5 PostgreSQL設定

`listen_addresses`を確認します。

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  sudo -u postgres psql -tAc "SHOW listen_addresses;"
```

次のように表示されれば、外部接続を待ち受けています。

```text
*
```

`pg_hba.conf`の場所を確認します。

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  sudo -u postgres psql -tAc "SHOW hba_file;"
```

このLabでは、使い捨ての検証環境として次の設定を使用します。

```text
host    all    postgres    0.0.0.0/0    trust
```

設定を確認する場合は次を実行します。

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  grep -F "host    all    postgres    0.0.0.0/0    trust" \
  /etc/postgresql/17/main/pg_hba.conf
```

この設定では、`postgres`ユーザーによるIPv4接続をパスワード認証なしで許可します。

`postgres`ユーザー自体には暫定パスワードを設定していますが、通常のLab利用時は`trust`認証のため使用しません。
将来、認証方式を変更して接続確認する場合の互換性確保を目的として設定しています。

この設定は、検証後に`tofu destroy`で削除する使い捨てLabを前提としています。
本番環境や常設環境では使用しないでください。

---

## 8. DBeaverから接続

DBeaverには次を設定します。

| 項目 | 値 |
| --- | --- |
| Host | `eth1`に割り当てられたIPv4アドレス |
| Port | `5432` |
| Database | `postgres` |
| Username | `postgres` |
| Password | `trust`認証のため通常の接続では使用しません |

既存記事ではローカルPostgreSQLへ`localhost`で接続していますが、このLabではHostにIncusコンテナのLAN側IPv4アドレスを指定します。

初回接続では、PostgreSQL標準の`postgres`データベースへ接続します。

接続後、必要に応じてDBeaverから新しいデータベースを作成できます。
また、実案件の検証では`pg_restore`などを使用してバックアップを復元して利用します。

---

## 9. PLCから接続する場合

PLCからPostgreSQLへ接続する場合は、DBeaverと同じく`eth1`に設定されたIPv4アドレスを使用します。

確認する主な項目は次のとおりです。

```text
Host
Port
Database
User
Password
```

PLCから接続できない場合は、次の順番で確認します。

```text
1. コンテナがRUNNINGか
2. Cloud-initが完了しているか
3. PostgreSQLサービスが起動しているか
4. eth1にIPv4アドレスが設定されているか
5. listen_addressesが外部接続を許可しているか
6. pg_hba.confにLab用trust設定が入っているか
7. 接続先DB名 / ユーザー名が正しいか
8. PLCからコンテナまでネットワーク到達性があるか
```

特に`pg_hba.conf`は外部接続時に確認を忘れやすいため、接続できない場合は次の設定が入っているか確認してください。

```text
host    all    postgres    0.0.0.0/0    trust
```

---

## 10. pgTAP検証へ利用する場合

DBロジックの検証には、Repository内の次のサンプルを使用します。

```text
samples/pgtap-incus-lab
```

想定する構成は次のとおりです。

```text
samples/pgtap-incus-lab/
├─ backup/
├─ fixtures/
├─ scripts/
├─ tests/
├─ config.env
├─ config.env.example
├─ .gitignore
└─ README.md
```

`config.env`は、固定IPを選択した場合に`create-terraform-tfvars.sh`から自動生成します。

想定する流れは次のとおりです。

```text
infra/incus-postgresql
  ↓
create-terraform-tfvars.sh
  ↓
terraform.tfvars作成
  ↓
staticの場合は
samples/pgtap-incus-lab/config.env作成
  ↓
tofu apply
  ↓
PostgreSQL検証環境を作成
  ↓
samples/pgtap-incus-lab
  ↓
必要な検証DBを作成またはバックアップから復元
  ↓
テスト用設定・データを投入
  ↓
Function / Triggerを適用
  ↓
pgTAPでテスト
  ↓
必要に応じてPLC実機試験
  ↓
tofu destroy
```

### 10.1 バックアップを復元する場合

バックアップファイルは、例えば次へ配置します。

```text
samples/pgtap-incus-lab/backup/base.dump
```

デフォルトの`testdb`へ復元する場合は、リポジトリルートから次を実行します。

```bash
./samples/pgtap-incus-lab/scripts/restore.sh
```

DB名を指定する場合：

```bash
./samples/pgtap-incus-lab/scripts/restore.sh sampledb
```

バックアップファイルも指定する場合：

```bash
./samples/pgtap-incus-lab/scripts/restore.sh \
  sampledb \
  /path/to/sample.dump
```

実案件のDBバックアップはGitへ登録しないでください。

---

## 11. コンテナの削除

```bash
tofu destroy
```

確認メッセージが表示されたら、`yes`を入力します。

PostgreSQLのデータだけではなく、Incusコンテナそのものが削除されます。

`terraform.tfvars`や`samples/pgtap-incus-lab/config.env`はローカルファイルとして残るため、同じIP設定で再作成する場合はそのまま利用できます。

---

## 再作成時の手順

Cloud-initの変更内容を初回起動から確認する場合は、既存コンテナを削除して再作成します。

```bash
tofu destroy
tofu apply
```

Cloud-initは基本的にインスタンスの初回起動時に実行されます。
既存コンテナのuser-dataを変更しただけでは、設定処理が再実行されない場合があります。

`terraform.tfvars`自体を作り直す場合は、既存ファイルを削除してから設定生成スクリプトを再実行します。

```bash
rm -f terraform.tfvars
./scripts/create-terraform-tfvars.sh
```

---

## 実行の流れ

```text
Ubuntuホスト
  ├─ git pull
  ├─ create-terraform-tfvars.sh
  │    ├─ terraform.tfvars作成
  │    └─ static時はsamples/pgtap-incus-lab/config.env作成
  ├─ tofu init / validate / plan
  ├─ tofu apply
  ├─ Incusコンテナを作成
  ├─ Cloud-init完了確認
  ├─ PostgreSQL確認
  └─ eth1のIPアドレス確認

Cloud-init
  ├─ PostgreSQL 17を導入
  ├─ postgres管理ユーザーへ暫定パスワードを設定
  └─ PostgreSQL外部接続設定
       └─ host all postgres 0.0.0.0/0 trust

Windows / PLC
  ├─ LAN側IPへ接続
  ├─ postgres DBへDBeaver接続確認
  └─ 必要に応じてPLC接続確認

pgTAP / DB検証
  ├─ 必要なDBを作成またはrestore
  ├─ fixturesを投入
  ├─ Function / Triggerを適用
  └─ pgTAPでテスト

検証終了
  └─ tofu destroy
```

---

## Gitへ登録するファイル

### 登録するもの

```text
infra/incus-postgresql/
├─ .terraform.lock.hcl
├─ cloud-init.yaml.tftpl
├─ main.tf
├─ outputs.tf
├─ terraform.tfvars.example
├─ variables.tf
├─ scripts/
│  └─ create-terraform-tfvars.sh
└─ README.md

samples/pgtap-incus-lab/
├─ backup/
├─ fixtures/
├─ scripts/
├─ tests/
├─ config.env.example
├─ .gitignore
└─ README.md
```

### 登録しないもの

```text
infra/incus-postgresql/.terraform/
infra/incus-postgresql/terraform.tfvars
infra/incus-postgresql/terraform.tfstate
infra/incus-postgresql/terraform.tfstate.*

samples/pgtap-incus-lab/config.env
samples/pgtap-incus-lab/backup/*.dump
samples/pgtap-incus-lab/backup/*.backup
samples/pgtap-incus-lab/backup/*.tar
```

---

## 次のステップ

最初はDBeaverから`postgres`データベースへ接続できるところまで確認します。

その後、必要に応じて次を追加します。

- バックアップファイルのrestore / 自動restore
- 案件用Schema / Function / Triggerの適用
- pgTAPによるDBテスト
- PLCからの実機接続試験
- 案件ごとの検証環境テンプレート化
