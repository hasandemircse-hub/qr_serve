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
@Table(name = "product_options")
public class ProductOption extends BaseEntity {

	@Column(name = "option_group_id", nullable = false, columnDefinition = "uuid")
	private UUID optionGroupId;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "option_group_id", insertable = false, updatable = false)
	private ProductOptionGroup optionGroup;

	@Column(nullable = false, length = 255)
	private String label;

	@Column(name = "price_adjustment", nullable = false, precision = 12, scale = 2)
	private BigDecimal priceAdjustment = BigDecimal.ZERO;

	@Column(name = "sort_index", nullable = false)
	private Integer sortIndex = 0;

	public UUID getOptionGroupId() {
		return optionGroupId;
	}

	public void setOptionGroupId(UUID optionGroupId) {
		this.optionGroupId = optionGroupId;
	}

	@JsonIgnore
	public ProductOptionGroup getOptionGroup() {
		return optionGroup;
	}

	public String getLabel() {
		return label;
	}

	public void setLabel(String label) {
		this.label = label;
	}

	public BigDecimal getPriceAdjustment() {
		return priceAdjustment;
	}

	public void setPriceAdjustment(BigDecimal priceAdjustment) {
		this.priceAdjustment = priceAdjustment;
	}

	public Integer getSortIndex() {
		return sortIndex;
	}

	public void setSortIndex(Integer sortIndex) {
		this.sortIndex = sortIndex;
	}
}
