# Incus PostgreSQL 17 Lab

OpenTofuとIncusを使用して、Ubuntu 24.04上へ使い捨て可能なPostgreSQL 17検証環境を作成します。

最初の目的はシンプルです。

1. OpenTofuでUbuntuコンテナを作成する
2. PostgreSQL 17を自動導入する
3. LAN側からPostgreSQLへ接続できるようにする
4. WindowsのDBeaverから接続確認する
5. `tofu destroy`で環境ごと削除する

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
└─ Ubuntu 24.04 container
     └─ PostgreSQL 17
          ├─ labdb
          ├─ labuser
          └─ sample_table
```

IncusコンテナのLAN側NICには、第6章と同じく`macvlan`を使用します。

## 1. terraform.tfvarsの作成

```bash
cd infra/incus-postgresql

chmod +x scripts/create-terraform-tfvars.sh
./scripts/create-terraform-tfvars.sh
```

対話形式で次の値を設定します。

- UbuntuホストのLANインターフェース
- DHCP / 固定IPv4
- PostgreSQLへ接続を許可するLANのCIDR
- DB名
- DBユーザー名
- DBパスワード

`terraform.tfvars`にはパスワードが入るため、Gitへ登録しません。

リポジトリルートの`.gitignore`では`*.tfvars`と`*.tfstate`が除外されています。

## 2. OpenTofuの実行

```bash
tofu init
tofu fmt
tofu validate
tofu plan
tofu apply
```

確認メッセージが表示されたら`yes`を入力します。

## 3. cloud-initの完了確認

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  cloud-init status --wait
```

`status: done`になれば初期設定完了です。

## 4. PostgreSQLの確認

PostgreSQLの状態を確認します。

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  systemctl is-active postgresql
```

バージョンを確認します。

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  psql --version
```

クラスタを確認します。

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  pg_lsclusters
```

LAN側IPv4アドレスを確認します。

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  ip -4 -br address show eth1
```

セットアップログも確認できます。

```bash
incus exec ubuntu2404-postgresql17-lab -- \
  cat /var/log/postgresql-lab-setup.log
```

## 5. DBeaverから接続

DBeaverには次を設定します。

| 項目 | 値 |
| --- | --- |
| Host | `eth1`に割り当てられたIPv4アドレス |
| Port | `5432` |
| Database | `labdb` |
| Username | `labuser` |
| Password | `terraform.tfvars`で設定した値 |

DBeaverそのものの導入や基本操作は、既存の記事を参照してください。

https://zenn.dev/mono_tec/articles/keyence_plc_db_dbeaver_setup

既存記事ではローカルPostgreSQLへ`localhost`で接続していますが、
このLabではHostにIncusコンテナのLAN側IPv4アドレスを指定します。

接続後、`public.sample_table`が作成されていることを確認します。

```sql
SELECT *
FROM public.sample_table;
```

確認用データを登録する場合は次のSQLを使用できます。

```sql
INSERT INTO public.sample_table (
    column1,
    column2,
    column3
)
VALUES (
    'TEST001',
    CURRENT_TIMESTAMP,
    123.45
);
```

## 6. 外部接続の設定

PostgreSQLは次の方針で設定します。

- `listen_addresses = '*'`
- 認証方式は`scram-sha-256`
- `pg_hba.conf`では`db_client_cidr`で指定したLANだけを許可

例：

```text
host    labdb    labuser    192.168.1.0/24    scram-sha-256
```

検証用途であっても、`0.0.0.0/0`を指定して全ネットワークへ公開しないでください。

## 7. コンテナの削除

```bash
tofu destroy
```

確認メッセージが表示されたら`yes`を入力します。

再検証するときは再度、

```bash
tofu apply
```

を実行します。

## 次のステップ

最初はDBeaverから接続できるところまで確認します。

その後、必要に応じて次を追加します。

- KEYENCE PLCからPostgreSQLへ接続
- バックアップファイルの自動restore
- 案件用Schema / Function / Triggerの適用
- pgTAPによるDBテスト
- 案件ごとの検証環境テンプレート化
