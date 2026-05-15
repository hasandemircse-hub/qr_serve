-- İlk kurulum sihirbazı (Edge yerel) + Cloud'da Edge discovery meta verisi.

ALTER TABLE edge_local_sync_state ADD COLUMN setup_wizard_completed BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE edge_local_sync_state ADD COLUMN setup_wizard_step VARCHAR(64);

ALTER TABLE edge_sync_checkpoint ADD COLUMN public_edge_url VARCHAR(512);
ALTER TABLE edge_sync_checkpoint ADD COLUMN last_hello_at TIMESTAMP;
ALTER TABLE edge_sync_checkpoint ADD COLUMN registered_restaurant_id UUID;
