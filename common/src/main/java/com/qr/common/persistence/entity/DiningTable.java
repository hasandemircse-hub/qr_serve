package com.qr.common.persistence.entity;

import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonIgnore;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "dining_tables")
public class DiningTable extends BaseEntity {

	@Column(name = "restaurant_id", nullable = false, columnDefinition = "uuid")
	private UUID restaurantId;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "restaurant_id", insertable = false, updatable = false)
	private Restaurant restaurant;

	@Column(nullable = false, length = 64)
	private String label;

	@Column(name = "seat_count")
	private Integer seatCount;

	@Column(length = 64)
	private String zone;

	@Column(name = "layout_pos_x")
	private Double layoutPosX;

	@Column(name = "layout_pos_y")
	private Double layoutPosY;

	@Column(name = "layout_width", nullable = false)
	private Double layoutWidth = 64.0;

	@Column(name = "layout_height", nullable = false)
	private Double layoutHeight = 64.0;

	@Column(name = "layout_shape", nullable = false, length = 16)
	@Enumerated(EnumType.STRING)
	private TableLayoutShape layoutShape = TableLayoutShape.SQUARE;

	@Column(name = "floor_index", nullable = false)
	private Integer floorIndex = 0;

	@Column(name = "layout_group_id", columnDefinition = "uuid")
	private UUID layoutGroupId;

	@Column(name = "availability_status", nullable = false, length = 16)
	@Enumerated(EnumType.STRING)
	private TableAvailabilityStatus availabilityStatus = TableAvailabilityStatus.EMPTY;

	@Column(name = "layout_rotation", nullable = false)
	private Double layoutRotation = 0.0;

	@Column(name = "merge_group_id", columnDefinition = "uuid")
	private UUID mergeGroupId;

	public UUID getRestaurantId() {
		return restaurantId;
	}

	public void setRestaurantId(UUID restaurantId) {
		this.restaurantId = restaurantId;
	}

	@JsonIgnore
	public Restaurant getRestaurant() {
		return restaurant;
	}

	public String getLabel() {
		return label;
	}

	public void setLabel(String label) {
		this.label = label;
	}

	public Integer getSeatCount() {
		return seatCount;
	}

	public void setSeatCount(Integer seatCount) {
		this.seatCount = seatCount;
	}

	public String getZone() {
		return zone;
	}

	public void setZone(String zone) {
		this.zone = zone;
	}

	public Double getLayoutPosX() {
		return layoutPosX;
	}

	public void setLayoutPosX(Double layoutPosX) {
		this.layoutPosX = layoutPosX;
	}

	public Double getLayoutPosY() {
		return layoutPosY;
	}

	public void setLayoutPosY(Double layoutPosY) {
		this.layoutPosY = layoutPosY;
	}

	public Double getLayoutWidth() {
		return layoutWidth;
	}

	public void setLayoutWidth(Double layoutWidth) {
		this.layoutWidth = layoutWidth;
	}

	public Double getLayoutHeight() {
		return layoutHeight;
	}

	public void setLayoutHeight(Double layoutHeight) {
		this.layoutHeight = layoutHeight;
	}

	public TableLayoutShape getLayoutShape() {
		return layoutShape;
	}

	public void setLayoutShape(TableLayoutShape layoutShape) {
		this.layoutShape = layoutShape;
	}

	public Integer getFloorIndex() {
		return floorIndex;
	}

	public void setFloorIndex(Integer floorIndex) {
		this.floorIndex = floorIndex;
	}

	public UUID getLayoutGroupId() {
		return layoutGroupId;
	}

	public void setLayoutGroupId(UUID layoutGroupId) {
		this.layoutGroupId = layoutGroupId;
	}

	public TableAvailabilityStatus getAvailabilityStatus() {
		return availabilityStatus;
	}

	public void setAvailabilityStatus(TableAvailabilityStatus availabilityStatus) {
		this.availabilityStatus = availabilityStatus;
	}

	public Double getLayoutRotation() {
		return layoutRotation;
	}

	public void setLayoutRotation(Double layoutRotation) {
		this.layoutRotation = layoutRotation != null ? layoutRotation : 0.0;
	}

	public UUID getMergeGroupId() {
		return mergeGroupId;
	}

	public void setMergeGroupId(UUID mergeGroupId) {
		this.mergeGroupId = mergeGroupId;
	}
}
