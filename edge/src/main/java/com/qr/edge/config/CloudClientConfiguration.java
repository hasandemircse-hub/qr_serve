package com.qr.edge.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

import com.qr.common.auth.SyncSharedSecretFilter;
import com.qr.edge.sync.cloud.CloudGateway;
import com.qr.edge.sync.cloud.MockCloudGateway;
import com.qr.edge.sync.cloud.RestCloudGateway;

@Configuration
public class CloudClientConfiguration {

	private static final Logger log = LoggerFactory.getLogger(CloudClientConfiguration.class);

	@Bean
	@ConditionalOnProperty(name = "quickserve.cloud.mock", havingValue = "false", matchIfMissing = true)
	RestClient cloudRestClient(QuickserveProperties properties) {
		RestClient.Builder builder = RestClient.builder()
				.baseUrl(properties.getCloud().getBaseUrl());

		// Edge ↔ Cloud sync için paylaşılan secret. Cloud tarafında SyncSharedSecretFilter
		// bunu zorunlu kılar. Boşsa Cloud da geri uyumlu modda çalışır (uyarı log'u).
		String syncSecret = properties.getCloud().getSyncSharedSecret();
		if (syncSecret != null && !syncSecret.isBlank()) {
			builder.defaultHeader(SyncSharedSecretFilter.HEADER_NAME, syncSecret.trim());
			log.info("Cloud RestClient: {} header enabled (secret len={})",
					SyncSharedSecretFilter.HEADER_NAME, syncSecret.trim().length());
		} else {
			log.warn("Cloud RestClient: sync shared-secret NOT set; "
					+ "set quickserve.cloud.sync-shared-secret to harden Edge→Cloud sync");
		}
		return builder.build();
	}

	@Bean
	CloudGateway cloudGateway(QuickserveProperties properties, org.springframework.beans.factory.ObjectProvider<RestClient> restClient) {
		if (properties.getCloud().isMock()) {
			return new MockCloudGateway();
		}
		return new RestCloudGateway(restClient.getObject(), properties);
	}
}
