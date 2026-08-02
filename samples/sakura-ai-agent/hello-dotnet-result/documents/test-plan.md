# テスト計画書

## 1. テスト目的

要求された文字列 `Hello from Linux Build Lab` が、.NET 10 コンソールアプリケーション実行時に正しく標準出力へ表示されることを検証する。

## 2. テスト対象

- `HelloLinuxBuildLab.Program.Main(string[] args)`

## 3. テスト環境

| 項目 | 内容 |
|------|------|
| OS | Linux |
| SDK | .NET 10 SDK |
| テストフレームワーク | MSTest |
| NuGet パッケージ（標準） | `Microsoft.NET.Test.Sdk`, `MSTest.TestAdapter`, `MSTest.TestFramework` |

## 4. テスト観点

- 正常系: 固定文字列が標準出力に出力されること
- 出力の末尾にシステム既定の改行が付与されること（`Console.WriteLine` の標準動作として確認）

## 5. 正常系テスト

### テストケース: TC-001 標準出力の内容確認

| 項目 | 内容 |
|------|------|
| 目的 | `Program.Main` 実行時に、要求された文字列が標準出力へ出力されることを確認する |
| 前提条件 | テスト対象プロジェクトがビルド済みであること |
| 入力 | `args = Array.Empty<string>()` |
| 実行手順 | 1. `StringWriter` で `Console.Out` をリダイレクトする<br>2. `Program.Main(Array.Empty<string>())` を呼び出す<br>3. `StringWriter` から文字列を取得する<br>4. `Console.Out` を元に戻す |
| 期待結果 | 取得した文字列が `"Hello from Linux Build Lab\n"` と一致すること |
| 合否基準 | `Assert.AreEqual("Hello from Linux Build Lab\n", actual)` が成功すること |

## 6. 境界値・異常系を実施しない理由

本アプリケーションは以下の特徴を持つため、境界値テストおよび異常系テストは実施しない。

| 観点 | 理由 |
|------|------|
| 入力がない | コマンドライン引数、標準入力、ファイル入力を一切受け付けないため、入力の境界値が存在しない |
| 処理が単純 | 固定文字列の出力のみであり、分岐、ループ、状態遷移がない |
| 外部依存がない | ファイル入出力、ネットワーク、データベースアクセスがないため、リソース枯竭や通信異常が発生しない |
| 異常系の定義がない | `request.md` および設計書にて異常系の要求が定義されていない |

## 7. 実行コマンド

```bash
dotnet test tests/HelloLinuxBuildLab.Tests/HelloLinuxBuildLab.Tests.csproj
```

または

```bash
dotnet test
```

## 8. 合格基準

- すべてのテストがパスすること（テスト実行結果に `Passed!` と表示されること）
- テスト失敗が 0 件であること
- スキップまたは実行されなかったテストがないこと

## 9. 証跡として残す内容

以下の内容を `reports/test-result.md` へ記録する。

- テスト実行日時
- 実行コマンド
- テスト実行結果のサマリ（総数 / パス / 失敗 / スキップ）
- 失敗があった場合はその詳細と対処内容

## 10. 要求とテストの対応関係

| 要求（request.md） | テスト計画での対応 |
|--------------------|--------------------|
| `Hello from Linux Build Lab` を表示すること | TC-001: 標準出力の内容を検証し、要求文字列と完全一致することを確認 |
| .NET 10 を使用すること | テストターゲットフレームワークを `net10.0` とし、テストプロジェクトでも同一フレームワークを使用 |
| MSTest を使用すること | テストフレームワークとして MSTest を採用し、`[TestClass]`, `[TestMethod]` を使用 |
| 外部 NuGet パッケージは使用しないこと | 標準 MSTest 用パッケージ以外の NuGet パッケージ追加を禁止し、`.csproj` で確認 |
| Linux でビルド・実行できること | Linux 環境上で `dotnet test` を実行する手順とする |