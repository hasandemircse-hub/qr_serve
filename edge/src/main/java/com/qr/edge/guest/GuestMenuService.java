package com.qr.edge.guest;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.UUID;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.GuestServiceRequest;
import com.qr.common.persistence.entity.OrderLineItem;
import com.qr.common.persistence.entity.OrderStatus;
import com.qr.common.persistence.entity.Product;
import com.qr.common.persistence.entity.RestaurantOrder;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.GuestServiceRequestRepository;
import com.qr.common.persistence.repository.MenuRepository;
import com.qr.common.persistence.repository.OrderLineItemRepository;
import com.qr.common.persistence.repository.ProductRepository;
import com.qr.common.persistence.repository.RestaurantOrderRepository;
import com.qr.common.persistence.repository.RestaurantRepository;
import com.qr.common.persistence.repository.TableGuestTokenRepository;
import com.qr.edge.guest.api.GuestCartOrderRequest;
import com.qr.edge.guest.api.GuestMenuMenuDto;
import com.qr.edge.guest.api.GuestMenuPayload;
import com.qr.edge.guest.api.GuestMenuProductDto;
import com.qr.edge.guest.api.GuestOrderStatusResponse;
import com.qr.edge.guest.api.GuestOrderStatusResponse.Line;
import com.qr.edge.guest.api.GuestOrderStatusResponse.Order;
import com.qr.edge.guest.api.GuestServiceRequestBody;
import com.qr.edge.guest.api.GuestSessionResponse;
import com.qr.edge.guest.events.GuestServiceRequestPostedEvent;
import com.qr.edge.qr.ProductOptionWizardService;
import com.qr.edge.qr.QrOrderService;
import com.qr.edge.qr.api.CreateQrOrderRequest;
import com.qr.edge.qr.api.CreateQrOrderResponse;
import com.qr.edge.qr.api.ProductOptionWizardResponse;


@Service
public class GuestMenuService {

	private final java.time.Clock clock;

	private final TableGuestTokenRepository tableGuestTokenRepository;

	private final RestaurantRepository restaurantRepository;

	private final DiningTableRepository diningTableRepository;

	private final MenuRepository menuRepository;

	private final ProductRepository productRepository;

	private final GuestServiceRequestRepository guestServiceRequestRepository;

	private final RestaurantOrderRepository restaurantOrderRepository;

	private final OrderLineItemRepository orderLineItemRepository;

	private final QrOrderService qrOrderService;

	private final ProductOptionWizardService productOptionWizardService;

	private final ApplicationEventPublisher eventPublisher;

	private static final EnumSet<OrderStatus> GUEST_ORDER_STATUS_EXCLUDED = EnumSet.of(
			OrderStatus.CLOSED,
			OrderStatus.CANCELLED,
			OrderStatus.DRAFT);

	public GuestMenuService(
			java.time.Clock clock,
			TableGuestTokenRepository tableGuestTokenRepository,
			RestaurantRepository restaurantRepository,
			DiningTableRepository diningTableRepository,
			MenuRepository menuRepository,
			ProductRepository productRepository,
			GuestServiceRequestRepository guestServiceRequestRepository,
			RestaurantOrderRepository restaurantOrderRepository,
			OrderLineItemRepository orderLineItemRepository,
			QrOrderService qrOrderService,
			ProductOptionWizardService productOptionWizardService,
			ApplicationEventPublisher eventPublisher) {
		this.clock = clock;
		this.tableGuestTokenRepository = tableGuestTokenRepository;
		this.restaurantRepository = restaurantRepository;
		this.diningTableRepository = diningTableRepository;
		this.menuRepository = menuRepository;
		this.productRepository = productRepository;
		this.guestServiceRequestRepository = guestServiceRequestRepository;
		this.restaurantOrderRepository = restaurantOrderRepository;
		this.orderLineItemRepository = orderLineItemRepository;
		this.qrOrderService = qrOrderService;
		this.productOptionWizardService = productOptionWizardService;
		this.eventPublisher = eventPublisher;
	}

	public ProductOptionWizardResponse productOptionWizard(
			UUID restaurantId,
			UUID tableId,
			String token,
			UUID productId) {
		validateToken(restaurantId, tableId, token);
		return productOptionWizardService.buildWizard(productId);
	}

	public GuestSessionResponse session(UUID restaurantId, UUID tableId, String token) {
		validateToken(restaurantId, tableId, token);
		var rest = restaurantRepository.findById(restaurantId)
				.filter(r -> !Boolean.TRUE.equals(r.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurant not found"));
		var table = diningTableRepository.findById(tableId)
				.filter(t -> !Boolean.TRUE.equals(t.getIsDeleted()))
				.filter(t -> t.getRestaurantId().equals(restaurantId))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Table not found"));
		return new GuestSessionResponse(restaurantId, tableId, rest.getName(), table.getLabel());
	}

	public GuestMenuPayload menu(UUID restaurantId, UUID tableId, String token) {
		validateToken(restaurantId, tableId, token);
		return menuForStaff(restaurantId);
	}

	/**
	 * Personel (garson / restoran yöneticisi) için menü; JWT ile doğrulanmış restoran kimliği kullanılmalıdır.
	 */
	public GuestMenuPayload menuForStaff(UUID restaurantId) {
		restaurantRepository.findById(restaurantId)
				.filter(r -> !Boolean.TRUE.equals(r.getIsDeleted()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Restaurant not found"));
		var menus = menuRepository.findByRestaurantIdAndIsDeletedFalseAndActiveTrueOrderByNameAsc(restaurantId);
		List<GuestMenuMenuDto> out = new ArrayList<>();
		for (var m : menus) {
			var products = productRepository.findByMenuIdAndIsDeletedFalseOrderByNameAsc(m.getId());
			List<GuestMenuProductDto> pd = new ArrayList<>();
			for (var p : products) {
				pd.add(new GuestMenuProductDto(p.getId(), p.getName(), p.getDescription(), p.getPrice()));
			}
			out.add(new GuestMenuMenuDto(m.getId(), m.getName(), pd));
		}
		return new GuestMenuPayload(out);
	}

	@Transactional(readOnly = true)
	public GuestOrderStatusResponse listGuestOrdersSnapshot(UUID restaurantId, UUID tableId, String token) {
		validateToken(restaurantId, tableId, token);
		List<RestaurantOrder> orders = restaurantOrderRepository
				.findByRestaurantIdAndTableIdAndGuestTokenAndIsDeletedFalseAndStatusNotInOrderByOrderedAtDesc(
						restaurantId,
						tableId,
						token.trim(),
						GUEST_ORDER_STATUS_EXCLUDED);
		List<Order> out = new ArrayList<>();
		for (RestaurantOrder o : orders) {
			List<OrderLineItem> lines = orderLineItemRepository.findByOrderIdOrderByCreatedAtAsc(o.getId());
			List<Line> ld = new ArrayList<>();
			for (OrderLineItem li : lines) {
				if (Boolean.TRUE.equals(li.getIsDeleted())) {
					continue;
				}
				String name = productRepository.findById(li.getProductId())
						.filter(p -> !Boolean.TRUE.equals(p.getIsDeleted()))
						.map(Product::getName)
						.orElse("?");
				ld.add(new Line(li.getId(), name, li.getQuantity(), li.getKitchenLineStatus()));
			}
			out.add(new Order(
					o.getId(),
					o.getOrderNumber() != null ? o.getOrderNumber() : "",
					o.getStatus(),
					o.getOrderedAt(),
					ld));
		}
		return new GuestOrderStatusResponse(out);
	}

	@Transactional
	public CreateQrOrderResponse placeOrder(UUID restaurantId, UUID tableId, String token, GuestCartOrderRequest body) {
		validateToken(restaurantId, tableId, token);
		CreateQrOrderRequest req = new CreateQrOrderRequest(restaurantId, tableId, token, body.lines());
		return qrOrderService.placeOrder(req);
	}

	@Transactional
	public void serviceRequest(UUID restaurantId, UUID tableId, String token, GuestServiceRequestBody body) {
		validateToken(restaurantId, tableId, token);
		GuestServiceRequest row = new GuestServiceRequest();
		row.setRestaurantId(restaurantId);
		row.setTableId(tableId);
		row.setGuestToken(token);
		row.setRequestType(body.type());
		row.assignIdIfAbsent();
		guestServiceRequestRepository.save(row);
		eventPublisher.publishEvent(new GuestServiceRequestPostedEvent(row.getId()));
	}

	private void validateToken(UUID restaurantId, UUID tableId, String token) {
		LocalDateTime now = LocalDateTime.now(clock);
		tableGuestTokenRepository
				.findByRestaurantIdAndTableIdAndTokenAndIsDeletedFalseAndExpiresAtAfter(restaurantId, tableId, token, now)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.FORBIDDEN, "Invalid or expired table link"));
	}
}
