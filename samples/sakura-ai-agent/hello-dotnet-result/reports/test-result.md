# テスト結果報告書

## 1. 実行したテスト

| テストクラス | テストメソッド | テスト目的 |
|-------------|---------------|-----------|
| `ProgramTests` | `Main_WritesExpectedOutputToConsole` | `Program.Main` 実行時に、標準出力へ `Hello from Linux Build Lab\n` が出力されることを確認する |

## 2. テストコマンド

```bash
dotnet test --verbosity normal
```

## 3. テスト件数

- 総数：1
- 成功：1
- 失敗：0
- スキップ：0

## 4. テスト結果

```text
Test Run Successful.
Total tests: 1
     Passed: 1
 Total time: 1.1895 Seconds
```

## 5. 発生した問題と修正内容

- なし（初回実行から全件パス）

## 6. テスト計画との対応関係

| テスト計画書 | 該当箇所 | 実装での対応 |
|-------------|----------|--------------|
| `test-plan.md` | TC-001 標準出力の内容確認 | `ProgramTests.Main_WritesExpectedOutputToConsole` で実装 |
| `test-plan.md` | 実行手順 | `StringWriter` で `Console.Out` をリダイレクトし、`Program.Main` を呼び出して出力を検証 |
| `test-plan.md` | 期待結果 | `Assert.AreEqual("Hello from Linux Build Lab\n", sw.ToString())` で確認 |
| `test-plan.md` | 合否基準 | 1件すべてパスし、`Test Run Successful` を確認 |

## 7. 未実施項目と理由

- 境界値テスト：入力が存在しないため実施対象なし
- 異常系テスト：異常系の要求がないため実施対象なし
- 負荷テスト・統合テスト：最小構成のサンプルアプリのため対象外

## 8. その他留意事項

- Linux 環境では `StringWriter` の `NewLine` は `\n` となるため、期待値も `\n` で設定している
- テスト終了後は `finally` ブロックで `Console.Out` を元のストリームへ復元している
