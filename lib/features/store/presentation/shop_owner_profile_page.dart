import 'package:barcode_widget/barcode_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/store_scope.dart';
import 'store_auth_controller.dart';

class ShopOwnerProfilePage extends ConsumerStatefulWidget {
  const ShopOwnerProfilePage({super.key});

  @override
  ConsumerState<ShopOwnerProfilePage> createState() => _ShopOwnerProfilePageState();
}

class _ShopOwnerProfilePageState extends ConsumerState<ShopOwnerProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _storeNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();

  String? _loadedStoreId;
  bool _saving = false;

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _usernameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _taglineCtrl.dispose();
    super.dispose();
  }

  void _loadOnce(String storeId, Map<String, dynamic>? data) {
    if (_loadedStoreId == storeId) return;
    _loadedStoreId = storeId;
    _storeNameCtrl.text = (data?['name'] as String?) ?? '';
    _ownerNameCtrl.text = (data?['ownerName'] as String?) ?? '';
    _usernameCtrl.text = (data?['ownerUsername'] as String?) ?? '';
    _mobileCtrl.text = (data?['mobile'] as String?) ?? '';
    _emailCtrl.text = (data?['email'] as String?) ?? '';
    _addressCtrl.text = (data?['address'] as String?) ?? '';
    _taglineCtrl.text = (data?['tagline'] as String?) ?? '';
  }

  Future<void> _save(String storeId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.collection('stores').doc(storeId).set(
        {
          'name': _storeNameCtrl.text.trim(),
          'ownerName': _ownerNameCtrl.text.trim(),
          'ownerUsername': _usernameCtrl.text.trim(),
          'mobile': _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
          'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
          'tagline': _taglineCtrl.text.trim().isEmpty ? null : _taglineCtrl.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Owner profile updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copyVisitingCardText(String storeId) async {
    final text = _visitingCardText(storeId);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visiting card details copied.')),
      );
    }
  }

  String _visitingCardText(String storeId) {
    final lines = <String>[
      _storeNameCtrl.text.trim(),
      if (_taglineCtrl.text.trim().isNotEmpty) _taglineCtrl.text.trim(),
      'Owner: ${_ownerNameCtrl.text.trim().isEmpty ? '-' : _ownerNameCtrl.text.trim()}',
      if (_mobileCtrl.text.trim().isNotEmpty) 'Mobile: ${_mobileCtrl.text.trim()}',
      if (_emailCtrl.text.trim().isNotEmpty) 'Email: ${_emailCtrl.text.trim()}',
      if (_addressCtrl.text.trim().isNotEmpty) 'Address: ${_addressCtrl.text.trim()}',
      'Store ID: $storeId',
    ];
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final storeId = ref.watch(activeStoreIdProvider);

    if (storeId == null || storeId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Shop Owner Profile')),
        body: const Center(child: Text('No active store found.')),
      );
    }

    final storeDoc = FirebaseFirestore.instance.collection('stores').doc(storeId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Owner Profile'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : () => _save(storeId),
            icon: _saving
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Update'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: storeDoc.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data();
          _loadOnce(storeId, data);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Owner & Shop Details',
                            style:
                                TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 12),
                        _field(
                          _storeNameCtrl,
                          'Shop Name',
                          required: true,
                        ),
                        const SizedBox(height: 10),
                        _field(
                          _ownerNameCtrl,
                          'Owner Name',
                          required: true,
                        ),
                        const SizedBox(height: 10),
                        _field(
                          _usernameCtrl,
                          'Owner Username',
                          required: true,
                        ),
                        const SizedBox(height: 10),
                        _field(
                          _mobileCtrl,
                          'Mobile Number',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 10),
                        _field(
                          _emailCtrl,
                          'Email',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 10),
                        _field(
                          _addressCtrl,
                          'Address',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        _field(
                          _taglineCtrl,
                          'Tagline (for visiting card)',
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text('Store ID: ',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(storeId),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Visiting Card',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _copyVisitingCardText(storeId),
                            icon: const Icon(Icons.copy_outlined, size: 16),
                            label: const Text('Copy'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _VisitingCardPreview(
                        storeId: storeId,
                        storeName: _storeNameCtrl.text.trim(),
                        ownerName: _ownerNameCtrl.text.trim(),
                        mobile: _mobileCtrl.text.trim(),
                        email: _emailCtrl.text.trim(),
                        address: _addressCtrl.text.trim(),
                        tagline: _taglineCtrl.text.trim(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}

class _VisitingCardPreview extends StatelessWidget {
  const _VisitingCardPreview({
    required this.storeId,
    required this.storeName,
    required this.ownerName,
    required this.mobile,
    required this.email,
    required this.address,
    required this.tagline,
  });

  final String storeId;
  final String storeName;
  final String ownerName;
  final String mobile;
  final String email;
  final String address;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final displayStore = storeName.isEmpty ? 'Your Shop Name' : storeName;
    final qrPayload = [
      displayStore,
      if (ownerName.isNotEmpty) ownerName,
      if (mobile.isNotEmpty) mobile,
      if (email.isNotEmpty) email,
      'Store ID: $storeId',
    ].join('|');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayStore,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          if (tagline.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              tagline,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: BarcodeWidget(
                      barcode: Barcode.qrCode(),
                      data: qrPayload,
                      drawText: false,
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line('Owner', ownerName.isEmpty ? '-' : ownerName),
                  _line('Mobile', mobile.isEmpty ? '-' : mobile),
                  _line('Email', email.isEmpty ? '-' : email),
                  _line('Address', address.isEmpty ? '-' : address),
                  _line('Store ID', storeId),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        '$key: $value',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
