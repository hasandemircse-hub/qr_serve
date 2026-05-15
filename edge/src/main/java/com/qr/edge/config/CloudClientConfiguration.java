package com.qr.edge.config;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

import com.qr.edge.sync.cloud.CloudGateway;
import com.qr.edge.sync.cloud.MockCloudGateway;
import com.qr.edge.sync.cloud.RestCloudGateway;

@Configuration
public class CloudClientConfiguration {

	@Bean
	@ConditionalOnProperty(name = "quickserve.cloud.mock", havingValue = "false", matchIfMissing = true)
	RestClient cloudRestClient(QuickserveProperties properties) {
		return RestClient.builder()
				.baseUrl(properties.getCloud().getBaseUrl())
				.build();
	}

	@Bean
	CloudGateway cloudGateway(QuickserveProperties properties, org.springframework.beans.factory.ObjectProvider<RestClient> restClient) {
		if (properties.getCloud().isMock()) {
			return new MockCloudGateway();
		}
		return new RestCloudGateway(restClient.getObject(), properties);
	}
}
