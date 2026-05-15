-- No-app QR menü: masa token'ı + misafir siparişi izlenebilirliği + garson çağrısı

CREATE TABLE table_guest_tokens (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	restaurant_id UUID NOT NULL,
	table_id UUID NOT NULL,
	token VARCHAR(128) NOT NULL,
	expires_at TIMESTAMP NOT NULL,
	CONSTRAINT pk_table_guest_tokens PRIMARY KEY (id),
	CONSTRAINT fk_tgt_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurants (id),
	CONSTRAINT fk_tgt_table FOREIGN KEY (table_id) REFERENCES dining_tables (id),
	CONSTRAINT uk_tgt_token UNIQUE (token)
);

CREATE INDEX idx_tgt_restaurant_table ON table_guest_tokens (restaurant_id, table_id);

ALTER TABLE customer_orders ADD COLUMN guest_token VARCHAR(128);

CREATE INDEX idx_customer_orders_guest_token ON customer_orders (guest_token);

CREATE TABLE guest_service_requests (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	restaurant_id UUID NOT NULL,
	table_id UUID NOT NULL,
	guest_token VARCHAR(128) NOT NULL,
	request_type VARCHAR(32) NOT NULL,
	CONSTRAINT pk_guest_service_requests PRIMARY KEY (id),
	CONSTRAINT fk_gsr_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurants (id),
	CONSTRAINT fk_gsr_table FOREIGN KEY (table_id) REFERENCES dining_tables (id)
);

CREATE INDEX idx_gsr_restaurant_created ON guest_service_requests (restaurant_id, created_at);
