BEGIN;

SELECT plan(1);

-- 最終結果・整合性確認をここに追加します。
SELECT pass('003_result.sql: pgTAP result test scaffold is ready');

SELECT * FROM finish();
ROLLBACK;
