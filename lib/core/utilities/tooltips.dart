/// Centralized tooltip strings for the entire application.
///
/// Usage:
/// ```dart
/// Tooltip(
///   message: Tooltips.paddyProcurement.grossWeight,
///   child: ...
/// )
/// ```
///
/// Or with the TooltipFormField widget:
/// ```dart
/// TooltipFormField(
///   labelText: 'Gr.Wt',
///   tooltip: Tooltips.paddyProcurement.grossWeight,
///   controller: _grossWtCtrl,
/// )
/// ```

class Tooltips {
  // ──────────────────────────────────────────────────────────────
  // PADDY PROCUREMENT
  // ──────────────────────────────────────────────────────────────

  static const PaddyProcurement paddyProcurement = PaddyProcurement._();

  // ──────────────────────────────────────────────────────────────
  // WEIGHBRIDGE / VEHICLE ENTRY
  // ──────────────────────────────────────────────────────────────

  static const Weighbridge weighbridge = Weighbridge._();

  // ──────────────────────────────────────────────────────────────
  // INVENTORY
  // ──────────────────────────────────────────────────────────────

  static const Inventory inventory = Inventory._();

  // ──────────────────────────────────────────────────────────────
  // MILL RUN
  // ──────────────────────────────────────────────────────────────

  static const MillRun millRun = MillRun._();

  // ──────────────────────────────────────────────────────────────
  // MILLING CHARGES
  // ──────────────────────────────────────────────────────────────

  static const MillingCharges millingCharges = MillingCharges._();

  // ──────────────────────────────────────────────────────────────
  // FARMERS / MANDI
  // ──────────────────────────────────────────────────────────────

  static const Farmers farmers = Farmers._();

  // ──────────────────────────────────────────────────────────────
  // PRODUCTS
  // ──────────────────────────────────────────────────────────────

  static const Products products = Products._();

  // ──────────────────────────────────────────────────────────────
  // GENERAL
  // ──────────────────────────────────────────────────────────────

  static const General general = General._();
}

// ──────────────────────────────────────────────────────────────
// PADDY PROCUREMENT TOOLTIPS
// ──────────────────────────────────────────────────────────────

class PaddyProcurement {
  const PaddyProcurement._();

  // ── Header Section ──
  String get vType =>
      'Bill: For farmer purchases (with pricing)\nChallan: For mandi/government procurement (without pricing)';
  String get date =>
      'Procurement date. Usually the date when paddy is received.';
  String get slipNo =>
      'Auto-generated slip number for tracking this procurement.';
  String get voucherNo =>
      'Voucher number (if any) from the purchase order or reference.';
  String get rstManual =>
      'RST (Rough Slip Ticket) number from the vehicle entry system.\nThis links the procurement to the weighbridge entry.';
  String get area =>
      'Area/Village/Mandi name where the procurement is happening.';

  // ── Party & Vehicle ──
  String get partyName =>
      'Name of the Farmer, Mandi Agent, or Government Agency.';
  String get truckNo => 'Vehicle registration number (e.g., OD15R7734).';
  String get emptyWeight =>
      'Weight of the empty truck (in Kg) for tare weight verification.';
  String get marketType =>
      'FT: Direct Farmer procurement (with pricing)\nMKT: Market/Mandi procurement (without pricing)';
  String get procurementType =>
      'Local: Direct purchase from farmer\nMandi: Government procurement (FCI/PPC/OSCSC)';

  // ── Weighment ──
  String get grossWeight =>
      'Gross weight: Vehicle + Paddy load (in Kg).\nThis is the first weighment when the vehicle arrives loaded.';
  String get tareWeight =>
      'Tare weight: Empty vehicle after unloading (in Kg).\nThis is the second weighment after unloading.';
  String get netWeight =>
      'Net weight: Gross - Tare (in Kg).\nThis is the actual paddy weight before quality deductions.';
  String get juteBags => 'Number of Jute/Gunny bags (J.Pkt).';
  String get plasticBags => 'Number of Plastic bags (P.Pkt).';
  String get totalBags => 'Total bags: Jute + Plastic bags.';
  String get avgBagWeight =>
      'Average weight per bag (Net Weight ÷ Total Bags).\nUsed to verify bag consistency and detect underweight bags.';
  String get gnyWtLess =>
      'Deduct gunny bag weight from net weight?\nGunny bags add to the gross weight.';
  String get bagReturn =>
      'Will empty gunny bags be returned?\nYes = The miller returns the bags.';
  String get otherCut =>
      'Fixed deduction for damaged/bad quality bags (in Kg).';

  // ── Rate & Calculation ──
  String get rateCalculation =>
      'Rate Calculation basis:\nQntl = Rate per Quintal (100 Kg)\nKg = Rate per Kilogram';
  String get kgPerBag =>
      'Standard weight per bag (in Kg).\nTypically 75 Kg or 50 Kg.';
  String get eBag => 'Empty bag weight (in Kg) for bag weight deduction.';
  String get ePkt => 'Empty packet weight (in Kg) for packet weight deduction.';
  String get unloadTime => 'Unloading time (in hours).';

  // ── Product & Pricing (FT only) ──
  String get product => 'Paddy variety (e.g., MOTA, Swarna, etc.).';
  String get productName => 'Name of the paddy variety.';
  String get quantityNew =>
      'New or Old paddy crop.\nN = New (current season)\nY = Old (previous season)';
  String get quantityQntl => 'Quantity in Quintals (1 Qntl = 100 Kg).';
  String get ratePerQntl =>
      'Rate per Quintal (in ₹).\nApplicable only for FT (Farmer) mode.';
  String get totalAmount =>
      'Total amount: Quantity × Rate (in ₹).\nApplicable only for FT (Farmer) mode.';

  // ── Quality Cuts ──
  String get qualityCutName =>
      'Name of the quality issue:\n- Dust & Pol: Dust and polishing waste\n- Other: Broken grains, foreign matter, discolored grains';
  String get qualityCutBagQty =>
      'Quantity of bags affected by this quality issue.';
  String get qualityCutType =>
      'Cut Type:\nPkts = Deduction per bag\nQntl = Deduction per quintal';
  String get qualityCutPerUnit =>
      'Cutting per unit:\n- If Pkts: Deduction in Kg per bag\n- If Qntl: Deduction in Kg per quintal';
  String get qualityCutKg =>
      'Total deduction in Kg (calculated automatically).';
  String get qualityCutRemark => 'Additional remarks for this quality cut.';

  // ── Gunny Tracking ──
  String get gunnyReceive => 'Gunny bags received from the party/vehicle.';
  String get gunnyIssue => 'Gunny bags issued/returned to the party.';
  String get gunnyBagType =>
      'Bag type: J.PKT (Jute), P.PKT (Plastic), REJ (Rejected), OLD (Used), Other';

  // ── Transport ──
  String get deliveryType => 'Delivery Type (e.g., MD = Mandi Delivery).';
  String get truckRentType =>
      'Truck rent calculation basis:\nQntl = Per Quintal\nKg = Per Kilogram';
  String get truckRent =>
      'Truck rent amount:\nPositive = Paid to transporter\nNegative = Received from transporter';
  String get otherAmount =>
      'Other charges:\nPositive = Received\nNegative = Paid';
  String get transportType =>
      'Transport type:\nDirect = Direct transport\nIndirect = Multiple hops';
  String get truckAccount => 'Truck account/company name.';
  String get freightAmount => 'Freight charges (in ₹).';

  // ── Mandi/Government ──
  String get mandiInvoiceNo =>
      'Mandi Invoice Number from the government agency (FCI/PPC/OSCSC).';
  String get tenderNumber => 'Tender/Scheme number for government procurement.';
  String get commissionAgent =>
      'Commission agent handling the mandi procurement.';

  // ── Status ──
  String get status =>
      'Status of the procurement:\nDraft = Not yet finalized\nCompleted = Stock added to inventory\nCancelled = Procurement cancelled';
  String get completeCode =>
      'Auto-generated completion code when procurement is finalized.';
  String get completeDate => 'Date when the procurement was completed.';
}

// ──────────────────────────────────────────────────────────────
// WEIGHBRIDGE TOOLTIPS
// ──────────────────────────────────────────────────────────────

class Weighbridge {
  const Weighbridge._();

  String get entryDate => 'Date of vehicle weighment.';
  String get slipNo => 'Slip number for the vehicle entry.';
  String get voucherNo => 'Voucher number (if any).';
  String get vehicleNo => 'Vehicle registration number (e.g., OD15R7734).';
  String get rstManual => 'Manual RST (Rough Slip Ticket) number.';
  String get partyName => 'Name of the party (farmer, vendor, or company).';
  String get product => 'Product being weighed (Paddy, Rice, Bran, etc.).';
  String get firstWeight =>
      'First weight:\n- Inward: Weight with load (Gross)\n- Outward: Weight empty (Tare)';
  String get secondWeight =>
      'Second weight:\n- Inward: Weight empty (Tare)\n- Outward: Weight with load (Gross)';
  String get firstWeightTime => 'Time of first weighment.';
  String get secondWeightTime => 'Time of second weighment.';
  String get netWeight => 'Net weight (calculated automatically).';
  String get bags => 'Number of bags/packets.';
  String get lotNumber => 'Lot/Batch number for tracking.';
  String get entryType =>
      'Inward: Paddy coming into the mill\nOutward: Rice/Bran/Husk leaving the mill';
  String get remark => 'Additional remarks or notes.';
  String get complete => 'Mark as complete to finalize the vehicle entry.';
  String get completeCode => 'Auto-generated completion code.';
}

// ──────────────────────────────────────────────────────────────
// INVENTORY TOOLTIPS
// ──────────────────────────────────────────────────────────────

class Inventory {
  const Inventory._();

  String get product => 'Product name.';
  String get warehouse => 'Warehouse/Godown where the stock is stored.';
  String get currentStock => 'Current stock quantity in the inventory.';
  String get availableStock => 'Available stock for sale/use.';
  String get lowStockThreshold => 'Low stock threshold for notifications.';
  String get unitCost => 'Average cost per unit.';
  String get stockIn => 'Add stock to inventory.';
  String get stockOut => 'Remove stock from inventory.';
  String get stockAdjustment =>
      'Manual stock adjustment (increase or decrease).';
}

// ──────────────────────────────────────────────────────────────
// MILL RUN TOOLTIPS
// ──────────────────────────────────────────────────────────────

class MillRun {
  const MillRun._();

  String get runDate => 'Date of the milling run.';
  String get paddyProduct => 'Paddy variety being milled.';
  String get paddyConsumed => 'Paddy consumed in the milling run (in Kg).';
  String get outputProduct => 'Output product (Rice, Bran, Husk, Broken Rice).';
  String get outputQuantity => 'Quantity of output product (in Kg).';
  String get outputGrade => 'Grade/Quality of the output product.';
  String get yield => 'Yield percentage (Output ÷ Input × 100).';
  String get warehouse => 'Warehouse/Godown where the milling is happening.';
  String get lotNumber => 'Lot/Batch number from procurement.';
}

// ──────────────────────────────────────────────────────────────
// MILLING CHARGES TOOLTIPS
// ──────────────────────────────────────────────────────────────

class MillingCharges {
  const MillingCharges._();

  String get invoiceNo => 'Milling charge invoice number.';
  String get invoiceDate => 'Invoice date.';
  String get party => 'Customer/Party (Rice party or FCI).';
  String get millRun => 'Completed mill run this invoice is for.';
  String get chargeBasis =>
      'Basis for milling charge:\n- Per Input Quintal\n- Per Output Quintal\n- Per Bag';
  String get billedQty => 'Quantity on which charge is calculated.';
  String get ratePerUnit => 'Base milling charge rate per unit.';
  String get dryingCharge => 'Drying surcharge per unit.';
  String get loadingCharge => 'Loading/Unloading charge per unit.';
  String get baggingCharge => 'Stitching/Bagging charge per unit.';
  String get deduction => 'Contracted deduction per unit.';
  String get gstPercent => 'GST percentage on milling charges.';
  String get tdsPercent => 'TDS percentage on milling charges.';
  String get grossCharge => 'Gross charge before taxes.';
  String get netPayable => 'Net payable after GST and TDS.';
}

// ──────────────────────────────────────────────────────────────
// FARMERS / MANDI TOOLTIPS
// ──────────────────────────────────────────────────────────────

class Farmers {
  const Farmers._();

  String get name => 'Full name of the farmer or mandi agent.';
  String get type =>
      'Farmer: Individual farmer\nMandi Agent: Government/Commission agent';
  String get mobile => 'Mobile phone number.';
  String get gstNumber => 'GST Number (for mandi agents).';
  String get email => 'Email address.';
  String get address => 'Full address.';
  String get contactPerson => 'Contact person name (for mandi agents).';
  String get kisanCardNumber => 'Kisan Card Number (for farmers).';
  String get aadhaarNumber => 'Aadhaar Number (for farmers).';
  String get village => 'Village name (for farmers).';
  String get district => 'District name (for farmers).';
  String get mandiLicenseNumber => 'Mandi License Number (for mandi agents).';
  String get outstandingBalance => 'Outstanding balance (due amount).';
  String get isActive => 'Active or inactive record.';
}

// ──────────────────────────────────────────────────────────────
// PRODUCTS TOOLTIPS
// ──────────────────────────────────────────────────────────────

class Products {
  const Products._();

  String get name => 'Product name.';
  String get productCode => 'Unique product code for identification.';
  String get barcode => 'Barcode for scanning.';
  String get category => 'Product category.';
  String get purchasePrice => 'Purchase price (cost price).';
  String get sellingPrice => 'Selling price (retail price).';
  String get mrp => 'Maximum Retail Price.';
  String get taxPercent => 'Tax/GST percentage.';
  String get unit => 'Unit of measurement (piece, kg, liter, etc.).';
}

// ──────────────────────────────────────────────────────────────
// GENERAL TOOLTIPS
// ──────────────────────────────────────────────────────────────

class General {
  const General._();

  String get search => 'Search by name, code, or barcode.';
  String get save => 'Save the current form/record.';
  String get cancel => 'Cancel and discard changes.';
  String get delete => 'Delete this record (cannot be undone).';
  String get edit => 'Edit this record.';
  String get view => 'View details.';
  String get print => 'Print this document.';
  String get export => 'Export data.';
  String get import => 'Import data from file.';
  String get refresh => 'Refresh data.';
  String get filter => 'Filter results.';
  String get sort => 'Sort results.';
  String get selectAll => 'Select all items.';
  String get deselectAll => 'Deselect all items.';
  String get confirm => 'Confirm action.';
  String get yes => 'Yes, proceed.';
  String get no => 'No, cancel.';
  String get done => 'Done.';
  String get close => 'Close this dialog.';
  String get loading => 'Loading data, please wait.';
  String get noData => 'No data found.';
  String get error => 'An error occurred.';
  String get success => 'Operation completed successfully.';
  String get required => 'This field is required.';
  String get optional => 'This field is optional.';
  String get help => 'Need help? Click here for guidance.';
}
