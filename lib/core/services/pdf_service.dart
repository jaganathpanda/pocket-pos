import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

import '../models/invoice_branding.dart';

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
    InvoiceBranding? branding,
    List<
            ({
              String method,
              double amount,
              DateTime paidAt,
              String? referenceNo
            })>
        refundEntries = const [],
  }) async {
    final doc = pw.Document();

    // Use the branding display name when set, otherwise fall back to shopName.
    final headerName =
        (branding?.displayName.isNotEmpty ?? false) ? branding!.displayName : shopName;

    // Refund totals (computed here — a collection `if ...[]` list literal cannot
    // contain local variable declarations).
    final totalRefund =
        refundEntries.fold<double>(0, (sum, r) => sum + r.amount);
    final netPaidAfterRefund =
        (grandTotal - totalRefund).clamp(0, 999999999).toDouble();
    final totalCollected =
        (netPaidAfterRefund + totalRefund).clamp(0, 999999999).toDouble();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(headerName,
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          if (branding != null && branding.address.isNotEmpty)
            pw.Text(branding.address,
                style: const pw.TextStyle(fontSize: 8)),
          if (branding != null &&
              (branding.phone.isNotEmpty || branding.email.isNotEmpty))
            pw.Text(
              [
                if (branding.phone.isNotEmpty) branding.phone,
                if (branding.email.isNotEmpty) branding.email,
              ].join('  |  '),
              style: const pw.TextStyle(fontSize: 8),
            ),
          if (branding != null && branding.gstin.isNotEmpty)
            pw.Text('GSTIN: ${branding.gstin}',
                style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 4),
          pw.Text('Invoice: $invoiceNo',
              style: const pw.TextStyle(fontSize: 9)),
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
          if (refundEntries.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: PdfColors.orange50,
                border: pw.Border.all(color: PdfColors.orange200, width: 0.6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Refund Summary',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange800,
                      fontSize: 9,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  ...refundEntries.map(
                    (r) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              '${r.method.toUpperCase()} • ${DateFormat('dd MMM yyyy hh:mm a').format(r.paidAt)}'
                              '${(r.referenceNo == null || r.referenceNo!.isEmpty) ? '' : ' • ${r.referenceNo}'}',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Text(
                            '-Rs ${r.amount.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.orange800,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.Divider(color: PdfColors.orange200, height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Collected',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                      ),
                      pw.Text(
                        'Rs ${totalCollected.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Refunded',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                      ),
                      pw.Text(
                        'Rs ${totalRefund.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.orange800,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Net Paid After Refund',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                      ),
                      pw.Text(
                        'Rs ${netPaidAfterRefund.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (branding != null && branding.gstin.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Text(
                'This is a tax invoice.',
                style: const pw.TextStyle(fontSize: 8),
              ),
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
