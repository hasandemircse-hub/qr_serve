package com.qr.edge.admin;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.Menu;
import com.qr.common.persistence.entity.Product;
import com.qr.common.persistence.repository.MenuRepository;
import com.qr.common.persistence.repository.ProductRepository;
import com.qr.edge.config.QuickserveProperties;

@Service
public class ProductImageService {

	private static final Set<String> ALLOWED_CONTENT_TYPES = Set.of(
			MediaType.IMAGE_JPEG_VALUE,
			MediaType.IMAGE_PNG_VALUE,
			"image/webp");

	private final Clock clock;

	private final QuickserveProperties properties;

	private final ProductRepository productRepository;

	private final MenuRepository menuRepository;

	public ProductImageService(
			Clock clock,
			QuickserveProperties properties,
			ProductRepository productRepository,
			MenuRepository menuRepository) {
		this.clock = clock;
		this.properties = properties;
		this.productRepository = productRepository;
		this.menuRepository = menuRepository;
	}

	public String publicImageUrl(UUID restaurantId, Product product) {
		if (product.getImagePath() == null || product.getImagePath().isBlank()) {
			return null;
		}
		String base = properties.getPublicEdgeUrl().trim().replaceAll("/+$", "");
		return base + "/api/v1/media/product-images/" + restaurantId + "/" + product.getId();
	}

	public Path resolveImagePath(Product product) {
		if (product.getImagePath() == null || product.getImagePath().isBlank()) {
			return null;
		}
		return storageRoot().resolve(product.getImagePath()).normalize();
	}

	public MediaType resolveMediaType(Path file) {
		String name = file.getFileName().toString().toLowerCase(Locale.ROOT);
		if (name.endsWith(".png")) {
			return MediaType.IMAGE_PNG;
		}
		if (name.endsWith(".webp")) {
			return MediaType.parseMediaType("image/webp");
		}
		return MediaType.IMAGE_JPEG;
	}

	@Transactional
	public void uploadImage(UUID restaurantId, UUID productId, MultipartFile file) {
		Product product = requireProductInRestaurant(restaurantId, productId);
		if (file == null || file.isEmpty()) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Image file is required");
		}
		if (file.getSize() > properties.getMedia().getMaxImageBytes()) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Image file too large");
		}
		String contentType = resolveImageContentType(file);
		String ext = extensionForContentType(contentType);
		deleteStoredFile(product);
		Path target = storageRoot()
				.resolve(restaurantId.toString())
				.resolve(productId + ext)
				.normalize();
		if (!target.startsWith(storageRoot())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid image path");
		}
		try {
			Files.createDirectories(target.getParent());
			file.transferTo(target);
		} catch (IOException e) {
			throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to store image", e);
		}
		String relative = restaurantId + "/" + productId + ext;
		product.setImagePath(relative);
		product.setUpdatedAt(LocalDateTime.now(clock));
		productRepository.save(product);
	}

	@Transactional
	public void deleteImage(UUID restaurantId, UUID productId) {
		Product product = requireProductInRestaurant(restaurantId, productId);
		deleteStoredFile(product);
		product.setImagePath(null);
		product.setUpdatedAt(LocalDateTime.now(clock));
		productRepository.save(product);
	}

	private void deleteStoredFile(Product product) {
		Path existing = resolveImagePath(product);
		if (existing == null) {
			return;
		}
		try {
			Files.deleteIfExists(existing);
		} catch (IOException e) {
			throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to delete image file", e);
		}
	}

	private Path storageRoot() {
		return Path.of(properties.getMedia().getProductImagesDir()).toAbsolutePath().normalize();
	}

	private Product requireProductInRestaurant(UUID restaurantId, UUID productId) {
		Product product = productRepository.findById(productId)
				.filter(p -> !Boolean.TRUE.equals(p.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Product not found"));
		Menu menu = menuRepository.findById(product.getMenuId())
				.filter(m -> !Boolean.TRUE.equals(m.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Menu not found"));
		if (!menu.getRestaurantId().equals(restaurantId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Product does not belong to restaurant");
		}
		return product;
	}

	/**
	 * Tarayıcı / Flutter Web çoğu zaman {@code application/octet-stream} veya boş Content-Type
	 * gönderir; uzantıdan JPEG/PNG/WebP çıkarımı yapılır.
	 */
	private String resolveImageContentType(MultipartFile file) {
		String raw = file.getContentType();
		if (raw != null && !raw.isBlank()) {
			String normalized = raw.toLowerCase(Locale.ROOT).split(";")[0].trim();
			if ("image/jpg".equals(normalized)) {
				normalized = MediaType.IMAGE_JPEG_VALUE;
			}
			if (!MediaType.APPLICATION_OCTET_STREAM_VALUE.equals(normalized)
					&& ALLOWED_CONTENT_TYPES.contains(normalized)) {
				return normalized;
			}
		}
		String filename = file.getOriginalFilename();
		if (filename != null && !filename.isBlank()) {
			String lower = filename.toLowerCase(Locale.ROOT);
			if (lower.endsWith(".png")) {
				return MediaType.IMAGE_PNG_VALUE;
			}
			if (lower.endsWith(".webp")) {
				return "image/webp";
			}
			if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
				return MediaType.IMAGE_JPEG_VALUE;
			}
		}
		throw new ResponseStatusException(
				HttpStatus.BAD_REQUEST,
				"Yalnızca JPEG, PNG veya WebP yükleyebilirsiniz (.jpg, .png, .webp)");
	}

	private static String extensionForContentType(String contentType) {
		if (MediaType.IMAGE_PNG_VALUE.equalsIgnoreCase(contentType)) {
			return ".png";
		}
		if ("image/webp".equalsIgnoreCase(contentType)) {
			return ".webp";
		}
		return ".jpg";
	}
}
