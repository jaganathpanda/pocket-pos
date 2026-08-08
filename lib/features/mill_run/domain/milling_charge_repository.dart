import 'milling_charge_models.dart';
import 'milling_config.dart';

abstract class MillingChargeRepository {
  /// Live stream of all invoices (newest first).
  Stream<List<MillingChargeInvoice>> watchAll();

  /// Generate a new invoice from a mill run. Returns the invoice id.
  /// Rates are auto-populated from [config]; caller may override any field.
  Future<int> createInvoice({
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
    required DateTime invoiceDate,
    String? lotNumber,
    String? note,
  });

  /// Update a draft invoice's fields (recalculates derived amounts).
  Future<void> updateInvoice({
    required int id,
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
    required DateTime invoiceDate,
    String? lotNumber,
    String? note,
  });

  /// Mark as issued (locks the invoice from further edits).
  Future<void> issueInvoice(int id);

  /// Record a payment against an invoice. Updates paidAmount and status.
  Future<void> recordPayment({
    required int invoiceId,
    required double amount,
    required String method,
    String? referenceNo,
  });

  /// Fetch payment history for an invoice.
  Future<List<MillingChargePayment>> getPayments(int invoiceId);

  /// Cancel a draft or issued invoice.
  Future<void> cancelInvoice(int id);

  /// Hard-delete a draft invoice.
  Future<void> deleteInvoice(int id);
}
