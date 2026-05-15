-- Per-edge high-water mark on Cloud (acknowledged max updatedAt for push batches)
CREATE TABLE edge_sync_checkpoint (
	edge_id UUID NOT NULL,
	last_acknowledged_updated_at TIMESTAMP NOT NULL,
	CONSTRAINT pk_edge_sync_checkpoint PRIMARY KEY (edge_id)
);

-- Durable outbox on Edge (queue + resume). Table also exists on Cloud; unused there.
CREATE TABLE sync_outbox (
	id UUID NOT NULL,
	created_at TIMESTAMP NOT NULL,
	updated_at TIMESTAMP NOT NULL,
	version BIGINT NOT NULL DEFAULT 0,
	is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	batch_id UUID NOT NULL,
	edge_id UUID NOT NULL,
	status VARCHAR(32) NOT NULL,
	attempt_count INT NOT NULL DEFAULT 0,
	next_attempt_at TIMESTAMP,
	payload_json TEXT NOT NULL,
	CONSTRAINT pk_sync_outbox PRIMARY KEY (id)
);

CREATE INDEX idx_sync_outbox_status_next ON sync_outbox (status, created_at);

-- Edge singleton: cached Cloud watermark for filtering local changes
CREATE TABLE edge_local_sync_state (
	singleton_key VARCHAR(16) NOT NULL,
	edge_id UUID NOT NULL,
	cloud_watermark_at TIMESTAMP NOT NULL,
	CONSTRAINT pk_edge_local_sync_state PRIMARY KEY (singleton_key),
	CONSTRAINT ck_edge_local_singleton CHECK (singleton_key = 'DEFAULT')
);

INSERT INTO edge_local_sync_state (singleton_key, edge_id, cloud_watermark_at)
VALUES ('DEFAULT', '00000000-0000-0000-0000-000000000001', TIMESTAMP '1970-01-01 00:00:00');
