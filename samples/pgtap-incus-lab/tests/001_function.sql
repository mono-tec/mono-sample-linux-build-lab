BEGIN;

SELECT plan(1);

-- Function単体テストをここに追加します。
-- 最初はpgTAP自体が動作することだけを確認します。
SELECT pass('001_function.sql: pgTAP function test scaffold is ready');

SELECT * FROM finish();
ROLLBACK;
