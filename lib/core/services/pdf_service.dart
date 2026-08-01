import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReceiptPdfService {
  Future<List<int>> generateSimpleReceipt({
    required String shopName,
    required String invoiceNo,
    required List<
            ({
              String name,
              double qty,
              double discountAmount,
              double netAmount
            })>
        items,
    required double grandTotal,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => [
          pw.Text(shopName,
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.Text('Invoice: $invoiceNo'),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey700, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.8),
              3: pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _tableCell('Item', isHeader: true),
                  _tableCell('QTY', isHeader: true, alignRight: true),
                  _tableCell('Disc. Amt', isHeader: true, alignRight: true),
                  _tableCell('Net.amt', isHeader: true, alignRight: true),
                ],
              ),
              ...items.map(
                (i) => pw.TableRow(
                  children: [
                    _tableCell(i.name),
                    _tableCell(_formatQty(i.qty), alignRight: true),
                    _tableCell(i.discountAmount.toStringAsFixed(2),
                        alignRight: true),
                    _tableCell(i.netAmount.toStringAsFixed(2),
                        alignRight: true),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('Total: Rs ${grandTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _tableCell(String text,
      {bool isHeader = false, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 9,
        ),
      ),
    );
  }

  String _formatQty(double qty) {
    return qty % 1 == 0 ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);
  }
}
