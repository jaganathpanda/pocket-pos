import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/firestore/store_scope.dart';
import '../../products/data/firestore_product_repository.dart';
import '../../sales/data/firestore_sales_repository.dart';
import '../../sales/domain/sales_repository.dart';

class PublicStorefrontPage extends ConsumerStatefulWidget {
  const PublicStorefrontPage({super.key});

  @override
  ConsumerState<PublicStorefrontPage> createState() =>
      _PublicStorefrontPageState();
}

class _PublicStorefrontPageState extends ConsumerState<PublicStorefrontPage> {
  final _storeId = TextEditingController();
  final _customerName = TextEditingController();
  final _customerMobile = TextEditingController();
  final _search = TextEditingController();

  bool _busy = false;
  String? _error;
  String? _activeStoreId;
  String? _storeName;
  int? _cartId;
  bool _cartClosed = false;

  // Keep these streams stable across cart document updates. Recreating the
  // streams inside build() causes the product list to unsubscribe/resubscribe
  // whenever a cart item is added, which makes the products flicker.
  Stream<List<Product>>? _productsStream;
  Stream<List<CartItemWithProduct>>? _cartItemsStream;
  String? _streamStoreId;
  int? _streamCartId;

  // Listen to the cart document only for lifecycle changes (completed/deleted).
  // Normal cart updates such as updatedAt must NOT rebuild the storefront.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _cartSubscription;

  @override
  void dispose() {
    _cartSubscription?.cancel();

    _storeId.dispose();
    _customerName.dispose();
    _customerMobile.dispose();
    _search.dispose();
    super.dispose();
  }

  FirestoreProductRepository _productRepo(String storeId) {
    return FirestoreProductRepository(ref.read(firestoreProvider), storeId);
  }

  FirestoreSalesRepository _salesRepo(String storeId) {
    return FirestoreSalesRepository(ref.read(firestoreProvider), storeId,
        customerMode: true);
  }

  Future<void> _watchCart(int cartId, String storeId) async {
    await _cartSubscription?.cancel();

    final fs = ref.read(firestoreProvider);

    _cartSubscription = storeCollection(
      fs,
      storeId,
      'carts',
    ).doc('$cartId').snapshots().listen((snapshot) {
      if (!mounted) return;

      // Owner deleted the cart.
      if (!snapshot.exists) {
        if (!_cartClosed) {
          setState(() {
            _cartClosed = true;
          });
        }
        return;
      }

      final data = snapshot.data();
      final status = data?['status']?.toString().trim().toLowerCase();

      // Owner completed the cart.
      if (status == 'completed') {
        if (!_cartClosed) {
          setState(() {
            _cartClosed = true;
          });
        }
        return;
      }

      // Cart is active.
      //
      // IMPORTANT: Do not call setState() here. Normal changes such as
      // updatedAt after adding/changing an item must not rebuild the
      // entire storefront, otherwise the product list flickers.
    });
  }

  Future<void> _startShopping() async {
    final storeId = _storeId.text.trim().toUpperCase();
    final customerName = _customerName.text.trim();
    final customerMobile = _customerMobile.text.trim();

    if (storeId.isEmpty || customerName.isEmpty || customerMobile.isEmpty) {
      setState(() {
        _error = 'Enter store ID, customer name and mobile number.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // ── Step 1: Call Apps Script to validate + mint a scoped cart token ──
      final uri = Uri.parse(AppConstants.cartSessionEndpoint);
      // Replace HttpClient with http.post
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'text/plain'},
        body: jsonEncode({
          'storeId': storeId,
          'customerName': customerName,
          'mobile': customerMobile,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception(
            'Failed to connect to backend service (${response.statusCode})');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json.containsKey('error')) {
        throw Exception(json['error'] as String);
      }

      final customToken = json['customToken'] as String;
      final cartId = (json['cartId'] as num).toInt();
      final storeName = (json['storeName'] as String?) ?? storeId;

      // ── Step 2: Sign into Firebase with the scoped custom token ──────────
      final auth = FirebaseAuth.instance;
      await auth.signInWithCustomToken(customToken);
      final user = auth.currentUser;

      if (user == null) {
        throw Exception('Unable to create a customer session.');
      }

      final idTokenResult = await user.getIdTokenResult(true);

      debugPrint('========== CUSTOMER CART AUTH DEBUG ==========');
      debugPrint('UID: ${user.uid}');
      debugPrint('Store ID claim: ${idTokenResult.claims?['storeId']}');
      debugPrint('Cart ID claim: ${idTokenResult.claims?['cartId']}');
      debugPrint('Role claim: ${idTokenResult.claims?['role']}');
      debugPrint('ALL CLAIMS: ${idTokenResult.claims}');
      debugPrint('==============================================');
      // ── Step 3: Create the Firestore cart ONLY now ───────────────────────
      // Apps Script does not create the cart. Therefore if the HTTP request
      // fails before this point, no orphan cart is visible to the owner.
      // This is the single customer-cart creation point.
      final fs = ref.read(firestoreProvider);
      await storeCollection(fs, storeId, 'carts').doc('$cartId').set({
        'name': customerName,
        'status': 'active',
        'customerId': null,
        'posCounterId': null,
        'warehouseId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'source': 'customer',
        'customerName': customerName,
        'customerMobile': customerMobile,
        'createdByUid': user.uid,
      });

      // Stop watching the previous cart before switching to the new cart.
      await _cartSubscription?.cancel();
      _cartSubscription = null;

      // A new cart needs a fresh cart-item stream.
      _streamStoreId = null;
      _streamCartId = null;
      _productsStream = null;
      _cartItemsStream = null;

      setState(() {
        _activeStoreId = storeId;
        _storeName = storeName;
        _cartId = cartId;
        _cartClosed = false;
      });

      // Watch the cart only for lifecycle changes:
      // owner completion or owner deletion.
      await _watchCart(cartId, storeId);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addProduct(Product product) async {
    final storeId = _activeStoreId;
    final cartId = _cartId;
    if (storeId == null || cartId == null) return;

    try {
      await _salesRepo(storeId).addItem(cartId: cartId, productId: product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} added to your cart'),
          duration: const Duration(milliseconds: 900),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _changeQuantity(CartItem item, double quantity) async {
    final storeId = _activeStoreId;
    if (storeId == null) return;
    try {
      await _salesRepo(storeId)
          .updateItemQuantity(item.id, quantity.clamp(0, 999999).toDouble());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _removeItem(CartItem item) async {
    final storeId = _activeStoreId;
    if (storeId == null) return;
    await _salesRepo(storeId).removeItem(item.id);
  }

  Widget _buildActiveStorefront(
    BuildContext context,
    String storeId,
    int cartId,
  ) {
    // Keep these stream instances stable for the current store/cart.
    if (_streamStoreId != storeId || _streamCartId != cartId) {
      _streamStoreId = storeId;
      _streamCartId = cartId;
      _productsStream = _productRepo(storeId).watchAll();
      _cartItemsStream = _salesRepo(storeId).watchCartItems(cartId);
    }

    final products = _productsStream!;
    final items = _cartItemsStream!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;

        final productPane = StreamBuilder<List<Product>>(
          stream: products,
          builder: (context, snap) {
            final rows = snap.data ?? const <Product>[];
            final query = _search.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? rows
                : rows.where((p) {
                    final haystack =
                        '${p.name} ${p.productCode} ${p.barcode ?? ''}'
                            .toLowerCase();
                    return haystack.contains(query);
                  }).toList();
            return Card(
              margin: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        labelText: 'Search products',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: snap.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'No products available for this store.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final product = filtered[index];
                                  return ListTile(
                                    title: Text(product.name),
                                    subtitle: Text(
                                      'Code: ${product.productCode} · Rs ${product.sellingPrice.toStringAsFixed(2)}',
                                    ),
                                    trailing: FilledButton.tonalIcon(
                                      onPressed: () => _addProduct(product),
                                      icon: const Icon(Icons.add_shopping_cart),
                                      label: const Text('Add'),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );

        final cartPane = StreamBuilder<List<CartItemWithProduct>>(
          stream: items,
          builder: (context, snap) {
            final rows = snap.data ?? const <CartItemWithProduct>[];
            final totals = _CartTotals.fromItems(rows);
            return Card(
              margin: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Cart',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This cart appears live on the store POS as a customer cart.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Add products to start your cart.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final row = rows[index];
                              return ListTile(
                                title: Text(row.product.name),
                                subtitle: Text(
                                  'Rs ${row.item.unitPrice.toStringAsFixed(2)} x ${row.item.quantity.toStringAsFixed(0)}',
                                ),
                                trailing: SizedBox(
                                  width: 152,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        onPressed: () => _changeQuantity(
                                          row.item,
                                          row.item.quantity - 1,
                                        ),
                                        icon: const Icon(
                                            Icons.remove_circle_outline),
                                      ),
                                      Text(
                                          row.item.quantity.toStringAsFixed(0)),
                                      IconButton(
                                        onPressed: () => _changeQuantity(
                                          row.item,
                                          row.item.quantity + 1,
                                        ),
                                        icon: const Icon(
                                            Icons.add_circle_outline),
                                      ),
                                      IconButton(
                                        onPressed: () => _removeItem(row.item),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${totals.items} item${totals.items == 1 ? '' : 's'}',
                          ),
                        ),
                        Text(
                          'Rs ${totals.grandTotal.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );

        if (narrow) {
          return Column(
            children: [
              Expanded(flex: 3, child: productPane),
              SizedBox(height: 340, child: cartPane),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: productPane),
            SizedBox(width: 420, child: cartPane),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final storeId = _activeStoreId;
    final cartId = _cartId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          storeId == null ? 'Customer Storefront' : _storeName ?? storeId,
        ),
      ),
      body: storeId == null || cartId == null
          ? _StorefrontSetup(
              storeId: _storeId,
              customerName: _customerName,
              customerMobile: _customerMobile,
              busy: _busy,
              error: _error,
              onContinue: _startShopping,
            )
          : _cartClosed
              ? _CompletedCustomerCart(
                  onStartNewCart: _busy ? null : _startShopping,
                  cartId: cartId,
                )
              : _buildActiveStorefront(
                  context,
                  storeId,
                  cartId,
                ),
    );
  }
}

class _CompletedCustomerCart extends StatelessWidget {
  const _CompletedCustomerCart({
    required this.onStartNewCart,
    required this.cartId,
  });

  final Future<void> Function()? onStartNewCart;
  final int cartId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 72,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cart completed',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'The store owner has completed this cart. You can no longer add, remove, or change items in this cart.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cart #$cartId is closed.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onStartNewCart,
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Start a New Cart'),
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

class _StorefrontSetup extends StatelessWidget {
  const _StorefrontSetup({
    required this.storeId,
    required this.customerName,
    required this.customerMobile,
    required this.busy,
    required this.error,
    required this.onContinue,
  });

  final TextEditingController storeId;
  final TextEditingController customerName;
  final TextEditingController customerMobile;
  final bool busy;
  final String? error;
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.store_mall_directory_outlined,
                      size: 44, color: Color(0xFF005D4D)),
                  const SizedBox(height: 12),
                  Text(
                    'Create a customer cart',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the store ID and your details. The store owner will see this cart live in POS.',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: storeId,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Store ID',
                      hintText: 'STR-XXXXXX',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customerName,
                    decoration: const InputDecoration(
                      labelText: 'Your Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customerMobile,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    onSubmitted: (_) => busy ? null : onContinue(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: busy ? null : onContinue,
                      child: busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Start Shopping'),
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

class _CartTotals {
  const _CartTotals({required this.items, required this.grandTotal});

  final int items;
  final double grandTotal;

  factory _CartTotals.fromItems(List<CartItemWithProduct> items) {
    var quantity = 0.0;
    var total = 0.0;
    for (final row in items) {
      quantity += row.item.quantity;
      total +=
          (row.item.quantity * row.item.unitPrice) - row.item.discountAmount;
    }
    return _CartTotals(items: quantity.toInt(), grandTotal: total);
  }
}
