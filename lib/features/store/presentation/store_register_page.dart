import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/seed/demo_business_type.dart';
import 'store_auth_controller.dart';

class StoreRegisterPage extends ConsumerStatefulWidget {
  const StoreRegisterPage({super.key});

  @override
  ConsumerState<StoreRegisterPage> createState() => _StoreRegisterPageState();
}

class _StoreRegisterPageState extends ConsumerState<StoreRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _storeName = TextEditingController();
  final _ownerName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _referralCode = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  DemoBusinessType _businessType = DemoBusinessType.grocery;

  @override
  void dispose() {
    _storeName.dispose();
    _ownerName.dispose();
    _mobile.dispose();
    _email.dispose();
    _referralCode.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final storeId =
        await ref.read(storeAuthControllerProvider.notifier).register(
              storeName: _storeName.text,
              ownerName: _ownerName.text,
              ownerUsername: _username.text,
              password: _password.text,
              businessType: _businessType,
              mobile: _mobile.text,
              email: _email.text,
              referralCode: _referralCode.text,
            );
    if (!mounted) return;
    if (storeId == null) {
      final err = ref.read(storeAuthControllerProvider).error;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err ?? 'Registration failed')));
    }
    // On success the router redirect moves to the pending-approval screen.
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _validEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Required';
    // Simple, permissive format check: something@something.tld
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    return ok ? null : 'Enter a valid email';
  }

  String? _validReferralCode(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    final ok = RegExp(r'^[A-Za-z0-9]{6,12}$').hasMatch(value);
    return ok ? null : 'Use 6-12 letters or numbers';
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(storeAuthControllerProvider).busy;

    return Scaffold(
      appBar: AppBar(title: const Text('Register your store')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Create your store account. Your Store ID is generated '
                    'automatically and must be approved before you can start.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  _field(_storeName, 'Store name *', Icons.storefront_rounded,
                      validator: _required),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<DemoBusinessType>(
                      initialValue: _businessType,
                      decoration: const InputDecoration(
                        labelText: 'Business type *',
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_rounded),
                        helperText:
                            'Sample products & categories are created for this type',
                      ),
                      items: [
                        for (final t in DemoBusinessType.values)
                          DropdownMenuItem(value: t, child: Text(t.label)),
                      ],
                      onChanged: (v) =>
                          setState(() => _businessType = v ?? _businessType),
                    ),
                  ),
                  _field(_ownerName, 'Owner name *', Icons.person_rounded,
                      validator: _required),
                  _field(_mobile, 'Mobile', Icons.phone,
                      keyboard: TextInputType.phone),
                  _field(_email, 'Email *', Icons.email_outlined,
                      keyboard: TextInputType.emailAddress,
                      validator: _validEmail),
                  _field(
                    _referralCode,
                    'Referral Code (Optional)',
                    Icons.redeem_rounded,
                    validator: _validReferralCode,
                  ),
                  const Divider(height: 28),
                  _field(_username, 'Owner username *',
                      Icons.account_circle_outlined,
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Min 3 characters'
                          : null),
                  _field(_password, 'Password *', Icons.lock_outline,
                      obscure: true,
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Min 6 characters'
                          : null),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : _submit,
                      child: busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Register Store'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool obscure = false,
      TextInputType? keyboard,
      String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        keyboardType: keyboard,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }
}
