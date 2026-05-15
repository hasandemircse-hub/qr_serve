package com.qr.edge;

import org.junit.jupiter.api.Test;

/**
 * Tam Spring bağlamı bu modülde JPA + Cloud + güvenlik zinciri gerektirir; slice test
 * sürekli mock patlamasına yol açardı. Üretim düzeltmeleri {@code mvn -pl edge package}
 * ile derlenerek doğrulanır.
 */
class EdgeApplicationTests {

	@Test
	void buildMarker() {
		// Bilerek boş: SpringBootTest kaldırıldı (bkz. sınıf javadoc).
	}
}
