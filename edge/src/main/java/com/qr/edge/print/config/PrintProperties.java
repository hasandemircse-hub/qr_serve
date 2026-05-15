package com.qr.edge.print.config;

import java.util.ArrayList;
import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;

import com.qr.edge.print.PrinterConnectionType;
import com.qr.edge.print.PrinterStation;

@ConfigurationProperties(prefix = "quickserve.print")
public class PrintProperties {

	private boolean enabled = true;

	private String charset = "UTF-8";

	private int defaultNetworkPort = 9100;

	private int slipWidthChars = 42;

	private final List<PrinterDefinition> printers = new ArrayList<>();

	public boolean isEnabled() {
		return enabled;
	}

	public void setEnabled(boolean enabled) {
		this.enabled = enabled;
	}

	public String getCharset() {
		return charset;
	}

	public void setCharset(String charset) {
		this.charset = charset;
	}

	public int getDefaultNetworkPort() {
		return defaultNetworkPort;
	}

	public void setDefaultNetworkPort(int defaultNetworkPort) {
		this.defaultNetworkPort = defaultNetworkPort;
	}

	public int getSlipWidthChars() {
		return slipWidthChars;
	}

	public void setSlipWidthChars(int slipWidthChars) {
		this.slipWidthChars = slipWidthChars;
	}

	public List<PrinterDefinition> getPrinters() {
		return printers;
	}

	public static class PrinterDefinition {

		private String id;

		private PrinterStation station = PrinterStation.KITCHEN;

		private PrinterConnectionType connection = PrinterConnectionType.NETWORK;

		private String networkHost;

		private Integer networkPort;

		private String usbDevicePath;

		private String template = "kitchen-slip";

		public String getId() {
			return id;
		}

		public void setId(String id) {
			this.id = id;
		}

		public PrinterStation getStation() {
			return station;
		}

		public void setStation(PrinterStation station) {
			this.station = station;
		}

		public PrinterConnectionType getConnection() {
			return connection;
		}

		public void setConnection(PrinterConnectionType connection) {
			this.connection = connection;
		}

		public String getNetworkHost() {
			return networkHost;
		}

		public void setNetworkHost(String networkHost) {
			this.networkHost = networkHost;
		}

		public Integer getNetworkPort() {
			return networkPort;
		}

		public void setNetworkPort(Integer networkPort) {
			this.networkPort = networkPort;
		}

		public String getUsbDevicePath() {
			return usbDevicePath;
		}

		public void setUsbDevicePath(String usbDevicePath) {
			this.usbDevicePath = usbDevicePath;
		}

		public String getTemplate() {
			return template;
		}

		public void setTemplate(String template) {
			this.template = template;
		}
	}
}
