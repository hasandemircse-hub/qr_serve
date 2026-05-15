package com.qr.edge.admin;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.repository.DiningTableRepository;


@Service
public class TableMergeService {

	private final DiningTableRepository diningTableRepository;

	public TableMergeService(DiningTableRepository diningTableRepository) {
		this.diningTableRepository = diningTableRepository;
	}

	/**
	 * Birleşik hesap: aynı {@code merge_group_id} ile masalar tek hesap mantığında gruplanır.
	 * Faturalama / QR için birincil masa: gruptaki en küçük UUID.
	 */
	@Transactional
	public void mergeTables(UUID restaurantId, List<UUID> tableIds) {
		if (tableIds == null || tableIds.size() < 2) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "At least two tables required");
		}
		List<DiningTable> tables = tableIds.stream()
				.map(id -> diningTableRepository.findById(id)
						.filter(t -> t.getRestaurantId().equals(restaurantId))
						.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Table not found: " + id)))
				.toList();
		UUID mergeGroupId = UUID.randomUUID();
		LocalDateTime now = LocalDateTime.now();
		for (DiningTable t : tables) {
			t.setMergeGroupId(mergeGroupId);
			t.setUpdatedAt(now);
			diningTableRepository.save(t);
		}
	}

	@Transactional
	public void unmergeTable(UUID restaurantId, UUID tableId) {
		DiningTable t = diningTableRepository.findById(tableId)
				.filter(x -> x.getRestaurantId().equals(restaurantId))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Table not found"));
		UUID g = t.getMergeGroupId();
		if (g == null) {
			return;
		}
		List<DiningTable> members = diningTableRepository.findByRestaurantIdAndMergeGroupId(restaurantId, g);
		LocalDateTime now = LocalDateTime.now();
		for (DiningTable m : members) {
			m.setMergeGroupId(null);
			m.setUpdatedAt(now);
			diningTableRepository.save(m);
		}
	}

	public UUID resolveBillingTableId(UUID restaurantId, UUID tableId) {
		DiningTable t = diningTableRepository.findById(tableId)
				.filter(x -> x.getRestaurantId().equals(restaurantId))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Table not found"));
		if (t.getMergeGroupId() == null) {
			return tableId;
		}
		return diningTableRepository.findByRestaurantIdAndMergeGroupId(restaurantId, t.getMergeGroupId()).stream()
				.map(DiningTable::getId)
				.min(Comparator.naturalOrder())
				.orElse(tableId);
	}
}
