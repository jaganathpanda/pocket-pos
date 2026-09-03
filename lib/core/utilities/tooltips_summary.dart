import 'tooltips.dart';

/// Print all tooltips for documentation/translation purposes.
class TooltipsSummary {
  static String getAll() {
    final buffer = StringBuffer();

    buffer.writeln('=== PADDY PROCUREMENT TOOLTIPS ===\n');
    _addCategory(buffer, 'Header', Tooltips.paddyProcurement,
        ['vType', 'date', 'slipNo', 'voucherNo', 'rstManual', 'area']);
    _addCategory(buffer, 'Party & Vehicle', Tooltips.paddyProcurement, [
      'partyName',
      'truckNo',
      'emptyWeight',
      'marketType',
      'procurementType'
    ]);
    _addCategory(buffer, 'Weighment', Tooltips.paddyProcurement, [
      'grossWeight',
      'tareWeight',
      'netWeight',
      'juteBags',
      'plasticBags',
      'totalBags',
      'avgBagWeight',
      'gnyWtLess',
      'bagReturn',
      'otherCut'
    ]);
    _addCategory(buffer, 'Rate & Calculation', Tooltips.paddyProcurement,
        ['rateCalculation', 'kgPerBag', 'eBag', 'ePkt', 'unloadTime']);
    _addCategory(buffer, 'Product & Pricing', Tooltips.paddyProcurement, [
      'product',
      'productName',
      'quantityNew',
      'quantityQntl',
      'ratePerQntl',
      'totalAmount'
    ]);
    _addCategory(buffer, 'Quality Cuts', Tooltips.paddyProcurement, [
      'qualityCutName',
      'qualityCutBagQty',
      'qualityCutType',
      'qualityCutPerUnit',
      'qualityCutKg',
      'qualityCutRemark'
    ]);
    _addCategory(buffer, 'Gunny Tracking', Tooltips.paddyProcurement,
        ['gunnyReceive', 'gunnyIssue', 'gunnyBagType']);
    _addCategory(buffer, 'Transport', Tooltips.paddyProcurement, [
      'deliveryType',
      'truckRentType',
      'truckRent',
      'otherAmount',
      'transportType',
      'truckAccount',
      'freightAmount'
    ]);
    _addCategory(buffer, 'Mandi/Government', Tooltips.paddyProcurement,
        ['mandiInvoiceNo', 'tenderNumber', 'commissionAgent']);
    _addCategory(buffer, 'Status', Tooltips.paddyProcurement,
        ['status', 'completeCode', 'completeDate']);

    buffer.writeln('\n=== WEIGHBRIDGE TOOLTIPS ===\n');
    _addCategory(buffer, 'Weighbridge', Tooltips.weighbridge, [
      'entryDate',
      'slipNo',
      'voucherNo',
      'vehicleNo',
      'rstManual',
      'partyName',
      'product',
      'firstWeight',
      'secondWeight',
      'firstWeightTime',
      'secondWeightTime',
      'netWeight',
      'bags',
      'lotNumber',
      'entryType',
      'remark',
      'complete',
      'completeCode'
    ]);

    buffer.writeln('\n=== FARMERS TOOLTIPS ===\n');
    _addCategory(buffer, 'Farmers', Tooltips.farmers, [
      'name',
      'type',
      'mobile',
      'gstNumber',
      'email',
      'address',
      'contactPerson',
      'kisanCardNumber',
      'aadhaarNumber',
      'village',
      'district',
      'mandiLicenseNumber',
      'outstandingBalance',
      'isActive'
    ]);

    buffer.writeln('\n=== GENERAL TOOLTIPS ===\n');
    _addCategory(buffer, 'General', Tooltips.general, [
      'search',
      'save',
      'cancel',
      'delete',
      'edit',
      'view',
      'print',
      'export',
      'import',
      'refresh',
      'filter',
      'sort',
      'selectAll',
      'deselectAll',
      'confirm',
      'yes',
      'no',
      'done',
      'close',
      'loading',
      'noData',
      'error',
      'success',
      'required',
      'optional',
      'help'
    ]);

    return buffer.toString();
  }

  static void _addCategory(
      StringBuffer buffer, String category, dynamic obj, List<String> keys) {
    buffer.writeln('[$category]');
    for (final key in keys) {
      try {
        final value = obj[key];
        if (value is String) {
          buffer.writeln('  $key: $value');
        }
      } catch (_) {}
    }
    buffer.writeln();
  }
}
