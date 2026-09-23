\set ON_ERROR_STOP on

-- pgTAP検証用の設定値をここに記述します。
-- 実案件では、マスタや設定テーブルに対する INSERT / UPDATE を追加してください。
--
-- 例:
-- INSERT INTO public.m_settings(setting_key, setting_value)
-- VALUES ('TEST_MODE', '1')
-- ON CONFLICT (setting_key)
-- DO UPDATE SET setting_value = EXCLUDED.setting_value;

SELECT 'fixtures/settings.sql loaded' AS fixture_status;
