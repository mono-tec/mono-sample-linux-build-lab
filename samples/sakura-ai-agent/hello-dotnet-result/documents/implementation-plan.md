# 実装計画書

## 1. 実装順序

| 順番 | 作業内容 |
|------|----------|
| 1 | `src/` ディレクトリへ .NET 10 コンソールプロジェクトを作成する |
| 2 | `Program.cs` に出力ロジックを実装する |
| 3 | `tests/` ディレクトリへ MSTest プロジェクトを作成する |
| 4 | テストプロジェクトから本体プロジェクトへのプロジェクト参照を追加する |
| 5 | `ProgramTests.cs` にテストコードを実装する（本工程では計画のみ作成） |
| 6 | `dotnet build` を実行し、ビルドエラーを解消する |
| 7 | `dotnet test` を実行し、テストをパスさせる |
| 8 | 自己レビューを実施する |
| 9 | 必要に応じて修正し、最終報告書を作成する |

## 2. 作成するプロジェクト

| プロジェクト名 | 対象フレームワーク | 種別 | 配置先 |
|----------------|--------------------|------|--------|
| HelloLinuxBuildLab | `net10.0` | Console Application | `src/HelloLinuxBuildLab/` |
| HelloLinuxBuildLab.Tests | `net10.0` | Unit Test Project (MSTest) | `tests/HelloLinuxBuildLab.Tests/` |

## 3. 作成するファイル

### 3.1 本体プロジェクト

| ファイル | 役割 |
|----------|------|
| `src/HelloLinuxBuildLab/HelloLinuxBuildLab.csproj` | コンソールアプリのプロジェクト定義。<br>`<OutputType>Exe</OutputType>`、`<TargetFramework>net10.0</TargetFramework>` を含む。<br>`Nullable` および `ImplicitUsings` は標準設定とする。 |
| `src/HelloLinuxBuildLab/Program.cs` | エントリポイント。`Console.WriteLine("Hello from Linux Build Lab");` を実行し終了する。 |

### 3.2 テストプロジェクト

| ファイル | 役割 |
|----------|------|
| `tests/HelloLinuxBuildLab.Tests/HelloLinuxBuildLab.Tests.csproj` | MSTest プロジェクトの定義。<br>標準 NuGet パッケージ（`Microsoft.NET.Test.Sdk`, `MSTest.TestAdapter`, `MSTest.TestFramework`）を参照する。<br>本体プロジェクトへのプロジェクト参照を含む。 |
| `tests/HelloLinuxBuildLab.Tests/ProgramTests.cs` | テストクラス。`Program.Main` を呼び出し、標準出力をキャプチャして期待文字列と比較する。 |

## 4. 各ファイルの役割詳細

### `src/HelloLinuxBuildLab/Program.cs`

```csharp
namespace HelloLinuxBuildLab;

public class Program
{
    public static void Main(string[] args)
    {
        Console.WriteLine("Hello from Linux Build Lab");
    }
}
```

> 実装時に上記のコード構造を満たすこと。`Console.WriteLine` に渡す文字列は `request.md` と完全に一致させる。

### `tests/HelloLinuxBuildLab.Tests/ProgramTests.cs`

テストコードの実装方針（実際のコードは実装工程で作成）：
1. `StringWriter` を利用して `Console.Out` をリダイレクトする
2. `Program.Main(Array.Empty<string>())` を呼び出す
3. `StringWriter.ToString()` の内容が `"Hello from Linux Build Lab\n"` であることを `Assert.AreEqual` で検証する
4. テスト終了後に `Console.Out` を元に戻す

## 5. ビルド手順

```bash
# リポジトリルートから実行
dotnet build src/HelloLinuxBuildLab/HelloLinuxBuildLab.csproj
dotnet build tests/HelloLinuxBuildLab.Tests/HelloLinuxBuildLab.Tests.csproj
```

または

```bash
dotnet build
```

（ソリューションファイルが作成されていればルートから一括ビルド可能。未作成の場合は各プロジェクトを個別にビルドする。）

## 6. テスト手順

```bash
# テストプロジェクトを対象に実行
dotnet test tests/HelloLinuxBuildLab.Tests/HelloLinuxBuildLab.Tests.csproj
```

または

```bash
dotnet test
```

## 7. 自己レビュー手順

| チェック項目 | 確認方法 |
|--------------|----------|
| ソースコードに `Hello from Linux Build Lab` が含まれているか | `grep` またはエディタ検索 |
| テストコードが `Program.Main` を呼び出しているか | コードレビュー |
| テストが標準出力を検証しているか | コードレビュー |
| `dotnet build` が警告なし（または許容範囲内）で成功するか | コマンド実行 |
| `dotnet test` が全件パスするか | コマンド実行 |
| 外部 NuGet パッケージが追加されていないか | `.csproj` を確認（標準 MSTest 用パッケージ以外の追加を禁止） |

## 8. 失敗時の調査方針

| 現象 | 調査・対処方法 |
|------|----------------|
| `dotnet` コマンドが見つからない | `dotnet --version` で SDK パスを確認。`.NET 10 SDK` がインストールされているか確認する |
| ビルドエラー（構文エラー等） | コンパイルエラーメッセージを読み、該当ファイルの C# 構文を修正する |
| テスト失敗（出力不一致） | `Console.WriteLine` の文字列が要求と完全に一致しているか確認する。改行コードの差異（`\n` vs `\r\n`）にも留意する |
| テスト失敗（出力キャプtrap失敗） | `StringWriter` のスコープと `Console.SetOut` の復元処理を確認する |

## 9. 完了判定方法

以下のすべてを満たしたとき、実装工程を完了とする。

- `dotnet build` がエラーおよび致命的な警告なく成功する
- `dotnet test` がすべてのテストをパスする（`Passed!` が出力される）
- `request.md` に記載された文字列が標準出力に表示されることにテストで合格している
- ソースコードに外部 NuGet パッケージが追加されていないことを確認している