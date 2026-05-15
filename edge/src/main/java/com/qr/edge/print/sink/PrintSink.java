package com.qr.edge.print.sink;

import java.io.IOException;

@FunctionalInterface
public interface PrintSink {

	void send(byte[] payload) throws IOException;
}
