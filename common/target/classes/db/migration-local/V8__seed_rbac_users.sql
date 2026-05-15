-- Yerel demo kullanıcıları (tüm roller). Şifre düz metin: demo
-- BCrypt ($2y$10$, Spring ile uyumlu)

INSERT INTO users (id, created_at, updated_at, version, is_deleted, restaurant_id, email, password_hash, role, display_name)
VALUES (
	'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
	TIMESTAMP '2024-06-01 12:00:00',
	TIMESTAMP '2024-06-01 12:00:00',
	0,
	FALSE,
	NULL,
	'superadmin@quickserve.local',
	'$2y$10$RzqWerXwLKVnrpswXkGHhO8K1q85SizceU6FiNC0ZiQZgPcFGknDe',
	'SUPERADMIN',
	'Süper Yönetici'
);

INSERT INTO users (id, created_at, updated_at, version, is_deleted, restaurant_id, email, password_hash, role, display_name)
VALUES (
	'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
	TIMESTAMP '2024-06-01 12:00:00',
	TIMESTAMP '2024-06-01 12:00:00',
	0,
	FALSE,
	'11111111-1111-1111-1111-111111111111',
	'admin@demo.local',
	'$2y$10$RzqWerXwLKVnrpswXkGHhO8K1q85SizceU6FiNC0ZiQZgPcFGknDe',
	'RESTAURANT_ADMIN',
	'Restoran Yöneticisi'
);

INSERT INTO users (id, created_at, updated_at, version, is_deleted, restaurant_id, email, password_hash, role, display_name)
VALUES (
	'cccccccc-cccc-cccc-cccc-cccccccccccc',
	TIMESTAMP '2024-06-01 12:00:00',
	TIMESTAMP '2024-06-01 12:00:00',
	0,
	FALSE,
	'11111111-1111-1111-1111-111111111111',
	'waiter@demo.local',
	'$2y$10$RzqWerXwLKVnrpswXkGHhO8K1q85SizceU6FiNC0ZiQZgPcFGknDe',
	'WAITER',
	'Garson'
);

INSERT INTO users (id, created_at, updated_at, version, is_deleted, restaurant_id, email, password_hash, role, display_name)
VALUES (
	'dddddddd-dddd-dddd-dddd-dddddddddddd',
	TIMESTAMP '2024-06-01 12:00:00',
	TIMESTAMP '2024-06-01 12:00:00',
	0,
	FALSE,
	'11111111-1111-1111-1111-111111111111',
	'kitchen@demo.local',
	'$2y$10$RzqWerXwLKVnrpswXkGHhO8K1q85SizceU6FiNC0ZiQZgPcFGknDe',
	'KITCHEN',
	'Mutfak'
);

INSERT INTO users (id, created_at, updated_at, version, is_deleted, restaurant_id, email, password_hash, role, display_name)
VALUES (
	'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
	TIMESTAMP '2024-06-01 12:00:00',
	TIMESTAMP '2024-06-01 12:00:00',
	0,
	FALSE,
	'11111111-1111-1111-1111-111111111111',
	'cashier@demo.local',
	'$2y$10$RzqWerXwLKVnrpswXkGHhO8K1q85SizceU6FiNC0ZiQZgPcFGknDe',
	'CASHIER',
	'Kasa'
);
