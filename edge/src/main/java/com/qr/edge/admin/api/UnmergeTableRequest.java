package com.qr.edge.admin.api;

import java.util.UUID;

import jakarta.validation.constraints.NotNull;

public record UnmergeTableRequest(@NotNull UUID tableId) {
}
