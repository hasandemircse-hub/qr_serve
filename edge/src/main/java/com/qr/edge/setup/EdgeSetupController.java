package com.qr.edge.setup;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;


@RestController
@RequestMapping("/api/v1/setup")
public class EdgeSetupController {

	private final EdgeSetupService edgeSetupService;

	public EdgeSetupController(EdgeSetupService edgeSetupService) {
		this.edgeSetupService = edgeSetupService;
	}

	@GetMapping("/status")
	public EdgeSetupStatusResponse status() {
		return edgeSetupService.getStatus();
	}

	public record WizardStepRequest(String step) {
	}

	@PostMapping("/wizard/step")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void saveStep(@RequestBody WizardStepRequest body) {
		edgeSetupService.saveStep(body.step() == null ? "" : body.step());
	}

	@PostMapping("/wizard/complete")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void complete() {
		edgeSetupService.completeWizard();
	}
}
