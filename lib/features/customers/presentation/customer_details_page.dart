import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/di/providers.dart';
import '../../../core/utilities/money.dart';

class CustomerDetailsPage extends ConsumerStatefulWidget {
  const CustomerDetailsPage({required this.customerId, super.key});

  final int customerId;

  @override
  ConsumerState<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends ConsumerState<CustomerDetailsPage> {
  late Future<Customer?> _customerFuture;
  late Future<List<({Sale sale, int itemCount})>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final db = ref.read(appDatabaseProvider);
    _customerFuture = (db.select(db.customers)..where((c) => c.id.equals(widget.customerId))).getSingleOrNull();
    _ordersFuture = ref.read(customerRepositoryProvider).getCustomerOrders(widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        elevation: 0,
      ),
      body: FutureBuilder<Customer?>(
        future: _customerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Customer not found'));
          }

          final customer = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        _infoRow('Mobile', customer.mobile ?? 'Not provided'),
                        const SizedBox(height: 8),
                        _infoRow('Address', customer.address ?? 'Not provided'),
                        const SizedBox(height: 8),
                        _infoRow('Loyalty Points', customer.loyaltyPoints.toString()),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Orders',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<({Sale sale, int itemCount})>>(
                  future: _ordersFuture,
                  builder: (context, ordersSnapshot) {
                    if (ordersSnapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      );
                    }
                    if (!ordersSnapshot.hasData || ordersSnapshot.data!.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No orders found',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                      );
                    }

                    final orders = ordersSnapshot.data!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () => context.push('/customer/${widget.customerId}/orders'),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Orders',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      orders.length.toString(),
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            color: Colors.blue,
                                          ),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.blue),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
