package com.qr.edge.setup;

import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import com.qr.edge.config.QuickserveProperties;
import com.qr.edge.sync.cloud.CloudGateway;
import com.qr.edge.sync.domain.EdgeLocalSyncState;
import com.qr.edge.sync.repo.EdgeLocalSyncStateRepository;


@Service
public class EdgeSetupService {

	private final QuickserveProperties properties;

	private final CloudGateway cloudGateway;

	private final EdgeLocalSyncStateRepository edgeLocalSyncStateRepository;

	private final TransactionTemplate transactionTemplate;

	public EdgeSetupService(
			QuickserveProperties properties,
			CloudGateway cloudGateway,
			EdgeLocalSyncStateRepository edgeLocalSyncStateRepository,
			TransactionTemplate transactionTemplate) {
		this.properties = properties;
		this.cloudGateway = cloudGateway;
		this.edgeLocalSyncStateRepository = edgeLocalSyncStateRepository;
		this.transactionTemplate = transactionTemplate;
	}

	public EdgeSetupStatusResponse getStatus() {
		EdgeLocalSyncState s = edgeLocalSyncStateRepository
				.findById(EdgeLocalSyncState.SINGLETON_KEY)
				.orElseThrow();
		boolean wizardEnabled = properties.getSetup().isWizardEnabled();
		boolean needsWizard = wizardEnabled && !Boolean.TRUE.equals(s.getSetupWizardCompleted());
		boolean cloudOk = cloudGateway.ping();
		return new EdgeSetupStatusResponse(
				needsWizard,
				s.getSetupWizardStep(),
				cloudOk,
				properties.getEdgeId(),
				properties.getRestaurantId(),
				properties.getCloud().isMock(),
				properties.getMode().name());
	}

	public void saveStep(String step) {
		transactionTemplate.executeWithoutResult(status -> {
			EdgeLocalSyncState s = edgeLocalSyncStateRepository
					.findById(EdgeLocalSyncState.SINGLETON_KEY)
					.orElseThrow();
			s.setSetupWizardStep(step);
			edgeLocalSyncStateRepository.save(s);
		});
	}

	public void completeWizard() {
		transactionTemplate.executeWithoutResult(status -> {
			EdgeLocalSyncState s = edgeLocalSyncStateRepository
					.findById(EdgeLocalSyncState.SINGLETON_KEY)
					.orElseThrow();
			s.setSetupWizardCompleted(true);
			s.setSetupWizardStep("DONE");
			edgeLocalSyncStateRepository.save(s);
		});
	}
}
