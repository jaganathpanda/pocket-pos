import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';

enum _InvoiceLookupType { mobile, invoice }

class InvoiceLookupPage extends ConsumerStatefulWidget {
  const InvoiceLookupPage({super.key});

  @override
  ConsumerState<InvoiceLookupPage> createState() => _InvoiceLookupPageState();
}

class _InvoiceLookupPageState extends ConsumerState<InvoiceLookupPage> {
  final _queryController = TextEditingController();
  _InvoiceLookupType _lookupType = _InvoiceLookupType.mobile;
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() => _error = _lookupType == _InvoiceLookupType.mobile
          ? 'Enter a mobile number.'
          : 'Enter an invoice number.');
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      if (_lookupType == _InvoiceLookupType.mobile) {
        final customer =
            await ref.read(customerRepositoryProvider).findByMobile(query);
        if (!mounted) return;
        if (customer == null) {
          setState(() => _error = 'No customer found with that mobile number.');
        } else {
          context.push('/customer/${customer.id}/orders');
        }
      } else {
        final sale =
            await ref.read(salesRepositoryProvider).findByInvoiceNo(query);
        if (!mounted) return;
        if (sale == null) {
          setState(() => _error = 'No invoice found with that number.');
        } else {
          context.push('/invoice/${sale.id}');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Search failed. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobileLookup = _lookupType == _InvoiceLookupType.mobile;

    return Scaffold(
      appBar: AppBar(title: const Text('Find Invoice')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(20),
            shrinkWrap: true,
            children: [
              SegmentedButton<_InvoiceLookupType>(
                segments: const [
                  ButtonSegment(
                    value: _InvoiceLookupType.mobile,
                    label: Text('Mobile number'),
                  ),
                  ButtonSegment(
                    value: _InvoiceLookupType.invoice,
                    label: Text('Invoice number'),
                  ),
                ],
                selected: {_lookupType},
                onSelectionChanged: (selection) {
                  setState(() {
                    _lookupType = selection.first;
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _queryController,
                autofocus: true,
                keyboardType:
                    isMobileLookup ? TextInputType.phone : TextInputType.text,
                textInputAction: TextInputAction.search,
                autofillHints: isMobileLookup
                    ? const [AutofillHints.telephoneNumber]
                    : null,
                decoration: InputDecoration(
                  labelText:
                      isMobileLookup ? 'Mobile number' : 'Invoice number',
                  hintText: isMobileLookup
                      ? 'Enter customer mobile'
                      : 'e.g. INV-12345',
                  prefixIcon: Icon(isMobileLookup
                      ? Icons.phone_android_rounded
                      : Icons.receipt_long_rounded),
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
                onSubmitted: (_) => _searching ? null : _search(),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _searching ? null : _search,
                icon: _searching
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(_searching ? 'Searching' : 'Search'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
