\set ON_ERROR_STOP on

-- pgTAPで使用する最小テストデータをここに記述します。
-- 実案件では、対象Function / Triggerを動作させるために必要なデータだけ投入してください。
--
-- 例:
-- INSERT INTO public.target_table(id, value)
-- VALUES (1, 'TEST');

SELECT 'fixtures/test-data.sql loaded' AS fixture_status;
