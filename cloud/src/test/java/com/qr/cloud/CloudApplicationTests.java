package com.qr.cloud;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest(
		properties = {
				"spring.autoconfigure.exclude="
						+ "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
						+ "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration,"
						+ "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration,"
						+ "org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration,"
						+ "org.springframework.boot.autoconfigure.security.servlet.SecurityAutoConfiguration,"
						+ "org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration",
				"spring.task.scheduling.enabled=false"
		})
@ActiveProfiles("test")
class CloudApplicationTests {

	@Test
	void contextLoads() {
	}

}
