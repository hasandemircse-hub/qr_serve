package com.qr.common.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "quickserve.jwt")
public class JwtProperties {

	/**
	 * HS256 için en az 32 UTF-8 bayt.
	 */
	private String secret = "local-dev-only-change-in-production-min-32-bytes!!";

	private long expirationHours = 24L;

	public String getSecret() {
		return secret;
	}

	public void setSecret(String secret) {
		this.secret = secret;
	}

	public long getExpirationHours() {
		return expirationHours;
	}

	public void setExpirationHours(long expirationHours) {
		this.expirationHours = expirationHours;
	}
}
