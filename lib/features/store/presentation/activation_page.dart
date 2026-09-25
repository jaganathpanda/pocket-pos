import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';

/// Email activation page: visitor clicks the link from the registration email
/// and activates their store account.
///
/// The activation token (sent in the email) is validated against the store doc
/// in Firestore. On success, the store is marked `status: 'approved'` and the
/// visitor is redirected to login.
class ActivationPage extends ConsumerStatefulWidget {
  const ActivationPage({
    super.key,
    required this.storeId,
    required this.token,
  });

  final String? storeId;
  final String? token;

  @override
  ConsumerState<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends ConsumerState<ActivationPage> {
  late Future<void> _activationFuture;

  @override
  void initState() {
    super.initState();
    _activationFuture = _activate();
  }

  Future<void> _activate() async {
    final storeId = widget.storeId?.trim().toUpperCase();
    final token = widget.token?.trim();

    if (storeId == null || storeId.isEmpty) {
      throw Exception('Missing store ID');
    }
    if (token == null || token.isEmpty) {
      throw Exception('Missing activation token');
    }

    final db = FirebaseFirestore.instance;
    final storeRef = db.collection('stores').doc(storeId);

    try {
      // 1. Fetch the store doc and verify the token matches
      final storeSnap = await storeRef.get();
      if (!storeSnap.exists) {
        throw Exception('Store not found');
      }

      final data = storeSnap.data()!;
      final storedToken = data['activationToken'] as String?;

      if (storedToken == null || storedToken.isEmpty) {
        throw Exception(
            'This store has no pending activation. It may already be approved.');
      }

      if (storedToken != token) {
        throw Exception('Invalid activation token');
      }

      // 2. Mark the store as approved and clear the token
      await storeRef.update({
        'status': 'approved',
        'activationToken': FieldValue.delete(),
        'activatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Success — redirect to login after a brief pause for UX
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      context.go('/store-login');
    } catch (e) {
      // Let the UI render the error via FutureBuilder
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _activationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoading();
          }

          if (snapshot.hasError) {
            return _buildError(snapshot.error.toString());
          }

          // Success state (though we redirect before reaching this)
          return _buildSuccess();
        },
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            'Activating your store...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildError(String error) {
    final message = error.replaceFirst('Exception: ', '');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Activation Failed',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.go('/store-login'),
                      child: const Text('Back to Login'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => context.go('/'),
                      child: const Text('Back to Home'),
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

  Widget _buildSuccess() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 64,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Store Activated!',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your store has been successfully activated. You can now log in with your credentials.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.go('/store-login'),
                      child: const Text('Go to Login'),
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
}
