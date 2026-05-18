package com.qr.edge.demo;

import java.net.Inet4Address;
import java.net.NetworkInterface;
import java.net.URI;
import java.util.Collections;
import java.util.Enumeration;
import java.util.Locale;
import java.util.Optional;

import org.springframework.stereotype.Component;

import com.qr.edge.config.QuickserveProperties;

@Component
public class DemoNetworkHelper {

	private final QuickserveProperties properties;

	public DemoNetworkHelper(QuickserveProperties properties) {
		this.properties = properties;
	}

	/** Telefonun aynı WiFi'den erişeceği IPv4 (yapılandırma veya otomatik). */
	public String resolveLanHost() {
		String configured = properties.getDemo().getLanHost();
		if (configured != null && !configured.isBlank()) {
			return configured.trim();
		}
		return detectSiteLocalIpv4().orElse("127.0.0.1");
	}

	public String rewriteLoopbackToLan(String url) {
		if (url == null || url.isBlank()) {
			return url;
		}
		String lan = resolveLanHost();
		if (isLoopbackHost(lan)) {
			return url;
		}
		try {
			URI u = URI.create(url.trim());
			if (!isLoopbackHost(u.getHost())) {
				return url;
			}
			int port = u.getPort();
			String portPart = port > 0 ? String.valueOf(port) : null;
			URI rewritten = new URI(u.getScheme(), null, lan, port, u.getPath(), u.getQuery(), u.getFragment());
			if (portPart == null) {
				return rewritten.toString();
			}
			return rewritten.toString();
		} catch (Exception ex) {
			return url;
		}
	}

	public Optional<String> suggestedGuestWebBase() {
		int port = properties.getDemo().getGuestWebPort();
		if (port <= 0) {
			return Optional.empty();
		}
		String lan = resolveLanHost();
		if (isLoopbackHost(lan)) {
			return Optional.empty();
		}
		return Optional.of("http://" + lan + ":" + port);
	}

	private static Optional<String> detectSiteLocalIpv4() {
		try {
			Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
			while (interfaces.hasMoreElements()) {
				NetworkInterface ni = interfaces.nextElement();
				if (!ni.isUp() || ni.isLoopback()) {
					continue;
				}
				for (var addr : Collections.list(ni.getInetAddresses())) {
					if (!(addr instanceof Inet4Address inet4) || inet4.isLoopbackAddress() || !inet4.isSiteLocalAddress()) {
						continue;
					}
					String host = inet4.getHostAddress();
					if (host != null && !host.isBlank()) {
						return Optional.of(host);
					}
				}
			}
		} catch (Exception ignored) {
			// Yerel demo: otomatik IP bulunamazsa 127.0.0.1 kalır
		}
		return Optional.empty();
	}

	private static boolean isLoopbackHost(String host) {
		if (host == null) {
			return true;
		}
		String h = host.toLowerCase(Locale.ROOT);
		return h.equals("localhost") || h.equals("127.0.0.1") || h.startsWith("127.");
	}
}
