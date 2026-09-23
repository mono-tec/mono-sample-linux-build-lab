BEGIN;

SELECT plan(1);

-- Triggerテストをここに追加します。
-- INSERT / UPDATE / DELETE 後の結果を is(), results_eq() などで確認します。
SELECT pass('002_trigger.sql: pgTAP trigger test scaffold is ready');

SELECT * FROM finish();
ROLLBACK;
