package com.qr.edge.config;

import java.time.Clock;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class EdgeTimeConfig {

	@Bean
	Clock systemUtcClock() {
		return Clock.systemUTC();
	}
}
