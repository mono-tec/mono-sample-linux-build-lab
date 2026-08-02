# 基本設計書

## 1. アプリケーション名

HelloLinuxBuildLab

## 2. アプリケーション種別

Console Application

## 3. 対象フレームワーク

.NET 10 (`net10.0`)

## 4. 入力

なし（コマンドライン引数、標準入力、ファイル入力は一切受け付けない）

## 5. 処理

1. 固定文字列 `Hello from Linux Build Lab` を標準出力へ書き込む
2. 改行を付与する
3. プロセスを終了コード `0` で終了する

## 6. 出力

標準出力へ以下の文字列を表示する（末尾に改行を含む）。

```text
Hello from Linux Build Lab
```

> **留意事項**: `request.md` に記載された内容と**完全に一致**させること。余分な空白、改行、大文字小文字の違いは許容しない。

## 7. 正常時の動作

| ステップ | 動作 |
|----------|------|
| 1 | `dotnet run` または実行ファイルを起動する |
| 2 | 標準出力に `Hello from Linux Build Lab` が出力される |
| 3 | 終了コード `0` でプロセスが終了する |

## 8. 異常時の扱い

本要求に異常系は存在しない。  
実装上、想定されない例外が発生した場合は、そのまま非ゼロの終了コードでプロセスが終了するものとし、個別のエラーハンドリングは実装しない。

## 9. プロジェクト構成

```
src/
└── HelloLinuxBuildLab/
    ├── HelloLinuxBuildLab.csproj
    └── Program.cs

tests/
└── HelloLinuxBuildLab.Tests/
    ├── HelloLinuxBuildLab.Tests.csproj
    └── ProgramTests.cs
```

### 9.1 プロジェクトファイル概要

| ファイル | 種別 | 用途 |
|----------|------|------|
| `src/HelloLinuxBuildLab/HelloLinuxBuildLab.csproj` | プロジェクト | コンソールアプリケーションの定義（`OutputType=Exe`, `TargetFramework=net10.0`） |
| `src/HelloLinuxBuildLab/Program.cs` | ソース | エントリポイントおよび出力ロジック |
| `tests/HelloLinuxBuildLab.Tests/HelloLinuxBuildLab.Tests.csproj` | プロジェクト | MSTest プロジェクトの定義。参照先プロジェクトを含む |
| `tests/HelloLinuxBuildLab.Tests/ProgramTests.cs` | テスト | 標準出力の内容を検証するテストクラス |

## 10. 名前空間と主要クラス

| 名前空間 | クラス / ファイル | 役割 |
|----------|-----------------|------|
| `HelloLinuxBuildLab` | `Program` | エントリポイント。`Main` メソッド内で標準出力へ文字列を書き込む |

> top-level statements を使用しても構わないが、テスト容易性を考慮し、`Program` クラスの `Main` メソッドを直接呼び出せる構成とする。

## 11. テスト対象

- `Program.Main(string[] args)` の実行結果として、標準出力に `Hello from Linux Build Lab` が出力されること

## 12. 完了条件との対応関係

| 完了条件 | 対応内容 |
|----------|----------|
| 概念設計書が作成されている | `documents/concept-design.md` を作成 |
| 基本設計書が作成されている | 本書 (`documents/basic-specification.md`) |
| 実装計画書が作成されている | `documents/implementation-plan.md` を作成 |
| テスト計画書が作成されている | `documents/test-plan.md` を作成 |
| ソースコードが作成されている | `src/HelloLinuxBuildLab/Program.cs` および `.csproj`（実装工程で対応） |
| テストコードが作成されている | `tests/HelloLinuxBuildLab.Tests/ProgramTests.cs` および `.csproj`（実装工程で対応） |
| `dotnet build` が成功する | ビルド手順に基づき実行（実装工程で対応） |
| `dotnet test` が成功する | テスト手順に基づき実行（実装工程で対応） |
| 要求・設計・実装・テストの対応関係が説明されている | `basic-specification.md` および各設計書に記載 |
| 未解決事項が明記されている | `concept-design.md` および `reports/design-result.md` に記載 |
| 最終報告書が作成されている | `reports/final-report.md`（最終工程で対応） |