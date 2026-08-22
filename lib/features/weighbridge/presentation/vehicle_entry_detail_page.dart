import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../domain/vehicle_entry.dart';

class VehicleEntryDetailPage extends ConsumerStatefulWidget {
  const VehicleEntryDetailPage({super.key, this.entryId});

  final int? entryId;

  @override
  ConsumerState<VehicleEntryDetailPage> createState() =>
      _VehicleEntryDetailPageState();
}

class _VehicleEntryDetailPageState
    extends ConsumerState<VehicleEntryDetailPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _dateCtrl;
  late TextEditingController _slipNoCtrl;
  late TextEditingController _voucherCtrl;
  late TextEditingController _vehicleCtrl;
  late TextEditingController _rstCtrl;
  late TextEditingController _partyCtrl;
  late TextEditingController _firstWtCtrl;
  late TextEditingController _firstTimeCtrl;
  late TextEditingController _secondWtCtrl;
  late TextEditingController _secondTimeCtrl;
  late TextEditingController _bagsCtrl;
  late TextEditingController _lotCtrl;
  late TextEditingController _remarkCtrl;
  late TextEditingController _completeCodeCtrl;
  late TextEditingController _completeDateCtrl;

  // Selected values
  DateTime _date = DateTime.now();
  int? _selectedProductId;
  int? _selectedPartyId;
  bool _complete = false;
  DateTime? _firstTime;
  DateTime? _secondTime;
  DateTime? _completeDate;
  String _entryType = 'inward'; // 👈 ADDED: 'inward' or 'outward'

  @override
  void initState() {
    super.initState();
    _dateCtrl = TextEditingController();
    _slipNoCtrl = TextEditingController();
    _voucherCtrl = TextEditingController();
    _vehicleCtrl = TextEditingController();
    _rstCtrl = TextEditingController();
    _partyCtrl = TextEditingController();
    _firstWtCtrl = TextEditingController();
    _firstTimeCtrl = TextEditingController();
    _secondWtCtrl = TextEditingController();
    _secondTimeCtrl = TextEditingController();
    _bagsCtrl = TextEditingController();
    _lotCtrl = TextEditingController();
    _remarkCtrl = TextEditingController();
    _completeCodeCtrl = TextEditingController();
    _completeDateCtrl = TextEditingController();

    if (widget.entryId != null) {
      _loadEntry();
    } else {
      // Set defaults
      _date = DateTime.now();
      _dateCtrl.text = DateFormat('dd/MM/yyyy').format(_date);
      _slipNoCtrl.text = _generateSlipNo();
      _firstTime = DateTime.now();
      _firstTimeCtrl.text = DateFormat('dd/MM/yyyy HH:mm').format(_firstTime!);
      _entryType = 'inward';
    }
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _slipNoCtrl.dispose();
    _voucherCtrl.dispose();
    _vehicleCtrl.dispose();
    _rstCtrl.dispose();
    _partyCtrl.dispose();
    _firstWtCtrl.dispose();
    _firstTimeCtrl.dispose();
    _secondWtCtrl.dispose();
    _secondTimeCtrl.dispose();
    _bagsCtrl.dispose();
    _lotCtrl.dispose();
    _remarkCtrl.dispose();
    _completeCodeCtrl.dispose();
    _completeDateCtrl.dispose();
    super.dispose();
  }

  String _generateSlipNo() {
    final now = DateTime.now();
    return '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 4)}';
  }

  Future<void> _loadEntry() async {
    final entry = await ref.read(vehicleEntryProvider(widget.entryId!).future);
    if (entry == null) return;
    setState(() {
      _date = entry.date;
      _dateCtrl.text = DateFormat('dd/MM/yyyy').format(_date);
      _slipNoCtrl.text = entry.slipNo;
      _voucherCtrl.text = entry.voucherNo ?? '';
      _vehicleCtrl.text = entry.vehicleNo;
      _rstCtrl.text = entry.rstManual ?? '';
      _partyCtrl.text = entry.partyName;
      _selectedPartyId = entry.partyId;
      _selectedProductId = entry.productId;
      _entryType = entry.entryType ?? 'inward'; // 👈 set from loaded entry
      _firstWtCtrl.text = entry.firstWeight.toString();
      _firstTime = entry.firstWeightTime;
      _firstTimeCtrl.text = entry.firstWeightTime != null
          ? DateFormat('dd/MM/yyyy HH:mm').format(entry.firstWeightTime!)
          : '';
      _secondWtCtrl.text = entry.secondWeight.toString();
      _secondTime = entry.secondWeightTime;
      _secondTimeCtrl.text = entry.secondWeightTime != null
          ? DateFormat('dd/MM/yyyy HH:mm').format(entry.secondWeightTime!)
          : '';
      _bagsCtrl.text = entry.bags?.toString() ?? '';
      _lotCtrl.text = entry.lotNumber ?? '';
      _remarkCtrl.text = entry.remark ?? '';
      _complete = entry.complete;
      _completeCodeCtrl.text = entry.completeCode ?? '';
      _completeDate = entry.completeDate;
      _completeDateCtrl.text = entry.completeDate != null
          ? DateFormat('dd/MM/yyyy').format(entry.completeDate!)
          : '';
    });
  }

  double _calculateNetWeight() {
    final first = double.tryParse(_firstWtCtrl.text.trim()) ?? 0;
    final second = double.tryParse(_secondWtCtrl.text.trim()) ?? 0;
    if (_entryType == 'inward') {
      return (first - second).clamp(0, double.infinity);
    } else {
      return (second - first).clamp(0, double.infinity);
    }
  }

  void _updateNetWeight() {
    setState(() {}); // Just refresh the displayed net weight
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final firstWt = double.tryParse(_firstWtCtrl.text.trim()) ?? 0;
    final secondWt = double.tryParse(_secondWtCtrl.text.trim()) ?? 0;
    final netWt = _calculateNetWeight();

    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a product.')));
      return;
    }

    final companion = VehicleEntryCompanion(
      id: widget.entryId,
      date: _date,
      slipNo: _slipNoCtrl.text.trim(),
      voucherNo:
          _voucherCtrl.text.trim().isEmpty ? null : _voucherCtrl.text.trim(),
      vehicleNo: _vehicleCtrl.text.trim(),
      rstManual: _rstCtrl.text.trim().isEmpty ? null : _rstCtrl.text.trim(),
      partyName: _partyCtrl.text.trim(),
      partyId: _selectedPartyId,
      productId: _selectedProductId!,
      firstWeight: firstWt,
      firstWeightTime: _firstTime,
      secondWeight: secondWt,
      secondWeightTime: _secondTime,
      netWeight: netWt,
      bags: int.tryParse(_bagsCtrl.text.trim()),
      lotNumber: _lotCtrl.text.trim().isEmpty ? null : _lotCtrl.text.trim(),
      entryType: _entryType, // 👈 PASS entryType
      complete: _complete,
      completeCode: _complete ? _completeCodeCtrl.text.trim() : null,
      completeDate: _complete ? _completeDate : null,
      remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
    );

    try {
      if (widget.entryId == null) {
        await ref.read(weighbridgeRepositoryProvider).createEntry(companion);
      } else {
        await ref.read(weighbridgeRepositoryProvider).updateEntry(companion);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickDate(TextEditingController ctrl, DateTime initial,
      void Function(DateTime) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        ctrl.text = DateFormat('dd/MM/yyyy').format(picked);
        onPicked(picked);
      });
    }
  }

  Future<void> _pickTime(TextEditingController ctrl, DateTime? initial,
      void Function(DateTime) onPicked) async {
    final base = initial ?? DateTime.now();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time != null) {
      final dt =
          DateTime(base.year, base.month, base.day, time.hour, time.minute);
      setState(() {
        ctrl.text = DateFormat('dd/MM/yyyy HH:mm').format(dt);
        onPicked(dt);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final products =
        ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final suppliers =
        ref.watch(suppliersProvider).valueOrNull ?? const <Supplier>[];
    final netWt = _calculateNetWeight();

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.entryId == null
              ? 'New Vehicle Entry'
              : 'Edit Vehicle Entry')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Date & Slip
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: Text(DateFormat('dd/MM/yyyy').format(_date)),
                      subtitle: const Text('Date'),
                      onTap: () =>
                          _pickDate(_dateCtrl, _date, (d) => _date = d),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _slipNoCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Slip No', border: OutlineInputBorder()),
                      validator: (v) =>
                          v?.trim().isNotEmpty == true ? null : 'Required',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _voucherCtrl,
                decoration: const InputDecoration(
                    labelText: 'Vch No', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _vehicleCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Vehicle No',
                          border: OutlineInputBorder()),
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
                          border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Autocomplete<Supplier>(
                      optionsBuilder: (text) {
                        if (text.text.isEmpty) return const Iterable.empty();
                        return suppliers.where((s) =>
                            s.name
                                .toLowerCase()
                                .contains(text.text.toLowerCase()) ||
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
                              border: OutlineInputBorder()),
                          validator: (v) =>
                              v?.trim().isNotEmpty == true ? null : 'Required',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedProductId,
                      decoration: const InputDecoration(
                          labelText: 'Product', border: OutlineInputBorder()),
                      items: [
                        for (final p in products)
                          DropdownMenuItem(value: p.id, child: Text(p.name)),
                      ],
                      onChanged: (v) => setState(() => _selectedProductId = v),
                      validator: (v) => v != null ? null : 'Required',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _remarkCtrl,
                decoration: const InputDecoration(
                    labelText: 'Remark (e.g., PKT 63)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              // 👇 ENTRY TYPE SEGMENTED BUTTON
              Row(
                children: [
                  const Text('Entry Type:  ',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'inward',
                          label: Text('Inward'),
                          icon: Icon(Icons.arrow_downward, size: 16)),
                      ButtonSegment(
                          value: 'outward',
                          label: Text('Outward'),
                          icon: Icon(Icons.arrow_upward, size: 16)),
                    ],
                    selected: {_entryType},
                    onSelectionChanged: (s) {
                      setState(() {
                        _entryType = s.first;
                        _updateNetWeight();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Weights',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstWtCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'First Wt', border: OutlineInputBorder()),
                      onChanged: (_) => _updateNetWeight(),
                      validator: (v) =>
                          v?.trim().isNotEmpty == true ? null : 'Required',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_firstTime != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(_firstTime!)
                          : 'Set time'),
                      subtitle: const Text('Time'),
                      onTap: () => _pickTime(
                          _firstTimeCtrl, _firstTime, (dt) => _firstTime = dt),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _secondWtCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Second Wt', border: OutlineInputBorder()),
                      onChanged: (_) => _updateNetWeight(),
                      validator: (v) =>
                          v?.trim().isNotEmpty == true ? null : 'Required',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_secondTime != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(_secondTime!)
                          : 'Set time'),
                      subtitle: const Text('Time'),
                      onTap: () => _pickTime(_secondTimeCtrl, _secondTime,
                          (dt) => _secondTime = dt),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 👇 Net Weight display with correct calculation
              Text(
                'Net.Wt : ${netWt.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bagsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Pkts', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _lotCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Lot No', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Completion',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Switch(
                    value: _complete,
                    onChanged: (v) => setState(() {
                      _complete = v;
                      if (v && _completeDate == null) {
                        _completeDate = DateTime.now();
                        _completeDateCtrl.text =
                            DateFormat('dd/MM/yyyy').format(_completeDate!);
                      }
                    }),
                  ),
                  const Text('Complete'),
                ],
              ),
              if (_complete) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _completeCodeCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Complete Code',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_completeDate != null
                            ? DateFormat('dd/MM/yyyy').format(_completeDate!)
                            : 'Pick date'),
                        subtitle: const Text('Date'),
                        onTap: () => _pickDate(
                            _completeDateCtrl,
                            _completeDate ?? DateTime.now(),
                            (d) => _completeDate = d),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                      onPressed: _save,
                      child: Text(widget.entryId == null ? 'Save' : 'Update')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
