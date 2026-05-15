package com.qr.edge.qr;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.Product;
import com.qr.common.persistence.entity.ProductOption;
import com.qr.common.persistence.entity.ProductOptionGroup;
import com.qr.common.persistence.repository.ProductOptionGroupRepository;
import com.qr.common.persistence.repository.ProductOptionRepository;
import com.qr.common.persistence.repository.ProductRepository;
import com.qr.edge.qr.api.ProductOptionWizardResponse;
import com.qr.edge.qr.api.ProductOptionWizardResponse.OptionGroupPayload;
import com.qr.edge.qr.api.ProductOptionWizardResponse.OptionItemPayload;

@Service
public class ProductOptionWizardService {

	private final ProductRepository productRepository;

	private final ProductOptionGroupRepository productOptionGroupRepository;

	private final ProductOptionRepository productOptionRepository;

	public ProductOptionWizardService(
			ProductRepository productRepository,
			ProductOptionGroupRepository productOptionGroupRepository,
			ProductOptionRepository productOptionRepository) {
		this.productRepository = productRepository;
		this.productOptionGroupRepository = productOptionGroupRepository;
		this.productOptionRepository = productOptionRepository;
	}

	public ProductOptionWizardResponse buildWizard(UUID productId) {
		Product product = productRepository.findById(productId)
				.filter(p -> !Boolean.TRUE.equals(p.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Product not found"));
		List<ProductOptionGroup> groups = productOptionGroupRepository
				.findByProductIdAndIsDeletedFalseOrderBySortIndexAsc(product.getId());
		List<OptionGroupPayload> payloads = new ArrayList<>();
		for (ProductOptionGroup g : groups) {
			List<ProductOption> opts = productOptionRepository.findByOptionGroupIdAndIsDeletedFalseOrderBySortIndexAsc(g.getId());
			List<OptionItemPayload> items = opts.stream()
					.map(o -> new OptionItemPayload(
							o.getId(),
							o.getLabel(),
							o.getPriceAdjustment() != null ? o.getPriceAdjustment() : java.math.BigDecimal.ZERO,
							o.getSortIndex() != null ? o.getSortIndex() : 0))
					.toList();
			payloads.add(new OptionGroupPayload(
					g.getId(),
					g.getName(),
					g.getSelectionType().name(),
					g.getSortIndex() != null ? g.getSortIndex() : 0,
					items));
		}
		return new ProductOptionWizardResponse(productId, payloads);
	}
}
