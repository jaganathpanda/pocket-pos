import 'package:intl/intl.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

import '../models/invoice_branding.dart';
import '../models/printer_config.dart';

class PrinterFailure implements Exception {
  const PrinterFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class ThermalPrinterService {
  final PrinterManager _manager = PrinterManager();

  String toUserMessage(Object error) {
    if (error is PrinterFailure) return error.message;
    final raw = error.toString();
    final text = raw.toLowerCase();
    if (text.contains('permission')) {
      return 'Printer permission denied. Allow Bluetooth/USB permissions and try again.';
    }
    if (text.contains('bluetooth')) {
      return 'Bluetooth is unavailable. Turn on Bluetooth and try again.';
    }
    if (text.contains('usb')) {
      return 'USB printer is unavailable. Reconnect cable/device and try again.';
    }
    if (text.contains('timeout')) {
      return 'Printer connection timed out. Move closer or reconnect and retry.';
    }
    return 'Unable to print to thermal printer. $raw';
  }

  Future<List<PrinterDevice>> scanDevices(PrinterConnectionOption option) {
    return _manager.scanPrinters(
      timeout: const Duration(seconds: 5),
      types: {
        option == PrinterConnectionOption.usb
            ? PrinterConnectionType.usb
            : PrinterConnectionType.bluetooth,
      },
    );
  }

  Future<void> printInvoice({
    required PrinterConfig config,
    required InvoiceBranding branding,
    required String fallbackShopName,
    required String invoiceNo,
    required List<
            ({
              String name,
              double qty,
              double discountAmount,
              double netAmount
            })>
        items,
    required double grandTotal,
  }) async {
    if (!config.enabled) {
      throw const PrinterFailure(
        'Printer integration is disabled in Settings.',
      );
    }

    final targetType = config.connection == PrinterConnectionOption.usb
        ? PrinterConnectionType.usb
        : PrinterConnectionType.bluetooth;

    final devices = await _manager.scanPrinters(
      timeout: const Duration(seconds: 5),
      types: {targetType},
    );
    if (devices.isEmpty) {
      throw const PrinterFailure(
        'No printer found. Check Bluetooth/USB and try again.',
      );
    }

    final selected = _selectDevice(devices, config.deviceIdentifier);
    if (selected == null) {
      throw const PrinterFailure(
        'Configured printer not found. Update Device Identifier in Settings.',
      );
    }

    await _manager.connect(selected);

    try {
      final ticket = await Ticket.create(PaperSize.mm80);
      _composeTicket(
        ticket: ticket,
        branding: branding,
        fallbackShopName: fallbackShopName,
        invoiceNo: invoiceNo,
        items: items,
        grandTotal: grandTotal,
      );

      await _manager.printTicket(ticket);
      await _manager.waitWriteComplete();
    } finally {
      await _manager.disconnect();
    }
  }

  PrinterDevice? _selectDevice(List<PrinterDevice> devices, String identifier) {
    final key = identifier.trim().toLowerCase();
    if (key.isEmpty) return devices.first;

    for (final d in devices) {
      if (_deviceKey(d).toLowerCase() == key) return d;
    }
    for (final d in devices) {
      if (_deviceKey(d).toLowerCase().contains(key)) return d;
    }
    return null;
  }

  String deviceIdentifier(PrinterDevice d) => _deviceKey(d);

  String _deviceKey(PrinterDevice d) {
    return switch (d) {
      BluetoothPrinterDevice(address: final addr) => addr,
      BlePrinterDevice(deviceId: final id) => id,
      UsbPrinterDevice(identifier: final id) => id,
      NetworkPrinterDevice(host: final host, port: final port) => '$host:$port',
      _ => d.name,
    };
  }

  void _composeTicket({
    required Ticket ticket,
    required InvoiceBranding branding,
    required String fallbackShopName,
    required String invoiceNo,
    required List<
            ({
              String name,
              double qty,
              double discountAmount,
              double netAmount
            })>
        items,
    required double grandTotal,
  }) {
    final shopName = branding.displayName.trim().isNotEmpty
        ? branding.displayName.trim()
        : fallbackShopName;

    ticket.text(
      shopName,
      align: PrintAlign.center,
      style: const PrintTextStyle(
        bold: true,
        height: TextSize.size2,
        width: TextSize.size2,
      ),
    );

    if (branding.address.trim().isNotEmpty) {
      ticket.text(branding.address.trim(), align: PrintAlign.center);
    }
    final contact = [
      if (branding.phone.trim().isNotEmpty) branding.phone.trim(),
      if (branding.email.trim().isNotEmpty) branding.email.trim(),
    ].join(' | ');
    if (contact.isNotEmpty) {
      ticket.text(contact, align: PrintAlign.center);
    }
    if (branding.gstin.trim().isNotEmpty) {
      ticket.text('GSTIN: ${branding.gstin.trim()}', align: PrintAlign.center);
    }

    ticket.separator(char: '=');
    ticket.row([
      PrintColumn(
          text: 'Invoice', flex: 2, style: const PrintTextStyle(bold: true)),
      PrintColumn(text: invoiceNo, flex: 3, align: PrintAlign.right),
    ]);
    ticket.row([
      PrintColumn(text: 'Date', flex: 2),
      PrintColumn(
        text: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
        flex: 3,
        align: PrintAlign.right,
      ),
    ]);
    ticket.separator();

    ticket.row([
      PrintColumn(
          text: 'Item', flex: 6, style: const PrintTextStyle(bold: true)),
      PrintColumn(
          text: 'Qty',
          flex: 2,
          align: PrintAlign.center,
          style: const PrintTextStyle(bold: true)),
      PrintColumn(
          text: 'Amt',
          flex: 3,
          align: PrintAlign.right,
          style: const PrintTextStyle(bold: true)),
    ]);
    ticket.separator();

    var discountTotal = 0.0;
    for (final item in items) {
      discountTotal += item.discountAmount;
      ticket.row([
        PrintColumn(text: item.name.trim(), flex: 6),
        PrintColumn(text: _qty(item.qty), flex: 2, align: PrintAlign.center),
        PrintColumn(
            text: item.netAmount.toStringAsFixed(2),
            flex: 3,
            align: PrintAlign.right),
      ]);
      if (item.discountAmount > 0) {
        ticket.row([
          PrintColumn(text: '  Disc', flex: 6),
          PrintColumn(text: '', flex: 2),
          PrintColumn(
            text: '-${item.discountAmount.toStringAsFixed(2)}',
            flex: 3,
            align: PrintAlign.right,
          ),
        ]);
      }
    }

    ticket.separator();
    if (discountTotal > 0) {
      ticket.row([
        PrintColumn(text: 'Total Discount', flex: 8),
        PrintColumn(
          text: '-${discountTotal.toStringAsFixed(2)}',
          flex: 3,
          align: PrintAlign.right,
        ),
      ]);
    }
    ticket.row([
      PrintColumn(
          text: 'Grand Total', flex: 8, style: const PrintTextStyle(bold: true)),
      PrintColumn(
        text: grandTotal.toStringAsFixed(2),
        flex: 3,
        align: PrintAlign.right,
        style: const PrintTextStyle(bold: true),
      ),
    ]);

    ticket.separator(char: '=');
    ticket.text('Thank you!', align: PrintAlign.center);
    ticket.emptyLines();
    ticket.cut();
  }

  String _qty(double qty) {
    return qty % 1 == 0 ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);
  }
}
