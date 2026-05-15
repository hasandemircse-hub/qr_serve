package com.qr.common.persistence.entity;

import com.qr.common.security.SubscriptionStatus;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;

@Entity
@Table(name = "restaurants")
public class Restaurant extends BaseEntity {

	@Column(nullable = false, length = 255)
	private String name;

	@Column(name = "legal_name", length = 255)
	private String legalName;

	@Column(name = "tax_id", length = 32)
	private String taxId;

	@Column(name = "subscription_status", nullable = false, length = 32)
	@Enumerated(EnumType.STRING)
	private SubscriptionStatus subscriptionStatus = SubscriptionStatus.DEMO;

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public String getLegalName() {
		return legalName;
	}

	public void setLegalName(String legalName) {
		this.legalName = legalName;
	}

	public String getTaxId() {
		return taxId;
	}

	public void setTaxId(String taxId) {
		this.taxId = taxId;
	}

	public SubscriptionStatus getSubscriptionStatus() {
		return subscriptionStatus;
	}

	public void setSubscriptionStatus(SubscriptionStatus subscriptionStatus) {
		this.subscriptionStatus = subscriptionStatus;
	}
}
