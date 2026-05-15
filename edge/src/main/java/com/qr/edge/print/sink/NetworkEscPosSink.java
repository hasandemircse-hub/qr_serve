package com.qr.edge.print.sink;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.time.Duration;

public final class NetworkEscPosSink implements PrintSink {

	private final String host;

	private final int port;

	private final Duration connectTimeout;

	public NetworkEscPosSink(String host, int port, Duration connectTimeout) {
		this.host = host;
		this.port = port;
		this.connectTimeout = connectTimeout;
	}

	@Override
	public void send(byte[] payload) throws IOException {
		try (Socket socket = new Socket()) {
			socket.connect(new InetSocketAddress(host, port), (int) connectTimeout.toMillis());
			socket.setSoTimeout((int) connectTimeout.toMillis());
			OutputStream out = socket.getOutputStream();
			out.write(payload);
			out.flush();
		}
	}
}
