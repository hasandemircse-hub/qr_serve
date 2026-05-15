-- Demo masa (V6) için QR menü token'ı; süresi uzun (yerel test)
INSERT INTO table_guest_tokens (id, created_at, updated_at, version, is_deleted, restaurant_id, table_id, token, expires_at)
VALUES (
	'f0f0f0f0-f0f0-f0f0-f0f0-f0f0f0f0f0f0',
	TIMESTAMP '2024-06-01 12:00:00',
	TIMESTAMP '2030-01-01 00:00:00',
	0,
	FALSE,
	'11111111-1111-1111-1111-111111111111',
	'33333333-3333-3333-3333-333333333333',
	'demo-qr-menu-token',
	TIMESTAMP '2030-12-31 23:59:59'
);
