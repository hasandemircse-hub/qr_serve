package com.qr.edge;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;

import com.qr.common.config.JwtProperties;
import com.qr.edge.config.QuickserveProperties;

@SpringBootApplication(scanBasePackages = { "com.qr.edge", "com.qr.common.sync" })
@EnableAsync
@EnableConfigurationProperties({ QuickserveProperties.class, JwtProperties.class })
@EnableScheduling
@EnableMethodSecurity
public class EdgeApplication {

	public static void main(String[] args) {
		SpringApplication.run(EdgeApplication.class, args);
	}

}
