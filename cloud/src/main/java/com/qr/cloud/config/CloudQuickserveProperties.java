package com.qr.cloud.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "quickserve")
public class CloudQuickserveProperties {

	/** QR ve misafir linklerinde kullanılacak Cloud taban URL (internet QR). */
	private String publicCloudUrl = "http://127.0.0.1:8080";

	private final Guest guest = new Guest();

	public String getPublicCloudUrl() {
		return publicCloudUrl;
	}

	public void setPublicCloudUrl(String publicCloudUrl) {
		this.publicCloudUrl = publicCloudUrl;
	}

	public Guest getGuest() {
		return guest;
	}

	public static class Guest {

		/**
		 * Misafir Flutter Web tabanı; dolu ise {@code GET /r/...} buraya yönlendirilir.
		 * Örnek: {@code http://127.0.0.1:57632}
		 */
		private String webBaseUrl = "";

		private int edgeProxyTimeoutSeconds = 15;

		public String getWebBaseUrl() {
			return webBaseUrl;
		}

		public void setWebBaseUrl(String webBaseUrl) {
			this.webBaseUrl = webBaseUrl;
		}

		public int getEdgeProxyTimeoutSeconds() {
			return edgeProxyTimeoutSeconds;
		}

		public void setEdgeProxyTimeoutSeconds(int edgeProxyTimeoutSeconds) {
			this.edgeProxyTimeoutSeconds = edgeProxyTimeoutSeconds;
		}
	}
}
