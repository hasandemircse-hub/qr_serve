package com.qr.cloud.admin.bootstrap;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * `application*.yml` veya ortam değişkenleriyle ilk süperadmin oluşturma ayarları.
 * <pre>
 * quickserve.bootstrap.superadmin.enabled=true
 * quickserve.bootstrap.superadmin.email=admin@example.com
 * quickserve.bootstrap.superadmin.password=ChangeMe123!
 * quickserve.bootstrap.superadmin.display-name=Hasan
 * quickserve.bootstrap.restaurant.name=Test Restoran      # opsiyonel
 * </pre>
 *
 * Davranış: uygulama açılışında {@link SuperadminBootstrapRunner} kontrol eder.
 * DB'de hiç süperadmin yoksa ve {@code enabled=true} ise bu değerlerle oluşturur.
 * Süperadmin zaten varsa hiçbir şey yapmaz.
 */
@ConfigurationProperties(prefix = "quickserve.bootstrap")
public class SuperadminBootstrapProperties {

	private final Superadmin superadmin = new Superadmin();

	private final Restaurant restaurant = new Restaurant();

	public Superadmin getSuperadmin() {
		return superadmin;
	}

	public Restaurant getRestaurant() {
		return restaurant;
	}

	public static class Superadmin {

		private boolean enabled = false;

		private String email = "";

		private String password = "";

		private String displayName = "Süper Yönetici";

		public boolean isEnabled() {
			return enabled;
		}

		public void setEnabled(boolean enabled) {
			this.enabled = enabled;
		}

		public String getEmail() {
			return email;
		}

		public void setEmail(String email) {
			this.email = email;
		}

		public String getPassword() {
			return password;
		}

		public void setPassword(String password) {
			this.password = password;
		}

		public String getDisplayName() {
			return displayName;
		}

		public void setDisplayName(String displayName) {
			this.displayName = displayName;
		}
	}

	public static class Restaurant {

		/** Boşsa restoran oluşturulmaz (sadece süperadmin). */
		private String name = "";

		public String getName() {
			return name;
		}

		public void setName(String name) {
			this.name = name;
		}
	}
}
