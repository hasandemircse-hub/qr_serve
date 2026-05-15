-- Esnek ödeme (ürün / tutar / kalan), bahşiş, satır bazlı kapama; mali denetim günlüğü.

ALTER TABLE order_line_items ADD COLUMN settled_amount NUMERIC(12, 2) NOT NULL DEFAULT 0;

ALTER TABLE payments ADD COLUMN tip_amount NUMERIC(12, 2) NOT NULL DEFAULT 0;
ALTER TABLE payments ADD COLUMN allocation_kind VARCHAR(32) NOT NULL DEFAULT 'FIXED_AMOUNT';
ALTER TABLE payments ADD COLUMN allocation_details TEXT;

CREATE TABLE fiscal_audit_logs (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	restaurant_id UUID NOT NULL,
	order_id UUID NOT NULL,
	payment_id UUID,
	event_type VARCHAR(32) NOT NULL,
	provider_code VARCHAR(64) NOT NULL,
	correlation_id VARCHAR(64) NOT NULL,
	request_payload TEXT NOT NULL,
	response_payload TEXT,
	status VARCHAR(16) NOT NULL,
	error_message VARCHAR(2000),
	CONSTRAINT pk_fiscal_audit_logs PRIMARY KEY (id),
	CONSTRAINT fk_fiscal_audit_restaurant FOREIGN KEY (restaurant_id) REFERENCES restaurants (id),
	CONSTRAINT fk_fiscal_audit_order FOREIGN KEY (order_id) REFERENCES customer_orders (id),
	CONSTRAINT fk_fiscal_audit_payment FOREIGN KEY (payment_id) REFERENCES payments (id)
);

CREATE INDEX idx_fiscal_audit_restaurant_id ON fiscal_audit_logs (restaurant_id);
CREATE INDEX idx_fiscal_audit_order_id ON fiscal_audit_logs (order_id);
CREATE INDEX idx_fiscal_audit_payment_id ON fiscal_audit_logs (payment_id);
CREATE INDEX idx_fiscal_audit_correlation ON fiscal_audit_logs (correlation_id);
