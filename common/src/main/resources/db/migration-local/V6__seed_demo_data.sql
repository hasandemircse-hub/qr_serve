-- Bu dosya yalnızca spring profile `local` ile eklenen classpath:db/migration-local üzerinden çalışır.
-- Demo kimlikler edge application-local.yml ve QuickserveProperties ile eşleşmeli.

INSERT INTO restaurants (id, created_at, updated_at, version, is_deleted, name, legal_name, tax_id)
VALUES (
	'11111111-1111-1111-1111-111111111111',
	TIMESTAMP '2024-06-01 10:00:00',
	TIMESTAMP '2024-06-01 10:00:00',
	0,
	FALSE,
	'Demo Restoran',
	'Demo Restoran A.Ş.',
	NULL
);

INSERT INTO menus (id, created_at, updated_at, version, is_deleted, restaurant_id, name, description, active)
VALUES (
	'22222222-2222-2222-2222-222222222222',
	TIMESTAMP '2024-06-01 10:00:00',
	TIMESTAMP '2024-06-01 10:00:00',
	0,
	FALSE,
	'11111111-1111-1111-1111-111111111111',
	'Ana Menü',
	'Yerel geliştirme için örnek menü',
	TRUE
);

INSERT INTO dining_tables (id, created_at, updated_at, version, is_deleted, restaurant_id, label, seat_count, zone)
VALUES (
	'33333333-3333-3333-3333-333333333333',
	TIMESTAMP '2024-06-01 10:00:00',
	TIMESTAMP '2024-06-01 10:00:00',
	0,
	FALSE,
	'11111111-1111-1111-1111-111111111111',
	'M1',
	4,
	'Salon'
);

INSERT INTO products (id, created_at, updated_at, version, is_deleted, menu_id, name, description, price, sku, tax_rate)
VALUES (
	'44444444-4444-4444-4444-444444444444',
	TIMESTAMP '2024-06-01 10:00:00',
	TIMESTAMP '2024-06-01 10:00:00',
	0,
	FALSE,
	'22222222-2222-2222-2222-222222222222',
	'Demo Ürün',
	'Örnek sipariş satırı için',
	125.00,
	'DEMO-001',
	0.10
);

-- Cloud tarafında watermark isteği tutarlı olsun diye demo edge için başlangıç checkpoint'i.
INSERT INTO edge_sync_checkpoint (edge_id, last_acknowledged_updated_at)
VALUES ('550e8400-e29b-41d4-a716-446655440000', TIMESTAMP '1970-01-01 00:00:00');
