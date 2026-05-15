-- Ürün seçenek grupları / seçenekleri ve sipariş satırları (JSONB selected_options)

CREATE TABLE product_option_groups (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	product_id UUID NOT NULL,
	name VARCHAR(255) NOT NULL,
	selection_type VARCHAR(16) NOT NULL,
	sort_index INTEGER NOT NULL DEFAULT 0,
	CONSTRAINT pk_product_option_groups PRIMARY KEY (id),
	CONSTRAINT fk_product_option_groups_product FOREIGN KEY (product_id) REFERENCES products (id)
);

CREATE INDEX idx_product_option_groups_product_id ON product_option_groups (product_id);

CREATE TABLE product_options (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	option_group_id UUID NOT NULL,
	label VARCHAR(255) NOT NULL,
	price_adjustment NUMERIC(12, 2) NOT NULL DEFAULT 0,
	sort_index INTEGER NOT NULL DEFAULT 0,
	CONSTRAINT pk_product_options PRIMARY KEY (id),
	CONSTRAINT fk_product_options_group FOREIGN KEY (option_group_id) REFERENCES product_option_groups (id)
);

CREATE INDEX idx_product_options_group_id ON product_options (option_group_id);

CREATE TABLE order_line_items (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	order_id UUID NOT NULL,
	product_id UUID NOT NULL,
	quantity INTEGER NOT NULL,
	unit_price NUMERIC(12, 2) NOT NULL,
	line_total NUMERIC(12, 2) NOT NULL,
	selected_options JSON NOT NULL DEFAULT '{}'::json,
	CONSTRAINT pk_order_line_items PRIMARY KEY (id),
	CONSTRAINT fk_order_line_items_order FOREIGN KEY (order_id) REFERENCES customer_orders (id),
	CONSTRAINT fk_order_line_items_product FOREIGN KEY (product_id) REFERENCES products (id),
	CONSTRAINT ck_order_line_items_qty_positive CHECK (quantity > 0)
);

CREATE INDEX idx_order_line_items_order_id ON order_line_items (order_id);
