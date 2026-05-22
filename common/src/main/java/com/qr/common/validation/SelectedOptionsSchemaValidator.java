package com.qr.common.validation;

import java.io.InputStream;
import java.util.Set;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.JsonNode;
import com.networknt.schema.JsonSchema;
import com.networknt.schema.JsonSchemaFactory;
import com.networknt.schema.SchemaValidatorsConfig;
import com.networknt.schema.SpecVersion.VersionFlag;
import com.networknt.schema.ValidationMessage;

/**
 * QR sipariş `selectedOptions` payload'ı için JSON Schema validator.
 *
 * <p>Şema kaynak yolu: {@code /schemas/order_selected_options.schema.json}.
 * Şema bir kere yüklenir; thread-safe; her sipariş POST'unda yapısal doğrulama yapılır.
 *
 * <p>Bu, {@link com.qr.edge.qr.QrOrderService#normalizeSelectedOptions}'taki
 * domain doğrulamasından <em>önce</em> çağrılarak şema hatalarını erken yakalar.
 * Domain doğrulaması (DB cross-check, SINGLE/MULTI count) yine çalışır.
 */
@Component
public class SelectedOptionsSchemaValidator {

	private static final Logger log = LoggerFactory.getLogger(SelectedOptionsSchemaValidator.class);

	private static final String SCHEMA_RESOURCE = "/schemas/order_selected_options.schema.json";

	private final JsonSchema schema;

	public SelectedOptionsSchemaValidator() {
		JsonSchemaFactory factory = JsonSchemaFactory.getInstance(VersionFlag.V202012);
		// JSON Schema 2020-12 default'unda `format` sadece annotation; UUID/email gibi
		// format'ları assertion'a çevirmek için bu config gerekiyor.
		SchemaValidatorsConfig config = SchemaValidatorsConfig.builder()
				.formatAssertionsEnabled(true)
				.build();
		try (InputStream is = getClass().getResourceAsStream(SCHEMA_RESOURCE)) {
			if (is == null) {
				throw new IllegalStateException(
						"JSON schema not found on classpath: " + SCHEMA_RESOURCE);
			}
			this.schema = factory.getSchema(is, config);
		} catch (Exception ex) {
			throw new IllegalStateException("Failed to load JSON schema " + SCHEMA_RESOURCE, ex);
		}
		log.info("Loaded JSON schema {} (format assertions enabled)", SCHEMA_RESOURCE);
	}

	/**
	 * JSON node'u şemaya göre doğrula.
	 *
	 * @param node validate edilecek JSON (null kabul edilmez)
	 * @return hata yoksa {@code null}; varsa human-readable mesajların birleşimi
	 */
	public String validate(JsonNode node) {
		if (node == null) {
			return "payload must not be null";
		}
		Set<ValidationMessage> errors = schema.validate(node);
		if (errors.isEmpty()) {
			return null;
		}
		return errors.stream()
				.map(ValidationMessage::getMessage)
				.collect(Collectors.joining("; "));
	}
}
