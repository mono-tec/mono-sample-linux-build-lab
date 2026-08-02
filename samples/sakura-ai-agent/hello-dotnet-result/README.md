# HelloLinuxBuildLab

> 本ディレクトリは、OpenTofuとIncusで構築した環境上で、
> さくらのAI EngineとOpenCodeを使用し、
> 設計担当・実装担当のAIエージェントが作成した検証成果物です。
>
> 実行環境や開発依頼の詳細は、次を参照してください。
>
> - [AIエージェント実行環境](../../infra/incus-sakura-ai-team)
> - [開発依頼と役割別プロンプト](../../infra/incus-sakura-ai-team/hello-dotnet)

.NET 10 コンソールアプリケーションの最小構成サンプルです。Linux Build Lab 環境でのビルドおよび実行を想定しています。

## 要件

- .NET 10 SDK
- Linux (x64 / ARM64)

## プロジェクト構成

```text
src/HelloLinuxBuildLab/
  HelloLinuxBuildLab.csproj
  Program.cs
tests/HelloLinuxBuildLab.Tests/
  HelloLinuxBuildLab.Tests.csproj
  ProgramTests.cs
```

## ビルド

リポジトリルートから以下のコマンドを実行します。

```bash
dotnet build
```

## テスト

```bash
dotnet test
```

## 実行

```bash
dotnet run --project src/HelloLinuxBuildLab/HelloLinuxBuildLab.csproj
```

実行すると、以下の文字列が標準出力に表示されます。

```text
Hello from Linux Build Lab
```

## 制約

- 外部 NuGet パッケージは使用しません（MSTest の標準パッケージを除く）
- 要求されていない機能は追加しません


## 公開範囲

本ディレクトリには、AIエージェントが作成した設計書、ソースコード、
テストコードおよび結果報告書を収録しています。

`bin`、`obj`、実行ログ、状態管理ファイルなどの生成物は除外しています。