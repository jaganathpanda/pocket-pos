import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utilities/money.dart';
import '../domain/farmer.dart';
import '../providers/farmer_providers.dart';

class FarmerListPage extends ConsumerStatefulWidget {
  const FarmerListPage({super.key});

  @override
  ConsumerState<FarmerListPage> createState() => _FarmerListPageState();
}

class _FarmerListPageState extends ConsumerState<FarmerListPage> {
  final _searchController = TextEditingController();
  bool _showOnlyMandi = false;
  bool _showOnlyFarmers = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farmers = ref.watch(farmersProvider);
    final searchQuery = ref.watch(farmerSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmers / Mandi Agents'),
        actions: [
          // Filter by type
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _showOnlyFarmers = false;
                _showOnlyMandi = false;
                if (value == 'farmers') _showOnlyFarmers = true;
                if (value == 'mandi') _showOnlyMandi = true;
                if (value == 'all') {
                  _showOnlyFarmers = false;
                  _showOnlyMandi = false;
                }
                _applyFilter();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'farmers', child: Text('Farmers')),
              const PopupMenuItem(value: 'mandi', child: Text('Mandi Agents')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(null),
        icon: const Icon(Icons.add),
        label: const Text('Add Farmer/Mandi'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Name, Mobile, Aadhaar, or Kisan Card',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(farmerSearchQueryProvider.notifier).state =
                              '';
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(farmerSearchQueryProvider.notifier).state = value;
              },
            ),
          ),
          // Filter chips
          if (searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: !_showOnlyFarmers && !_showOnlyMandi,
                    onSelected: (_) {
                      setState(() {
                        _showOnlyFarmers = false;
                        _showOnlyMandi = false;
                        _applyFilter();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Farmers'),
                    selected: _showOnlyFarmers,
                    onSelected: (_) {
                      setState(() {
                        _showOnlyFarmers = true;
                        _showOnlyMandi = false;
                        _applyFilter();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Mandi Agents'),
                    selected: _showOnlyMandi,
                    onSelected: (_) {
                      setState(() {
                        _showOnlyFarmers = false;
                        _showOnlyMandi = true;
                        _applyFilter();
                      });
                    },
                  ),
                ],
              ),
            ),
          // List
          Expanded(
            child: farmers.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_rounded,
                            size: 56, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No farmers or mandi agents yet.',
                            style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 6),
                        Text('Tap + to add one.',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final farmer = list[index];
                    return _FarmerTile(
                      farmer: farmer,
                      onEdit: () => _showAddEditDialog(farmer),
                      onDelete: () => _confirmDelete(farmer),
                      onViewProcurements: () => _viewProcurements(farmer),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _applyFilter() {
    if (_showOnlyFarmers) {
      ref.read(farmerFilterTypeProvider.notifier).state = 'farmer';
    } else if (_showOnlyMandi) {
      ref.read(farmerFilterTypeProvider.notifier).state = 'mandi';
    } else {
      ref.read(farmerFilterTypeProvider.notifier).state = null;
    }
  }

  Future<void> _showAddEditDialog(Farmer? existing) async {
    final isEdit = existing != null;
    final name = TextEditingController(text: existing?.name);
    final type = existing?.type ?? 'farmer';
    final mobile = TextEditingController(text: existing?.mobile);
    final gst = TextEditingController(text: existing?.gstNumber);
    final email = TextEditingController(text: existing?.email);
    final address = TextEditingController(text: existing?.address);
    final contact = TextEditingController(text: existing?.contactPerson);
    final kisan = TextEditingController(text: existing?.kisanCardNumber);
    final aadhaar = TextEditingController(text: existing?.aadhaarNumber);
    final village = TextEditingController(text: existing?.village);
    final district = TextEditingController(text: existing?.district);
    final mandiLicense =
        TextEditingController(text: existing?.mandiLicenseNumber);

    String selectedType = type;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(
              isEdit ? 'Edit Farmer/Mandi Agent' : 'Add Farmer/Mandi Agent'),
          content: SingleChildScrollView(
            child: SizedBox(
              width:
                  MediaQuery.of(ctx).size.width > 600 ? 500 : double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Type selector
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'farmer', child: Text('🌾 Farmer')),
                      DropdownMenuItem(
                          value: 'mandi', child: Text('🏪 Mandi Agent')),
                    ],
                    onChanged: (v) => setState(() => selectedType = v!),
                  ),
                  const SizedBox(height: 10),
                  // Name
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Mobile
                  TextField(
                    controller: mobile,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // GST
                  if (selectedType == 'mandi') ...[
                    TextField(
                      controller: gst,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'GST Number',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Email
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Address
                  TextField(
                    controller: address,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Contact Person
                  if (selectedType == 'mandi') ...[
                    TextField(
                      controller: contact,
                      decoration: const InputDecoration(
                        labelText: 'Contact Person',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: mandiLicense,
                      decoration: const InputDecoration(
                        labelText: 'Mandi License Number',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.assignment),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Farmer-specific fields
                  if (selectedType == 'farmer') ...[
                    TextField(
                      controller: kisan,
                      decoration: const InputDecoration(
                        labelText: 'Kisan Card Number',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.card_membership),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: aadhaar,
                      decoration: const InputDecoration(
                        labelText: 'Aadhaar Number',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.qr_code),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: village,
                            decoration: const InputDecoration(
                              labelText: 'Village',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: district,
                            decoration: const InputDecoration(
                              labelText: 'District',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Name is required.')),
                  );
                  return;
                }
                final repo = ref.read(farmerRepositoryProvider);
                try {
                  if (isEdit) {
                    await repo.update(
                      id: existing!.id,
                      name: name.text.trim(),
                      type: selectedType,
                      mobile: mobile.text.trim().isEmpty
                          ? null
                          : mobile.text.trim(),
                      gstNumber:
                          gst.text.trim().isEmpty ? null : gst.text.trim(),
                      email:
                          email.text.trim().isEmpty ? null : email.text.trim(),
                      address: address.text.trim().isEmpty
                          ? null
                          : address.text.trim(),
                      contactPerson: contact.text.trim().isEmpty
                          ? null
                          : contact.text.trim(),
                      kisanCardNumber:
                          kisan.text.trim().isEmpty ? null : kisan.text.trim(),
                      aadhaarNumber: aadhaar.text.trim().isEmpty
                          ? null
                          : aadhaar.text.trim(),
                      village: village.text.trim().isEmpty
                          ? null
                          : village.text.trim(),
                      district: district.text.trim().isEmpty
                          ? null
                          : district.text.trim(),
                      mandiLicenseNumber: mandiLicense.text.trim().isEmpty
                          ? null
                          : mandiLicense.text.trim(),
                    );
                  } else {
                    await repo.add(
                      name: name.text.trim(),
                      type: selectedType,
                      mobile: mobile.text.trim().isEmpty
                          ? null
                          : mobile.text.trim(),
                      gstNumber:
                          gst.text.trim().isEmpty ? null : gst.text.trim(),
                      email:
                          email.text.trim().isEmpty ? null : email.text.trim(),
                      address: address.text.trim().isEmpty
                          ? null
                          : address.text.trim(),
                      contactPerson: contact.text.trim().isEmpty
                          ? null
                          : contact.text.trim(),
                      kisanCardNumber:
                          kisan.text.trim().isEmpty ? null : kisan.text.trim(),
                      aadhaarNumber: aadhaar.text.trim().isEmpty
                          ? null
                          : aadhaar.text.trim(),
                      village: village.text.trim().isEmpty
                          ? null
                          : village.text.trim(),
                      district: district.text.trim().isEmpty
                          ? null
                          : district.text.trim(),
                      mandiLicenseNumber: mandiLicense.text.trim().isEmpty
                          ? null
                          : mandiLicense.text.trim(),
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.refresh(farmersProvider);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Farmer farmer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record?'),
        content: Text(
            'Remove "${farmer.name}"? Existing procurements will be retained.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(farmerRepositoryProvider).delete(farmer.id);
      ref.refresh(farmersProvider);
    }
  }

  void _viewProcurements(Farmer farmer) {
    // Navigate to paddy procurements filtered by this farmer
    // This will be implemented when paddy procurement module is integrated
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing procurements for ${farmer.name}')),
    );
  }
}

class _FarmerTile extends StatelessWidget {
  const _FarmerTile({
    required this.farmer,
    required this.onEdit,
    required this.onDelete,
    required this.onViewProcurements,
  });

  final Farmer farmer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onViewProcurements;

  @override
  Widget build(BuildContext context) {
    final isMandi = farmer.type == 'mandi';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isMandi ? Colors.blue.shade100 : Colors.green.shade100,
        child: Icon(
          farmer.icon,
          color: isMandi ? Colors.blue.shade700 : Colors.green.shade700,
        ),
      ),
      title: Text(farmer.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMandi
                ? '🏪 Mandi Agent ${farmer.mandiLicenseNumber != null ? '• Lic: ${farmer.mandiLicenseNumber}' : ''}'
                : '🌾 Farmer ${farmer.village != null ? '• ${farmer.village}' : ''}',
            style: TextStyle(
                fontSize: 12, color: isMandi ? Colors.blue : Colors.green),
          ),
          const SizedBox(height: 2),
          Text(
            '📞 ${farmer.mobile ?? 'No mobile'}'
            '${farmer.gstNumber != null ? '  •  GST: ${farmer.gstNumber}' : ''}',
            style: const TextStyle(fontSize: 12),
          ),
          if (farmer.aadhaarNumber != null)
            Text(
              '🆔 Aadhaar: ${farmer.aadhaarNumber}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
        ],
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Chip(
            label: Text(
              'Due: ₹${farmer.outstandingBalance.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 11,
                color:
                    farmer.outstandingBalance > 0 ? Colors.red : Colors.green,
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'procurements') onViewProcurements();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'procurements', child: Text('Procurements')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}
