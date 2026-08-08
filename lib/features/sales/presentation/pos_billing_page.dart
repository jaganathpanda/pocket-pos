import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/models/discount_policy.dart';
import '../../barcode/presentation/barcode_scanner_page.dart';
import '../../barcode/presentation/hid_scanner_listener.dart';
import '../../warehouse/domain/inventory_mode.dart';

class PosBillingPage extends ConsumerWidget {
  const PosBillingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carts = ref.watch(activeCartsProvider);
    final rawSelectedCartId = ref.watch(selectedCartIdProvider);
    final counterName = ref.watch(currentUserProvider)?.posCounterName;

    // Only honor a selection that belongs to the current (counter-scoped)
    // active carts, so a lingering selection from a previous user/counter is
    // never shown. While the list is still loading we keep the raw value.
    final cartList0 = carts.valueOrNull;
    final selectedCartId = rawSelectedCartId == null
        ? null
        : (cartList0 == null
            ? rawSelectedCartId
            : (cartList0.any((c) => c.id == rawSelectedCartId)
                ? rawSelectedCartId
                : null));

    // Counter id -> name, so each cart tile can show which POS owns it.
    final counterNameById = {
      for (final c in (ref.watch(countersProvider).valueOrNull ?? const []))
        c.id: c.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
            counterName == null ? 'POS Billing' : 'POS Billing · $counterName'),
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
                  child: Text('Active Carts',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: carts.when(
                    data: (list) {
                      if (list.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'No active carts.\nTap New Cart to start.',
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
                              selectedTileColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              leading: const Icon(Icons.shopping_cart_outlined,
                                  size: 18),
                              title: Text(cart.name,
                                  style: const TextStyle(fontSize: 13)),
                              subtitle: _CartMetaText(
                                cart: cart,
                                counterName: counterNameById[cart.posCounterId],
                              ),
                              onTap: () => ref
                                  .read(selectedCartIdProvider.notifier)
                                  .state = cart.id,
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                onSelected: (value) async {
                                  if (value == 'rename') {
                                    await _showRenameCartDialog(
                                        context, ref, cart);
                                    return;
                                  }

                                  if (value == 'transfer') {
                                    await _showTransferCartDialog(
                                        context, ref, cart);
                                    return;
                                  }

                                  if (value == 'toggle_hold') {
                                    final next = cart.status == 'hold'
                                        ? 'active'
                                        : 'hold';
                                    await ref
                                        .read(salesRepositoryProvider)
                                        .setCartStatus(cart.id, next);
                                    ref.invalidate(dashboardMetricsProvider);
                                    return;
                                  }

                                  if (value == 'delete') {
                                    await ref
                                        .read(salesRepositoryProvider)
                                        .deleteCart(cart.id);
                                    if (cart.id == selectedCartId) {
                                      ref
                                          .read(selectedCartIdProvider.notifier)
                                          .state = null;
                                    }
                                    ref.invalidate(dashboardMetricsProvider);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Rename Cart'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'transfer',
                                    child: Text('Transfer to POS…'),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle_hold',
                                    child: Text(cart.status == 'hold'
                                        ? 'Resume Cart'
                                        : 'Hold Cart'),
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
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
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
                      Icon(Icons.point_of_sale_rounded,
                          size: 64, color: Colors.grey),
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
                        onPressed: () => ref
                            .read(selectedCartIdProvider.notifier)
                            .state = null,
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

  Future<void> _showCustomerMobileDialog(
      BuildContext context, WidgetRef ref) async {
    final mobileCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final customers = ref.read(customerRepositoryProvider);

    final mode =
        ref.read(inventoryModeProvider).valueOrNull ?? InventoryMode.single;
    final multiple = mode == InventoryMode.multiple;
    final warehouses =
        (ref.read(warehousesProvider).valueOrNull ?? const <Warehouse>[])
            .where((w) => w.isActive)
            .toList();
    int? selectedWarehouse = multiple
        ? (warehouses.isEmpty
            ? null
            : warehouses
                .firstWhere((w) => w.isDefault, orElse: () => warehouses.first)
                .id)
        : null;

    final result =
        await showDialog<({String mobile, String name, int? warehouseId})?>(
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
                    final foundCustomer =
                        await customers.findByMobile(value.trim());
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
                if (multiple) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: selectedWarehouse,
                    decoration: const InputDecoration(
                      labelText: 'Warehouse *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warehouse_rounded),
                    ),
                    items: [
                      for (final w in warehouses)
                        DropdownMenuItem(value: w.id, child: Text(w.name)),
                    ],
                    onChanged: (v) => setState(() => selectedWarehouse = v),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (multiple && selectedWarehouse == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('Select a warehouse for this cart.')),
                    );
                    return;
                  }
                  Navigator.pop(
                    ctx,
                    (
                      mobile: mobileCtrl.text.trim(),
                      name: nameCtrl.text.trim(),
                      warehouseId: selectedWarehouse,
                    ),
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
      final counterId = ref.read(activeCounterIdProvider);
      final warehouseId = result.warehouseId;

      if (mobile.isNotEmpty) {
        // Link cart to customer by mobile and update name when provided.
        final customerId = await customers.createOrUpdate(
          mobile: mobile,
          name: name.isNotEmpty ? name : 'Customer $mobile',
        );

        id = await ref.read(salesRepositoryProvider).createCartWithCustomer(
              cartLabel,
              customerId,
              posCounterId: counterId,
              warehouseId: warehouseId,
            );
      } else {
        // Name-only carts are allowed; keep cart unlinked from customers table.
        id = await ref.read(salesRepositoryProvider).createCart(
              cartLabel,
              posCounterId: counterId,
              warehouseId: warehouseId,
            );
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

  Future<void> _showRenameCartDialog(
      BuildContext context, WidgetRef ref, Cart cart) async {
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
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    await ref.read(salesRepositoryProvider).renameCart(cart.id, newName);
    ref.invalidate(dashboardMetricsProvider);
  }

  Future<void> _showTransferCartDialog(
      BuildContext context, WidgetRef ref, Cart cart) async {
    final counters =
        (ref.read(countersProvider).valueOrNull ?? const <PosCounter>[])
            .where((c) => c.isActive)
            .toList();
    if (counters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No POS counters yet. Ask the owner to add one.')),
      );
      return;
    }

    int selected = cart.posCounterId ?? counters.first.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Transfer Cart #${cart.id}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Move "${cart.name}" to another POS counter.'),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Target counter',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in counters)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) =>
                    setDialogState(() => selected = v ?? selected),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Transfer')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    await ref.read(salesRepositoryProvider).setCartCounter(cart.id, selected);

    // If the cart just left the current user's counter, drop the selection.
    final myCounter = ref.read(activeCounterIdProvider);
    if (myCounter != null &&
        myCounter != selected &&
        ref.read(selectedCartIdProvider) == cart.id) {
      ref.read(selectedCartIdProvider.notifier).state = null;
    }
    ref.invalidate(dashboardMetricsProvider);

    if (context.mounted) {
      final name = counters.firstWhere((c) => c.id == selected).name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cart #${cart.id} transferred to $name')),
      );
    }
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
  // While a dialog owns the keyboard, pause the page-level HID scanner so a
  // scan isn't handled twice (once by the dialog field, once by the page).
  bool _dialogOpen = false;

  /// Resolves a scanned/typed code to a product and adds it to the cart.
  Future<void> _addByBarcode(String code) async {
    final product =
        await ref.read(productRepositoryProvider).findByBarcode(code);
    if (!mounted) return;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No product found for "$code"')),
      );
      return;
    }
    try {
      await ref.read(salesRepositoryProvider).addItem(
            cartId: widget.cartId,
            productId: product.id,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${product.name}'),
            duration: const Duration(milliseconds: 900),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _scanWithCamera() async {
    setState(() => _dialogOpen = true);
    try {
      final code = await scanBarcodeWithCamera(context);
      if (code != null) await _addByBarcode(code);
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartItemsProvider(widget.cartId));

    return HidScannerListener(
      enabled: !_dialogOpen,
      onScan: _addByBarcode,
      child: Column(
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                                flex: 3,
                                child: Text('Product',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            Expanded(
                                flex: 4,
                                child: Text('Qty',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            Expanded(
                                flex: 2,
                                child: Text('Price',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            Expanded(
                                flex: 3,
                                child: Text('Total',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))),
                            SizedBox(width: 48),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Items list
                      Expanded(
                        child: list.isEmpty
                            ? const Center(
                                child: Text(
                                    'Cart is empty.\nTap Add Item to add products.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey)),
                              )
                            : ListView.separated(
                                itemCount: list.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final row = list[index];
                                  final lineTotal =
                                      row.item.quantity * row.item.unitPrice -
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
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                        ),
                                        Expanded(
                                          flex: 4,
                                          child: _QtyControl(
                                            qty: row.item.quantity,
                                            onChanged: (newQty) async {
                                              try {
                                                if (newQty <= 0) {
                                                  await ref
                                                      .read(
                                                          salesRepositoryProvider)
                                                      .removeItem(row.item.id);
                                                } else {
                                                  await ref
                                                      .read(
                                                          salesRepositoryProvider)
                                                      .updateItemQuantity(
                                                          row.item.id, newQty);
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                        content: Text('$e')),
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
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            '₹${lineTotal.toStringAsFixed(2)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close,
                                              size: 16, color: Colors.red),
                                          tooltip: 'Remove item',
                                          onPressed: () async {
                                            try {
                                              await ref
                                                  .read(salesRepositoryProvider)
                                                  .removeItem(row.item.id);
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
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
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
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
                            _sumRow(
                              'Bill Discount %',
                              summary.subTotal <= 0
                                  ? 0
                                  : (summary.discountTotal * 100 / summary.subTotal),
                              suffix: '%',
                            ),
                            _sumRow('Sub Total', summary.subTotal),
                            if (summary.discountTotal > 0)
                              _sumRow('Discount', -summary.discountTotal,
                                  color: Colors.green),
                            _sumRow('GST / Tax', summary.taxTotal),
                            const Divider(),
                            _sumRow('Grand Total', summary.grandTotal,
                                isBold: true),
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Scan barcode (camera)',
                    onPressed: _scanWithCamera,
                    icon: const Icon(Icons.qr_code_scanner),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _showAddItemDialog(context, ref),
                    icon: const Icon(Icons.add_shopping_cart_rounded),
                    label: const Text('Add Item'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showBillDiscountDialog(context, ref),
                    icon: const Icon(Icons.percent_rounded),
                    label: const Text('Bill Discount'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700),
                      onPressed: () => _showCheckoutDialog(context, ref),
                      icon: const Icon(Icons.receipt_long_rounded),
                      label: const Text('Checkout & Pay'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sumRow(String label, double value,
      {bool isBold = false, Color? color, String prefix = '₹', String suffix = ''}) {
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
          Text('$prefix${value.abs().toStringAsFixed(2)}$suffix', style: style),
        ],
      ),
    );
  }

  Future<void> _showBillDiscountDialog(BuildContext context, WidgetRef ref) async {
    final items = await ref
        .read(salesRepositoryProvider)
        .watchCartItems(widget.cartId)
        .first;
    if (items.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cart is empty.')),
        );
      }
      return;
    }

    final summary = ref.read(cartSummaryProvider(items));
    final currentPercent = summary.subTotal <= 0
        ? 0.0
        : (summary.discountTotal * 100 / summary.subTotal);
    final policy =
        ref.read(discountPolicyProvider).valueOrNull ??
            const DiscountPolicy.defaults();

    if (!policy.enabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bill discount is disabled in Settings.')),
        );
      }
      return;
    }

    final ctrl = TextEditingController(
      text: currentPercent.toStringAsFixed(currentPercent % 1 == 0 ? 0 : 2),
    );

    final percent = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bill Discount (%)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Allowed: 0 to ${policy.maxBillDiscountPercent.toStringAsFixed(policy.maxBillDiscountPercent % 1 == 0 ? 0 : 2)}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Discount percentage',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx, double.tryParse(ctrl.text.trim()));
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (percent == null || !context.mounted) return;
    if (percent < 0 || percent > policy.maxBillDiscountPercent + 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Discount cannot exceed ${policy.maxBillDiscountPercent.toStringAsFixed(2)}%.'),
        ),
      );
      return;
    }

    try {
      await ref
          .read(salesRepositoryProvider)
          .updateCartDiscountPercent(widget.cartId, percent);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Applied ${percent.toStringAsFixed(2)}% bill discount.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _showCheckoutDialog(BuildContext context, WidgetRef ref) async {
    final items = await ref
        .read(salesRepositoryProvider)
        .watchCartItems(widget.cartId)
        .first;
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
      customer =
          await ref.read(customerRepositoryProvider).getById(cart!.customerId!);
    }

    final customerMobileCtrl =
        TextEditingController(text: customer?.mobile ?? '');
    final customerNameCtrl = TextEditingController(text: customer?.name ?? '');
    final customerAddressCtrl =
        TextEditingController(text: customer?.address ?? '');

    String paymentMode = 'cash';

    if (!context.mounted) return;

    setState(() => _dialogOpen = true);
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
                  const Text('Customer (Optional)',
                      style:
                          TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
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
                  const Text('Payment Mode',
                      style:
                          TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                            value: 'cash',
                            label: Text('Cash'),
                            icon: Icon(Icons.money)),
                        ButtonSegment(
                            value: 'card',
                            label: Text('Card'),
                            icon: Icon(Icons.credit_card)),
                        ButtonSegment(
                            value: 'upi',
                            label: Text('UPI'),
                            icon: Icon(Icons.qr_code)),
                        ButtonSegment(
                            value: 'credit',
                            label: Text('Credit'),
                            icon: Icon(Icons.timer_outlined)),
                      ],
                      selected: {paymentMode},
                      onSelectionChanged: (s) =>
                          setDialogState(() => paymentMode = s.first),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount received
                  TextField(
                    controller: paidCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm Payment'),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() => _dialogOpen = false);

    if (confirmed != true || !context.mounted) return;

    try {
      final paid = double.tryParse(paidCtrl.text) ?? summary;
      await ref.read(salesRepositoryProvider).checkout(
            cartId: widget.cartId,
            paymentMode: paymentMode,
            paidAmount: paid,
            customerMobile: customerMobileCtrl.text.isEmpty
                ? null
                : customerMobileCtrl.text,
            customerName:
                customerNameCtrl.text.isEmpty ? null : customerNameCtrl.text,
            customerAddress: customerAddressCtrl.text.isEmpty
                ? null
                : customerAddressCtrl.text,
          );
      ref.invalidate(dashboardMetricsProvider);
      ref.invalidate(salesReportProvider);
      if (context.mounted) {
        ref.read(selectedCartIdProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content:
                Text('✓ Sale complete!  Payment: ${paymentMode.toUpperCase()}  '
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

  /// Adds a product to the cart by barcode/product-code from within the
  /// add-item dialog. Returns true when a matching product was found.
  Future<bool> _tryAddByCode(BuildContext dialogContext, String code) async {
    final product =
        await ref.read(productRepositoryProvider).findByBarcode(code);
    if (product == null) return false;
    try {
      await ref.read(salesRepositoryProvider).addItem(
            cartId: widget.cartId,
            productId: product.id,
          );
    } catch (e) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    return true;
  }

  Future<void> _showAddItemDialog(BuildContext context, WidgetRef ref) async {
    final query = TextEditingController();
    final results = ValueNotifier<List<dynamic>>([]);

    // Resolve which warehouse this cart draws from so we can show and enforce
    // per-warehouse stock. Null = stock not tracked (No-Inventory mode).
    final mode =
        ref.read(inventoryModeProvider).valueOrNull ?? InventoryMode.single;
    final cart = await ref.read(salesRepositoryProvider).getCart(widget.cartId);
    final int? stockWarehouseId = mode.tracksStock
        ? (cart?.warehouseId ??
            await ref.read(warehouseRepositoryProvider).defaultWarehouseId())
        : null;

    setState(() => _dialogOpen = true);
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
                  textInputAction: TextInputAction.search,
                  onChanged: (value) async {
                    if (value.trim().isEmpty) {
                      results.value = [];
                      return;
                    }
                    results.value =
                        await ref.read(productRepositoryProvider).search(value);
                  },
                  // Fires when a HID scanner sends its terminating Enter.
                  onSubmitted: (value) async {
                    final code = value.trim();
                    if (code.isEmpty) return;
                    if (await _tryAddByCode(ctx, code)) {
                      if (ctx.mounted) Navigator.pop(ctx);
                    } else {
                      results.value = await ref
                          .read(productRepositoryProvider)
                          .search(code);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Name / Code / Barcode',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Scan with camera',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () async {
                        final code = await scanBarcodeWithCamera(ctx);
                        if (code == null) return;
                        if (await _tryAddByCode(ctx, code)) {
                          if (ctx.mounted) Navigator.pop(ctx);
                        } else {
                          query.text = code;
                          results.value = await ref
                              .read(productRepositoryProvider)
                              .search(code);
                        }
                      },
                    ),
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
                          return _AddProductTile(
                            key: ValueKey(p.id),
                            product: p,
                            warehouseId: stockWarehouseId,
                            onAdd: () async {
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
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
          ],
        );
      },
    );
    if (mounted) setState(() => _dialogOpen = false);
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
          child:
              const Icon(Icons.remove_rounded, size: 18, color: Colors.orange),
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
          decoration: const InputDecoration(
              labelText: 'Quantity', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
  const _CartMetaText({required this.cart, this.counterName});

  final Cart cart;
  final String? counterName;

  Widget _wrap({String? mobile}) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (counterName != null) _CounterChip(name: counterName!),
        if (mobile != null && mobile.isNotEmpty)
          Text(mobile, style: const TextStyle(fontSize: 11)),
        _CartStatusChip(status: cart.status),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cart.customerId == null) {
      return _wrap();
    }

    return FutureBuilder<Customer?>(
      future: ref.read(customerRepositoryProvider).getById(cart.customerId!),
      builder: (_, snap) => _wrap(mobile: snap.data?.mobile),
    );
  }
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.indigo.shade700,
        ),
      ),
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

/// A product row in the Add-to-cart dialog. When [warehouseId] is provided
/// (stock is tracked) it shows that warehouse's available stock and disables
/// adding when the product is out of stock there.
class _AddProductTile extends ConsumerStatefulWidget {
  const _AddProductTile({
    super.key,
    required this.product,
    required this.warehouseId,
    required this.onAdd,
  });

  final dynamic product;
  final int? warehouseId;
  final Future<void> Function() onAdd;

  @override
  ConsumerState<_AddProductTile> createState() => _AddProductTileState();
}

class _AddProductTileState extends ConsumerState<_AddProductTile> {
  // Cached once so rebuilds don't re-issue the stock read (which caused the
  // tile to briefly flash "Out of stock" while the future re-resolved).
  Future<double>? _stockFuture;

  @override
  void initState() {
    super.initState();
    if (widget.warehouseId != null) {
      _stockFuture = ref.read(inventoryRepositoryProvider).availableStock(
            productId: widget.product.id,
            warehouseId: widget.warehouseId!,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final priceText = '₹${product.sellingPrice.toStringAsFixed(2)}';
    final meta = '${product.productCode}  •  ${product.unit}';

    // No stock tracking → always addable, no chip.
    if (widget.warehouseId == null) {
      return ListTile(
        title: Text(product.name),
        subtitle: Text(meta),
        trailing: Text(priceText,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        onTap: widget.onAdd,
      );
    }

    return FutureBuilder<double>(
      future: _stockFuture,
      builder: (_, snap) {
        // Until the stock read resolves, stay neutral — never render the red
        // "Out of stock" state on the initial (null) frame.
        final loading = snap.connectionState == ConnectionState.waiting;
        final available = snap.data ?? 0;
        final out = !loading && available <= 0;
        final label = available % 1 == 0
            ? available.toInt().toString()
            : available.toStringAsFixed(2);

        final Color chipBg;
        final Color chipBorder;
        final Color chipFg;
        if (loading) {
          chipBg = Colors.grey.shade100;
          chipBorder = Colors.grey.shade300;
          chipFg = Colors.grey.shade600;
        } else if (out) {
          chipBg = Colors.red.shade50;
          chipBorder = Colors.red.shade300;
          chipFg = Colors.red.shade700;
        } else {
          chipBg = Colors.green.shade50;
          chipBorder = Colors.green.shade300;
          chipFg = Colors.green.shade700;
        }

        return ListTile(
          enabled: !out,
          title: Text(product.name),
          subtitle: Row(
            children: [
              Expanded(child: Text(meta)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: chipBorder),
                ),
                child: loading
                    ? SizedBox(
                        height: 12,
                        width: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: chipFg),
                      )
                    : Text(
                        out ? 'Out of stock' : 'Stock: $label',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: chipFg,
                        ),
                      ),
              ),
            ],
          ),
          trailing: Text(priceText,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          onTap: out ? null : widget.onAdd,
        );
      },
    );
  }
}
