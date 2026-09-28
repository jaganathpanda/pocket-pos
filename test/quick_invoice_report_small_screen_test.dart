import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_pos/features/products/presentation/quick_invoice_report_page.dart';

void main() {
  testWidgets('quick invoice trailing actions stay inside narrow mobile widths',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: ListTile(
                title: const Text('INV-1'),
                trailing: QuickInvoiceReportTrailing(
                  grandTotal: 2500,
                  createdAt: DateTime(2026, 9, 24, 10, 30),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('₹2,500.00'), findsOneWidget);
  });
}
