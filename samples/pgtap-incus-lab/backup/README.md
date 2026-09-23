# backup

ここに `pg_dump -Fc` 形式の実DBバックアップを `base.dump` という名前で配置します。

```bash
pg_dump -Fc -d your_database -f backup/base.dump
```

実DBデータを誤ってGitへ登録しないよう、`*.dump` は `.gitignore` の対象にしています。
