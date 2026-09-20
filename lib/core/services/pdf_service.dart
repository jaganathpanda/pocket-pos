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
    List<({String method, double amount, DateTime paidAt, String? referenceNo})>
        refundEntries = const [],
  }) async {
    final doc = pw.Document();

    // Use the branding display name when set, otherwise fall back to shopName.
    final headerName = (branding?.displayName.isNotEmpty ?? false)
        ? branding!.displayName
        : shopName;

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
            pw.Text(branding.address, style: const pw.TextStyle(fontSize: 8)),
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
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 8),
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
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 8),
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
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 8),
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

  Future<List<int>> generateClassicInvoice({
    required String shopName,
    required String invoiceNo,
    required DateTime invoiceDate,
    required String customerName,
    required String customerAddress,
    required List<
            ({
              String description,
              double unitPrice,
              double qty,
              double lineTotal,
            })>
        items,
    required double subTotal,
    required double total,
    double? taxTotal,
    InvoiceBranding? branding,
    String? footerNote,
  }) async {
    final doc = pw.Document();
    final headerName = (branding?.displayName.isNotEmpty ?? false)
        ? branding!.displayName
        : shopName;
    final customerBlock = [
      if (customerName.trim().isNotEmpty) customerName.trim(),
      if (customerAddress.trim().isNotEmpty) customerAddress.trim(),
    ].join('\n');
    final footerContacts = [
      if (branding != null && branding.phone.trim().isNotEmpty)
        branding.phone.trim(),
      if (branding != null && branding.email.trim().isNotEmpty)
        branding.email.trim(),
    ].join(' | ');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      headerName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (branding != null && branding.address.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      pw.Text(branding.address,
                          style: const pw.TextStyle(fontSize: 11)),
                    ],
                    if (footerContacts.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(footerContacts,
                          style: const pw.TextStyle(fontSize: 11)),
                    ],
                    if (branding != null && branding.gstin.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text('GSTIN: ${branding.gstin}',
                          style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 30,
                      fontWeight: pw.FontWeight.normal,
                      letterSpacing: 1.4,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _classicMetaLine(
                      'Date', DateFormat('dd/MM/yyyy').format(invoiceDate)),
                  _classicMetaLine('Invoice No', invoiceNo),
                  _classicMetaLine('Invoice To',
                      customerName.trim().isEmpty ? '-' : customerName.trim()),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          if (customerBlock.isNotEmpty)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                constraints: const pw.BoxConstraints(maxWidth: 220),
                child: pw.Text(customerBlock, textAlign: pw.TextAlign.right),
              ),
            ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: const pw.TableBorder(
              horizontalInside:
                  pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.7),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(4.5),
              1: pw.FlexColumnWidth(1.6),
              2: pw.FlexColumnWidth(1.6),
              3: pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.7),
                  ),
                ),
                children: [
                  _classicCell('Description', isHeader: true),
                  _classicCell('Price', isHeader: true, alignRight: true),
                  _classicCell('Quantity', isHeader: true, alignRight: true),
                  _classicCell('Total', isHeader: true, alignRight: true),
                ],
              ),
              ...items.map(
                (item) => pw.TableRow(
                  children: [
                    _classicCell(item.description),
                    _classicCell(item.unitPrice.toStringAsFixed(2),
                        alignRight: true),
                    _classicCell(_formatQty(item.qty), alignRight: true),
                    _classicCell(item.lineTotal.toStringAsFixed(2),
                        alignRight: true),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  _classicTotalLine('Sub-total', subTotal),
                  if (taxTotal != null && taxTotal > 0)
                    _classicTotalLine('GST', taxTotal),
                  _classicTotalLine('TOTAL', total, bold: true),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 44),
          pw.Center(
            child: pw.Text(
              'Thank You!',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (footerContacts.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(footerContacts, textAlign: pw.TextAlign.center),
            ),
          ],
          if (footerNote != null && footerNote.trim().isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(footerNote.trim(), textAlign: pw.TextAlign.center),
            ),
          ],
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

  pw.Widget _classicMetaLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4),
      child:
          pw.Text('$label : $value', style: const pw.TextStyle(fontSize: 11)),
    );
  }

  pw.Widget _classicCell(String text,
      {bool isHeader = false, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _classicTotalLine(String label, double value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 14 : 12,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
              child: pw.Text('$label :',
                  textAlign: pw.TextAlign.right, style: style)),
          pw.SizedBox(width: 12),
          pw.SizedBox(
            width: 84,
            child: pw.Text(value.toStringAsFixed(2),
                textAlign: pw.TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}
