package com.qr.cloud;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;

import com.qr.cloud.config.CloudQuickserveProperties;
import com.qr.common.config.JwtProperties;

@SpringBootApplication(scanBasePackages = { "com.qr.cloud", "com.qr.common.sync", "com.qr.common.validation" })
@EnableConfigurationProperties({ JwtProperties.class, CloudQuickserveProperties.class })
@EnableMethodSecurity
public class CloudApplication {

	public static void main(String[] args) {
		SpringApplication.run(CloudApplication.class, args);
	}

}
