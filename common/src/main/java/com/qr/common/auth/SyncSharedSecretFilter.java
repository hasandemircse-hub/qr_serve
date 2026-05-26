package com.qr.common.auth;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.concurrent.atomic.AtomicLong;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.lang.NonNull;
import org.springframework.web.filter.OncePerRequestFilter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * /api/v1/sync/** path'lerini paylaşılan secret ile korur.
 *
 * Tasarım:
 * - Cloud env'inde {@code QUICKSERVE_SYNC_SHARED_SECRET} set ise → header zorunlu.
 *   Edge isteğinde {@code X-QuickServe-Sync-Key} header'ı tam eşleşmeli; aksi halde 401.
 * - Secret boş/null ise filter pasif (yalnızca ilk açılışta uyarı log'u).
 *   Bu sayede mevcut deployment'lar kırılmadan, secret ortama eklenince
 *   sertleştirmeye geçebilir.
 *
 * Karşılaştırma sabit zamanlı yapılır (timing-attack koruması).
 *
 * Filter sadece /api/v1/sync/ ile başlayan path'lere uygulanır.
 */
public class SyncSharedSecretFilter extends OncePerRequestFilter {

	public static final String HEADER_NAME = "X-QuickServe-Sync-Key";

	private static final String SYNC_PATH_PREFIX = "/api/v1/sync/";

	private static final Logger log = LoggerFactory.getLogger(SyncSharedSecretFilter.class);

	private final byte[] expectedSecretBytes;

	private final boolean enforced;

	private final AtomicLong lastWarnNanos = new AtomicLong(0L);

	public SyncSharedSecretFilter(String sharedSecret) {
		String trimmed = sharedSecret == null ? "" : sharedSecret.trim();
		this.enforced = !trimmed.isEmpty();
		this.expectedSecretBytes = enforced ? trimmed.getBytes(StandardCharsets.UTF_8) : new byte[0];
		if (enforced) {
			log.info("Sync shared-secret auth ENFORCED for {}** (secret len={} bytes)",
					SYNC_PATH_PREFIX, expectedSecretBytes.length);
		} else {
			log.warn("Sync shared-secret auth DISABLED — set QUICKSERVE_SYNC_SHARED_SECRET to harden /api/v1/sync/**");
		}
	}

	@Override
	protected boolean shouldNotFilter(@NonNull HttpServletRequest request) {
		String path = request.getRequestURI();
		return path == null || !path.startsWith(SYNC_PATH_PREFIX);
	}

	@Override
	protected void doFilterInternal(
			@NonNull HttpServletRequest request,
			@NonNull HttpServletResponse response,
			@NonNull FilterChain filterChain) throws ServletException, IOException {

		if (!enforced) {
			throttledWarn(request);
			filterChain.doFilter(request, response);
			return;
		}

		String provided = request.getHeader(HEADER_NAME);
		if (provided == null || provided.isBlank()) {
			deny(response, "missing X-QuickServe-Sync-Key");
			return;
		}
		byte[] providedBytes = provided.getBytes(StandardCharsets.UTF_8);
		if (!MessageDigest.isEqual(providedBytes, expectedSecretBytes)) {
			deny(response, "invalid sync secret");
			return;
		}
		filterChain.doFilter(request, response);
	}

	private void deny(HttpServletResponse response, String reason) throws IOException {
		log.warn("Sync auth rejected: {}", reason);
		response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
		response.setContentType("application/json;charset=UTF-8");
		response.getWriter().write("{\"error\":\"sync_unauthorized\",\"reason\":\"" + reason + "\"}");
	}

	private void throttledWarn(HttpServletRequest request) {
		long now = System.nanoTime();
		long last = lastWarnNanos.get();
		long oneHourNanos = 3_600_000_000_000L;
		if (now - last > oneHourNanos && lastWarnNanos.compareAndSet(last, now)) {
			log.warn("Sync auth disabled — unauthenticated request to {} from {}",
					request.getRequestURI(), request.getRemoteAddr());
		}
	}
}
