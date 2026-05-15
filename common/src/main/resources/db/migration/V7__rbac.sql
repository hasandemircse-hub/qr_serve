-- RBAC: abonelik durumu + kullanıcılar (multi-tenant)

ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS subscription_status VARCHAR(32) NOT NULL DEFAULT 'DEMO';

CREATE TABLE IF NOT EXISTS users (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	restaurant_id UUID,
	email VARCHAR(320) NOT NULL,
	password_hash VARCHAR(255) NOT NULL,
	role VARCHAR(32) NOT NULL,
	display_name VARCHAR(255),
	CONSTRAINT pk_users PRIMARY KEY (id),
	CONSTRAINT fk_users_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurants (id),
	CONSTRAINT uk_users_email UNIQUE (email)
);

CREATE INDEX IF NOT EXISTS idx_users_restaurant_id ON users (restaurant_id);
