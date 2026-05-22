package com.qr.common.validation;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

class SelectedOptionsSchemaValidatorTest {

	private static SelectedOptionsSchemaValidator validator;
	private static ObjectMapper mapper;

	@BeforeAll
	static void setUp() {
		validator = new SelectedOptionsSchemaValidator();
		mapper = new ObjectMapper();
	}

	@Test
	void valid_emptySteps_isAccepted() throws Exception {
		JsonNode node = mapper.readTree("""
				{ "schemaVersion": 1, "steps": [] }
				""");
		assertThat(validator.validate(node)).isNull();
	}

	@Test
	void valid_singleAndMultiSteps_areAccepted() throws Exception {
		JsonNode node = mapper.readTree("""
				{
				  "schemaVersion": 1,
				  "steps": [
				    {
				      "groupId": "11111111-1111-1111-1111-111111111111",
				      "selectionType": "SINGLE",
				      "selectedOptionIds": ["22222222-2222-2222-2222-222222222222"]
				    },
				    {
				      "groupId": "33333333-3333-3333-3333-333333333333",
				      "selectionType": "MULTI",
				      "selectedOptionIds": []
				    }
				  ],
				  "optionsTotalAdjustment": 2.5
				}
				""");
		assertThat(validator.validate(node)).isNull();
	}

	@Test
	void invalid_missingSchemaVersion_isRejected() throws Exception {
		JsonNode node = mapper.readTree("""
				{ "steps": [] }
				""");
		assertThat(validator.validate(node)).contains("schemaVersion");
	}

	@Test
	void invalid_wrongSchemaVersion_isRejected() throws Exception {
		JsonNode node = mapper.readTree("""
				{ "schemaVersion": 2, "steps": [] }
				""");
		assertThat(validator.validate(node)).isNotNull();
	}

	@Test
	void invalid_unknownTopLevelProperty_isRejected() throws Exception {
		JsonNode node = mapper.readTree("""
				{ "schemaVersion": 1, "steps": [], "extra": "boom" }
				""");
		assertThat(validator.validate(node)).contains("extra");
	}

	@Test
	void invalid_nonUuidGroupId_isRejected() throws Exception {
		JsonNode node = mapper.readTree("""
				{
				  "schemaVersion": 1,
				  "steps": [
				    { "groupId": "not-a-uuid", "selectionType": "SINGLE", "selectedOptionIds": [] }
				  ]
				}
				""");
		assertThat(validator.validate(node)).isNotNull();
	}

	@Test
	void invalid_unknownSelectionType_isRejected() throws Exception {
		JsonNode node = mapper.readTree("""
				{
				  "schemaVersion": 1,
				  "steps": [
				    {
				      "groupId": "11111111-1111-1111-1111-111111111111",
				      "selectionType": "WEIRD",
				      "selectedOptionIds": []
				    }
				  ]
				}
				""");
		assertThat(validator.validate(node)).isNotNull();
	}

	@Test
	void invalid_missingSelectedOptionIds_isRejected() throws Exception {
		JsonNode node = mapper.readTree("""
				{
				  "schemaVersion": 1,
				  "steps": [
				    { "groupId": "11111111-1111-1111-1111-111111111111", "selectionType": "SINGLE" }
				  ]
				}
				""");
		assertThat(validator.validate(node)).contains("selectedOptionIds");
	}

	@Test
	void invalid_nullPayload_isRejected() {
		assertThat(validator.validate(null)).contains("null");
	}
}
