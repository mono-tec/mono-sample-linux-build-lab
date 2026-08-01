# 開発依頼

## 1．概要

開発者向けの.NET 10コンソールアプリケーションを作成する。

アプリを実行すると、次の文字列を表示すること。

```text
Hello from Linux Build Lab
```

## 2．技術条件

- .NET 10
- C#
- Console Application
- Linuxでビルド・実行できること
- MSTestを使用すること
- 外部NuGetパッケージは使用しないこと

## 3．開発基準

次のリポジトリを開発基準として参照すること。

- https://github.com/mono-tec/mono-docs-engineering-handbook

次のリポジトリを成果物構成と進め方の参考例として参照すること。

- https://github.com/mono-tec/mono-docs-scheduled-app-platform

参考プロジェクトの内容や構成をそのまま複製せず、今回の小規模サンプルに必要な範囲へ縮小すること。

## 4．実施範囲

次の工程を順番に実施すること。

1. 概要要求の確認
2. 概念設計
3. 基本設計
4. 実装計画
5. テスト計画
6. 実装
7. 単体テスト
8. 自己レビュー
9. 必要な修正
10. 最終報告

## 5．成果物

次の成果物を作成すること。

```text
documents/
├─ concept-design.md
├─ basic-specification.md
├─ implementation-plan.md
└─ test-plan.md

src/
└─ ソースコード一式

tests/
└─ テストコード一式

reports/
├─ design-result.md
├─ build-result.md
├─ test-result.md
└─ final-report.md

README.md
```

## 6．制約

- workspace外を変更しないこと
- sudoを使用しないこと
- GitHubへpushしないこと
- 認証情報を読み取らないこと
- 要求されていない機能を追加しないこと
- 不明点は合理的な仮定として文書へ記録すること
- テスト失敗を隠さないこと
- ビルドまたはテストに失敗した場合は、原因を調査して修正すること
- 設計変更が必要な場合は、理由を記録すること

## 7．完了条件

- 概念設計書が作成されていること
- 基本設計書が作成されていること
- 実装計画書が作成されていること
- テスト計画書が作成されていること
- ソースコードが作成されていること
- テストコードが作成されていること
- `dotnet build`が成功すること
- `dotnet test`が成功すること
- 要求、設計、実装、テストの対応関係が説明されていること
- 未解決事項が明記されていること
- 最終報告書が作成されていること

## 8．役割分担

最初の検証では、次の2コンテナで作業する。

### agent-design

`request.md`と開発基準を参照し、次を作成する。

- `documents/concept-design.md`
- `documents/basic-specification.md`
- `documents/implementation-plan.md`
- `documents/test-plan.md`
- `reports/design-result.md`

この工程では、ソースコードの作成や実装を行わないこと。

### agent-build

`request.md`と先行工程で作成された設計成果物を参照し、次を実施する。

1. .NET 10プロジェクトを作成する
2. 基本仕様に従って実装する
3. MSTestプロジェクトを作成する
4. テスト計画に従ってテストを作成する
5. `dotnet build`を実行する
6. `dotnet test`を実行する
7. 失敗した場合は原因を調査して修正する
8. 自己レビューを実施する
9. 最終報告書を作成する

設計変更が必要な場合は、設計書を無断で変更せず、理由を`reports/design-change-request.md`へ記録すること。
