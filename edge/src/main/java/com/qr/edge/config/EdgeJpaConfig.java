package com.qr.edge.config;

import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

@Configuration
@Profile("!test")
@EntityScan(basePackages = { "com.qr.common.persistence.entity", "com.qr.edge.sync.domain" })
@EnableJpaRepositories(basePackages = { "com.qr.common.persistence.repository", "com.qr.edge.sync.repo" })
public class EdgeJpaConfig {
}
