CREATE TABLE table_closure_audit_logs (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	restaurant_id UUID NOT NULL,
	table_id UUID NOT NULL,
	order_id UUID NOT NULL,
	policy VARCHAR(32) NOT NULL,
	reason_code VARCHAR(48) NOT NULL,
	actor_user_id UUID,
	actor_role VARCHAR(48),
	remaining_principal NUMERIC(12, 2) NOT NULL,
	closed_at TIMESTAMP NOT NULL,
	note VARCHAR(1000),
	CONSTRAINT pk_table_closure_audit_logs PRIMARY KEY (id),
	CONSTRAINT fk_table_closure_audit_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurants (id),
	CONSTRAINT fk_table_closure_audit_table FOREIGN KEY (table_id) REFERENCES dining_tables (id),
	CONSTRAINT fk_table_closure_audit_order FOREIGN KEY (order_id) REFERENCES customer_orders (id)
);

CREATE INDEX idx_table_closure_audit_restaurant_id ON table_closure_audit_logs (restaurant_id);
CREATE INDEX idx_table_closure_audit_table_id ON table_closure_audit_logs (table_id);
CREATE INDEX idx_table_closure_audit_order_id ON table_closure_audit_logs (order_id);
CREATE INDEX idx_table_closure_audit_closed_at ON table_closure_audit_logs (closed_at);
