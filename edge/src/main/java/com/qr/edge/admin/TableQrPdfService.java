package com.qr.edge.admin;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.time.LocalDateTime;
import java.util.UUID;

import javax.imageio.ImageIO;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.apache.pdfbox.pdmodel.font.Standard14Fonts;
import org.apache.pdfbox.pdmodel.graphics.image.PDImageXObject;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import com.qr.common.persistence.entity.DiningTable;
import com.qr.common.persistence.entity.TableGuestToken;
import com.qr.common.persistence.repository.DiningTableRepository;
import com.qr.common.persistence.repository.TableGuestTokenRepository;
import com.qr.edge.config.QuickserveProperties;
import com.qr.edge.guest.GuestQrLinks;


@Service
public class TableQrPdfService {

	private static final int QR_SIZE = 400;

	private final QuickserveProperties properties;

	private final DiningTableRepository diningTableRepository;

	private final TableGuestTokenRepository tableGuestTokenRepository;

	private final TableMergeService tableMergeService;

	public TableQrPdfService(
			QuickserveProperties properties,
			DiningTableRepository diningTableRepository,
			TableGuestTokenRepository tableGuestTokenRepository,
			TableMergeService tableMergeService) {
		this.properties = properties;
		this.diningTableRepository = diningTableRepository;
		this.tableGuestTokenRepository = tableGuestTokenRepository;
		this.tableMergeService = tableMergeService;
	}

	public byte[] buildQrMenuPdf(UUID restaurantId, UUID tableId) throws Exception {
		DiningTable table = diningTableRepository.findById(tableId)
				.filter(t -> t.getRestaurantId().equals(restaurantId))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Table not found"));
		UUID billingTableId = tableMergeService.resolveBillingTableId(restaurantId, tableId);
		TableGuestToken tokenRow = tableGuestTokenRepository
				.findFirstByRestaurantIdAndTableIdAndIsDeletedFalseOrderByExpiresAtDesc(restaurantId, billingTableId)
				.orElseGet(() -> createToken(restaurantId, billingTableId));
		String url = GuestQrLinks.absolute(
				properties.resolvePublicCloudUrl(),
				restaurantId,
				billingTableId,
				tokenRow.getToken());
		BufferedImage qr = toImage(url);
		try (PDDocument doc = new PDDocument(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
			PDPage page = new PDPage(PDRectangle.A4);
			doc.addPage(page);
			try (PDPageContentStream cs = new PDPageContentStream(doc, page)) {
				float pw = page.getMediaBox().getWidth();
				float margin = 48;
				float imgSize = Math.min(QR_SIZE, pw - 2 * margin);
				ByteArrayOutputStream png = new ByteArrayOutputStream();
				ImageIO.write(qr, "PNG", png);
				PDImageXObject img = PDImageXObject.createFromByteArray(doc, png.toByteArray(), "qr");
				float x = (pw - imgSize) / 2;
				float y = page.getMediaBox().getHeight() - margin - imgSize;
				cs.drawImage(img, x, y, imgSize, imgSize);
				PDType1Font bold = new PDType1Font(Standard14Fonts.FontName.HELVETICA_BOLD);
				PDType1Font regular = new PDType1Font(Standard14Fonts.FontName.HELVETICA);
				cs.beginText();
				cs.setFont(bold, 14);
				cs.newLineAtOffset(margin, y - 28);
				cs.showText("Masa: " + table.getLabel());
				cs.endText();
				cs.beginText();
				cs.setFont(regular, 9);
				cs.newLineAtOffset(margin, y - 48);
				cs.showText(url.length() > 120 ? url.substring(0, 117) + "..." : url);
				cs.endText();
			}
			doc.save(out);
			return out.toByteArray();
		}
	}

	private TableGuestToken createToken(UUID restaurantId, UUID tableId) {
		String token = "t-" + UUID.randomUUID().toString().replace("-", "").substring(0, 24);
		TableGuestToken row = new TableGuestToken();
		row.setRestaurantId(restaurantId);
		row.setTableId(tableId);
		row.setToken(token);
		row.setExpiresAt(LocalDateTime.now().plusYears(5));
		return tableGuestTokenRepository.save(row);
	}

	private static BufferedImage toImage(String text) throws Exception {
		QRCodeWriter writer = new QRCodeWriter();
		BitMatrix matrix = writer.encode(text, BarcodeFormat.QR_CODE, QR_SIZE, QR_SIZE);
		return MatrixToImageWriter.toBufferedImage(matrix);
	}
}
