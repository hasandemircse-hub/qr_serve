ALTER TABLE menus
	ADD COLUMN sort_index INTEGER NOT NULL DEFAULT 0;

ALTER TABLE products
	ADD COLUMN sort_index INTEGER NOT NULL DEFAULT 0;

UPDATE menus m
SET sort_index = COALESCE((
	SELECT ranked.rn
	FROM (
		SELECT id, ROW_NUMBER() OVER (PARTITION BY restaurant_id ORDER BY name ASC) - 1 AS rn
		FROM menus
		WHERE is_deleted = false
	) ranked
	WHERE ranked.id = m.id
), 0);

UPDATE products p
SET sort_index = COALESCE((
	SELECT ranked.rn
	FROM (
		SELECT id, ROW_NUMBER() OVER (PARTITION BY menu_id ORDER BY name ASC) - 1 AS rn
		FROM products
		WHERE is_deleted = false
	) ranked
	WHERE ranked.id = p.id
), 0);
