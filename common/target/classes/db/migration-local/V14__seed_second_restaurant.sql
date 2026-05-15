-- İkinci demo restoran: Cloud süperadmin listesinde çok kayıt testi için.
-- Sürüm 14: ana migration ile V11 çakışmasını önlemek için (V11 = floor_rotation_table_merge).
INSERT INTO restaurants (id, created_at, updated_at, version, is_deleted, name, legal_name, tax_id, subscription_status)
VALUES (
	'22221111-1111-1111-1111-111111111111',
	TIMESTAMP '2024-06-01 11:00:00',
	TIMESTAMP '2024-06-01 11:00:00',
	0,
	FALSE,
	'İkinci Demo Restoran',
	'İkinci Demo Ltd.',
	NULL,
	'ACTIVE'
);
