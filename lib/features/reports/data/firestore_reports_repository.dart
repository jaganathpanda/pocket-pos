import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../../core/firestore/firestore_mappers.dart';
import '../../../core/firestore/store_scope.dart';

/// Firestore aggregate reads for Dashboard, Sales Report and Credit Ledger,
/// scoped to a store (and optionally a single POS counter).
class FirestoreReportsRepository {
  FirestoreReportsRepository(this._db, this._storeId, this._counterId);

  final FirebaseFirestore _db;
  final String _storeId;
  final int? _counterId;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      storeCollection(_db, _storeId, name);

  bool _inCounter(int? posCounterId) =>
      _counterId == null || posCounterId == _counterId;

  Future<List<Sale>> _allSales() async {
    final snap = await _col('sales').get();
    return snap.docs
        .map(saleFromDoc)
        .where((s) => _inCounter(s.posCounterId))
        .toList();
  }

  // ── Dashboard ──────────────────────────────────────────────────────────────

  Future<DashboardMetrics> dashboard() async {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final sales = await _allSales();
    final today = sales.where((s) => !s.soldAt.isBefore(dayStart)).toList();

    final carts = (await _col('carts').get()).docs.map(cartFromDoc).where(
        (c) => (c.status == 'active' || c.status == 'hold') && _inCounter(c.posCounterId));
    final inventory = (await _col('inventory').get()).docs;
    final products = (await _col('products').get()).docs;
    final customers = (await _col('customers').get()).docs;

    double sum(Iterable<Sale> xs, double Function(Sale) f) =>
        xs.fold(0, (a, s) => a + f(s));

    final low = inventory.where((d) {
      final avail = fsNum(d.data()['availableStock']);
      return avail <= fsNum(d.data()['lowStockThreshold'], 5);
    }).length;
    final out =
        inventory.where((d) => fsNum(d.data()['availableStock']) <= 0).length;

    final credit = sales.where(
        (s) => s.paymentStatus == 'partial' || s.paymentStatus == 'credit');

    return DashboardMetrics(
      todayRevenue: sum(today, (s) => s.grandTotal),
      todayTransactions: today.length,
      totalRevenue: sum(sales, (s) => s.grandTotal),
      totalTransactions: sales.length,
      totalTax: sum(sales, (s) => s.taxTotal),
      totalDiscount: sum(sales, (s) => s.discountTotal),
      activeCarts: carts.length,
      lowStockItems: low,
      outOfStockItems: out,
      pendingCredit: sum(credit, (s) => s.grandTotal),
      totalProducts: products.length,
      totalCustomers: customers.length,
    );
  }

  // ── Sales report ─────────────────────────────────────────────────────────

  Future<SalesReportData> salesReport(DateTimeRange range) async {
    final start = DateTime(range.start.year, range.start.month, range.start.day);
    final end =
        DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);

    final salesInRange = (await _allSales())
        .where((s) => !s.soldAt.isBefore(start) && !s.soldAt.isAfter(end))
        .toList()
      ..sort((a, b) => b.soldAt.compareTo(a.soldAt));

    if (salesInRange.isEmpty) {
      return SalesReportData(
        start: start,
        end: end,
        totalSales: 0,
        totalAmount: 0,
        totalTax: 0,
        totalDiscount: 0,
        totalItems: 0,
        totalQuantity: 0,
        paymentMethodTotals: const {},
        topProducts: const [],
        rows: const [],
      );
    }

    final saleIds = salesInRange.map((s) => s.id).toSet();
    final allItems =
        (await _col('sale_items').get()).docs.map(saleItemFromDoc).where((i) => saleIds.contains(i.saleId)).toList();
    final allPayments =
        (await _col('payments').get()).docs.map(paymentFromDoc).where((p) => saleIds.contains(p.saleId)).toList();
    final products = {
      for (final d in (await _col('products').get()).docs)
        (int.tryParse(d.id) ?? 0): productFromDoc(d)
    };

    final itemsBySale = <int, List<SaleItem>>{};
    for (final i in allItems) {
      itemsBySale.putIfAbsent(i.saleId, () => []).add(i);
    }
    final paymentsBySale = <int, List<Payment>>{};
    for (final p in allPayments) {
      paymentsBySale.putIfAbsent(p.saleId, () => []).add(p);
    }

    final paymentMethodTotals = <String, double>{};
    for (final p in allPayments) {
      paymentMethodTotals[p.method] = (paymentMethodTotals[p.method] ?? 0) + p.amount;
    }

    final productTotals = <int, ({double qty, double amount})>{};
    for (final i in allItems) {
      final cur = productTotals[i.productId] ?? (qty: 0.0, amount: 0.0);
      productTotals[i.productId] =
          (qty: cur.qty + i.quantity, amount: cur.amount + i.lineTotal);
    }
    final topProducts = productTotals.entries
        .map((e) => TopSellingProduct(
              productId: e.key,
              name: products[e.key]?.name ?? 'Product #${e.key}',
              quantity: e.value.qty,
              amount: e.value.amount,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final rows = salesInRange.map((sale) {
      final pays = paymentsBySale[sale.id] ?? const <Payment>[];
      final paid = pays.fold<double>(0, (s, p) => s + p.amount);
      final due = (sale.grandTotal - paid).clamp(0, 999999999).toDouble();
      final items = itemsBySale[sale.id] ?? const <SaleItem>[];
      return SalesReportRow(
        saleId: sale.id,
        invoiceNo: sale.invoiceNo,
        soldAt: sale.soldAt,
        paymentStatus: sale.paymentStatus,
        grandTotal: sale.grandTotal,
        itemsCount: items.length,
        totalQty: items.fold<double>(0, (s, i) => s + i.quantity),
        paymentCount: pays.length,
        paidAmount: paid,
        dueAmount: due,
        productGstSummary: _gstSummary(items, products),
        paymentMethod: pays.isEmpty ? null : pays.last.method,
      );
    }).toList(growable: false);

    return SalesReportData(
      start: start,
      end: end,
      totalSales: salesInRange.length,
      totalAmount: salesInRange.fold<double>(0, (s, x) => s + x.grandTotal),
      totalTax: salesInRange.fold<double>(0, (s, x) => s + x.taxTotal),
      totalDiscount: salesInRange.fold<double>(0, (s, x) => s + x.discountTotal),
      totalItems: allItems.length,
      totalQuantity: allItems.fold<double>(0, (s, i) => s + i.quantity),
      paymentMethodTotals: paymentMethodTotals,
      topProducts: topProducts.take(5).toList(growable: false),
      rows: rows,
    );
  }

  // ── Credit ledger ─────────────────────────────────────────────────────────

  Future<List<CreditLedgerRow>> creditLedger() async {
    final sales = (await _allSales())..sort((a, b) => b.soldAt.compareTo(a.soldAt));
    if (sales.isEmpty) return const [];

    final saleIds = sales.map((s) => s.id).toSet();
    final payments = (await _col('payments').get())
        .docs
        .map(paymentFromDoc)
        .where((p) => saleIds.contains(p.saleId));
    final paidBySale = <int, double>{};
    for (final p in payments) {
      paidBySale[p.saleId] = (paidBySale[p.saleId] ?? 0) + p.amount;
    }
    final customers = {
      for (final d in (await _col('customers').get()).docs)
        (int.tryParse(d.id) ?? 0): _customerFromDoc(d)
    };

    return sales
        .map((sale) {
          final paid = paidBySale[sale.id] ?? 0;
          final due = (sale.grandTotal - paid).clamp(0, 999999999).toDouble();
          return CreditLedgerRow(
            sale: sale,
            customer: sale.customerId == null ? null : customers[sale.customerId],
            paidAmount: paid,
            dueAmount: due,
          );
        })
        .where((r) {
          final st = r.sale.paymentStatus.toLowerCase();
          return r.dueAmount > 0 || st == 'partial' || st == 'credit';
        })
        .toList(growable: false);
  }

  String _gstSummary(List<SaleItem> items, Map<int, Product> productById) {
    if (items.isEmpty) return '-';
    return items.map((item) {
      final name = productById[item.productId]?.name ?? 'Product #${item.productId}';
      final qty = item.quantity % 1 == 0
          ? item.quantity.toInt().toString()
          : item.quantity.toStringAsFixed(2);
      final gst = item.taxPercent % 1 == 0
          ? item.taxPercent.toInt().toString()
          : item.taxPercent.toStringAsFixed(2);
      return '$name x$qty (GST $gst%)';
    }).join(' | ');
  }

  Customer _customerFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Customer(
      id: int.tryParse(doc.id) ?? 0,
      name: (d['name'] as String?) ?? '',
      mobile: d['mobile'] as String?,
      address: d['address'] as String?,
      loyaltyPoints: (d['loyaltyPoints'] as num?)?.toInt() ?? 0,
    );
  }
}
