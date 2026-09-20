import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/firestore/firestore_mappers.dart';
import '../../../core/firestore/store_scope.dart';
import '../../../core/models/invoice_branding.dart';
import '../../barcode/presentation/barcode_scanner_page.dart';
import '../../barcode/presentation/hid_scanner_listener.dart';
import '../../store/presentation/store_auth_controller.dart';
import '../domain/sales_repository.dart';

class QuickCheckoutPage extends ConsumerStatefulWidget {
  const QuickCheckoutPage({super.key});

  @override
  ConsumerState<QuickCheckoutPage> createState() => _QuickCheckoutPageState();
}

class _QuickCheckoutPageState extends ConsumerState<QuickCheckoutPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final Set<int> _addingProductIds = <int>{};

  List<_QuickProductItem> _products = const <_QuickProductItem>[];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loading = false;
  bool _hasMore = true;
  String _query = '';
  Timer? _debounce;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitial();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>>? get _productsCol {
    final storeId = ref.read(activeStoreIdProvider);
    if (storeId == null || storeId.isEmpty) return null;
    return storeCollection(ref.read(firestoreProvider), storeId, 'products');
  }

  bool get _isCartUpdating => _addingProductIds.isNotEmpty;

  void _onScroll() {
    if (_query.isNotEmpty || _loading || !_hasMore) return;
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels + 320 >=
        _scrollCtrl.position.maxScrollExtent) {
      _loadMore(limit: 10);
    }
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;
    setState(() {
      _products = const <_QuickProductItem>[];
      _cursor = null;
      _hasMore = true;
    });

    if (_query.isEmpty) {
      await _loadMore(limit: 50, replace: true);
      return;
    }
    await _runSearch(_query);
  }

  Future<void> _loadMore({required int limit, bool replace = false}) async {
    final col = _productsCol;
    if (col == null || _loading || !_hasMore) return;

    setState(() => _loading = true);
    try {
      Query<Map<String, dynamic>> q =
          col.where('isActive', isEqualTo: true).orderBy('name').limit(limit);
      if (_cursor != null) {
        q = q.startAfterDocument(_cursor!);
      }

      final snap = await q.get();
      final incoming = snap.docs
          .map((doc) => _QuickProductItem.fromDoc(doc))
          .where((row) => !row.hideFromQuickCheckout)
          .where((row) => row.product.name.trim().isNotEmpty)
          .toList();

      setState(() {
        if (replace) {
          _products = incoming;
        } else {
          _products = <_QuickProductItem>[..._products, ...incoming];
        }
        if (snap.docs.isNotEmpty) {
          _cursor = snap.docs.last;
        }
        _hasMore = snap.docs.length == limit;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load products: $e')),
        );
      }
      setState(() => _hasMore = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      await _loadInitial();
      return;
    }
    setState(() => _loading = true);
    try {
      final rows = await ref.read(productRepositoryProvider).search(q);
      final result = rows
          .map((p) => _QuickProductItem(
                product: p,
                hideFromQuickCheckout: false,
                emoji: '',
              ))
          .toList(growable: false);
      if (mounted) {
        setState(() {
          _products = <_QuickProductItem>[...result];
          _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onTapProduct(_QuickProductItem row) async {
    if (_isCartUpdating || _addingProductIds.contains(row.product.id)) return;

    setState(() => _addingProductIds.add(row.product.id));
    try {
      var cartId = ref.read(selectedCartIdProvider);
      if (cartId == null) {
        cartId = await _autoCreateQuickCart();
        if (cartId == null) return;
      }

      await ref.read(salesRepositoryProvider).addItem(
            cartId: cartId,
            productId: row.product.id,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 700),
            content: Text('${row.product.name} added'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _addingProductIds.remove(row.product.id));
      }
    }
  }

  Future<void> _scanAndSearchProduct() async {
    final scanned = await scanBarcodeWithCamera(context);
    if (!mounted || scanned == null || scanned.trim().isEmpty) return;
    _searchCtrl.text = scanned.trim();
    setState(() => _query = scanned.trim());
    await _runSearch(scanned.trim());
  }

  Future<void> _handleScannerInput(String scanned) async {
    final value = scanned.trim();
    if (value.isEmpty) return;
    _searchCtrl.text = value;
    if (mounted) {
      setState(() => _query = value);
    }
    await _runSearch(value);
  }

  Future<String> _nextDailyTokenLabel() async {
    final branding = ref.read(invoiceBrandingProvider).valueOrNull ??
        const InvoiceBranding.defaults();
    final today = DateTime.now();
    final dateStr =
        '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    final nextTokenNumber =
        await ref.read(salesRepositoryProvider).nextQuickCartTokenNumber();
    final tokenCounter = (nextTokenNumber % 1000).toInt();
    return 'TOKEN-$dateStr-${tokenCounter.toString().padLeft(3, '0')}';
  }

  /// Auto-create cart with persistent token (date + counter, resets daily)
  Future<int?> _autoCreateQuickCart() async {
    try {
      final label = await _nextDailyTokenLabel();

      final counterId = ref.read(activeCounterIdProvider);
      final cartId = await ref.read(salesRepositoryProvider).createCart(
            label,
            posCounterId: counterId,
          );

      ref.read(selectedCartIdProvider.notifier).state = cartId;
      return cartId;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create cart: $e')),
        );
      }
      return null;
    }
  }

  Future<int?> _createQuickCart({Cart? existingCart}) async {
    // Load existing customer if editing cart with customer
    String initialMobile = '';
    String initialName = '';
    if (existingCart?.customerId != null) {
      try {
        final customer = await ref
            .read(customerRepositoryProvider)
            .getById(existingCart!.customerId!);
        if (customer != null) {
          initialMobile = customer.mobile ?? '';
          initialName = customer.name;
        }
      } catch (e) {
        // Ignore if customer not found
      }
    }

    final mobileCtrl = TextEditingController(text: initialMobile);
    final nameCtrl = TextEditingController(text: initialName);
    final cartNameCtrl = TextEditingController(text: existingCart?.name ?? '');

    final result =
        await showDialog<({String mobile, String name, String cartName})?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(existingCart == null ? 'New Quick Cart' : 'Edit Quick Cart'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) async {
                  final mobile = value.trim();
                  if (mobile.isEmpty) return;
                  final existing = await ref
                      .read(customerRepositoryProvider)
                      .findByMobile(mobile);
                  if (existing != null && ctx.mounted) {
                    nameCtrl.text = existing.name;
                  }
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cartNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cart Label',
                  hintText: 'Will auto-generate if blank',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              (
                mobile: mobileCtrl.text.trim(),
                name: nameCtrl.text.trim(),
                cartName: cartNameCtrl.text.trim(),
              ),
            ),
            child: Text(existingCart == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );

    if (result == null) return null;

    final mobile = result.mobile;
    final name = result.name;
    final customCartName = result.cartName;

    // Generate label: use custom name, or auto-generate from mobile/name/token
    String label;
    if (customCartName.isNotEmpty) {
      label = customCartName;
    } else if (name.isNotEmpty) {
      label = name;
    } else if (mobile.isNotEmpty) {
      label = mobile;
    } else {
      label = await _nextDailyTokenLabel();
    }

    final counterId = ref.read(activeCounterIdProvider);
    int cartId;

    if (existingCart != null) {
      // Edit existing cart: rename and update customer if needed
      cartId = existingCart.id;
      await ref.read(salesRepositoryProvider).renameCart(cartId, label);

      // Update customer association if mobile/name changed
      if (mobile.isNotEmpty) {
        final customerId =
            await ref.read(customerRepositoryProvider).createOrUpdate(
                  mobile: mobile,
                  name: name.isNotEmpty ? name : 'Customer $mobile',
                );
        // Update cart's customerId
        await ref
            .read(salesRepositoryProvider)
            .updateCartCustomer(cartId, customerId);
      }
    } else {
      // Create new cart
      if (mobile.isNotEmpty) {
        final customerId =
            await ref.read(customerRepositoryProvider).createOrUpdate(
                  mobile: mobile,
                  name: name.isNotEmpty ? name : 'Customer $mobile',
                );
        cartId = await ref.read(salesRepositoryProvider).createCartWithCustomer(
              label,
              customerId,
              posCounterId: counterId,
            );
      } else {
        cartId = await ref.read(salesRepositoryProvider).createCart(
              label,
              posCounterId: counterId,
            );
      }
    }

    ref.read(selectedCartIdProvider.notifier).state = cartId;
    return cartId;
  }

  Future<void> _showInvoiceSearch() async {
    final searchCtrl = TextEditingController();
    final searchTypeNotifier = ValueNotifier<String>('mobile');

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Find Invoice'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Search by:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: searchTypeNotifier,
                builder: (context, type, _) => Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Customer Mobile'),
                      value: 'mobile',
                      groupValue: type,
                      onChanged: (v) =>
                          searchTypeNotifier.value = v ?? 'mobile',
                    ),
                    RadioListTile<String>(
                      title: const Text('Invoice Number'),
                      value: 'invoice',
                      groupValue: type,
                      onChanged: (v) =>
                          searchTypeNotifier.value = v ?? 'invoice',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  labelText: searchTypeNotifier.value == 'mobile'
                      ? 'Mobile Number'
                      : 'Invoice Number (e.g., INV-...)',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(
                    searchTypeNotifier.value == 'mobile'
                        ? Icons.phone
                        : Icons.receipt,
                  ),
                ),
                keyboardType: searchTypeNotifier.value == 'mobile'
                    ? TextInputType.phone
                    : TextInputType.text,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final query = searchCtrl.text.trim();
              if (query.isEmpty) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter search value')),
                  );
                }
                return;
              }

              try {
                List<Sale> invoices = [];

                if (searchTypeNotifier.value == 'mobile') {
                  invoices = await ref
                      .read(salesRepositoryProvider)
                      .findSalesByCustomerMobile(query, limit: 10);
                } else {
                  final sale = await ref
                      .read(salesRepositoryProvider)
                      .findByInvoiceNo(query);
                  if (sale != null) {
                    invoices = [sale];
                  }
                }

                if (!ctx.mounted) return;
                Navigator.pop(ctx);

                if (invoices.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No invoices found')),
                  );
                  return;
                }

                if (!mounted) return;
                _showInvoiceList(invoices);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Search failed: $e')),
                  );
                }
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _showInvoiceList(List<Sale> invoices) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Found ${invoices.length} Invoice${invoices.length > 1 ? 's' : ''}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...invoices.asMap().entries.map((entry) {
                final invoice = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: InkWell(
                    onTap: () => Navigator.pop(ctx),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invoice.invoiceNo,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '₹${invoice.grandTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  invoice.soldAt.toString().split('.')[0],
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.print_rounded),
                            onPressed: () {
                              // TODO: Implement invoice print
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (invoices.length >= 10) ...[
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // TODO: Navigate to customer module for full invoice list
                    // context.go('/customers');
                  },
                  child: const Text('Show More in Customer Module'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _printCartItems(List<CartItemWithProduct> rows) async {
    if (rows.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    final summary = ref.read(cartSummaryProvider(rows));
    final now = DateTime.now();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bill Preview'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bill Header
              Center(
                child: Column(
                  children: [
                    const Text('Bill of Supply',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('Cash', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Date and Invoice
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Date: ${now.day}/${now.month}/${now.year}',
                      style: const TextStyle(fontSize: 10)),
                  Text('Invoice no: ${now.millisecondsSinceEpoch % 1000}',
                      style: const TextStyle(fontSize: 10)),
                ],
              ),
              Text('Time: ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),

              const SizedBox(height: 12),
              const Divider(height: 1),

              // Table Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text('Item Name',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: Text('Qty',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center),
                    ),
                    Expanded(
                      child: Text('Price',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right),
                    ),
                    Expanded(
                      child: Text('Amount',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Items
              ...rows.map((row) {
                final lineTotal = row.product.sellingPrice * row.item.quantity;
                final taxText = row.item.taxPercent > 0
                    ? ' (${row.item.taxPercent.toStringAsFixed(0)}%)'
                    : '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text('${row.product.name}$taxText',
                            style: const TextStyle(fontSize: 9),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        child: Text(
                            row.item.quantity.toStringAsFixed(
                                row.item.quantity % 1 == 0 ? 0 : 1),
                            style: const TextStyle(fontSize: 9),
                            textAlign: TextAlign.center),
                      ),
                      Expanded(
                        child: Text(
                            '₹${row.product.sellingPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 9),
                            textAlign: TextAlign.right),
                      ),
                      Expanded(
                        child: Text('₹${lineTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 9),
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                );
              }),

              const Divider(height: 1),

              // Totals
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    // Bill discount percentage if applicable
                    if (summary.discountTotal > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Discount',
                              style:
                                  TextStyle(fontSize: 10, color: Colors.green)),
                          Text('-₹${summary.discountTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    // Subtotal (before discount)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text('₹${(summary.subTotal.toStringAsFixed(2))}',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Tax/GST
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('GST/Tax',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text('₹${summary.taxTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    // Grand Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Grand Total',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('₹${summary.grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Center(
                child: Text('Thank you for doing business with us',
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                    textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editCart(Cart cart) async {
    await _createQuickCart(existingCart: cart);
  }

  Future<void> _showCartItemsPopup(int cartId) async {
    // Calculate current discount from cart items
    final itemsAsync =
        await ref.read(salesRepositoryProvider).watchCartItems(cartId).first;
    double currentDiscountPercent = 0.0;

    if (itemsAsync.isNotEmpty) {
      final subtotal = itemsAsync.fold<double>(0,
          (sum, row) => sum + (row.product.sellingPrice * row.item.quantity));
      final totalDiscount = itemsAsync.fold<double>(
          0, (sum, row) => sum + row.item.discountAmount);
      if (subtotal > 0) {
        currentDiscountPercent = (totalDiscount * 100) / subtotal;
      }
    }

    final discountPercentCtrl = TextEditingController(
        text: currentDiscountPercent > 0
            ? currentDiscountPercent.toStringAsFixed(2)
            : '');
    final discountPercentNotifier =
        ValueNotifier<double>(currentDiscountPercent);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, child) {
          final cartItemsAsync = ref.watch(cartItemsProvider(cartId));

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cart Items'),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: cartItemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('Cart is empty'));
                }
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...rows.map((row) {
                        final lineTotal =
                            row.product.sellingPrice * row.item.quantity;
                        final gstAmount =
                            lineTotal * (row.product.taxPercent / 100);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            row.product.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            '₹${row.product.sellingPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(
                                                Icons.remove_circle_outline,
                                                size: 18),
                                            onPressed: () async {
                                              if (row.item.quantity <= 1) {
                                                await ref
                                                    .read(
                                                        salesRepositoryProvider)
                                                    .removeItem(row.item.id);
                                              } else {
                                                await ref
                                                    .read(
                                                        salesRepositoryProvider)
                                                    .updateItemQuantity(
                                                      row.item.id,
                                                      row.item.quantity - 1,
                                                    );
                                              }
                                            },
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Text(
                                            row.item.quantity.toStringAsFixed(
                                                row.item.quantity % 1 == 0
                                                    ? 0
                                                    : 1),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(
                                                Icons.add_circle_outline,
                                                size: 18),
                                            onPressed: () async {
                                              await ref
                                                  .read(salesRepositoryProvider)
                                                  .updateItemQuantity(
                                                    row.item.id,
                                                    row.item.quantity + 1,
                                                  );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Subtotal',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600),
                                    ),
                                    Text(
                                      '₹${lineTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                                if (row.product.taxPercent > 0) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'GST (${row.product.taxPercent.toStringAsFixed(0)}%)',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600),
                                      ),
                                      Text(
                                        '₹${gstAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                      const Divider(height: 24),
                      // Discount % field
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Discount %:',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (discCtx) => AlertDialog(
                                  title: const Text('Enter Discount %'),
                                  content: TextField(
                                    controller: discountPercentCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      hintText: '0',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(discCtx),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () async {
                                        final percent = double.tryParse(
                                                discountPercentCtrl.text) ??
                                            0.0;
                                        final clampedPercent =
                                            percent.clamp(0.0, 100.0);

                                        // Apply discount to cart in database
                                        try {
                                          await ref
                                              .read(salesRepositoryProvider)
                                              .updateCartDiscountPercent(
                                                  cartId, clampedPercent);
                                          discountPercentNotifier.value =
                                              clampedPercent;
                                          if (discCtx.mounted)
                                            Navigator.pop(discCtx);
                                        } catch (e) {
                                          if (discCtx.mounted) {
                                            ScaffoldMessenger.of(discCtx)
                                                .showSnackBar(SnackBar(
                                                    content:
                                                        Text('Error: $e')));
                                          }
                                        }
                                      },
                                      child: const Text('Apply'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: ValueListenableBuilder<double>(
                              valueListenable: discountPercentNotifier,
                              builder: (context, discPercent, _) => Text(
                                discPercent > 0
                                    ? '${discPercent.toStringAsFixed(1)}%'
                                    : 'Add',
                                style: TextStyle(
                                  color: discPercent > 0
                                      ? Colors.green
                                      : Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Summary with discount and GST
                      ValueListenableBuilder<double>(
                        valueListenable: discountPercentNotifier,
                        builder: (context, discPercent, _) {
                          final subtotal = rows.fold<double>(
                            0,
                            (sum, row) =>
                                sum +
                                (row.product.sellingPrice * row.item.quantity),
                          );
                          final discountAmount =
                              (subtotal * (discPercent / 100))
                                  .clamp(0, subtotal);
                          final taxableAmount = subtotal - discountAmount;
                          final totalGst = rows.fold<double>(
                            0,
                            (sum, row) {
                              final lineTotal =
                                  row.product.sellingPrice * row.item.quantity;
                              final lineTaxableAfterDisc =
                                  lineTotal * ((100 - discPercent) / 100);
                              return sum +
                                  (lineTaxableAfterDisc *
                                      (row.product.taxPercent / 100));
                            },
                          );
                          final finalTotal = taxableAmount + totalGst;

                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal'),
                                  Text('₹${subtotal.toStringAsFixed(2)}'),
                                ],
                              ),
                              if (discPercent > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        'Discount (${discPercent.toStringAsFixed(1)}%)'),
                                    Text(
                                      '-₹${discountAmount.toStringAsFixed(2)}',
                                      style:
                                          const TextStyle(color: Colors.green),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total GST'),
                                  Text('₹${totalGst.toStringAsFixed(2)}'),
                                ],
                              ),
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Grand Total',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  Text(
                                    '₹${finalTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              FilledButton.icon(
                onPressed: () async {
                  final itemsAsync = ref.read(cartItemsProvider(cartId));
                  if (itemsAsync is AsyncData) {
                    final cartRows = (itemsAsync as AsyncData).value;
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _checkoutDirect(cartId, cartRows);
                  }
                },
                icon: const Icon(Icons.payment_rounded),
                label: const Text('Checkout & Pay'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _checkoutDirect(
      int cartId, List<CartItemWithProduct> rows) async {
    if (rows.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty. Add products first.')),
      );
      return;
    }

    final summary = ref.read(cartSummaryProvider(rows));
    final paymentModeCtrl = ValueNotifier<String>('cash');

    // Fetch cart details to get customer info
    final cart = await ref.read(salesRepositoryProvider).getCart(cartId);
    final cartCustomerId = cart?.customerId;

    // Fetch customer details if cart has customer
    String? customerName;
    String? customerMobile;
    if (cartCustomerId != null) {
      final customer =
          await ref.read(customerRepositoryProvider).getById(cartCustomerId);
      customerName = customer?.name;
      customerMobile = customer?.mobile;
    }

    if (!mounted) return;
    final result = await showDialog<({String paymentMode, double paidAmount})?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Checkout'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Amount: ₹${summary.grandTotal.toStringAsFixed(2)}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Show customer details if available
              if (customerName != null || customerMobile != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (customerName != null)
                              Text(customerName!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            if (customerMobile != null)
                              Text(customerMobile!,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Walk-in Customer (no details)',
                          style: TextStyle(fontSize: 11, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text('Payment Mode:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: paymentModeCtrl,
                builder: (context, mode, _) => Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Cash'),
                      value: 'cash',
                      groupValue: mode,
                      onChanged: (v) => paymentModeCtrl.value = v ?? 'cash',
                    ),
                    RadioListTile<String>(
                      title: const Text('Card'),
                      value: 'card',
                      groupValue: mode,
                      onChanged: (v) => paymentModeCtrl.value = v ?? 'card',
                    ),
                    RadioListTile<String>(
                      title: const Text('UPI'),
                      value: 'upi',
                      groupValue: mode,
                      onChanged: (v) => paymentModeCtrl.value = v ?? 'upi',
                    ),
                    RadioListTile<String>(
                      title: const Text('Udhar (Credit)'),
                      value: 'credit',
                      groupValue: mode,
                      onChanged: (v) => paymentModeCtrl.value = v ?? 'credit',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              (
                paymentMode: paymentModeCtrl.value,
                paidAmount: summary.grandTotal
              ),
            ),
            child: const Text('Next'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    // If credit/udhar selected, require customer details
    if (result.paymentMode == 'credit') {
      final paidNowCtrl = TextEditingController();
      final nameCtrl = TextEditingController(text: customerName ?? '');
      final mobileCtrl = TextEditingController(text: customerMobile ?? '');

      if (!mounted) return;
      final udharResult = await showDialog<
          ({double paidNow, double creditAmount, String name, String mobile})?>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Udhar (Credit Sale)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total Amount: ₹${summary.grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  // Customer Details Section
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Customer Details *',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: mobileCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Payment Amount Section
                  TextField(
                    controller: paidNowCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount to Pay Now (₹)',
                      border: OutlineInputBorder(),
                      hintText: '0',
                      suffixText: 'Enter amount',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total to Pay:',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('₹${summary.grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Paying Now:',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                          '₹${(double.tryParse(paidNowCtrl.text) ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Credit (Udhar):',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600)),
                      Text(
                          '₹${(summary.grandTotal - (double.tryParse(paidNowCtrl.text) ?? 0)).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Back'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty ||
                      mobileCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Customer name and mobile are required')),
                    );
                    return;
                  }
                  final paidNow = double.tryParse(paidNowCtrl.text) ?? 0;
                  final creditAmount = summary.grandTotal - paidNow;
                  Navigator.pop(ctx, (
                    paidNow: paidNow,
                    creditAmount: creditAmount,
                    name: nameCtrl.text.trim(),
                    mobile: mobileCtrl.text.trim(),
                  ));
                },
                child: const Text('Confirm Udhar'),
              ),
            ],
          ),
        ),
      );
      if (udharResult == null || !mounted) return;

      try {
        // Create/update customer from Udhar dialog
        await ref.read(customerRepositoryProvider).createOrUpdate(
              mobile: udharResult.mobile,
              name: udharResult.name,
            );

        await ref.read(salesRepositoryProvider).checkout(
              cartId: cartId,
              paymentMode: 'credit',
              paidAmount: udharResult.paidNow,
              customerName: udharResult.name,
              customerMobile: udharResult.mobile,
            );
        ref.invalidate(dashboardMetricsProvider);
        ref.invalidate(salesReportProvider);
        ref.read(selectedCartIdProvider.notifier).state = null;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green.shade700,
              content: Text(
                'Udhar created: ₹${udharResult.creditAmount.toStringAsFixed(2)} to be paid later',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Udhar failed: $e')),
          );
        }
      }
      return;
    }

    try {
      // For Card/UPI/Cash: create Walk-in Customer if no details, else create/update customer
      String? checkoutCustomerName;
      String? checkoutCustomerMobile;

      if (customerName != null && customerMobile != null) {
        // Customer details exist - create/update
        checkoutCustomerName = customerName;
        checkoutCustomerMobile = customerMobile;
        await ref.read(customerRepositoryProvider).createOrUpdate(
              mobile: customerMobile,
              name: customerName,
            );
      } else {
        // No customer details - use Walk-in Customer
        checkoutCustomerName = 'Walk-in Customer';
        checkoutCustomerMobile = '0000000000';
        try {
          // Try to find or create Walk-in Customer
          final walkInCustomer = await ref
              .read(customerRepositoryProvider)
              .findByMobile('0000000000');
          if (walkInCustomer == null) {
            // Create Walk-in Customer if doesn't exist
            await ref.read(customerRepositoryProvider).createOrUpdate(
                  mobile: '0000000000',
                  name: 'Walk-in Customer',
                );
          }
        } catch (e) {
          // Ignore if Walk-in customer creation fails
        }
      }

      await ref.read(salesRepositoryProvider).checkout(
            cartId: cartId,
            paymentMode: result.paymentMode,
            paidAmount: result.paidAmount,
            customerName: checkoutCustomerName,
            customerMobile: checkoutCustomerMobile,
          );
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(salesReportProvider);
      ref.read(selectedCartIdProvider.notifier).state = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              'Checkout complete: ₹${summary.grandTotal.toStringAsFixed(2)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCartId = ref.watch(selectedCartIdProvider);
    final carts = ref.watch(activeCartsProvider).valueOrNull ?? const <Cart>[];

    Cart? selected;
    if (selectedCartId != null) {
      for (final cart in carts) {
        if (cart.id == selectedCartId) {
          selected = cart;
          break;
        }
      }
    }

    final cartItemsAsync = selectedCartId == null
        ? null
        : ref.watch(cartItemsProvider(selectedCartId));

    final rows = cartItemsAsync?.valueOrNull ?? const <CartItemWithProduct>[];
    final summary = ref.watch(cartSummaryProvider(rows));
    final qty = rows.fold<double>(0, (sum, row) => sum + row.item.quantity);
    final total = summary.grandTotal;

    return HidScannerListener(
      onScan: _handleScannerInput,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quick Checkout'),
          actions: [
            IconButton(
              tooltip: 'Find Invoice',
              onPressed: _isCartUpdating ? null : _showInvoiceSearch,
              icon: const Icon(Icons.search_rounded),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: _isGridView ? 'List view' : 'Grid view',
              onPressed: _isCartUpdating
                  ? null
                  : () => setState(() => _isGridView = !_isGridView),
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Open standard POS',
              onPressed: _isCartUpdating ? null : () => context.go('/billing'),
              icon: const Icon(Icons.point_of_sale_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            IgnorePointer(
              ignoring: _isCartUpdating,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Search by name, code or barcode',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: _searchCtrl.text.isEmpty
                                      ? null
                                      : IconButton(
                                          icon: const Icon(Icons.close_rounded),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            setState(() => _query = '');
                                            _loadInitial();
                                          },
                                        ),
                                ),
                                onChanged: (value) {
                                  _debounce?.cancel();
                                  _debounce = Timer(
                                    const Duration(milliseconds: 250),
                                    () {
                                      if (!mounted) return;
                                      setState(() => _query = value.trim());
                                      _loadInitial();
                                    },
                                  );
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Scan barcode',
                              onPressed: _scanAndSearchProduct,
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _autoCreateQuickCart,
                                icon: const Icon(Icons.add),
                                label: const Text('New Cart'),
                              ),
                              const SizedBox(width: 8),
                              for (final c in carts)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: c.id == selectedCartId
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ChoiceChip(
                                              selected: true,
                                              label: Text(c.name),
                                              onSelected: (_) => ref
                                                  .read(selectedCartIdProvider
                                                      .notifier)
                                                  .state = c.id,
                                            ),
                                            const SizedBox(width: 4),
                                            InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () async {
                                                final confirm =
                                                    await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                        'Delete Cart?'),
                                                    content: Text(
                                                        'Delete "${c.name}" and all items?'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                ctx, false),
                                                        child: const Text(
                                                            'Cancel'),
                                                      ),
                                                      FilledButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                ctx, true),
                                                        child: const Text(
                                                            'Delete'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true &&
                                                    mounted) {
                                                  await ref
                                                      .read(
                                                          salesRepositoryProvider)
                                                      .deleteCart(c.id);
                                                  ref
                                                      .read(
                                                          selectedCartIdProvider
                                                              .notifier)
                                                      .state = null;
                                                }
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade600,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : ChoiceChip(
                                          selected: false,
                                          label: Text(c.name),
                                          onSelected: (_) => ref
                                              .read(selectedCartIdProvider
                                                  .notifier)
                                              .state = c.id,
                                        ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isGridView
                        ? GridView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 170,
                              childAspectRatio: 1.0,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _products.length + (_loading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _products.length) {
                                return const Card(
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              final row = _products[index];
                              final busy =
                                  _addingProductIds.contains(row.product.id);

                              // Count this product in the cart
                              var cartCount = 0.0;
                              for (final item in rows) {
                                if (item.product.id == row.product.id) {
                                  cartCount = item.item.quantity;
                                  break;
                                }
                              }

                              // Watch stock in real-time from inventory provider
                              return Consumer(
                                builder: (context, localRef, _) {
                                  final inventoryAsync =
                                      localRef.watch(inventoryProvider);
                                  double stock = 0.0;

                                  if (inventoryAsync.hasValue) {
                                    final inventoryList =
                                        inventoryAsync.asData?.value ?? [];
                                    // Find stock for this product in real-time
                                    for (final item in inventoryList) {
                                      if (item.product.id == row.product.id) {
                                        stock += item.inventory.availableStock;
                                      }
                                    }
                                  }

                                  return _QuickCard(
                                    item: row,
                                    busy: busy,
                                    cartCount: cartCount,
                                    stock: stock,
                                    onTap: () => _onTapProduct(row),
                                  );
                                },
                              );
                            },
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: _products.length + (_loading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _products.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }
                              final row = _products[index];
                              final busy =
                                  _addingProductIds.contains(row.product.id);

                              // Count this product in the cart
                              var cartCount = 0.0;
                              for (final item in rows) {
                                if (item.product.id == row.product.id) {
                                  cartCount = item.item.quantity;
                                  break;
                                }
                              }

                              // Watch stock in real-time from inventory provider
                              return Consumer(
                                builder: (context, localRef, _) {
                                  final inventoryAsync =
                                      localRef.watch(inventoryProvider);
                                  double stock = 0.0;

                                  if (inventoryAsync.hasValue) {
                                    final inventoryList =
                                        inventoryAsync.asData?.value ?? [];
                                    // Find stock for this product in real-time
                                    for (final item in inventoryList) {
                                      if (item.product.id == row.product.id) {
                                        stock += item.inventory.availableStock;
                                      }
                                    }
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _QuickListItem(
                                      item: row,
                                      busy: busy,
                                      cartCount: cartCount,
                                      stock: stock,
                                      onTap: () => _onTapProduct(row),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: const Border(
                            top: BorderSide(color: Color(0xFFE5E5E5))),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isCartUpdating) ...[
                            Row(
                              children: const [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Updating cart...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            selected == null
                                                ? 'Select or create cart'
                                                : 'Cart: ${selected.name}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (selected != null)
                                          Tooltip(
                                            message: 'Edit cart',
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                  minWidth: 32, minHeight: 32),
                                              icon: const Icon(Icons.edit,
                                                  size: 16),
                                              onPressed: () =>
                                                  _editCart(selected!),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      'Qty: ${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 1)}  ·  Total: ₹${total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: selectedCartId == null ||
                                        rows.isEmpty
                                    ? null
                                    : () => _showCartItemsPopup(selectedCartId),
                                icon: const Icon(
                                    Icons.shopping_cart_checkout_rounded),
                                label: const Text('Checkout'),
                              ),
                              OutlinedButton.icon(
                                onPressed:
                                    selectedCartId == null || rows.isEmpty
                                        ? null
                                        : () => _printCartItems(rows),
                                icon: const Icon(Icons.print_rounded),
                                label: const Text('Print'),
                              ),
                              OutlinedButton.icon(
                                onPressed: selectedCartId == null
                                    ? null
                                    : () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Clear Cart?'),
                                            content: Text(
                                                'Remove all items from "${selected?.name}"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text('Clear'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true &&
                                            mounted &&
                                            selectedCartId != null) {
                                          final rows = await ref
                                              .read(salesRepositoryProvider)
                                              .watchCartItems(selectedCartId)
                                              .first;
                                          for (final item in rows) {
                                            await ref
                                                .read(salesRepositoryProvider)
                                                .removeItem(item.item.id);
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Clear'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isCartUpdating)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.item,
    required this.onTap,
    required this.busy,
    required this.cartCount,
    required this.stock,
  });

  final _QuickProductItem item;
  final VoidCallback onTap;
  final bool busy;
  final double cartCount;
  final double stock;

  @override
  Widget build(BuildContext context) {
    final emoji = item.emoji.trim();
    final isInCart = cartCount > 0;
    final backgroundColor = isInCart
        ? Colors.green.withValues(alpha: 0.15)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final borderColor = isInCart ? Colors.green : const Color(0xFFE3E3E3);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: busy ? null : onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isInCart ? 2 : 1,
          ),
          color: backgroundColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    emoji.isNotEmpty ? emoji : '🛒',
                    style: const TextStyle(fontSize: 22),
                  ),
                  const Spacer(),
                  if (isInCart)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${cartCount.toStringAsFixed(cartCount % 1 == 0 ? 0 : 1)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    )
                  else if (busy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(Icons.add_circle_rounded,
                        color: Theme.of(context).colorScheme.primary),
                ],
              ),
              const Spacer(),
              Text(
                item.product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '₹${item.product.sellingPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: stock <= 0
                          ? Colors.red.shade100
                          : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'S:${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 1)}',
                      style: TextStyle(
                        fontSize: 8,
                        color: stock <= 0 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickListItem extends StatelessWidget {
  const _QuickListItem({
    required this.item,
    required this.onTap,
    required this.busy,
    required this.cartCount,
    required this.stock,
  });

  final _QuickProductItem item;
  final VoidCallback onTap;
  final bool busy;
  final double cartCount;
  final double stock;

  @override
  Widget build(BuildContext context) {
    final emoji = item.emoji.trim();
    final isInCart = cartCount > 0;
    final backgroundColor = isInCart
        ? Colors.green.withValues(alpha: 0.15)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final borderColor = isInCart ? Colors.green : const Color(0xFFE3E3E3);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: busy ? null : onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isInCart ? 2 : 1,
          ),
          color: backgroundColor,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text(
                emoji.isNotEmpty ? emoji : '🛒',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '₹${item.product.sellingPrice.toStringAsFixed(2)}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: stock <= 0
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Stock: ${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 1)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: stock <= 0 ? Colors.red : Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isInCart)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${cartCount.toStringAsFixed(cartCount % 1 == 0 ? 0 : 1)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
              else if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.add_circle_rounded,
                    color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickProductItem {
  const _QuickProductItem({
    required this.product,
    required this.hideFromQuickCheckout,
    required this.emoji,
  });

  final Product product;
  final bool hideFromQuickCheckout;
  final String emoji;

  factory _QuickProductItem.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _QuickProductItem(
      product: productFromDoc(doc),
      hideFromQuickCheckout: data['hideFromQuickCheckout'] == true,
      emoji: (data['quickCheckoutEmoji'] as String?)?.trim() ?? '',
    );
  }
}
