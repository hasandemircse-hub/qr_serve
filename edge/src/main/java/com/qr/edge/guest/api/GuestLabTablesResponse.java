package com.qr.edge.guest.api;

import java.util.List;

public record GuestLabTablesResponse(
		List<GuestLabTableRow> tables,
		String lanHost,
		String phoneScanBaseUrl,
		String suggestedGuestWebBaseUrl,
		String setupHint) {
}
