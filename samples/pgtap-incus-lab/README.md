# pgTAP Incus Lab

Incus 上の使い捨て PostgreSQL 環境で、実DBバックアップを復元して pgTAP を実行するための最小Repositoryです。

## 構成

```text
pgtap-incus-lab/
├─ backup/
│  └─ base.dump          # pg_dump -Fc で取得したDBバックアップを配置
├─ tests/
│  ├─ 001_function.sql
│  ├─ 002_trigger.sql
│  └─ 003_result.sql
├─ fixtures/
│  ├─ settings.sql       # pgTAP検証用設定値
│  └─ test-data.sql      # 最小テストデータ
└─ scripts/
   ├─ restore.sh
   └─ test.sh
```

## 前提

- PostgreSQL がインストール済み
- pgTAP Extension が利用可能
- `pg_prove` がインストール済み
- `pg_dump -Fc` 形式のバックアップを `backup/base.dump` に配置

Ubuntu / Debian 系では、PostgreSQLのバージョンに合う pgTAP パッケージを導入してください。

## 使い方

### 1. バックアップを配置

```bash
cp /path/to/base.dump backup/base.dump
```

バックアップ例:

```bash
pg_dump -Fc -d your_database -f backup/base.dump
```

### 2. DBを復元

```bash
./scripts/restore.sh
```

既定DB名は `pgtap_lab` です。

変更する場合:

```bash
PGDATABASE=pgtap_test ./scripts/restore.sh
```

### 3. pgTAPを実行

```bash
./scripts/test.sh
```

## 注意

`restore.sh` は対象DBを削除して再作成します。
Incusなどの使い捨て検証環境で使用することを前提にしています。
`postgres`、`template0`、`template1` は削除対象に指定できません。
