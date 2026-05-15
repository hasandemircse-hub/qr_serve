package com.qr.edge.print;

import java.time.Duration;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.atomic.AtomicBoolean;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import com.qr.edge.print.config.PrintProperties;
import com.qr.edge.print.config.PrintProperties.PrinterDefinition;
import com.qr.edge.print.sink.NetworkEscPosSink;
import com.qr.edge.print.sink.PrintSink;
import com.qr.edge.print.sink.UsbRawEscPosSink;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;

@Component
public class PrintManager {

	private static final Logger log = LoggerFactory.getLogger(PrintManager.class);

	private final PrintProperties printProperties;

	private final BlockingQueue<PrintJob> queue = new LinkedBlockingQueue<>(500);

	private final AtomicBoolean running = new AtomicBoolean(true);

	private Thread worker;

	public PrintManager(PrintProperties printProperties) {
		this.printProperties = printProperties;
	}

	@PostConstruct
	public void startWorker() {
		worker = new Thread(this::drainLoop, "qs-print-worker");
		worker.setDaemon(true);
		worker.start();
	}

	@PreDestroy
	public void stopWorker() {
		running.set(false);
		worker.interrupt();
	}

	public void enqueue(String printerId, byte[] escPosPayload) {
		if (!printProperties.isEnabled()) {
			log.debug("Print disabled, skip job for {}", printerId);
			return;
		}
		if (!queue.offer(new PrintJob(printerId, escPosPayload))) {
			log.warn("Print queue full, dropping job for {}", printerId);
		}
	}

	private record PrintJob(String printerId, byte[] payload) {
	}

	private void drainLoop() {
		while (running.get() && !Thread.currentThread().isInterrupted()) {
			try {
				PrintJob job = queue.take();
				process(job);
			} catch (InterruptedException ex) {
				Thread.currentThread().interrupt();
				break;
			} catch (Exception ex) {
				log.error("Print worker error", ex);
			}
		}
	}

	private void process(PrintJob job) {
		PrinterDefinition def = printProperties.getPrinters().stream()
				.filter(p -> job.printerId().equals(p.getId()))
				.findFirst()
				.orElse(null);
		if (def == null) {
			log.warn("Unknown printer id {}, skip", job.printerId());
			return;
		}
		try {
			PrintSink sink = createSink(def);
			sink.send(job.payload());
		} catch (Exception ex) {
			log.error("Print failed for printer {}: {}", job.printerId(), ex.getMessage());
		}
	}

	private PrintSink createSink(PrinterDefinition def) {
		if (def.getConnection() == PrinterConnectionType.NETWORK
				&& (def.getNetworkHost() == null || def.getNetworkHost().isBlank())) {
			throw new IllegalArgumentException("networkHost required for NETWORK printer " + def.getId());
		}
		if (def.getConnection() == PrinterConnectionType.USB_RAW
				&& (def.getUsbDevicePath() == null || def.getUsbDevicePath().isBlank())) {
			throw new IllegalArgumentException("usbDevicePath required for USB_RAW printer " + def.getId());
		}
		return switch (def.getConnection()) {
			case NETWORK -> new NetworkEscPosSink(
					def.getNetworkHost(),
					def.getNetworkPort() != null ? def.getNetworkPort() : printProperties.getDefaultNetworkPort(),
					Duration.ofSeconds(8));
			case USB_RAW -> new UsbRawEscPosSink(def.getUsbDevicePath());
		};
	}
}
