package com.qr.edge.config;

import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

@Configuration
@ConditionalOnBean(PlatformTransactionManager.class)
public class EdgeTransactionConfig {

	@Bean
	TransactionTemplate transactionTemplate(PlatformTransactionManager platformTransactionManager) {
		return new TransactionTemplate(platformTransactionManager);
	}
}
