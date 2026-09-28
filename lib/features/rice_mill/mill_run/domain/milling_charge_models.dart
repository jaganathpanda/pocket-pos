import 'milling_config.dart';

/// Payment/collection status of a milling charge invoice.
enum MillingChargeStatus {
  draft,
  issued,
  paid,
  partiallyPaid,
  cancelled;

  String get label => switch (this) {
        MillingChargeStatus.draft => 'Draft',
        MillingChargeStatus.issued => 'Issued',
        MillingChargeStatus.paid => 'Paid',
        MillingChargeStatus.partiallyPaid => 'Partial',
        MillingChargeStatus.cancelled => 'Cancelled',
      };

  static MillingChargeStatus fromString(String? v) => switch (v) {
        'issued' => MillingChargeStatus.issued,
        'paid' => MillingChargeStatus.paid,
        'partiallyPaid' => MillingChargeStatus.partiallyPaid,
        'cancelled' => MillingChargeStatus.cancelled,
        _ => MillingChargeStatus.draft,
      };
}

/// A service invoice raised for toll milling (FCI / govt mandi).
/// The miller charges for the service — the paddy and rice belong to the party.
class MillingChargeInvoice {
  const MillingChargeInvoice({
    required this.id,
    required this.invoiceNo,
    required this.invoiceDate,
    required this.partyId,
    required this.millRunId,
    required this.chargeBasis,
    required this.billedQty,
    required this.ratePerUnit,
    required this.dryingChargePerUnit,
    required this.loadingChargePerUnit,
    required this.baggingChargePerUnit,
    required this.deductionPerUnit,
    required this.grossCharge,
    required this.gstPercent,
    required this.gstAmount,
    required this.tdsPercent,
    required this.tdsAmount,
    required this.netPayable,
    required this.paidAmount,
    required this.status,
    required this.createdAt,
    this.lotNumber,
    this.note,
    this.partyName,
    this.millRunDate,
    this.millRunPaddyQty,
  });

  final int id;
  final String invoiceNo;
  final DateTime invoiceDate;

  /// Customer (rice party / FCI depot) this invoice is raised for.
  final int partyId;

  /// The completed mill run this invoice covers.
  final int millRunId;

  final MillingChargeBasis chargeBasis;

  /// Qty on which charge is calculated (paddy qty or rice qty depending on basis).
  final double billedQty;

  final double ratePerUnit;
  final double dryingChargePerUnit;
  final double loadingChargePerUnit;
  final double baggingChargePerUnit;
  final double deductionPerUnit;

  /// = billedQty × (rate + drying + loading + bagging − deduction)
  final double grossCharge;

  final double gstPercent;

  /// = grossCharge × gstPercent / 100
  final double gstAmount;

  final double tdsPercent;

  /// = grossCharge × tdsPercent / 100
  final double tdsAmount;

  /// = grossCharge + gstAmount − tdsAmount
  final double netPayable;

  /// Amount collected so far.
  final double paidAmount;

  double get dueAmount => netPayable - paidAmount;

  final MillingChargeStatus status;
  final DateTime createdAt;
  final String? lotNumber;
  final String? note;

  // Joined fields for display (not stored):
  final String? partyName;
  final DateTime? millRunDate;
  final double? millRunPaddyQty;

  /// Auto-calculates all derived fields from the component rates and qty.
  static MillingChargeInvoice calculate({
    required int id,
    required String invoiceNo,
    required DateTime invoiceDate,
    required int partyId,
    required int millRunId,
    required MillingChargeBasis chargeBasis,
    required double billedQty,
    required double ratePerUnit,
    required double dryingChargePerUnit,
    required double loadingChargePerUnit,
    required double baggingChargePerUnit,
    required double deductionPerUnit,
    required double gstPercent,
    required double tdsPercent,
    String? lotNumber,
    String? note,
    String? partyName,
    DateTime? millRunDate,
    double? millRunPaddyQty,
  }) {
    final gross = billedQty *
        (ratePerUnit +
            dryingChargePerUnit +
            loadingChargePerUnit +
            baggingChargePerUnit -
            deductionPerUnit);
    final gst = gross * gstPercent / 100;
    final tds = gross * tdsPercent / 100;
    final net = gross + gst - tds;
    return MillingChargeInvoice(
      id: id,
      invoiceNo: invoiceNo,
      invoiceDate: invoiceDate,
      partyId: partyId,
      millRunId: millRunId,
      chargeBasis: chargeBasis,
      billedQty: billedQty,
      ratePerUnit: ratePerUnit,
      dryingChargePerUnit: dryingChargePerUnit,
      loadingChargePerUnit: loadingChargePerUnit,
      baggingChargePerUnit: baggingChargePerUnit,
      deductionPerUnit: deductionPerUnit,
      grossCharge: double.parse(gross.toStringAsFixed(2)),
      gstPercent: gstPercent,
      gstAmount: double.parse(gst.toStringAsFixed(2)),
      tdsPercent: tdsPercent,
      tdsAmount: double.parse(tds.toStringAsFixed(2)),
      netPayable: double.parse(net.toStringAsFixed(2)),
      paidAmount: 0,
      status: MillingChargeStatus.draft,
      createdAt: DateTime.now(),
      lotNumber: lotNumber,
      note: note,
      partyName: partyName,
      millRunDate: millRunDate,
      millRunPaddyQty: millRunPaddyQty,
    );
  }
}

/// A payment recorded against a milling charge invoice.
class MillingChargePayment {
  const MillingChargePayment({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.method,
    required this.paidAt,
    this.referenceNo,
  });

  final int id;
  final int invoiceId;
  final double amount;
  final String method;
  final DateTime paidAt;
  final String? referenceNo;
}
