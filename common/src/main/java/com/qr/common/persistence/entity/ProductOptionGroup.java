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
@Table(name = "product_option_groups")
public class ProductOptionGroup extends BaseEntity {

	@Column(name = "product_id", nullable = false, columnDefinition = "uuid")
	private UUID productId;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "product_id", insertable = false, updatable = false)
	private Product product;

	@Column(nullable = false, length = 255)
	private String name;

	@Column(name = "selection_type", nullable = false, length = 16)
	@Enumerated(EnumType.STRING)
	private OptionSelectionType selectionType;

	@Column(name = "sort_index", nullable = false)
	private Integer sortIndex = 0;

	public UUID getProductId() {
		return productId;
	}

	public void setProductId(UUID productId) {
		this.productId = productId;
	}

	@JsonIgnore
	public Product getProduct() {
		return product;
	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public OptionSelectionType getSelectionType() {
		return selectionType;
	}

	public void setSelectionType(OptionSelectionType selectionType) {
		this.selectionType = selectionType;
	}

	public Integer getSortIndex() {
		return sortIndex;
	}

	public void setSortIndex(Integer sortIndex) {
		this.sortIndex = sortIndex;
	}
}
