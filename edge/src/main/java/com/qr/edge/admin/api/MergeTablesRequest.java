package com.qr.edge.admin.api;

import java.util.List;
import java.util.UUID;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

public record MergeTablesRequest(@NotEmpty @Size(min = 2) List<UUID> tableIds) {
}
