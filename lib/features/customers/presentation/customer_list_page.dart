import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
  final _searchController = TextEditingController();
  final _itemsPerPage = 10;
  int _currentPage = 0;
  List<Customer> _filteredCustomers = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _currentPage = 0;
    });
    _performSearch();
  }

  void _performSearch() async {
    final query = _searchController.text.trim();
    final customerRepo = ref.read(customerRepositoryProvider);
    
    if (query.isEmpty) {
      final customers = ref.read(customerRepositoryProvider).watchAll();
      customers.listen((list) {
        if (mounted) {
          setState(() {
            _filteredCustomers = list;
          });
        }
      });
    } else {
      final results = await customerRepo.searchByNameOrMobile(query);
      if (mounted) {
        setState(() {
          _filteredCustomers = results;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search by name or mobile',
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Customer>>(
              stream: ref.read(customerRepositoryProvider).watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('Error loading customers'));
                }

                final allCustomers = snapshot.data!;
                final displayCustomers = _searchController.text.isEmpty ? allCustomers : _filteredCustomers;
                if (displayCustomers.isEmpty) {
                  return Center(
                    child: Text(_searchController.text.isEmpty ? 'No customers found' : 'No results found'),
                  );
                }

                final totalPages = (displayCustomers.length / _itemsPerPage).ceil();
                final startIndex = _currentPage * _itemsPerPage;
                final endIndex = (startIndex + _itemsPerPage).clamp(0, displayCustomers.length);
                final paginatedCustomers = displayCustomers.sublist(startIndex, endIndex);

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: paginatedCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = paginatedCustomers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text(customer.name),
                              subtitle: Text(customer.mobile ?? 'No mobile'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => context.push('/customer/${customer.id}'),
                            ),
                          );
                        },
                      ),
                    ),
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded),
                              onPressed: _currentPage > 0
                                  ? () => setState(() => _currentPage--)
                                  : null,
                            ),
                            Text('Page ${_currentPage + 1} of $totalPages'),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded),
                              onPressed: _currentPage < totalPages - 1
                                  ? () => setState(() => _currentPage++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
