package com.qr.edge.print.template;

import java.io.IOException;
import java.nio.charset.Charset;
import java.util.Map;

import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.stereotype.Component;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

import com.qr.edge.print.config.PrintProperties;
import com.qr.edge.print.escpos.EscPosBuilder;

import org.apache.commons.text.StringSubstitutor;

import javax.xml.parsers.DocumentBuilderFactory;

/**
 * {@code classpath:print/templates/*.xml} slip şeması veya {@code *.html} (basit etiket → satır).
 */
@Component
public class SlipDocumentRenderer {

	private final PrintProperties printProperties;

	private final PathMatchingResourcePatternResolver resolver = new PathMatchingResourcePatternResolver();

	public SlipDocumentRenderer(PrintProperties printProperties) {
		this.printProperties = printProperties;
	}

	public byte[] render(String templateBaseName, Map<String, String> variables) throws Exception {
		Resource xml = resolver.getResource("classpath:print/templates/" + templateBaseName + ".xml");
		String raw;
		if (xml.exists()) {
			raw = new String(xml.getInputStream().readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
			raw = StringSubstitutor.replace(raw, variables);
			return renderXml(raw);
		}
		Resource html = resolver.getResource("classpath:print/templates/" + templateBaseName + ".html");
		if (!html.exists()) {
			throw new IOException("Template not found: " + templateBaseName + " (.xml or .html)");
		}
		raw = new String(html.getInputStream().readAllBytes(), java.nio.charset.StandardCharsets.UTF_8);
		raw = replaceMustacheStyle(raw, variables);
		String plain = htmlToPlain(raw);
		return plainToEscPos(plain);
	}

	private static String replaceMustacheStyle(String template, Map<String, String> variables) {
		String result = template;
		for (Map.Entry<String, String> e : variables.entrySet()) {
			result = result.replace("{{" + e.getKey() + "}}", e.getValue() != null ? e.getValue() : "");
		}
		return result;
	}

	private byte[] renderXml(String xml) throws Exception {
		DocumentBuilderFactory f = DocumentBuilderFactory.newInstance();
		f.setNamespaceAware(true);
		f.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
		Document doc = f.newDocumentBuilder().parse(new java.io.ByteArrayInputStream(xml.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
		Element root = doc.getDocumentElement();
		int width = parseIntAttr(root, "widthChars", printProperties.getSlipWidthChars());
		Charset charset = Charset.forName(printProperties.getCharset());
		EscPosBuilder b = new EscPosBuilder(charset).init();
		NodeList children = root.getChildNodes();
		for (int i = 0; i < children.getLength(); i++) {
			Node n = children.item(i);
			if (n.getNodeType() != Node.ELEMENT_NODE) {
				continue;
			}
			Element el = (Element) n;
			String tag = el.getLocalName() != null ? el.getLocalName() : el.getTagName();
			switch (tag) {
				case "line" -> b.separatorLine(width);
				case "feed" -> b.feed(parseIntAttr(el, "lines", 1));
				case "cut" -> b.partialCut();
				case "text" -> {
					boolean bold = Boolean.parseBoolean(el.getAttribute("bold"));
					boolean big = Boolean.parseBoolean(el.getAttribute("large"));
					String content = el.getTextContent().strip();
					if (big) {
						b.doubleHeightOn();
					}
					if (bold) {
						b.boldOn();
					}
					b.text(content);
					if (bold) {
						b.boldOff();
					}
					if (big) {
						b.doubleHeightOff();
					}
				}
				default -> {
					// ignore unknown
				}
			}
		}
		return b.toBytes();
	}

	private static int parseIntAttr(Element el, String name, int def) {
		String v = el.getAttribute(name);
		if (v == null || v.isBlank()) {
			return def;
		}
		return Integer.parseInt(v.trim());
	}

	static String htmlToPlain(String html) {
		String s = html.replaceAll("(?i)<br\\s*/?>", "\n");
		s = s.replaceAll("(?i)</p>", "\n");
		s = s.replaceAll("<[^>]+>", "");
		return s.strip();
	}

	private byte[] plainToEscPos(String plain) throws IOException {
		Charset charset = Charset.forName(printProperties.getCharset());
		EscPosBuilder b = new EscPosBuilder(charset).init();
		for (String line : plain.split("\n")) {
			b.text(line);
		}
		b.feed(2);
		b.partialCut();
		return b.toBytes();
	}
}
