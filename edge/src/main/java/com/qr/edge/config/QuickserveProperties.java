package com.qr.edge.config;

import java.util.UUID;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "quickserve")
public class QuickserveProperties {

	private QuickserveMode mode = QuickserveMode.FULL_STACK;

	private UUID edgeId = UUID.fromString("00000000-0000-0000-0000-000000000001");

	/** Bu edge kurulumunun bağlı olduğu restoran (QR ve masa düzeni API filtreleri için referans). */
	private UUID restaurantId = UUID.fromString("11111111-1111-1111-1111-111111111111");

	private final Cloud cloud = new Cloud();

	private final Edge edge = new Edge();

	private final Setup setup = new Setup();

	private final Demo demo = new Demo();

	/** QR PDF ve misafir linklerinde kullanılacak Edge'in dışarıdan erişilen taban URL'i. */
	private String publicEdgeUrl = "http://127.0.0.1:8081";

	/**
	 * Misafir QR ve PDF'lerde kullanılacak Cloud taban URL (internet QR).
	 * Boşsa {@link Cloud#getBaseUrl()} kullanılır.
	 */
	private String publicCloudUrl = "";

	/**
	 * true iken {@code GET /api/v1/guest/lab/...} ile tüm masalar + test token URL üretilir (yalnızca dev).
	 */
	private boolean guestLabEnabled = false;

	public boolean isGuestLabEnabled() {
		return guestLabEnabled;
	}

	public void setGuestLabEnabled(boolean guestLabEnabled) {
		this.guestLabEnabled = guestLabEnabled;
	}

	public String getPublicEdgeUrl() {
		return publicEdgeUrl;
	}

	public void setPublicEdgeUrl(String publicEdgeUrl) {
		this.publicEdgeUrl = publicEdgeUrl;
	}

	public String getPublicCloudUrl() {
		return publicCloudUrl;
	}

	public void setPublicCloudUrl(String publicCloudUrl) {
		this.publicCloudUrl = publicCloudUrl;
	}

	/** Misafir QR / PDF için Cloud kök URL (public-cloud-url veya cloud.base-url). */
	public String resolvePublicCloudUrl() {
		if (publicCloudUrl != null && !publicCloudUrl.isBlank()) {
			return publicCloudUrl.trim().replaceAll("/+$", "");
		}
		return cloud.getBaseUrl().trim().replaceAll("/+$", "");
	}

	public QuickserveMode getMode() {
		return mode;
	}

	public void setMode(QuickserveMode mode) {
		this.mode = mode;
	}

	public UUID getEdgeId() {
		return edgeId;
	}

	public void setEdgeId(UUID edgeId) {
		this.edgeId = edgeId;
	}

	public UUID getRestaurantId() {
		return restaurantId;
	}

	public void setRestaurantId(UUID restaurantId) {
		this.restaurantId = restaurantId;
	}

	public Cloud getCloud() {
		return cloud;
	}

	public Edge getEdge() {
		return edge;
	}

	public Setup getSetup() {
		return setup;
	}

	public Demo getDemo() {
		return demo;
	}

	public static class Demo {

		/** Boşsa yerel ağ IPv4 otomatik seçilir (telefon QR testi). */
		private String lanHost = "";

		/** Doluysa misafir lab doğrudan Flutter Web QR önerir (Cloud redirect atlanabilir). */
		private int guestWebPort = 0;

		public String getLanHost() {
			return lanHost;
		}

		public void setLanHost(String lanHost) {
			this.lanHost = lanHost;
		}

		public int getGuestWebPort() {
			return guestWebPort;
		}

		public void setGuestWebPort(int guestWebPort) {
			this.guestWebPort = guestWebPort;
		}
	}

	public static class Setup {

		/** true ise ilk kurulum sihirbazı (REST + Flutter) aktif edilir. */
		private boolean wizardEnabled = false;

		public boolean isWizardEnabled() {
			return wizardEnabled;
		}

		public void setWizardEnabled(boolean wizardEnabled) {
			this.wizardEnabled = wizardEnabled;
		}
	}

	public static class Cloud {

		private String baseUrl = "http://localhost:8080";

		/** true iken Cloud REST mocklanır (ONLY_EDGE profili). */
		private boolean mock = false;

		public String getBaseUrl() {
			return baseUrl;
		}

		public void setBaseUrl(String baseUrl) {
			this.baseUrl = baseUrl;
		}

		public boolean isMock() {
			return mock;
		}

		public void setMock(boolean mock) {
			this.mock = mock;
		}
	}

	public static class Edge {

		private final Sync sync = new Sync();

		private final Discovery discovery = new Discovery();

		public Sync getSync() {
			return sync;
		}

		public Discovery getDiscovery() {
			return discovery;
		}

		public static class Discovery {

			/** Uygulama açılışında Cloud'a merhaba + bootstrap çekimi. */
			private boolean helloOnStartup = true;

			public boolean isHelloOnStartup() {
				return helloOnStartup;
			}

			public void setHelloOnStartup(boolean helloOnStartup) {
				this.helloOnStartup = helloOnStartup;
			}
		}

		public static class Sync {

			private boolean enabled = true;

			private boolean schedulerEnabled = true;

			private int batchSize = 50;

			private long pollIntervalMs = 5000L;

			public boolean isEnabled() {
				return enabled;
			}

			public void setEnabled(boolean enabled) {
				this.enabled = enabled;
			}

			public boolean isSchedulerEnabled() {
				return schedulerEnabled;
			}

			public void setSchedulerEnabled(boolean schedulerEnabled) {
				this.schedulerEnabled = schedulerEnabled;
			}

			public int getBatchSize() {
				return batchSize;
			}

			public void setBatchSize(int batchSize) {
				this.batchSize = batchSize;
			}

			public long getPollIntervalMs() {
				return pollIntervalMs;
			}

			public void setPollIntervalMs(long pollIntervalMs) {
				this.pollIntervalMs = pollIntervalMs;
			}
		}
	}
}
