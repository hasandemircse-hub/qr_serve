package com.qr.cloud.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import com.qr.common.auth.JwtAuthenticationFilter;
import com.qr.common.auth.JwtService;
import com.qr.common.auth.SyncSharedSecretFilter;
import com.qr.common.config.JwtProperties;

@Configuration
@Profile("!test")
public class CloudSecurityBeans {

	@Bean
	PasswordEncoder passwordEncoder() {
		return new BCryptPasswordEncoder();
	}

	@Bean
	JwtService jwtService(JwtProperties jwtProperties) {
		return new JwtService(jwtProperties.getSecret(), jwtProperties.getExpirationHours());
	}

	@Bean
	JwtAuthenticationFilter jwtAuthenticationFilter(JwtService jwtService) {
		return new JwtAuthenticationFilter(jwtService);
	}

	// Edge ↔ Cloud sync için paylaşılan secret. Boşsa filter pasif (uyarı log'u),
	// doluysa /api/v1/sync/** path'lerinde X-QuickServe-Sync-Key header'ı zorunlu.
	@Bean
	SyncSharedSecretFilter syncSharedSecretFilter(
			@Value("${quickserve.sync.shared-secret:}") String sharedSecret) {
		return new SyncSharedSecretFilter(sharedSecret);
	}
}
