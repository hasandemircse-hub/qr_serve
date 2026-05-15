package com.qr.edge.print.escpos;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.Charset;
import java.util.Arrays;

/**
 * Basit ESC/POS çıktısı: metin, ayırıcı, besleme, kısmi kesim.
 */
public final class EscPosBuilder {

	private static final byte ESC = 0x1B;

	private static final byte GS = 0x1D;

	private final ByteArrayOutputStream out = new ByteArrayOutputStream();

	private final Charset charset;

	public EscPosBuilder(Charset charset) {
		this.charset = charset;
	}

	public EscPosBuilder init() throws IOException {
		out.write(new byte[] { ESC, '@' });
		return this;
	}

	public EscPosBuilder text(String line) throws IOException {
		if (line == null) {
			return this;
		}
		out.write(line.getBytes(charset));
		out.write('\n');
		return this;
	}

	public EscPosBuilder boldOn() throws IOException {
		out.write(new byte[] { ESC, 'E', 1 });
		return this;
	}

	public EscPosBuilder boldOff() throws IOException {
		out.write(new byte[] { ESC, 'E', 0 });
		return this;
	}

	public EscPosBuilder doubleHeightOn() throws IOException {
		out.write(new byte[] { ESC, '!', 0x10 });
		return this;
	}

	public EscPosBuilder doubleHeightOff() throws IOException {
		out.write(new byte[] { ESC, '!', 0 });
		return this;
	}

	public EscPosBuilder alignLeft() throws IOException {
		out.write(new byte[] { ESC, 'a', 0 });
		return this;
	}

	public EscPosBuilder alignCenter() throws IOException {
		out.write(new byte[] { ESC, 'a', 1 });
		return this;
	}

	public EscPosBuilder alignRight() throws IOException {
		out.write(new byte[] { ESC, 'a', 2 });
		return this;
	}

	public EscPosBuilder separatorLine(int widthChars) throws IOException {
		char[] dash = new char[Math.max(8, widthChars)];
		Arrays.fill(dash, '-');
		text(new String(dash));
		return this;
	}

	public EscPosBuilder feed(int lines) throws IOException {
		for (int i = 0; i < lines; i++) {
			out.write('\n');
		}
		return this;
	}

	/** GS V 65 0 — kısmi kesim (model desteğine bağlı). */
	public EscPosBuilder partialCut() throws IOException {
		out.write(new byte[] { GS, 'V', 65, 0 });
		return this;
	}

	public byte[] toBytes() {
		return out.toByteArray();
	}
}
