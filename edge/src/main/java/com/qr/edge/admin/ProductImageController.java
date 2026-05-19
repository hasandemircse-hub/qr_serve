package com.qr.edge.admin;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;

import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.Menu;
import com.qr.common.persistence.entity.Product;
import com.qr.common.persistence.repository.MenuRepository;
import com.qr.common.persistence.repository.ProductRepository;

@RestController
@RequestMapping("/api/v1/media")
public class ProductImageController {

	private final ProductRepository productRepository;

	private final MenuRepository menuRepository;

	private final ProductImageService productImageService;

	public ProductImageController(
			ProductRepository productRepository,
			MenuRepository menuRepository,
			ProductImageService productImageService) {
		this.productRepository = productRepository;
		this.menuRepository = menuRepository;
		this.productImageService = productImageService;
	}

	@GetMapping("/product-images/{restaurantId}/{productId}")
	public ResponseEntity<Resource> productImage(
			@PathVariable UUID restaurantId,
			@PathVariable UUID productId) throws IOException {
		Product product = productRepository.findById(productId)
				.filter(p -> !Boolean.TRUE.equals(p.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Product not found"));
		Menu menu = menuRepository.findById(product.getMenuId())
				.filter(m -> !Boolean.TRUE.equals(m.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Menu not found"));
		if (!menu.getRestaurantId().equals(restaurantId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Product not found");
		}
		Path path = productImageService.resolveImagePath(product);
		if (path == null || !Files.isRegularFile(path)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Image not found");
		}
		MediaType type = productImageService.resolveMediaType(path);
		return ResponseEntity.ok()
				.header(HttpHeaders.CACHE_CONTROL, "public, max-age=86400")
				.contentType(type)
				.body(new FileSystemResource(path));
	}
}
