-- PostgreSQL-only migration.
-- order_line_items.selected_options kolonunu JSON -> JSONB'ye dönüştürür.
--
-- Neden JSONB?
--   * Binary storage (daha kompakt + hızlı okuma)
--   * GIN index'lenebilir (ileride seçenek bazlı raporlama için)
--   * Hibernate @JdbcTypeCode(SqlTypes.JSON) ile birlikte stringtype=unspecified
--     hack'ini ortadan kaldırır.
--
-- Bu dosya yalnızca PostgreSQL Flyway location'una yüklenir; H2 (local) görmez.
-- H2'de kolon JSON tipinde kalmaya devam eder ve @JdbcTypeCode(SqlTypes.JSON)
-- annotation'ı her iki tarafta da geçerlidir.

ALTER TABLE order_line_items
	ALTER COLUMN selected_options TYPE JSONB USING selected_options::JSONB;

ALTER TABLE order_line_items
	ALTER COLUMN selected_options SET DEFAULT '{}'::jsonb;
