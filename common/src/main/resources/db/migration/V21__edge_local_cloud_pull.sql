-- Edge tarafının Cloud'dan en son ne zamana kadar değişiklik çektiğini takip eder.
-- Eski mantık: Edge sadece kendi push'unun Cloud tarafından ack'lenmesini bekliyordu.
-- Yeni mantık: Edge ayrıca her sync cycle'da Cloud'dan since=lastCloudPulledAt
-- ile incremental değişiklikleri çekiyor (Cloud → Edge fan-out).
ALTER TABLE edge_local_sync_state ADD COLUMN IF NOT EXISTS last_cloud_pulled_at TIMESTAMP;
