-- QuickServe core schema (PostgreSQL). Shared by Cloud and Edge via Flyway on common classpath.

CREATE TABLE restaurants (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	name VARCHAR(255) NOT NULL,
	legal_name VARCHAR(255),
	tax_id VARCHAR(32),
	CONSTRAINT pk_restaurants PRIMARY KEY (id)
);

CREATE TABLE dining_tables (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	restaurant_id UUID NOT NULL,
	label VARCHAR(64) NOT NULL,
	seat_count INTEGER,
	zone VARCHAR(64),
	CONSTRAINT pk_dining_tables PRIMARY KEY (id),
	CONSTRAINT fk_dining_tables_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurants (id)
);

CREATE INDEX idx_dining_tables_restaurant_id ON dining_tables (restaurant_id);

CREATE TABLE menus (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	restaurant_id UUID NOT NULL,
	name VARCHAR(255) NOT NULL,
	description VARCHAR(2000),
	active BOOLEAN NOT NULL DEFAULT TRUE,
	CONSTRAINT pk_menus PRIMARY KEY (id),
	CONSTRAINT fk_menus_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurants (id)
);

CREATE INDEX idx_menus_restaurant_id ON menus (restaurant_id);

CREATE TABLE products (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	menu_id UUID NOT NULL,
	name VARCHAR(255) NOT NULL,
	description VARCHAR(2000),
	price NUMERIC(12, 2) NOT NULL,
	sku VARCHAR(64),
	tax_rate NUMERIC(5, 4),
	CONSTRAINT pk_products PRIMARY KEY (id),
	CONSTRAINT fk_products_menu FOREIGN KEY (menu_id) REFERENCES menus (id)
);

CREATE INDEX idx_products_menu_id ON products (menu_id);

CREATE TABLE customer_orders (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	restaurant_id UUID NOT NULL,
	table_id UUID,
	status VARCHAR(32) NOT NULL,
	order_number VARCHAR(64),
	ordered_at TIMESTAMP NOT NULL,
	notes VARCHAR(2000),
	CONSTRAINT pk_customer_orders PRIMARY KEY (id),
	CONSTRAINT fk_customer_orders_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurants (id),
	CONSTRAINT fk_customer_orders_table FOREIGN KEY (table_id) REFERENCES dining_tables (id)
);

CREATE INDEX idx_customer_orders_restaurant_id ON customer_orders (restaurant_id);
CREATE INDEX idx_customer_orders_table_id ON customer_orders (table_id);

CREATE TABLE payments (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	order_id UUID NOT NULL,
	amount NUMERIC(12, 2) NOT NULL,
	method VARCHAR(32) NOT NULL,
	paid_at TIMESTAMP NOT NULL,
	external_reference VARCHAR(255),
	CONSTRAINT pk_payments PRIMARY KEY (id),
	CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES customer_orders (id)
);

CREATE INDEX idx_payments_order_id ON payments (order_id);

CREATE TABLE sync_metadata (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	entity_type VARCHAR(64) NOT NULL,
	entity_id UUID NOT NULL,
	edge_id UUID NOT NULL,
	synced_at TIMESTAMP NOT NULL,
	CONSTRAINT pk_sync_metadata PRIMARY KEY (id),
	CONSTRAINT uk_sync_metadata_entity_edge UNIQUE (entity_type, entity_id, edge_id)
);

CREATE INDEX idx_sync_metadata_edge_id ON sync_metadata (edge_id);
CREATE INDEX idx_sync_metadata_entity ON sync_metadata (entity_type, entity_id);
