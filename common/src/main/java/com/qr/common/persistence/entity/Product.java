package com.qr.common.persistence.entity;

import java.math.BigDecimal;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonIgnore;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "products")
public class Product extends BaseEntity {

	@Column(name = "menu_id", nullable = false, columnDefinition = "uuid")
	private UUID menuId;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "menu_id", insertable = false, updatable = false)
	private Menu menu;

	@Column(nullable = false, length = 255)
	private String name;

	@Column(length = 2000)
	private String description;

	@Column(nullable = false, precision = 12, scale = 2)
	private BigDecimal price;

	@Column(length = 64)
	private String sku;

	@Column(name = "tax_rate", precision = 5, scale = 4)
	private BigDecimal taxRate;

	@Column(name = "sort_index", nullable = false)
	private Integer sortIndex = 0;

	@Column(name = "image_path", length = 512)
	private String imagePath;

	public UUID getMenuId() {
		return menuId;
	}

	public void setMenuId(UUID menuId) {
		this.menuId = menuId;
	}

	@JsonIgnore
	public Menu getMenu() {
		return menu;
	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public String getDescription() {
		return description;
	}

	public void setDescription(String description) {
		this.description = description;
	}

	public BigDecimal getPrice() {
		return price;
	}

	public void setPrice(BigDecimal price) {
		this.price = price;
	}

	public String getSku() {
		return sku;
	}

	public void setSku(String sku) {
		this.sku = sku;
	}

	public BigDecimal getTaxRate() {
		return taxRate;
	}

	public void setTaxRate(BigDecimal taxRate) {
		this.taxRate = taxRate;
	}

	public Integer getSortIndex() {
		return sortIndex;
	}

	public void setSortIndex(Integer sortIndex) {
		this.sortIndex = sortIndex;
	}

	public String getImagePath() {
		return imagePath;
	}

	public void setImagePath(String imagePath) {
		this.imagePath = imagePath;
	}
}
