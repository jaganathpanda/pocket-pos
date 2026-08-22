import 'package:equatable/equatable.dart';

/// A single manual weighment line (used when weighMode == 'manual'): the miller
/// weighs items one by one on a platform scale (paddy, rice, bran, husk…).
class ManualWeightLine extends Equatable {
  final String product;
  final int? bags;
  final double weight;

  const ManualWeightLine({
    required this.product,
    this.bags,
    required this.weight,
  });

  ManualWeightLine copyWith({String? product, int? bags, double? weight}) =>
      ManualWeightLine(
        product: product ?? this.product,
        bags: bags ?? this.bags,
        weight: weight ?? this.weight,
      );

  Map<String, dynamic> toMap() =>
      {'product': product, 'bags': bags, 'weight': weight};

  factory ManualWeightLine.fromMap(Map<String, dynamic> m) => ManualWeightLine(
        product: m['product'] as String? ?? '',
        bags: (m['bags'] as num?)?.toInt(),
        weight: (m['weight'] as num?)?.toDouble() ?? 0,
      );

  @override
  List<Object?> get props => [product, bags, weight];
}

class VehicleEntry extends Equatable {
  final int id;
  final DateTime date;
  final String slipNo;
  final String? voucherNo;
  final String vehicleNo;
  final String? rstManual;
  final String partyName;
  final int? partyId;
  final int productId;
  final double firstWeight;
  final DateTime? firstWeightTime;
  final double secondWeight;
  final DateTime? secondWeightTime;
  final double netWeight;
  final int? bags;
  final String? lotNumber;
  final bool complete;
  final String? completeCode;
  final DateTime? completeDate;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String entryType;
  final String weighMode; // 'weighbridge' | 'manual'
  final List<ManualWeightLine> manualWeights;

  // Joined fields for display (not stored)
  final String? productName;
  final String? partyNameFromSupplier;

  const VehicleEntry({
    required this.id,
    required this.date,
    required this.slipNo,
    this.voucherNo,
    required this.vehicleNo,
    this.rstManual,
    required this.partyName,
    this.partyId,
    required this.productId,
    required this.firstWeight,
    this.firstWeightTime,
    required this.secondWeight,
    this.secondWeightTime,
    required this.netWeight,
    this.bags,
    this.lotNumber,
    this.complete = false,
    this.completeCode,
    this.completeDate,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    this.productName,
    this.partyNameFromSupplier,
    this.entryType = 'inward',
    this.weighMode = 'weighbridge',
    this.manualWeights = const [],
  });

  @override
  List<Object?> get props => [id, slipNo];
}

// Companion class for creation/updates (like Drift's companion)
class VehicleEntryCompanion {
  final int? id;
  final DateTime? date;
  final String? slipNo;
  final String? voucherNo;
  final String? vehicleNo;
  final String? rstManual;
  final String? partyName;
  final int? partyId;
  final int? productId;
  final double? firstWeight;
  final DateTime? firstWeightTime;
  final double? secondWeight;
  final DateTime? secondWeightTime;
  final double? netWeight;
  final int? bags;
  final String? lotNumber;
  final bool? complete;
  final String? completeCode;
  final DateTime? completeDate;
  final String? remark;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? entryType;
  final String? weighMode;
  final List<ManualWeightLine>? manualWeights;
  VehicleEntryCompanion({
    this.id,
    this.date,
    this.slipNo,
    this.voucherNo,
    this.vehicleNo,
    this.rstManual,
    this.partyName,
    this.partyId,
    this.productId,
    this.firstWeight,
    this.firstWeightTime,
    this.secondWeight,
    this.secondWeightTime,
    this.netWeight,
    this.bags,
    this.lotNumber,
    this.complete,
    this.completeCode,
    this.completeDate,
    this.remark,
    this.createdAt,
    this.updatedAt,
    this.entryType,
    this.weighMode,
    this.manualWeights,
  });
}
