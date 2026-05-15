package com.qr.cloud;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;

import com.qr.common.config.JwtProperties;

@SpringBootApplication(scanBasePackages = { "com.qr.cloud", "com.qr.common.sync" })
@EnableConfigurationProperties(JwtProperties.class)
@EnableMethodSecurity
public class CloudApplication {

	public static void main(String[] args) {
		SpringApplication.run(CloudApplication.class, args);
	}

}
