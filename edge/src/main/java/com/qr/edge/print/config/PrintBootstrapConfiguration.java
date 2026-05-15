package com.qr.edge.print.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(PrintProperties.class)
public class PrintBootstrapConfiguration {
}
