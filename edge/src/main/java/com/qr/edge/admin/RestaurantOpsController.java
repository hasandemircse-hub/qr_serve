package com.qr.edge.admin;

import java.util.List;
import java.util.UUID;

import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.qr.edge.admin.api.MergeTablesRequest;
import com.qr.edge.admin.api.SplitOrderRequest;
import com.qr.edge.admin.api.UnmergeTableRequest;
import com.qr.edge.guest.GuestTablePhoneQrService;
import com.qr.edge.guest.api.GuestPhoneQrLink;
import com.qr.edge.layout.FloorLayoutService;
import com.qr.edge.layout.api.CreateDiningTableRequest;
import com.qr.edge.layout.api.FloorLayoutBroadcast;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/restaurants/{restaurantId}")
public class RestaurantOpsController {

	private final TableMergeService tableMergeService;

	private final OrderSplitService orderSplitService;

	private final TableQrPdfService tableQrPdfService;

	private final FloorLayoutService floorLayoutService;

	private final GuestTablePhoneQrService guestTablePhoneQrService;

	public RestaurantOpsController(
			TableMergeService tableMergeService,
			OrderSplitService orderSplitService,
			TableQrPdfService tableQrPdfService,
			FloorLayoutService floorLayoutService,
			GuestTablePhoneQrService guestTablePhoneQrService) {
		this.tableMergeService = tableMergeService;
		this.orderSplitService = orderSplitService;
		this.tableQrPdfService = tableQrPdfService;
		this.floorLayoutService = floorLayoutService;
		this.guestTablePhoneQrService = guestTablePhoneQrService;
	}

	@PostMapping("/tables")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public FloorLayoutBroadcast createTable(
			@PathVariable UUID restaurantId,
			@Valid @RequestBody CreateDiningTableRequest body) {
		return floorLayoutService.createDiningTable(restaurantId, body);
	}

	@PostMapping("/tables/merge")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public void mergeTables(@PathVariable UUID restaurantId, @Valid @RequestBody MergeTablesRequest body) {
		tableMergeService.mergeTables(restaurantId, body.tableIds());
	}

	@PostMapping("/tables/unmerge")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public void unmerge(@PathVariable UUID restaurantId, @Valid @RequestBody UnmergeTableRequest body) {
		tableMergeService.unmergeTable(restaurantId, body.tableId());
	}

	@PostMapping("/orders/{orderId}/split")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public SplitOrderResponse split(
			@PathVariable UUID restaurantId,
			@PathVariable UUID orderId,
			@Valid @RequestBody SplitOrderRequest body) {
		List<UUID> ids = orderSplitService.splitOrder(restaurantId, orderId, body.parts());
		return new SplitOrderResponse(ids);
	}

	@GetMapping("/tables/{tableId}/guest-phone-qr")
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public GuestPhoneQrLink guestPhoneQr(@PathVariable UUID restaurantId, @PathVariable UUID tableId) {
		return guestTablePhoneQrService.buildPhoneQrLink(restaurantId, tableId);
	}

	@GetMapping(value = "/tables/{tableId}/qr-menu.pdf", produces = MediaType.APPLICATION_PDF_VALUE)
	@PreAuthorize("@edgeAuth.isRestaurantAdmin(authentication, #restaurantId)")
	public ResponseEntity<Resource> qrMenuPdf(@PathVariable UUID restaurantId, @PathVariable UUID tableId)
			throws Exception {
		byte[] bytes = tableQrPdfService.buildQrMenuPdf(restaurantId, tableId);
		ByteArrayResource res = new ByteArrayResource(bytes);
		return ResponseEntity.ok()
				.header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"masa-" + tableId + "-qr.pdf\"")
				.contentType(MediaType.APPLICATION_PDF)
				.contentLength(bytes.length)
				.body(res);
	}

	public record SplitOrderResponse(List<UUID> newOrderIds) {
	}
}
