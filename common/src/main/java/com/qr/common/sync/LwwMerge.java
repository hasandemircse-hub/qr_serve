package com.qr.common.sync;

import java.time.LocalDateTime;

import com.qr.common.persistence.entity.BaseEntity;

public final class LwwMerge {

	private LwwMerge() {
	}

	/**
	 * Last-write-wins: primary key is {@code updatedAt}; if equal, higher {@code version} wins.
	 */
	public static boolean incomingWins(BaseEntity incoming, BaseEntity existing) {
		LocalDateTime i = incoming.getUpdatedAt();
		LocalDateTime e = existing.getUpdatedAt();
		if (i == null || e == null) {
			return true;
		}
		int c = i.compareTo(e);
		if (c > 0) {
			return true;
		}
		if (c < 0) {
			return false;
		}
		long iv = incoming.getVersion() != null ? incoming.getVersion() : 0L;
		long ev = existing.getVersion() != null ? existing.getVersion() : 0L;
		return iv > ev;
	}

	public static LocalDateTime max(LocalDateTime a, LocalDateTime b) {
		if (a == null) {
			return b;
		}
		if (b == null) {
			return a;
		}
		return a.isBefore(b) ? b : a;
	}
}
