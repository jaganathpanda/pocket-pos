import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pocket_pos/core/utilities/tooltips.dart';
import 'package:pocket_pos/core/widgets/DatePickerField.dart';
import 'package:pocket_pos/core/widgets/tooltip_form_field.dart';
import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../domain/paddy_procurement.dart';
import '../providers/paddy_procurement_providers.dart';

class PaddyProcurementForm extends ConsumerStatefulWidget {
  const PaddyProcurementForm({super.key, this.procurementId});

  final int? procurementId;

  @override
  ConsumerState<PaddyProcurementForm> createState() =>
      _PaddyProcurementFormState();
}

class _PaddyProcurementFormState extends ConsumerState<PaddyProcurementForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEdit = false;

  // ── Controllers ──
  late TextEditingController _dateCtrl;
  late TextEditingController _slipNoCtrl;
  late TextEditingController _voucherCtrl;
  late TextEditingController _rstCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _partyCtrl;
  late TextEditingController _truckCtrl;
  late TextEditingController _emptyWtCtrl;
  late TextEditingController _grossWtCtrl;
  late TextEditingController _tareWtCtrl;
  late TextEditingController _juteBagsCtrl;
  late TextEditingController _plasticBagsCtrl;
  late TextEditingController _otherCutCtrl;
  late TextEditingController _unloadCtrl;
  late TextEditingController _eBagCtrl;
  late TextEditingController _ePktCtrl;
  late TextEditingController _productCtrl;
  late TextEditingController _quantityQntlCtrl;
  late TextEditingController _ratePerQntlCtrl;
  late TextEditingController _deliveryTypeCtrl;
  late TextEditingController _truckRentCtrl;
  late TextEditingController _otherAmountCtrl;
  late TextEditingController _freightCtrl;
  late TextEditingController _mandiInvoiceCtrl;
  late TextEditingController _tenderCtrl;
  late TextEditingController _commissionAgentCtrl;
  late TextEditingController _weighbridgeImportCtrl;

  // ── Selected Values ──
  DateTime _date = DateTime.now();
  String _vType = 'BILL';
  String _marketType = 'FT';
  String _rateCalculation = 'Qntl';
  String _procurementType = 'local';
  int? _selectedProductId;
  int? _selectedPartyId;
  int? _selectedWarehouseId;
  bool _gnyWtLess = false;
  bool _bagReturn = false;

  // ── Quality Cuts ──
  List<QualityCut> _qualityCuts = [];
  final List<QualityCut> _deletedCuts = [];

  // ── Gunny Transactions ──
  List<GunnyTransaction> _gunnyTransactions = [];

  // ── Weighbridge Import ──
  int? _selectedVehicleEntryId;
  bool _showWeighbridgeImport = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _isEdit = widget.procurementId != null;
    if (_isEdit) {
      _loadProcurement();
    } else {
      _setDefaults();
      _addDefaultQualityCut();
      _initGunnyTransactions();
    }
  }

  void _initControllers() {
    _dateCtrl = TextEditingController();
    _slipNoCtrl = TextEditingController();
    _voucherCtrl = TextEditingController();
    _rstCtrl = TextEditingController();
    _areaCtrl = TextEditingController();
    _partyCtrl = TextEditingController();
    _truckCtrl = TextEditingController();
    _emptyWtCtrl = TextEditingController();
    _grossWtCtrl = TextEditingController();
    _tareWtCtrl = TextEditingController();
    _juteBagsCtrl = TextEditingController();
    _plasticBagsCtrl = TextEditingController();
    _otherCutCtrl = TextEditingController();
    _unloadCtrl = TextEditingController();
    _eBagCtrl = TextEditingController();
    _ePktCtrl = TextEditingController();
    _productCtrl = TextEditingController();
    _quantityQntlCtrl = TextEditingController();
    _ratePerQntlCtrl = TextEditingController();
    _deliveryTypeCtrl = TextEditingController(text: 'MD');
    _truckRentCtrl = TextEditingController();
    _otherAmountCtrl = TextEditingController();
    _freightCtrl = TextEditingController();
    _mandiInvoiceCtrl = TextEditingController();
    _tenderCtrl = TextEditingController();
    _commissionAgentCtrl = TextEditingController();
    _weighbridgeImportCtrl = TextEditingController();
  }

  void _setDefaults() {
    _date = DateTime.now();
    _dateCtrl.text = DateFormat('dd/MM/yyyy').format(_date);
    _slipNoCtrl.text = _generateSlipNo();
    _voucherCtrl.text = '399';
    _rstCtrl.text = '112';
    _areaCtrl.text = 'MADHAPUR';
    _deliveryTypeCtrl.text = 'MD';
    _truckRentCtrl.text = '0.00';
    _otherAmountCtrl.text = '0.00';
    _freightCtrl.text = '0.00';
    _eBagCtrl.text = '0.700';
    _ePktCtrl.text = '0.100';
    _unloadCtrl.text = '3.00';
    _otherCutCtrl.text = '0';
    _selectedWarehouseId = _getDefaultWarehouse();
  }

  int _getDefaultWarehouse() {
    final warehouses = ref.read(warehousesProvider).valueOrNull ?? [];
    return warehouses
        .firstWhere(
          (w) => w.isDefault,
          orElse: () => warehouses.isNotEmpty
              ? warehouses.first
              : Warehouse(
                  id: 0,
                  name: 'Default',
                  isDefault: true,
                  isActive: true,
                  createdAt: DateTime.now()),
        )
        .id;
  }

  String _generateSlipNo() {
    final now = DateTime.now();
    return 'A/${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  void _addDefaultQualityCut() {
    _qualityCuts = [
      const QualityCut(
        sl: 1,
        qualityName: 'Dust & Pol',
        bagQuantity: 0,
        cutType: 'Pkts',
        cutPerUnit: 1.00,
        difference: 1.00,
        cutQuantityKg: 0,
        remark: '',
      ),
      const QualityCut(
        sl: 2,
        qualityName: 'Other',
        bagQuantity: 0,
        cutType: 'Qntl',
        cutPerUnit: 3.00,
        difference: 3.00,
        cutQuantityKg: 0,
        remark: '',
      ),
    ];
  }

  void _initGunnyTransactions() {
    _gunnyTransactions = [
      const GunnyTransaction(bagType: 'J.PKT', receivedQty: 0, issuedQty: 0),
      const GunnyTransaction(bagType: 'P.PKT', receivedQty: 0, issuedQty: 0),
      const GunnyTransaction(bagType: 'REJ', receivedQty: 0, issuedQty: 0),
      const GunnyTransaction(bagType: 'OLD', receivedQty: 0, issuedQty: 0),
      const GunnyTransaction(bagType: 'Other', receivedQty: 0, issuedQty: 0),
    ];
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _slipNoCtrl.dispose();
    _voucherCtrl.dispose();
    _rstCtrl.dispose();
    _areaCtrl.dispose();
    _partyCtrl.dispose();
    _truckCtrl.dispose();
    _emptyWtCtrl.dispose();
    _grossWtCtrl.dispose();
    _tareWtCtrl.dispose();
    _juteBagsCtrl.dispose();
    _plasticBagsCtrl.dispose();
    _otherCutCtrl.dispose();
    _unloadCtrl.dispose();
    _eBagCtrl.dispose();
    _ePktCtrl.dispose();
    _productCtrl.dispose();
    _quantityQntlCtrl.dispose();
    _ratePerQntlCtrl.dispose();
    _deliveryTypeCtrl.dispose();
    _truckRentCtrl.dispose();
    _otherAmountCtrl.dispose();
    _freightCtrl.dispose();
    _mandiInvoiceCtrl.dispose();
    _tenderCtrl.dispose();
    _commissionAgentCtrl.dispose();
    _weighbridgeImportCtrl.dispose();
    super.dispose();
  }

  // ── Load Existing Procurement ──
  Future<void> _loadProcurement() async {
    final procurement =
        await ref.read(paddyProcurementProvider(widget.procurementId!).future);
    if (procurement == null) return;

    setState(() {
      _date = procurement.date;
      _dateCtrl.text = DateFormat('dd/MM/yyyy').format(_date);
      _slipNoCtrl.text = procurement.slipNo;
      _voucherCtrl.text = procurement.voucherNo ?? '';
      _rstCtrl.text = procurement.rstManual ?? '';
      _areaCtrl.text = procurement.area ?? '';
      _partyCtrl.text = procurement.partyName;
      _selectedPartyId = procurement.partyId;
      _truckCtrl.text = procurement.truckNo ?? '';
      _emptyWtCtrl.text = procurement.emptyWeight?.toString() ?? '';
      _grossWtCtrl.text = procurement.grossWeight?.toString() ?? '';
      _tareWtCtrl.text = procurement.tareWeight?.toString() ?? '';
      _juteBagsCtrl.text = procurement.juteBags?.toString() ?? '';
      _plasticBagsCtrl.text = procurement.plasticBags?.toString() ?? '';
      _otherCutCtrl.text = procurement.otherCut?.toString() ?? '0';
      _unloadCtrl.text = procurement.unloadTime?.toString() ?? '3.00';
      _eBagCtrl.text = procurement.eBag?.toString() ?? '0.700';
      _ePktCtrl.text = procurement.ePkt?.toString() ?? '0.100';
      _selectedProductId = procurement.productId;
      _productCtrl.text = procurement.productName ?? '';
      _quantityQntlCtrl.text = procurement.quantityQntl?.toString() ?? '';
      _ratePerQntlCtrl.text = procurement.ratePerQntl?.toString() ?? '';
      _deliveryTypeCtrl.text = procurement.deliveryType ?? 'MD';
      _truckRentCtrl.text = procurement.truckRent?.toString() ?? '0.00';
      _otherAmountCtrl.text = procurement.otherAmount?.toString() ?? '0.00';
      _freightCtrl.text = procurement.freightAmount?.toString() ?? '0.00';
      _vType = procurement.vType ?? 'BILL';
      _marketType = procurement.marketType ?? 'FT';
      _rateCalculation = procurement.rateCalculation ?? 'Qntl';
      _gnyWtLess = procurement.gnyWtLess ?? false;
      _bagReturn = procurement.bagReturn ?? false;
      _selectedWarehouseId = procurement.warehouseId;
      _qualityCuts = List.from(procurement.qualityCuts ?? []);
      _gunnyTransactions = List.from(procurement.gunnyTransactions ?? []);
      _mandiInvoiceCtrl.text = procurement.mandiInvoiceNo ?? '';
      _tenderCtrl.text = procurement.tenderNumber ?? '';
      _commissionAgentCtrl.text =
          procurement.commissionAgentId?.toString() ?? '';
    });
  }

  // ── Calculation Methods (All in Quintals) ──

  double get grossWeight => double.tryParse(_grossWtCtrl.text) ?? 0;
  double get tareWeight => double.tryParse(_tareWtCtrl.text) ?? 0;
  double get netWeightKg => grossWeight - tareWeight;
  double get netWeightQntl => netWeightKg / 100;

  int get totalBags =>
      (int.tryParse(_juteBagsCtrl.text) ?? 0) +
      (int.tryParse(_plasticBagsCtrl.text) ?? 0);
  double get avgBagWeight => totalBags > 0 ? netWeightKg / totalBags : 0;

  double get totalCutKg {
    return _qualityCuts.fold<double>(0, (sum, cut) => sum + cut.cutQuantityKg);
  }

  double get finalWeightKg => netWeightKg - totalCutKg;
  double get finalWeightQntl => finalWeightKg / 100;

  double get quantityQntl => double.tryParse(_quantityQntlCtrl.text) ?? 0;
  double get ratePerQntl => double.tryParse(_ratePerQntlCtrl.text) ?? 0;
  double get totalAmount => quantityQntl * ratePerQntl;

  bool get isFTMode => _marketType == 'FT';

  void _updateCalculations() {
    setState(() {
      // Auto-calculate based on entered values
    });
  }

  // ── Weighbridge Import ──
  Future<void> _importFromWeighbridge(String slipNo) async {
    try {
      final entries = await ref.read(vehicleEntriesStreamProvider.future);
      final entry = entries.firstWhere(
        (e) => e.slipNo == slipNo,
        orElse: () => throw Exception('Vehicle entry not found'),
      );

      setState(() {
        _date = entry.date;
        _dateCtrl.text = DateFormat('dd/MM/yyyy').format(_date);
        _truckCtrl.text = entry.vehicleNo;
        _rstCtrl.text = entry.rstManual ?? '';
        _grossWtCtrl.text = entry.firstWeight.toString();
        _tareWtCtrl.text = entry.secondWeight.toString();
        _juteBagsCtrl.text = (entry.bags ?? 0).toString();
        _selectedProductId = entry.productId;
        _selectedPartyId = entry.partyId;
        _partyCtrl.text = entry.partyName;
        _selectedVehicleEntryId = entry.id;
      });

      _updateCalculations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Imported from vehicle entry #${entry.slipNo}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ── Quality Cuts ──
  void _addQualityCut() {
    setState(() {
      _qualityCuts.add(QualityCut(
        sl: _qualityCuts.length + 1,
        qualityName: '',
        bagQuantity: 0,
        cutType: 'Pkts',
        cutPerUnit: 1.00,
        difference: 1.00,
        cutQuantityKg: 0,
        remark: '',
      ));
    });
  }

  void _removeQualityCut(int index) {
    setState(() {
      if (_qualityCuts[index].id != null) {
        _deletedCuts.add(_qualityCuts[index]);
      }
      _qualityCuts.removeAt(index);
      // Re-index
      for (var i = 0; i < _qualityCuts.length; i++) {
        _qualityCuts[i] = _qualityCuts[i].copyWith(sl: i + 1);
      }
    });
  }

  void _updateCutQuantity(int index) {
    setState(() {
      final cut = _qualityCuts[index];
      double newCutQuantityKg;

      if (cut.cutType == 'Pkts') {
        newCutQuantityKg = cut.bagQuantity * cut.cutPerUnit;
      } else {
        // Qntl case - convert to Kg
        newCutQuantityKg = cut.bagQuantity * cut.cutPerUnit * 100; // Qntl to Kg
      }

      _qualityCuts[index] = cut.copyWith(
        cutQuantityKg: newCutQuantityKg,
        difference: cut.cutPerUnit,
      );
    });
  }

  // ── Save ──
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a product.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final companion = PaddyProcurementCompanion(
        id: widget.procurementId,
        date: _date,
        slipNo: _slipNoCtrl.text.trim(),
        voucherNo:
            _voucherCtrl.text.trim().isEmpty ? null : _voucherCtrl.text.trim(),
        rstManual: _rstCtrl.text.trim().isEmpty ? null : _rstCtrl.text.trim(),
        area: _areaCtrl.text.trim().isEmpty ? null : _areaCtrl.text.trim(),
        vType: _vType,
        partyName: _partyCtrl.text.trim(),
        partyId: _selectedPartyId,
        truckNo: _truckCtrl.text.trim(),
        emptyWeight: double.tryParse(_emptyWtCtrl.text.trim()) ?? 0,
        grossWeight: grossWeight,
        tareWeight: tareWeight,
        juteBags: int.tryParse(_juteBagsCtrl.text.trim()) ?? 0,
        plasticBags: int.tryParse(_plasticBagsCtrl.text.trim()) ?? 0,
        totalBags: totalBags,
        avgBagWeight: avgBagWeight,
        gnyWtLess: _gnyWtLess,
        bagReturn: _bagReturn,
        otherCut: double.tryParse(_otherCutCtrl.text.trim()) ?? 0,
        unloadTime: double.tryParse(_unloadCtrl.text.trim()) ?? 3.00,
        eBag: double.tryParse(_eBagCtrl.text.trim()) ?? 0.700,
        ePkt: double.tryParse(_ePktCtrl.text.trim()) ?? 0.100,
        netWeight: netWeightKg,
        rateCalculation: _rateCalculation,
        kgPerBag: 75,
        productId: _selectedProductId!,
        productName: _productCtrl.text.trim(),
        quantityNew: 'N',
        quantityQntl: isFTMode ? quantityQntl : finalWeightQntl,
        ratePerQntl: isFTMode ? ratePerQntl : 0,
        totalAmount: isFTMode ? totalAmount : 0,
        avgRate: isFTMode ? ratePerQntl : 0,
        avgAmount: 0,
        qrtCutAmt: 0,
        paddyAmt: isFTMode ? totalAmount : 0,
        qualityCuts: _qualityCuts,
        totalCutKg: totalCutKg,
        finalWeight: finalWeightKg,
        gunnyTransactions: _gunnyTransactions,
        deliveryType: _deliveryTypeCtrl.text.trim(),
        truckRentType: 'Qntl',
        truckRent: double.tryParse(_truckRentCtrl.text.trim()) ?? 0,
        truckRentPaid: double.tryParse(_truckRentCtrl.text.trim()) ?? 0,
        otherAmount: double.tryParse(_otherAmountCtrl.text.trim()) ?? 0,
        transportType: 'Direct',
        truckAccount: 'none',
        freightAmount: double.tryParse(_freightCtrl.text.trim()) ?? 0,
        procurementType: _procurementType,
        mandiInvoiceNo: _mandiInvoiceCtrl.text.trim().isEmpty
            ? null
            : _mandiInvoiceCtrl.text.trim(),
        tenderNumber:
            _tenderCtrl.text.trim().isEmpty ? null : _tenderCtrl.text.trim(),
        commissionAgentId: _selectedPartyId,
        warehouseId: _selectedWarehouseId ?? _getDefaultWarehouse(),
        remainingStock: finalWeightKg,
        status: 'draft',
      );

      final repo = ref.read(paddyProcurementRepositoryProvider);
      if (widget.procurementId == null) {
        await repo.createProcurement(companion);
      } else {
        await repo.updateProcurement(companion);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Procurement saved successfully.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Complete (Stock-in to Inventory) ──
  Future<void> _completeProcurement() async {
    if (widget.procurementId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save the procurement first.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Procurement'),
        content: const Text('This will add the paddy to inventory. '
            'Quantity will be after quality cuts. '
            'This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(paddyProcurementRepositoryProvider)
          .completeProcurement(widget.procurementId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Procurement completed! Stock updated.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final products =
        ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final suppliers =
        ref.watch(suppliersProvider).valueOrNull ?? const <Supplier>[];
    final paddyProducts = products
        .where((p) =>
            p.name.toLowerCase().contains('paddy') ||
            p.name.toLowerCase().contains('mota'))
        .toList();
    final allProducts = paddyProducts.isNotEmpty ? paddyProducts : products;

    final netWtKg = netWeightKg;
    final netWtQntl = netWtKg / 100;
    final totalCut = totalCutKg;
    final finalWtKg = finalWeightKg;
    final finalWtQntl = finalWtKg / 100;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(_isEdit ? 'Edit Paddy Procurement' : 'New Paddy Procurement'),
        actions: [
          if (_isEdit && widget.procurementId != null)
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Complete',
              onPressed: _isLoading ? null : _completeProcurement,
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── SECTION 1: Header ──
                    _buildHeaderSection(),
                    const SizedBox(height: 12),

                    // ── SECTION 2: Weighbridge Import ──
                    _buildWeighbridgeImportSection(),
                    const SizedBox(height: 12),

                    // ── SECTION 3: Party & Vehicle ──
                    _buildPartyVehicleSection(suppliers),
                    const SizedBox(height: 12),

                    // ── SECTION 4: Weighment ──
                    _buildWeighmentSection(),
                    const SizedBox(height: 12),

                    // ── SECTION 5: Net & Rate ──
                    _buildNetRateSection(),
                    const SizedBox(height: 12),

                    // ── SECTION 6: Product & Pricing (FT only) ──
                    if (isFTMode) _buildProductPricingSection(allProducts),
                    if (isFTMode) const SizedBox(height: 12),

                    // ── SECTION 7: Quality Cuts ──
                    _buildQualityCutsSection(),
                    const SizedBox(height: 12),

                    // ── SECTION 8: Gunny Tracking ──
                    _buildGunnySection(),
                    const SizedBox(height: 12),

                    // ── SECTION 9: Transport ──
                    _buildTransportSection(),
                    const SizedBox(height: 20),

                    // ── Actions ──
                    _buildActions(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Section Builders ──

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _vType,
                  decoration: const InputDecoration(
                    labelText: 'V.Type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'BILL', child: Text('BILL')),
                    DropdownMenuItem(value: 'CHALLAN', child: Text('CHALLAN')),
                  ],
                  onChanged: (v) => setState(() => _vType = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DatePickerField(
                  date: _date,
                  onDatePicked: (d) => setState(() => _date = d),
                  tooltip: Tooltips.paddyProcurement.date,
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _slipNoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Slip No',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) =>
                      v?.trim().isNotEmpty == true ? null : 'Required',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _rstCtrl,
                  decoration: const InputDecoration(
                    labelText: 'RST(Manual)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _areaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Area',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _voucherCtrl,
                  decoration: const InputDecoration(
                    labelText: 'V.No',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _marketType,
                  decoration: const InputDecoration(
                    labelText: 'MKT/FT',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'FT', child: Text('🌾 FT - Farmer')),
                    DropdownMenuItem(
                        value: 'MKT', child: Text('🏪 MKT - Market')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _marketType = v!;
                      if (v == 'MKT') {
                        _ratePerQntlCtrl.text = '0.00';
                        _quantityQntlCtrl.text = '0.00';
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _procurementType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'local', child: Text('Local')),
                    DropdownMenuItem(
                        value: 'mandi', child: Text('Mandi/ Govt')),
                  ],
                  onChanged: (v) => setState(() => _procurementType = v!),
                ),
              ),
            ],
          ),
          if (_procurementType == 'mandi') ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _mandiInvoiceCtrl,
              decoration: const InputDecoration(
                labelText: 'Mandi Invoice No',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _tenderCtrl,
              decoration: const InputDecoration(
                labelText: 'Tender / Scheme',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeighbridgeImportSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.import_export_rounded, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Import from Vehicle Entry',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(
                    () => _showWeighbridgeImport = !_showWeighbridgeImport),
                child: Text(_showWeighbridgeImport ? 'Hide' : 'Show'),
              ),
            ],
          ),
          if (_showWeighbridgeImport) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weighbridgeImportCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Enter Vehicle Entry Slip No to import',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 18),
                      hintText: 'e.g. A/2024-1234 or 2301-5678',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    final slipNo = _weighbridgeImportCtrl.text.trim();
                    if (slipNo.isNotEmpty) {
                      _importFromWeighbridge(slipNo);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter a slip number.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Import'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tip: Enter the RST(Manual) or Slip No from the vehicle entry.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPartyVehicleSection(List<Supplier> suppliers) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Autocomplete<Supplier>(
            optionsBuilder: (text) {
              if (text.text.isEmpty) return const Iterable.empty();
              return suppliers.where((s) =>
                  s.name.toLowerCase().contains(text.text.toLowerCase()) ||
                  (s.mobile ?? '').contains(text.text));
            },
            onSelected: (s) {
              setState(() {
                _selectedPartyId = s.id;
                _partyCtrl.text = s.name;
              });
            },
            fieldViewBuilder: (ctx, ctrl, node, onEditingComplete) {
              return TextFormField(
                controller: _partyCtrl,
                focusNode: node,
                decoration: const InputDecoration(
                  labelText: 'Party Name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (v) =>
                    v?.trim().isNotEmpty == true ? null : 'Required',
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _truckCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Truck No',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _emptyWtCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Empty Wt',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _updateCalculations(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeighmentSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TooltipFormField(
                  labelText: 'Gr.Wt',
                  tooltip: Tooltips.paddyProcurement.grossWeight,
                  controller: _grossWtCtrl,
                  keyboardType: TextInputType.number,
                  isRequired: true,
                  onChanged: (_) => _updateCalculations(),
                  validator: (v) =>
                      v?.trim().isNotEmpty == true ? null : 'Required',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TooltipFormField(
                  labelText: 'Tr.Wt',
                  tooltip: Tooltips.paddyProcurement.tareWeight,
                  controller: _tareWtCtrl,
                  keyboardType: TextInputType.number,
                  isRequired: true,
                  onChanged: (_) => _updateCalculations(),
                  validator: (v) =>
                      v?.trim().isNotEmpty == true ? null : 'Required',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TooltipFormField(
                  labelText: 'J.Pkt',
                  tooltip: Tooltips.paddyProcurement.juteBags,
                  controller: _juteBagsCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _updateCalculations(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TooltipFormField(
                  labelText: 'P.Pkt',
                  tooltip: Tooltips.paddyProcurement.plasticBags,
                  controller: _plasticBagsCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _updateCalculations(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Total Pkt: ${totalBags.toString()}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Gny Wt(Less)'),
                  value: _gnyWtLess,
                  onChanged: (v) => setState(() => _gnyWtLess = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bag Rtn'),
                  value: _bagReturn,
                  onChanged: (v) => setState(() => _bagReturn = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TooltipFormField(
                  labelText: 'Other Cut',
                  tooltip: Tooltips.paddyProcurement.otherCut,
                  controller: _otherCutCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNetRateSection() {
    final netWtKg = netWeightKg;
    final netWtQntl = netWtKg / 100;
    final avgBagWt = avgBagWeight;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nett.Wt: ${netWtKg.toStringAsFixed(2)} kg',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Expanded(
                child: Text(
                  'Avg Wt/Pkt: ${avgBagWt.toStringAsFixed(4)} kg',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _rateCalculation,
                  decoration: const InputDecoration(
                    labelText: 'Rate Calculation',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Qntl', child: Text('Qntl')),
                    DropdownMenuItem(value: 'Kg', child: Text('Kg')),
                  ],
                  onChanged: (v) => setState(() => _rateCalculation = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _eBagCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'E Bag',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _unloadCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Unload',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _ePktCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'E Pkt',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductPricingSection(List<Product> products) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedProductId,
                  decoration: const InputDecoration(
                    labelText: 'Product',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final p in products)
                      DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) => setState(() {
                    _selectedProductId = v;
                    final product = products.firstWhere((p) => p.id == v);
                    _productCtrl.text = product.name;
                  }),
                  validator: (v) => v != null ? null : 'Required',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _quantityQntlCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Qntls',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _updateCalculations(),
                  validator: (v) =>
                      v?.trim().isNotEmpty == true ? null : 'Required',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ratePerQntlCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Rate / Qntl',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _updateCalculations(),
                  validator: (v) =>
                      v?.trim().isNotEmpty == true ? null : 'Required',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Total: ₹${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          if (isFTMode) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('Avg Rate: ${ratePerQntl.toStringAsFixed(4)}'),
                ),
                Expanded(
                  child: Text('Paddy Amt: ₹${totalAmount.toStringAsFixed(2)}'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQualityCutsSection() {
    final totalCut = totalCutKg;
    final finalWt = finalWeightKg;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Quality Cuts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text('Cut Type: Kg    Free/Pack: (0.00)'),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 8,
              columns: const [
                DataColumn(
                    label: Text('SL',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Quality Cut',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Qty(Pkts)',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Cut Type',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Cut/Pkt',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Diff.',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Cut(Kg)',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Rmk',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: [
                for (var i = 0; i < _qualityCuts.length; i++)
                  DataRow(cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(
                      TextFormField(
                        initialValue: _qualityCuts[i].qualityName,
                        onChanged: (v) {
                          setState(() {
                            _qualityCuts[i] =
                                _qualityCuts[i].copyWith(qualityName: v);
                          });
                        },
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(
                      TextFormField(
                        initialValue: _qualityCuts[i].bagQuantity.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final qty = double.tryParse(v) ?? 0;
                          setState(() {
                            _qualityCuts[i] =
                                _qualityCuts[i].copyWith(bagQuantity: qty);
                            _updateCutQuantity(i);
                          });
                        },
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(
                      DropdownButton<String>(
                        value: _qualityCuts[i].cutType,
                        items: const [
                          DropdownMenuItem(
                              value: 'Pkts',
                              child:
                                  Text('Pkts', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(
                              value: 'Qntl',
                              child:
                                  Text('Qntl', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _qualityCuts[i] =
                                _qualityCuts[i].copyWith(cutType: v!);
                            _updateCutQuantity(i);
                          });
                        },
                        underline: const SizedBox(),
                      ),
                    ),
                    DataCell(
                      TextFormField(
                        initialValue: _qualityCuts[i].cutPerUnit.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final cut = double.tryParse(v) ?? 0;
                          setState(() {
                            _qualityCuts[i] =
                                _qualityCuts[i].copyWith(cutPerUnit: cut);
                            _updateCutQuantity(i);
                          });
                        },
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        _qualityCuts[i].difference.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        _qualityCuts[i].cutQuantityKg.toStringAsFixed(2),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                    DataCell(
                      TextFormField(
                        initialValue: _qualityCuts[i].remark,
                        onChanged: (v) {
                          setState(() {
                            _qualityCuts[i] =
                                _qualityCuts[i].copyWith(remark: v);
                          });
                        },
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 16, color: Colors.red),
                        onPressed: _qualityCuts.length > 1
                            ? () => _removeQualityCut(i)
                            : null,
                      ),
                    ),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _addQualityCut,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add More'),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    Text('Quality Cut (Kg)'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('Total Cut: ${totalCut.toStringAsFixed(2)}'),
                        const SizedBox(width: 16),
                        Text('Final Wt: ${finalWt.toStringAsFixed(2)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGunnySection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Empty Gunny Transaction: Free Purchase',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 8,
              columns: const [
                DataColumn(
                    label: Text('Qlt:',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('J.PKT',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('P.PKT',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('REJ',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('OLD',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Other',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Total Receive',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('J.PKT',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('P.PKT',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('REJ',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('OLD',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Other',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Total Issue',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: [
                DataRow(cells: [
                  const DataCell(Text('Receive',
                      style: TextStyle(fontWeight: FontWeight.w500))),
                  ..._gunnyTransactions.map((g) => DataCell(
                        TextFormField(
                          initialValue: g.receivedQty.toString(),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final qty = int.tryParse(v) ?? 0;
                            final index = _gunnyTransactions.indexOf(g);
                            setState(() {
                              _gunnyTransactions[index] =
                                  g.copyWith(receivedQty: qty);
                            });
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      )),
                  DataCell(
                    Text(
                      _gunnyTransactions
                          .fold<int>(0, (sum, g) => sum + (g.receivedQty ?? 0))
                          .toString(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  ..._gunnyTransactions.map((g) => DataCell(
                        TextFormField(
                          initialValue: g.issuedQty.toString(),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final qty = int.tryParse(v) ?? 0;
                            final index = _gunnyTransactions.indexOf(g);
                            setState(() {
                              _gunnyTransactions[index] =
                                  g.copyWith(issuedQty: qty);
                            });
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      )),
                  DataCell(
                    Text(
                      _gunnyTransactions
                          .fold<int>(0, (sum, g) => sum + (g.issuedQty ?? 0))
                          .toString(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _deliveryTypeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Del Type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: 'Qntl',
                  decoration: const InputDecoration(
                    labelText: 'Truck Rent Type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Qntl', child: Text('Qntl')),
                    DropdownMenuItem(value: 'Kg', child: Text('Kg')),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _truckRentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'T.Rent Receive(+)/Paid(-)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _otherAmountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '(±)Oth Amt',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: 'Direct',
                  decoration: const InputDecoration(
                    labelText: 'Transport Type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Direct', child: Text('Direct')),
                    DropdownMenuItem(
                        value: 'Indirect', child: Text('Indirect')),
                  ],
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _freightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Frt Amt',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        if (_isEdit) ...[
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Update'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _isLoading ? null : _completeProcurement,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Complete'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: _isLoading ? null : _save,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, size: 18),
            label: const Text('Save Draft'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _isLoading
                ? null
                : () async {
                    await _save();
                    if (mounted && widget.procurementId != null) {
                      await _completeProcurement();
                    }
                  },
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Save & Complete'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ],
    );
  }
}
