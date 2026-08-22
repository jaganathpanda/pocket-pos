// ── lib/features/paddy_procurement/paddy_procurement_form.dart ──

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// tooltips.dart also declares a `PaddyProcurement` class; hide it so the bare
// name resolves to the domain model below.
import 'package:pocket_pos/core/utilities/tooltips.dart' hide PaddyProcurement;
import 'package:pocket_pos/core/widgets/DatePickerField.dart';
import 'package:pocket_pos/core/widgets/help_dialog.dart';
import 'package:pocket_pos/core/widgets/tooltip_form_field.dart';
import 'package:pocket_pos/core/widgets/tooltip_icon.dart';
import 'package:pocket_pos/features/paddy_procurement/domain/paddy_procurement.dart';
import 'package:pocket_pos/features/paddy_procurement/providers/paddy_procurement_providers.dart';

class PaddyProcurementForm extends ConsumerStatefulWidget {
  const PaddyProcurementForm({super.key, this.procurementId});

  final int? procurementId;

  @override
  ConsumerState<PaddyProcurementForm> createState() =>
      _PaddyProcurementFormState();
}

class _PaddyProcurementFormState extends ConsumerState<PaddyProcurementForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _partyNameCtrl;
  late final TextEditingController _slipNoCtrl;
  late final TextEditingController _vehicleNoCtrl;
  late final TextEditingController _grossWtCtrl;
  late final TextEditingController _tareWtCtrl;
  late final TextEditingController _jutePktCtrl;
  late final TextEditingController _plasticPktCtrl;
  late final TextEditingController _ratePerQntlCtrl;
  late final TextEditingController _dustCutCtrl;
  late final TextEditingController _polCutCtrl;
  late final TextEditingController _otherCutCtrl;
  late final TextEditingController _gunnyWtLessCtrl;
  late final TextEditingController _totalAmountCtrl;

  DateTime _date = DateTime.now();
  String _procurementType = 'Kharif';
  String _marketType = 'MKT';
  String _bagReturn = 'No';
  String _qualityGrade = 'A';
  String _vType = 'Bill';
  String _rateCalculation = 'Qntl';
  String _quantityNew = 'N';
  String _deliveryType = 'MD';
  String _truckRentType = 'Qntl';
  String _transportType = 'Direct';
  bool _isLoading = false;
  int? _editingId;

  // Available options
  final List<String> _procurementTypes = ['Kharif', 'Rabi', 'Summer'];
  final List<String> _marketTypes = ['MKT', 'FT'];
  final List<String> _bagReturnOptions = ['Yes', 'No'];
  final List<String> _qualityGrades = ['A', 'B', 'C', 'D'];
  final List<String> _vTypeOptions = ['Bill', 'Challan'];
  final List<String> _rateCalcOptions = ['Qntl', 'Kg'];
  final List<String> _quantityNewOptions = ['N', 'Y'];
  final List<String> _deliveryTypeOptions = ['MD', 'Local', 'Direct'];
  final List<String> _truckRentTypeOptions = ['Qntl', 'Kg'];
  final List<String> _transportTypeOptions = ['Direct', 'Indirect'];

  @override
  void initState() {
    super.initState();
    _partyNameCtrl = TextEditingController();
    _slipNoCtrl = TextEditingController();
    _vehicleNoCtrl = TextEditingController();
    _grossWtCtrl = TextEditingController();
    _tareWtCtrl = TextEditingController();
    _jutePktCtrl = TextEditingController();
    _plasticPktCtrl = TextEditingController();
    _ratePerQntlCtrl = TextEditingController();
    _dustCutCtrl = TextEditingController();
    _polCutCtrl = TextEditingController();
    _otherCutCtrl = TextEditingController();
    _gunnyWtLessCtrl = TextEditingController();
    _totalAmountCtrl = TextEditingController();

    if (widget.procurementId != null) {
      _loadProcurement(widget.procurementId!);
    }
  }

  @override
  void dispose() {
    _partyNameCtrl.dispose();
    _slipNoCtrl.dispose();
    _vehicleNoCtrl.dispose();
    _grossWtCtrl.dispose();
    _tareWtCtrl.dispose();
    _jutePktCtrl.dispose();
    _plasticPktCtrl.dispose();
    _ratePerQntlCtrl.dispose();
    _dustCutCtrl.dispose();
    _polCutCtrl.dispose();
    _otherCutCtrl.dispose();
    _gunnyWtLessCtrl.dispose();
    _totalAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProcurement(int id) async {
    setState(() => _isLoading = true);
    try {
      final procurement =
          await ref.read(paddyProcurementRepositoryProvider).getProcurement(id);
      if (procurement != null) {
        _editingId = id;
        _partyNameCtrl.text = procurement.partyName;
        _slipNoCtrl.text = procurement.slipNo;
        _date = procurement.date;
        _procurementType = procurement.procurementType;
        _vehicleNoCtrl.text = procurement.truckNo ?? '';
        _marketType = procurement.marketType;
        _grossWtCtrl.text = (procurement.grossWeight ?? 0).toString();
        _tareWtCtrl.text = (procurement.tareWeight ?? 0).toString();
        _jutePktCtrl.text = (procurement.juteBags ?? 0).toString();
        _plasticPktCtrl.text = (procurement.plasticBags ?? 0).toString();
        _ratePerQntlCtrl.text = (procurement.ratePerQntl ?? 0).toString();
        _dustCutCtrl.text = (procurement.dustCut ?? 0).toString();
        _polCutCtrl.text = (procurement.polCut ?? 0).toString();
        _otherCutCtrl.text = (procurement.otherCut ?? 0).toString();
        _qualityGrade = procurement.qualityGrade ?? 'A';
        _bagReturn = procurement.bagReturn ? 'Yes' : 'No';
        _gunnyWtLessCtrl.text = '0';
        _totalAmountCtrl.text = (procurement.totalAmount ?? 0).toString();
        _vType = procurement.vType ?? 'Bill';
        _rateCalculation = procurement.rateCalculation ?? 'Qntl';
        _quantityNew = procurement.quantityNew ?? 'N';
        _deliveryType = procurement.deliveryType ?? 'MD';
        _truckRentType = procurement.truckRentType ?? 'Qntl';
        _transportType = procurement.transportType ?? 'Direct';
        _calculateTotal();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateTotal() {
    final gross = double.tryParse(_grossWtCtrl.text) ?? 0;
    final tare = double.tryParse(_tareWtCtrl.text) ?? 0;
    final dust = double.tryParse(_dustCutCtrl.text) ?? 0;
    final pol = double.tryParse(_polCutCtrl.text) ?? 0;
    final other = double.tryParse(_otherCutCtrl.text) ?? 0;
    final gunnyLess = double.tryParse(_gunnyWtLessCtrl.text) ?? 0;

    final netWeight = gross - tare - dust - pol - other - gunnyLess;
    final rate = double.tryParse(_ratePerQntlCtrl.text) ?? 0;
    final total = (netWeight / 100) * rate;

    if (netWeight > 0 && rate > 0) {
      _totalAmountCtrl.text = total.toStringAsFixed(2);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final dustCut = double.tryParse(_dustCutCtrl.text) ?? 0;
    final polCut = double.tryParse(_polCutCtrl.text) ?? 0;
    final otherCut = double.tryParse(_otherCutCtrl.text) ?? 0;
    final gunnyLess = double.tryParse(_gunnyWtLessCtrl.text) ?? 0;
    final gross = double.tryParse(_grossWtCtrl.text) ?? 0;
    final tare = double.tryParse(_tareWtCtrl.text) ?? 0;

    final data = PaddyProcurementCompanion(
      id: _editingId,
      partyName: _partyNameCtrl.text.trim(),
      slipNo: _slipNoCtrl.text.trim(),
      date: _date,
      procurementType: _procurementType,
      truckNo: _vehicleNoCtrl.text.trim().isEmpty
          ? null
          : _vehicleNoCtrl.text.trim(),
      marketType: _marketType,
      productName: 'Paddy',
      productId: 0,
      grossWeight: gross,
      tareWeight: tare,
      juteBags: int.tryParse(_jutePktCtrl.text) ?? 0,
      plasticBags: int.tryParse(_plasticPktCtrl.text) ?? 0,
      ratePerQntl: double.tryParse(_ratePerQntlCtrl.text) ?? 0,
      otherCut: otherCut,
      dustCut: dustCut,
      polCut: polCut,
      qualityGrade: _qualityGrade,
      bagReturn: _bagReturn == 'Yes',
      gnyWtLess: gunnyLess > 0,
      totalAmount: double.tryParse(_totalAmountCtrl.text) ?? 0,
      netWeight: gross - tare - dustCut - polCut - otherCut - gunnyLess,
      status: 'draft',
      vType: _vType,
      rateCalculation: _rateCalculation,
      quantityNew: _quantityNew,
      deliveryType: _deliveryType,
      truckRentType: _truckRentType,
      transportType: _transportType,
    );

    setState(() => _isLoading = true);
    try {
      if (_editingId == null) {
        await ref
            .read(paddyProcurementRepositoryProvider)
            .createProcurement(data);
      } else {
        await ref
            .read(paddyProcurementRepositoryProvider)
            .updateProcurement(data);
      }
      if (mounted) {
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

  void _showHelp() {
    showDialog(
      context: context,
      builder: (ctx) => const PaddyProcurementHelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(_editingId == null ? 'New Procurement' : 'Edit Procurement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
            tooltip: Tooltips.general.help,
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
                    // ── HEADER SECTION ──
                    _buildSectionHeader(
                      'Header Details',
                      [
                        'vType',
                        'date',
                        'slipNo',
                        'voucherNo',
                        'rstManual',
                        'area'
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Voucher Type
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Voucher Type *',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Tooltip(
                          message: Tooltips.paddyProcurement.vType,
                          child: const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      value: _vType,
                      items: _vTypeOptions.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(
                                type == 'Bill'
                                    ? Icons.receipt_long
                                    : Icons.description,
                                size: 16,
                                color:
                                    type == 'Bill' ? Colors.green : Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(type),
                              const SizedBox(width: 8),
                              Text(
                                type == 'Bill'
                                    ? '(Farmer purchase)'
                                    : '(Govt procurement)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _vType = v!),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Date
                    DatePickerField(
                      date: _date,
                      onDatePicked: (d) => setState(() => _date = d),
                      label: 'Date',
                      isRequired: true,
                      tooltip: Tooltips.paddyProcurement.date,
                    ),
                    const SizedBox(height: 12),

                    // Slip No
                    TooltipFormField(
                      labelText: 'Slip No',
                      tooltip: Tooltips.paddyProcurement.slipNo,
                      controller: _slipNoCtrl,
                      isRequired: true,
                      validator: (v) =>
                          v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Voucher No
                    TooltipFormField(
                      labelText: 'Voucher No',
                      tooltip: Tooltips.paddyProcurement.voucherNo,
                      controller: TextEditingController(), // Add if needed
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),

                    // RST Manual
                    TooltipFormField(
                      labelText: 'RST Manual',
                      tooltip: Tooltips.paddyProcurement.rstManual,
                      controller: TextEditingController(), // Add if needed
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),

                    // Area
                    TooltipFormField(
                      labelText: 'Area',
                      tooltip: Tooltips.paddyProcurement.area,
                      controller: TextEditingController(), // Add if needed
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // ── PARTY & VEHICLE SECTION ──
                    _buildSectionHeader(
                      'Party & Vehicle',
                      [
                        'partyName',
                        'truckNo',
                        'emptyWeight',
                        'marketType',
                        'procurementType'
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Party Name
                    TooltipFormField(
                      labelText: 'Party Name',
                      tooltip: Tooltips.paddyProcurement.partyName,
                      controller: _partyNameCtrl,
                      isRequired: true,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Truck No
                    TooltipFormField(
                      labelText: 'Truck No',
                      tooltip: Tooltips.paddyProcurement.truckNo,
                      controller: _vehicleNoCtrl,
                      textCapitalization: TextCapitalization.characters,
                      isRequired: true,
                      validator: (v) =>
                          v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Empty Weight
                    TooltipFormField(
                      labelText: 'Empty Weight',
                      tooltip: Tooltips.paddyProcurement.emptyWeight,
                      controller: TextEditingController(), // Add if needed
                      keyboardType: TextInputType.number,
                      suffixText: 'Kg',
                    ),
                    const SizedBox(height: 12),

                    // Market Type
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Market Type *',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Tooltip(
                          message: Tooltips.paddyProcurement.marketType,
                          child: const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      value: _marketType,
                      items: _marketTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: type == 'FT'
                                      ? Colors.green.shade100
                                      : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: type == 'FT'
                                        ? Colors.green.shade800
                                        : Colors.blue.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(type == 'FT'
                                  ? 'Direct Farmer'
                                  : 'Market/Mandi'),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _marketType = v!),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Procurement Type
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Procurement Type *',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Tooltip(
                          message: Tooltips.paddyProcurement.procurementType,
                          child: const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      value: _procurementType,
                      items: _procurementTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _procurementType = v!),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── WEIGHMENT SECTION ──
                    _buildSectionHeader(
                      'Weighment',
                      [
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
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Gross Weight
                    TooltipFormField(
                      labelText: 'Gr.Wt',
                      tooltip: Tooltips.paddyProcurement.grossWeight,
                      controller: _grossWtCtrl,
                      keyboardType: TextInputType.number,
                      isRequired: true,
                      suffixText: 'Kg',
                      onChanged: (_) => _calculateTotal(),
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Required';
                        if (double.tryParse(v!) == null) return 'Invalid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Tare Weight
                    TooltipFormField(
                      labelText: 'Tr.Wt',
                      tooltip: Tooltips.paddyProcurement.tareWeight,
                      controller: _tareWtCtrl,
                      keyboardType: TextInputType.number,
                      isRequired: true,
                      suffixText: 'Kg',
                      onChanged: (_) => _calculateTotal(),
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Required';
                        if (double.tryParse(v!) == null) return 'Invalid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Net Weight (auto-calculated, read-only)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.scale, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text(
                            'Net Weight:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(double.tryParse(_grossWtCtrl.text) ?? 0) - (double.tryParse(_tareWtCtrl.text) ?? 0)} Kg',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue,
                            ),
                          ),
                          const Spacer(),
                          Tooltip(
                            message: Tooltips.paddyProcurement.netWeight,
                            child: Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Jute Bags
                    TooltipFormField(
                      labelText: 'J.Pkt',
                      tooltip: Tooltips.paddyProcurement.juteBags,
                      controller: _jutePktCtrl,
                      keyboardType: TextInputType.number,
                      isRequired: true,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Required';
                        if (int.tryParse(v!) == null) return 'Invalid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Plastic Bags
                    TooltipFormField(
                      labelText: 'P.Pkt',
                      tooltip: Tooltips.paddyProcurement.plasticBags,
                      controller: _plasticPktCtrl,
                      keyboardType: TextInputType.number,
                      isRequired: true,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Required';
                        if (int.tryParse(v!) == null) return 'Invalid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Total Bags (auto-calculated, read-only)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text(
                            'Total Bags:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(int.tryParse(_jutePktCtrl.text) ?? 0) + (int.tryParse(_plasticPktCtrl.text) ?? 0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Tooltip(
                            message: Tooltips.paddyProcurement.totalBags,
                            child: Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Avg Bag Weight (auto-calculated, read-only)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calculate,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text(
                            'Avg Bag Weight:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _calculateAvgBagWeight(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                          const Spacer(),
                          Tooltip(
                            message: Tooltips.paddyProcurement.avgBagWeight,
                            child: Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Gny Wt Less (Gunny Weight Less)
                    TooltipFormField(
                      labelText: 'Gny Wt(Less)',
                      tooltip: Tooltips.paddyProcurement.gnyWtLess,
                      controller: _gunnyWtLessCtrl,
                      keyboardType: TextInputType.number,
                      suffixText: 'Kg',
                      onChanged: (_) => _calculateTotal(),
                    ),
                    const SizedBox(height: 12),

                    // Bag Return
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Bag Rtn',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Tooltip(
                          message: Tooltips.paddyProcurement.bagReturn,
                          child: const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      value: _bagReturn,
                      items: _bagReturnOptions.map((option) {
                        return DropdownMenuItem(
                          value: option,
                          child: Row(
                            children: [
                              Icon(
                                option == 'Yes'
                                    ? Icons.check_circle_outline
                                    : Icons.cancel_outlined,
                                color: option == 'Yes'
                                    ? Colors.green
                                    : Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(option),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _bagReturn = v!),
                    ),
                    const SizedBox(height: 12),

                    // Other Cut
                    TooltipFormField(
                      labelText: 'Other Cut',
                      tooltip: Tooltips.paddyProcurement.otherCut,
                      controller: _otherCutCtrl,
                      keyboardType: TextInputType.number,
                      suffixText: 'Kg',
                      onChanged: (_) => _calculateTotal(),
                    ),
                    const SizedBox(height: 16),

                    // ── RATE & CALCULATION SECTION ──
                    _buildSectionHeader(
                      'Rate & Calculation',
                      [
                        'rateCalculation',
                        'kgPerBag',
                        'eBag',
                        'ePkt',
                        'unloadTime'
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Rate Calculation Basis
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Rate Calculation',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Tooltip(
                          message: Tooltips.paddyProcurement.rateCalculation,
                          child: const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      value: _rateCalculation,
                      items: _rateCalcOptions.map((option) {
                        return DropdownMenuItem(
                          value: option,
                          child:
                              Text(option == 'Qntl' ? 'Per Quintal' : 'Per Kg'),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _rateCalculation = v!),
                    ),
                    const SizedBox(height: 12),

                    // Kg Per Bag
                    TooltipFormField(
                      labelText: 'Kg/Bag',
                      tooltip: Tooltips.paddyProcurement.kgPerBag,
                      controller: TextEditingController(), // Add if needed
                      keyboardType: TextInputType.number,
                      suffixText: 'Kg',
                    ),
                    const SizedBox(height: 12),

                    // E Bag (Empty Bag)
                    TooltipFormField(
                      labelText: 'E Bag',
                      tooltip: Tooltips.paddyProcurement.eBag,
                      controller: TextEditingController(), // Add if needed
                      keyboardType: TextInputType.number,
                      suffixText: 'Kg',
                    ),
                    const SizedBox(height: 12),

                    // E Pkt (Empty Packet)
                    TooltipFormField(
                      labelText: 'E Pkt',
                      tooltip: Tooltips.paddyProcurement.ePkt,
                      controller: TextEditingController(), // Add if needed
                      keyboardType: TextInputType.number,
                      suffixText: 'Kg',
                    ),
                    const SizedBox(height: 12),

                    // Unload Time
                    TooltipFormField(
                      labelText: 'Unload Time',
                      tooltip: Tooltips.paddyProcurement.unloadTime,
                      controller: TextEditingController(), // Add if needed
                      keyboardType: TextInputType.number,
                      suffixText: 'hrs',
                    ),
                    const SizedBox(height: 16),

                    // ── PRODUCT & PRICING SECTION (FT only) ──
                    _buildSectionHeader(
                      'Product & Pricing',
                      [
                        'product',
                        'productName',
                        'quantityNew',
                        'quantityQntl',
                        'ratePerQntl',
                        'totalAmount'
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Product
                    TooltipFormField(
                      labelText: 'Product',
                      tooltip: Tooltips.paddyProcurement.product,
                      controller: TextEditingController()..text = 'Paddy',
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),

                    // Product Name
                    TooltipFormField(
                      labelText: 'Product Name',
                      tooltip: Tooltips.paddyProcurement.productName,
                      controller: TextEditingController(), // Add if needed
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),

                    // Quantity New (New/Old crop)
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Quantity New',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Tooltip(
                          message: Tooltips.paddyProcurement.quantityNew,
                          child: const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      value: _quantityNew,
                      items: _quantityNewOptions.map((option) {
                        return DropdownMenuItem(
                          value: option,
                          child: Row(
                            children: [
                              Text(option),
                              const SizedBox(width: 8),
                              Text(
                                option == 'N' ? '(New crop)' : '(Old crop)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _quantityNew = v!),
                    ),
                    const SizedBox(height: 12),

                    // Quantity in Quintals (auto-calculated)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calculate,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text(
                            'Qty (Qntl):',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _calculateQuintals(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.orange,
                            ),
                          ),
                          const Spacer(),
                          Tooltip(
                            message: Tooltips.paddyProcurement.quantityQntl,
                            child: Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Rate Per Quintal
                    TooltipFormField(
                      labelText: 'Rate/Qntl',
                      tooltip: Tooltips.paddyProcurement.ratePerQntl,
                      controller: _ratePerQntlCtrl,
                      keyboardType: TextInputType.number,
                      isRequired: true,
                      suffixText: '₹/Qntl',
                      onChanged: (_) => _calculateTotal(),
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true) return 'Required';
                        if (double.tryParse(v!) == null) return 'Invalid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Total Amount (auto-calculated)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.currency_rupee,
                              color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Total Amount:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '₹${_totalAmountCtrl.text.isEmpty ? '0.00' : _totalAmountCtrl.text}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: Tooltips.paddyProcurement.totalAmount,
                            child: Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.green.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── QUALITY CUTS SECTION ──
                    _buildSectionHeader(
                      'Quality Cuts',
                      [
                        'qualityCutName',
                        'qualityCutBagQty',
                        'qualityCutType',
                        'qualityCutPerUnit',
                        'qualityCutKg',
                        'qualityCutRemark'
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          // Dust Cut
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  'Dust',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: TooltipFormField(
                                  labelText: 'Dust Cut',
                                  tooltip:
                                      Tooltips.paddyProcurement.qualityCutName,
                                  controller: _dustCutCtrl,
                                  keyboardType: TextInputType.number,
                                  suffixText: 'Kg',
                                  onChanged: (_) => _calculateTotal(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Pol Cut
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  'Pol',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: TooltipFormField(
                                  labelText: 'Pol Cut',
                                  tooltip:
                                      Tooltips.paddyProcurement.qualityCutName,
                                  controller: _polCutCtrl,
                                  keyboardType: TextInputType.number,
                                  suffixText: 'Kg',
                                  onChanged: (_) => _calculateTotal(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Other Cut
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  'Other',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: TooltipFormField(
                                  labelText: 'Other Cut',
                                  tooltip:
                                      Tooltips.paddyProcurement.qualityCutName,
                                  controller: _otherCutCtrl,
                                  keyboardType: TextInputType.number,
                                  suffixText: 'Kg',
                                  onChanged: (_) => _calculateTotal(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Quality Grade
                          Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  'Grade',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    suffixIcon: Tooltip(
                                      message: Tooltips
                                          .paddyProcurement.qualityCutType,
                                      child: const Icon(
                                        Icons.info_outline,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  value: _qualityGrade,
                                  items: _qualityGrades.map((grade) {
                                    return DropdownMenuItem(
                                      value: grade,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getGradeColor(grade)
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          grade,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: _getGradeColor(grade),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (v) =>
                                      setState(() => _qualityGrade = v!),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── TRANSPORT SECTION ──
                    _buildSectionHeader(
                      'Transport',
                      [
                        'deliveryType',
                        'truckRentType',
                        'truckRent',
                        'otherAmount',
                        'transportType',
                        'truckAccount',
                        'freightAmount'
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Delivery Type
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Delivery Type',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Tooltip(
                          message: Tooltips.paddyProcurement.deliveryType,
                          child: const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      value: _deliveryType,
                      items: _deliveryTypeOptions.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _deliveryType = v!),
                    ),
                    const SizedBox(height: 12),

                    // Truck Rent Type
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Truck Rent Type',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Tooltip(
                          message: Tooltips.paddyProcurement.truckRentType,
                          child: const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      value: _truckRentType,
                      items: _truckRentTypeOptions.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child:
                              Text(type == 'Qntl' ? 'Per Quintal' : 'Per Kg'),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _truckRentType = v!),
                    ),
                    const SizedBox(height: 12),

                    // Truck Rent
                    TooltipFormField(
                      labelText: 'Truck Rent',
                      tooltip: Tooltips.paddyProcurement.truckRent,
                      controller: TextEditingController(), // Add if needed
                      keyboardType: TextInputType.number,
                      suffixText: '₹',
                    ),
                    const SizedBox(height: 12),

                    // Other Amount
                    TooltipFormField(
                      labelText: 'Other Amount',
                      tooltip: Tooltips.paddyProcurement.otherAmount,
                      controller: TextEditingController(), // Add if needed
                      keyboardType: TextInputType.number,
                      suffixText: '₹',
                    ),
                    const SizedBox(height: 12),

                    // Transport Type
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Transport Type',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: Tooltip(
                          message: Tooltips.paddyProcurement.transportType,
                          child: const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      value: _transportType,
                      items: _transportTypeOptions.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _transportType = v!),
                    ),
                    const SizedBox(height: 12),

                    // Truck Account
                    TooltipFormField(
                      labelText: 'Truck Account',
                      tooltip: Tooltips.paddyProcurement.truckAccount,
                      controller: TextEditingController(), // Add if needed
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),

                    // Freight Amount
                    TooltipFormField(
                      labelText: 'Freight Amount',
                      tooltip: Tooltips.paddyProcurement.freightAmount,
                      controller: TextEditingController(), // Add if needed
                      keyboardType: TextInputType.number,
                      suffixText: '₹',
                    ),
                    const SizedBox(height: 16),

                    // ── MANDI/GOVERNMENT SECTION ──
                    _buildSectionHeader(
                      'Mandi/Government',
                      ['mandiInvoiceNo', 'tenderNumber', 'commissionAgent'],
                    ),
                    const SizedBox(height: 12),

                    // Mandi Invoice No
                    TooltipFormField(
                      labelText: 'Mandi Invoice No',
                      tooltip: Tooltips.paddyProcurement.mandiInvoiceNo,
                      controller: TextEditingController(), // Add if needed
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),

                    // Tender Number
                    TooltipFormField(
                      labelText: 'Tender Number',
                      tooltip: Tooltips.paddyProcurement.tenderNumber,
                      controller: TextEditingController(), // Add if needed
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),

                    // Commission Agent
                    TooltipFormField(
                      labelText: 'Commission Agent',
                      tooltip: Tooltips.paddyProcurement.commissionAgent,
                      controller: TextEditingController(), // Add if needed
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(_editingId == null
                            ? 'Create Procurement'
                            : 'Update Procurement'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, List<String> tooltipKeys) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey,
          ),
        ),
        const Spacer(),
        TooltipIcon(
          tooltip: 'View field guide for this section',
          icon: Icons.help_outline,
          onTap: _showHelp,
          size: 16,
        ),
      ],
    );
  }

  String _calculateAvgBagWeight() {
    final gross = double.tryParse(_grossWtCtrl.text) ?? 0;
    final tare = double.tryParse(_tareWtCtrl.text) ?? 0;
    final jute = int.tryParse(_jutePktCtrl.text) ?? 0;
    final plastic = int.tryParse(_plasticPktCtrl.text) ?? 0;
    final totalBags = jute + plastic;

    if (totalBags == 0) return '0.00 Kg';
    final netWeight = gross - tare;
    if (netWeight <= 0) return '0.00 Kg';

    return '${(netWeight / totalBags).toStringAsFixed(2)} Kg';
  }

  String _calculateQuintals() {
    final gross = double.tryParse(_grossWtCtrl.text) ?? 0;
    final tare = double.tryParse(_tareWtCtrl.text) ?? 0;
    final dust = double.tryParse(_dustCutCtrl.text) ?? 0;
    final pol = double.tryParse(_polCutCtrl.text) ?? 0;
    final other = double.tryParse(_otherCutCtrl.text) ?? 0;
    final gunnyLess = double.tryParse(_gunnyWtLessCtrl.text) ?? 0;

    final netWeight = gross - tare - dust - pol - other - gunnyLess;
    if (netWeight <= 0) return '0.00 Qntl';

    return '${(netWeight / 100).toStringAsFixed(2)} Qntl';
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      case 'D':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
