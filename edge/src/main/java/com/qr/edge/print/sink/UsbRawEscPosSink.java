package com.qr.edge.print.sink;

import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;

/**
 * Linux/Edge (ör. Raspberry Pi) üzerinde ham bayt gönderimi: {@code /dev/usb/lp0} vb.
 */
public final class UsbRawEscPosSink implements PrintSink {

	private final String devicePath;

	public UsbRawEscPosSink(String devicePath) {
		this.devicePath = devicePath;
	}

	@Override
	public void send(byte[] payload) throws IOException {
		try (OutputStream out = new FileOutputStream(devicePath)) {
			out.write(payload);
			out.flush();
		}
	}
}
