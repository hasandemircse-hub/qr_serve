ALTER TABLE dining_tables ADD COLUMN layout_pos_x DOUBLE PRECISION;
ALTER TABLE dining_tables ADD COLUMN layout_pos_y DOUBLE PRECISION;
ALTER TABLE dining_tables ADD COLUMN layout_width DOUBLE PRECISION NOT NULL DEFAULT 64;
ALTER TABLE dining_tables ADD COLUMN layout_height DOUBLE PRECISION NOT NULL DEFAULT 64;
ALTER TABLE dining_tables ADD COLUMN layout_shape VARCHAR(16) NOT NULL DEFAULT 'SQUARE';
ALTER TABLE dining_tables ADD COLUMN floor_index INTEGER NOT NULL DEFAULT 0;
ALTER TABLE dining_tables ADD COLUMN layout_group_id UUID;
ALTER TABLE dining_tables ADD COLUMN availability_status VARCHAR(16) NOT NULL DEFAULT 'EMPTY';

CREATE INDEX idx_dining_tables_restaurant_floor ON dining_tables (restaurant_id, floor_index);
