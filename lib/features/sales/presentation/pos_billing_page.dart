import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Expression;

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/di/providers.dart';

class PosBillingPage extends ConsumerWidget {
  const PosBillingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carts = ref.watch(activeCartsProvider);
    final selectedCartId = ref.watch(selectedCartIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Billing'),
        actions: [
          FilledButton.tonalIcon(
            onPressed: () async {
              await _showCustomerMobileDialog(context, ref);
            },
            icon: const Icon(Icons.add),
            label: const Text('New Cart'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          final Widget cartList = Card(
              margin: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Active Carts', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: carts.when(
                      data: (list) {
                        if (list.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No active carts.\nTap New Cart to start.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          );
                        }
                        return ListView(
                          children: [
                            for (final cart in list)
                              ListTile(
                                selected: cart.id == selectedCartId,
                                selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
                                leading: const Icon(Icons.shopping_cart_outlined, size: 18),
                                title: Text(cart.name, style: const TextStyle(fontSize: 13)),
                                subtitle: _CartMetaText(cart: cart),
                                onTap: () =>
                                    ref.read(selectedCartIdProvider.notifier).state = cart.id,
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 18),
                                  onSelected: (value) async {
                                    if (value == 'rename') {
                                      await _showRenameCartDialog(context, ref, cart);
                                      return;
                                    }

                                    if (value == 'toggle_hold') {
                                      final next = cart.status == 'hold' ? 'active' : 'hold';
                                      await ref.read(salesRepositoryProvider).setCartStatus(cart.id, next);
                                      ref.invalidate(dashboardMetricsProvider);
                                      return;
                                    }

                                    if (value == 'delete') {
                                      await ref.read(salesRepositoryProvider).deleteCart(cart.id);
                                      if (cart.id == selectedCartId) {
                                        ref.read(selectedCartIdProvider.notifier).state = null;
                                      }
                                      ref.invalidate(dashboardMetricsProvider);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'rename',
                                      child: Text('Rename Cart'),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle_hold',
                                      child: Text(cart.status == 'hold' ? 'Resume Cart' : 'Hold Cart'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete Cart'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('$e')),
                    ),
                  ),
                ],
              ),
            );

          final Widget details = selectedCartId == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.point_of_sale_rounded, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Create or select a cart to start billing',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : _CartDetails(cartId: selectedCartId);

          // Phones: show one pane at a time (cart list, or the selected cart).
          if (isNarrow) {
            if (selectedCartId == null) {
              return cartList;
            }
            return Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back to carts',
                        onPressed: () =>
                            ref.read(selectedCartIdProvider.notifier).state = null,
                      ),
                      const Expanded(
                        child: Text('Cart Details',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Expanded(child: details),
              ],
            );
          }

          // Wide screens: cart list beside the bill.
          return Row(
            children: [
              SizedBox(width: 240, child: cartList),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCustomerMobileDialog(BuildContext context, WidgetRef ref) async {
    final mobileCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final customers = ref.read(customerRepositoryProvider);

    final result = await showDialog<({String mobile, String name})?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.person_add_rounded),
                SizedBox(width: 8),
                Text('New Cart Details'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: mobileCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  onChanged: (value) async {
                    if (value.trim().isEmpty) {
                      nameCtrl.clear();
                      setState(() {});
                      return;
                    }

                    // Search for customer with this mobile
                    final foundCustomer = await customers.findByMobile(value.trim());
                    if (foundCustomer != null && ctx.mounted) {
                      nameCtrl.text = foundCustomer.name;
                      setState(() {});
                    } else {
                      nameCtrl.clear();
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    ctx,
                    (mobile: mobileCtrl.text.trim(), name: nameCtrl.text.trim()),
                  );
                },
                child: const Text('Create Cart'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || !context.mounted) return;

    final mobile = result.mobile;
    final name = result.name;

    if (name.isEmpty && mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter mobile number or customer name.')),
      );
      return;
    }

    final cartLabel = name.isNotEmpty ? name : mobile;

    try {
      int id;

      if (mobile.isNotEmpty) {
        // Link cart to customer by mobile and update name when provided.
        final customerId = await customers.createOrUpdate(
          mobile: mobile,
          name: name.isNotEmpty ? name : 'Customer $mobile',
        );

        id = await ref.read(salesRepositoryProvider).createCartWithCustomer(cartLabel, customerId);
      } else {
        // Name-only carts are allowed; keep cart unlinked from customers table.
        id = await ref.read(salesRepositoryProvider).createCart(cartLabel);
      }

      ref.read(selectedCartIdProvider.notifier).state = id;
      ref.invalidate(dashboardMetricsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showRenameCartDialog(BuildContext context, WidgetRef ref, Cart cart) async {
    final nameCtrl = TextEditingController(text: cart.name);
    final newName = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Cart'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Cart Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    await ref.read(salesRepositoryProvider).renameCart(cart.id, newName);
    ref.invalidate(dashboardMetricsProvider);
  }
}

// ─── Cart Detail Panel ─────────────────────────────────────────────────────────

class _CartDetails extends ConsumerStatefulWidget {
  const _CartDetails({required this.cartId});

  final int cartId;

  @override
  ConsumerState<_CartDetails> createState() => _CartDetailsState();
}

class _CartDetailsState extends ConsumerState<_CartDetails> {
  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartItemsProvider(widget.cartId));

    return Column(
      children: [
        Expanded(
          child: Card(
            margin: const EdgeInsets.fromLTRB(0, 12, 12, 0),
            child: items.when(
              data: (list) {
                final summary = ref.watch(cartSummaryProvider(list));
                return Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 4, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 3, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Items list
                    Expanded(
                      child: list.isEmpty
                          ? const Center(
                              child: Text('Cart is empty.\nTap Add Item to add products.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.separated(
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final row = list[index];
                                final lineTotal = row.item.quantity * row.item.unitPrice -
                                    row.item.discountAmount;
                                return ListTile(
                                  dense: true,
                                  title: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(row.product.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13)),
                                      ),
                                      Expanded(
                                        flex: 4,
                                        child: _QtyControl(
                                          qty: row.item.quantity,
                                          onChanged: (newQty) async {
                                            try {
                                              if (newQty <= 0) {
                                                await ref.read(salesRepositoryProvider).removeItem(row.item.id);
                                              } else {
                                                await ref.read(salesRepositoryProvider).updateItemQuantity(row.item.id, newQty);
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('$e')),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '₹${row.item.unitPrice.toStringAsFixed(2)}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          '₹${lineTotal.toStringAsFixed(2)}',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                              fontSize: 13, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                        tooltip: 'Remove item',
                                        onPressed: () async {
                                          try {
                                            await ref.read(salesRepositoryProvider).removeItem(row.item.id);
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('$e')),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    'Tax: ${row.item.taxPercent}%  |  Discount: ₹${row.item.discountAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                );
                              },
                            ),
                    ),
                    // Summary
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _sumRow('Sub Total', summary.subTotal),
                          if (summary.discountTotal > 0)
                            _sumRow('Discount', -summary.discountTotal,
                                color: Colors.green),
                          _sumRow('GST / Tax', summary.taxTotal),
                          const Divider(),
                          _sumRow('Grand Total', summary.grandTotal, isBold: true),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 12, 12),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: () => _showAddItemDialog(context, ref),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('Add Item'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                  onPressed: () => _showCheckoutDialog(context, ref),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Checkout & Pay'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _sumRow(String label, double value,
      {bool isBold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontSize: isBold ? 16 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('₹${value.abs().toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }

  Future<void> _showCheckoutDialog(BuildContext context, WidgetRef ref) async {
    final items = await ref.read(salesRepositoryProvider).watchCartItems(widget.cartId).first;
    if (items.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart is empty — add products first')),
        );
      }
      return;
    }

    final summary = ref.read(cartSummaryProvider(items)).grandTotal;
    final paidCtrl = TextEditingController(text: summary.toStringAsFixed(2));
    
    final cart = await ref.read(salesRepositoryProvider).getCart(widget.cartId);
    Customer? customer;
    if (cart?.customerId != null) {
      final db = ref.read(appDatabaseProvider);
      customer = await (db.select(db.customers)..where((c) => c.id.equals(cart!.customerId!))).getSingleOrNull();
    }

    final customerMobileCtrl = TextEditingController(text: customer?.mobile ?? '');
    final customerNameCtrl = TextEditingController(text: customer?.name ?? '');
    final customerAddressCtrl = TextEditingController(text: customer?.address ?? '');
    
    String paymentMode = 'cash';

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: Colors.green),
              SizedBox(width: 8),
              Text('Checkout'),
            ],
          ),
          content: SizedBox(
            width: (MediaQuery.sizeOf(ctx).width - 48).clamp(280.0, 420.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${items.length} item(s)',
                            style: const TextStyle(color: Colors.grey)),
                        Text('Total: ₹${summary.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Customer section
                  const Text('Customer (Optional)', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: customerMobileCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Mobile Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: customerNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: customerAddressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Payment mode
                  const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'cash', label: Text('Cash'), icon: Icon(Icons.money)),
                        ButtonSegment(value: 'card', label: Text('Card'), icon: Icon(Icons.credit_card)),
                        ButtonSegment(value: 'upi', label: Text('UPI'), icon: Icon(Icons.qr_code)),
                        ButtonSegment(value: 'credit', label: Text('Credit'), icon: Icon(Icons.timer_outlined)),
                      ],
                      selected: {paymentMode},
                      onSelectionChanged: (s) => setDialogState(() => paymentMode = s.first),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Amount received
                  TextField(
                    controller: paidCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount Received (₹)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_rupee),
                      isDense: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  
                  // Change calculation
                  Builder(builder: (context) {
                    final paid = double.tryParse(paidCtrl.text) ?? 0;
                    final change = paid - summary;
                    return change >= 0
                        ? Row(
                            children: [
                              const Icon(Icons.change_circle_outlined,
                                  size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              Text('Change: ₹${change.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.green)),
                            ],
                          )
                        : Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text('Short by: ₹${(-change).toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.orange)),
                            ],
                          );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final paid = double.tryParse(paidCtrl.text) ?? summary;
      await ref.read(salesRepositoryProvider).checkout(
            cartId: widget.cartId,
            paymentMode: paymentMode,
            paidAmount: paid,
            customerMobile: customerMobileCtrl.text.isEmpty ? null : customerMobileCtrl.text,
            customerName: customerNameCtrl.text.isEmpty ? null : customerNameCtrl.text,
            customerAddress: customerAddressCtrl.text.isEmpty ? null : customerAddressCtrl.text,
          );
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(salesReportProvider);
      if (context.mounted) {
        ref.read(selectedCartIdProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text('✓ Sale complete!  Payment: ${paymentMode.toUpperCase()}  '
                'Paid: ₹${paid.toStringAsFixed(2)}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Checkout failed: $e'),
          ),
        );
      }
    }
  }

  Future<void> _showAddItemDialog(BuildContext context, WidgetRef ref) async {
    final query = TextEditingController();
    final results = ValueNotifier<List<dynamic>>([]);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.search_rounded),
              SizedBox(width: 8),
              Text('Add Product to Cart'),
            ],
          ),
          content: SizedBox(
            width: (MediaQuery.sizeOf(ctx).width - 48).clamp(280.0, 500.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: query,
                  autofocus: true,
                  onChanged: (value) async {
                    if (value.trim().isEmpty) {
                      results.value = [];
                      return;
                    }
                    results.value = await ref.read(productRepositoryProvider).search(value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Name / Code / Barcode',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: ValueListenableBuilder<List<dynamic>>(
                    valueListenable: results,
                    builder: (_, list, __) {
                      if (list.isEmpty) {
                        return const Center(
                          child: Text('Search by name, code or barcode',
                              style: TextStyle(color: Colors.grey)),
                        );
                      }
                      return ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final p = list[index];
                          return ListTile(
                            title: Text(p.name),
                            subtitle: Row(
                              children: [
                                Expanded(child: Text('${p.productCode}  •  ${p.unit}')),
                                _AvailableStockChip(productId: p.id),
                              ],
                            ),
                            trailing: Text('₹${p.sellingPrice.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () async {
                              try {
                                await ref.read(salesRepositoryProvider).addItem(
                                      cartId: widget.cartId,
                                      productId: p.id,
                                    );
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('$e')),
                                  );
                                }
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        );
      },
    );
  }
}

// ─── Quantity control widget ───────────────────────────────────────────────────

class _QtyControl extends StatelessWidget {
  const _QtyControl({required this.qty, required this.onChanged});

  final double qty;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => onChanged(qty - 1),
          borderRadius: BorderRadius.circular(4),
          child: const Icon(Icons.remove_rounded, size: 18, color: Colors.orange),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _editQty(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: () => onChanged(qty + 1),
          borderRadius: BorderRadius.circular(4),
          child: const Icon(Icons.add_rounded, size: 18, color: Colors.green),
        ),
      ],
    );
  }

  Future<void> _editQty(BuildContext context) async {
    final ctrl = TextEditingController(
        text: qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Quantity'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (result != null && result >= 0) {
      onChanged(result);
    }
  }
}

class _CartMetaText extends ConsumerWidget {
  const _CartMetaText({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cart.customerId == null) {
      return _CartStatusChip(status: cart.status);
    }

    final db = ref.read(appDatabaseProvider);
    return FutureBuilder<Customer?>(
      future: (db.select(db.customers)..where((c) => c.id.equals(cart.customerId!))).getSingleOrNull(),
      builder: (_, snap) {
        final mobile = snap.data?.mobile;
        if (mobile == null || mobile.isEmpty) {
          return _CartStatusChip(status: cart.status);
        }
        return Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(mobile, style: const TextStyle(fontSize: 11)),
            _CartStatusChip(status: cart.status),
          ],
        );
      },
    );
  }
}

class _CartStatusChip extends StatelessWidget {
  const _CartStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final bool isHold = normalized == 'hold';
    final bool isCompleted = normalized == 'completed';

    final Color bg = isHold
        ? Colors.orange.shade50
        : isCompleted
            ? Colors.blue.shade50
            : Colors.green.shade50;
    final Color border = isHold
        ? Colors.orange.shade300
        : isCompleted
            ? Colors.blue.shade300
            : Colors.green.shade300;
    final Color text = isHold
        ? Colors.orange.shade800
        : isCompleted
            ? Colors.blue.shade800
            : Colors.green.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        normalized.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }
}

class _AvailableStockChip extends ConsumerWidget {
  const _AvailableStockChip({required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(appDatabaseProvider);
    return FutureBuilder<InventoryData?>(
      future: (db.select(db.inventory)
            ..where((i) => Expression.and([i.productId.equals(productId), i.variantId.isNull()])))
          .getSingleOrNull(),
      builder: (_, snap) {
        final available = snap.data?.availableStock ?? 0;
        final low = available <= 0;
        final label = available % 1 == 0
            ? available.toInt().toString()
            : available.toStringAsFixed(2);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: low ? Colors.red.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: low ? Colors.red.shade300 : Colors.green.shade300),
          ),
          child: Text(
            'Stock: $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: low ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
        );
      },
    );
  }
}
