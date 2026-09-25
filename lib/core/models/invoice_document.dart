import 'invoice_branding.dart';

class InvoiceLine {
  const InvoiceLine({
    required this.description,
    required this.unitPrice,
    required this.qty,
    required this.lineTotal,
  });

  final String description;
  final double unitPrice;
  final double qty;
  final double lineTotal;
}

class InvoiceDocument {
  const InvoiceDocument({
    required this.shopName,
    required this.invoiceNo,
    required this.invoiceDate,
    required this.customerName,
    required this.customerAddress,
    required this.items,
    required this.subTotal,
    required this.total,
    this.taxTotal,
    this.footerNote,
    this.branding,
  });

  final String shopName;
  final String invoiceNo;
  final DateTime invoiceDate;
  final String customerName;
  final String customerAddress;
  final List<InvoiceLine> items;
  final double subTotal;
  final double total;
  final double? taxTotal;
  final String? footerNote;
  final InvoiceBranding? branding;
}
