package com.qr.edge.admin.api;

import java.util.List;
import java.util.UUID;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;

public record ReorderIdsRequest(@NotEmpty List<@NotNull UUID> orderedIds) {
}
