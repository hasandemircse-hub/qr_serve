-- Demo Ürün (44444444-…) için garson / misafir seçenek testi.

INSERT INTO product_option_groups (
	id, created_at, updated_at, version, is_deleted, product_id, name, selection_type, sort_index
) VALUES (
	'55555555-5555-5555-5555-555555555551',
	TIMESTAMP '2024-06-01 10:00:00',
	TIMESTAMP '2024-06-01 10:00:00',
	0,
	FALSE,
	'44444444-4444-4444-4444-444444444444',
	'Boyut',
	'SINGLE',
	0
);

INSERT INTO product_options (
	id, created_at, updated_at, version, is_deleted, option_group_id, label, price_adjustment, sort_index
) VALUES
	(
		'66666666-6666-6666-6666-666666666661',
		TIMESTAMP '2024-06-01 10:00:00',
		TIMESTAMP '2024-06-01 10:00:00',
		0,
		FALSE,
		'55555555-5555-5555-5555-555555555551',
		'Küçük',
		0.00,
		0
	),
	(
		'66666666-6666-6666-6666-666666666662',
		TIMESTAMP '2024-06-01 10:00:00',
		TIMESTAMP '2024-06-01 10:00:00',
		0,
		FALSE,
		'55555555-5555-5555-5555-555555555551',
		'Orta',
		5.00,
		1
	),
	(
		'66666666-6666-6666-6666-666666666663',
		TIMESTAMP '2024-06-01 10:00:00',
		TIMESTAMP '2024-06-01 10:00:00',
		0,
		FALSE,
		'55555555-5555-5555-5555-555555555551',
		'Büyük',
		10.00,
		2
	);

INSERT INTO product_option_groups (
	id, created_at, updated_at, version, is_deleted, product_id, name, selection_type, sort_index
) VALUES (
	'55555555-5555-5555-5555-555555555552',
	TIMESTAMP '2024-06-01 10:00:00',
	TIMESTAMP '2024-06-01 10:00:00',
	0,
	FALSE,
	'44444444-4444-4444-4444-444444444444',
	'Ekstralar',
	'MULTI',
	1
);

INSERT INTO product_options (
	id, created_at, updated_at, version, is_deleted, option_group_id, label, price_adjustment, sort_index
) VALUES
	(
		'66666666-6666-6666-6666-666666666671',
		TIMESTAMP '2024-06-01 10:00:00',
		TIMESTAMP '2024-06-01 10:00:00',
		0,
		FALSE,
		'55555555-5555-5555-5555-555555555552',
		'Ek peynir',
		15.00,
		0
	),
	(
		'66666666-6666-6666-6666-666666666672',
		TIMESTAMP '2024-06-01 10:00:00',
		TIMESTAMP '2024-06-01 10:00:00',
		0,
		FALSE,
		'55555555-5555-5555-5555-555555555552',
		'Acı sos',
		3.00,
		1
	);
