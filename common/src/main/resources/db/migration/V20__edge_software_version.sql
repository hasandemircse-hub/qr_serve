-- Edge'in bildirdiği yazılım sürümünü Cloud tarafında persist etmek için.
-- Hello payload'ında zaten taşınıyordu ama saklanmıyordu.
ALTER TABLE edge_sync_checkpoint ADD COLUMN IF NOT EXISTS software_version VARCHAR(64);
