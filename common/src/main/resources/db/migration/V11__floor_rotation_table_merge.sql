-- Kroki: masa rotasyonu + birleşik hesap (merge_group_id)

ALTER TABLE dining_tables ADD COLUMN IF NOT EXISTS layout_rotation DOUBLE PRECISION NOT NULL DEFAULT 0;
ALTER TABLE dining_tables ADD COLUMN IF NOT EXISTS merge_group_id UUID;

CREATE INDEX IF NOT EXISTS idx_dining_tables_merge_group ON dining_tables (restaurant_id, merge_group_id);
