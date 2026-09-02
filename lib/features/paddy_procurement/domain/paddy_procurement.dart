import 'package:equatable/equatable.dart';

class PaddyProcurement extends Equatable {
  final int? id;
  final DateTime date;
  final String slipNo;
  final String? voucherNo;
  final String? rstManual;
  final String? area;
  final String vType;
  final String partyName;
  final int? partyId;
  final String? truckNo;
  final double? emptyWeight;
  final String marketType; // 'MKT' or 'FT'
  final double? grossWeight;
  final double? tareWeight;
  final int? juteBags;
  final int? plasticBags;
  final int? totalBags;
  final bool gnyWtLess;
  final bool bagReturn;
  final double? otherCut;
  final double? dustCut;
  final double? polCut;
  final String? qualityGrade;
  final double? unloadTime;
  final double? eBag;
  final double? ePkt;
  final double netWeight;
  final double? avgBagWeight;
  final String rateCalculation; // 'Qntl' or 'Kg'
  final double? kgPerBag;
  final int productId;
  final String productName;
  final String quantityNew; // 'N' or 'Y'
  final double? quantityQntl;
  final double? ratePerQntl;
  final double? totalAmount;
  final double? avgRate;
  final double? avgAmount;
  final double? qrtCutAmt;
  final double? paddyAmt;
  final List<QualityCut> qualityCuts;
  final double? totalCutKg;
  final double? finalWeight;
  final List<GunnyTransaction> gunnyTransactions;
  final String? deliveryType;
  final String? truckRentType;
  final double? truckRent;
  final double? truckRentPaid;
  final double? otherAmount;
  final String? transportType;
  final String? truckAccount;
  final double? freightAmount;
  final String procurementType; // 'local' or 'mandi'
  final String? mandiInvoiceNo;
  final String? tenderNumber;
  final int? commissionAgentId;
  final int? warehouseId;

  /// How the procured paddy is split across godowns (multi-warehouse mode).
  /// Empty = store all in [warehouseId] (single-warehouse behaviour).
  final List<WarehouseAllocation> warehouseAllocations;
  final int? vehicleEntryId;
  final String? weighMode; // 'weighbridge' or 'manual' (from the vehicle entry)
  final double? remainingStock;
  final String status; // 'draft', 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaddyProcurement({
    this.id,
    required this.date,
    required this.slipNo,
    this.voucherNo,
    this.rstManual,
    this.area,
    this.vType = 'BILL',
    required this.partyName,
    this.partyId,
    this.truckNo,
    this.emptyWeight,
    this.marketType = 'FT',
    this.grossWeight,
    this.tareWeight,
    this.juteBags,
    this.plasticBags,
    this.totalBags,
    this.gnyWtLess = false,
    this.bagReturn = false,
    this.otherCut,
    this.dustCut,
    this.polCut,
    this.qualityGrade,
    this.unloadTime,
    this.eBag,
    this.ePkt,
    required this.netWeight,
    this.avgBagWeight,
    this.rateCalculation = 'Qntl',
    this.kgPerBag = 75,
    required this.productId,
    required this.productName,
    this.quantityNew = 'N',
    this.quantityQntl,
    this.ratePerQntl,
    this.totalAmount,
    this.avgRate,
    this.avgAmount,
    this.qrtCutAmt,
    this.paddyAmt,
    this.qualityCuts = const [],
    this.totalCutKg,
    this.finalWeight,
    this.gunnyTransactions = const [],
    this.deliveryType,
    this.truckRentType,
    this.truckRent,
    this.truckRentPaid,
    this.otherAmount,
    this.transportType,
    this.truckAccount,
    this.freightAmount,
    this.procurementType = 'local',
    this.mandiInvoiceNo,
    this.tenderNumber,
    this.commissionAgentId,
    this.warehouseId,
    this.warehouseAllocations = const [],
    this.vehicleEntryId,
    this.weighMode,
    this.remainingStock,
    this.status = 'draft',
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, slipNo, partyName];
}

/// One line of a procurement's warehouse split: [quantityKg] of paddy stored
/// in godown [warehouseId].
class WarehouseAllocation extends Equatable {
  final int warehouseId;
  final double quantityKg;

  const WarehouseAllocation({
    required this.warehouseId,
    required this.quantityKg,
  });

  Map<String, dynamic> toMap() =>
      {'warehouseId': warehouseId, 'quantityKg': quantityKg};

  factory WarehouseAllocation.fromMap(Map<String, dynamic> m) =>
      WarehouseAllocation(
        warehouseId: (m['warehouseId'] as num?)?.toInt() ?? 0,
        quantityKg: (m['quantityKg'] as num?)?.toDouble() ?? 0,
      );

  @override
  List<Object?> get props => [warehouseId, quantityKg];
}

class QualityCut extends Equatable {
  final int? id;
  final int sl;
  final String qualityName;
  final double bagQuantity;
  final String cutType; // 'Pkts' or 'Qntl'
  final double cutPerUnit;
  final double difference;
  final double cutQuantityKg;
  final String remark;

  const QualityCut({
    this.id,
    required this.sl,
    required this.qualityName,
    required this.bagQuantity,
    required this.cutType,
    required this.cutPerUnit,
    required this.difference,
    required this.cutQuantityKg,
    this.remark = '',
  });

  QualityCut copyWith({
    int? id,
    int? sl,
    String? qualityName,
    double? bagQuantity,
    String? cutType,
    double? cutPerUnit,
    double? difference,
    double? cutQuantityKg,
    String? remark,
  }) {
    return QualityCut(
      id: id ?? this.id,
      sl: sl ?? this.sl,
      qualityName: qualityName ?? this.qualityName,
      bagQuantity: bagQuantity ?? this.bagQuantity,
      cutType: cutType ?? this.cutType,
      cutPerUnit: cutPerUnit ?? this.cutPerUnit,
      difference: difference ?? this.difference,
      cutQuantityKg: cutQuantityKg ?? this.cutQuantityKg,
      remark: remark ?? this.remark,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sl': sl,
      'qualityName': qualityName,
      'bagQuantity': bagQuantity,
      'cutType': cutType,
      'cutPerUnit': cutPerUnit,
      'difference': difference,
      'cutQuantityKg': cutQuantityKg,
      'remark': remark,
    };
  }

  factory QualityCut.fromMap(Map<String, dynamic> map) {
    return QualityCut(
      id: map['id'] as int?,
      sl: (map['sl'] as num?)?.toInt() ?? 0,
      qualityName: map['qualityName'] as String? ?? '',
      bagQuantity: (map['bagQuantity'] as num?)?.toDouble() ?? 0,
      cutType: map['cutType'] as String? ?? 'Pkts',
      cutPerUnit: (map['cutPerUnit'] as num?)?.toDouble() ?? 0,
      difference: (map['difference'] as num?)?.toDouble() ?? 0,
      cutQuantityKg: (map['cutQuantityKg'] as num?)?.toDouble() ?? 0,
      remark: map['remark'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, sl, qualityName];
}

class GunnyTransaction extends Equatable {
  final int? id;
  final String bagType; // 'J.PKT', 'P.PKT', 'REJ', 'OLD', 'Other'
  final int? receivedQty;
  final int? issuedQty;

  const GunnyTransaction({
    this.id,
    required this.bagType,
    this.receivedQty,
    this.issuedQty,
  });

  GunnyTransaction copyWith({
    int? id,
    String? bagType,
    int? receivedQty,
    int? issuedQty,
  }) {
    return GunnyTransaction(
      id: id ?? this.id,
      bagType: bagType ?? this.bagType,
      receivedQty: receivedQty ?? this.receivedQty,
      issuedQty: issuedQty ?? this.issuedQty,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bagType': bagType,
      'receivedQty': receivedQty,
      'issuedQty': issuedQty,
    };
  }

  factory GunnyTransaction.fromMap(Map<String, dynamic> map) {
    return GunnyTransaction(
      id: map['id'] as int?,
      bagType: map['bagType'] as String? ?? '',
      receivedQty: (map['receivedQty'] as num?)?.toInt(),
      issuedQty: (map['issuedQty'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [id, bagType];
}

class PaddyProcurementCompanion {
  final int? id;
  final DateTime? date;
  final String? slipNo;
  final String? voucherNo;
  final String? rstManual;
  final String? area;
  final String? vType;
  final String? partyName;
  final int? partyId;
  final String? truckNo;
  final double? emptyWeight;
  final String? marketType;
  final double? grossWeight;
  final double? tareWeight;
  final int? juteBags;
  final int? plasticBags;
  final int? totalBags;
  final bool? gnyWtLess;
  final bool? bagReturn;
  final double? otherCut;
  final double? dustCut;
  final double? polCut;
  final String? qualityGrade;
  final double? unloadTime;
  final double? eBag;
  final double? ePkt;
  final double? netWeight;
  final double? avgBagWeight;
  final String? rateCalculation;
  final double? kgPerBag;
  final int? productId;
  final String? productName;
  final String? quantityNew;
  final double? quantityQntl;
  final double? ratePerQntl;
  final double? totalAmount;
  final double? avgRate;
  final double? avgAmount;
  final double? qrtCutAmt;
  final double? paddyAmt;
  final List<QualityCut>? qualityCuts;
  final double? totalCutKg;
  final double? finalWeight;
  final List<GunnyTransaction>? gunnyTransactions;
  final String? deliveryType;
  final String? truckRentType;
  final double? truckRent;
  final double? truckRentPaid;
  final double? otherAmount;
  final String? transportType;
  final String? truckAccount;
  final double? freightAmount;
  final String? procurementType;
  final String? mandiInvoiceNo;
  final String? tenderNumber;
  final int? commissionAgentId;
  final int? warehouseId;
  final List<WarehouseAllocation>? warehouseAllocations;
  final int? vehicleEntryId;
  final String? weighMode;
  final double? remainingStock;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PaddyProcurementCompanion({
    this.id,
    this.date,
    this.slipNo,
    this.voucherNo,
    this.rstManual,
    this.area,
    this.vType,
    this.partyName,
    this.partyId,
    this.truckNo,
    this.emptyWeight,
    this.marketType,
    this.grossWeight,
    this.tareWeight,
    this.juteBags,
    this.plasticBags,
    this.totalBags,
    this.gnyWtLess,
    this.bagReturn,
    this.otherCut,
    this.dustCut,
    this.polCut,
    this.qualityGrade,
    this.unloadTime,
    this.eBag,
    this.ePkt,
    this.netWeight,
    this.avgBagWeight,
    this.rateCalculation,
    this.kgPerBag,
    this.productId,
    this.productName,
    this.quantityNew,
    this.quantityQntl,
    this.ratePerQntl,
    this.totalAmount,
    this.avgRate,
    this.avgAmount,
    this.qrtCutAmt,
    this.paddyAmt,
    this.qualityCuts,
    this.totalCutKg,
    this.finalWeight,
    this.gunnyTransactions,
    this.deliveryType,
    this.truckRentType,
    this.truckRent,
    this.truckRentPaid,
    this.otherAmount,
    this.transportType,
    this.truckAccount,
    this.freightAmount,
    this.procurementType,
    this.mandiInvoiceNo,
    this.tenderNumber,
    this.commissionAgentId,
    this.warehouseId,
    this.warehouseAllocations,
    this.vehicleEntryId,
    this.weighMode,
    this.remainingStock,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  /// Builds a companion carrying every field of a full [PaddyProcurement]
  /// (including its id) — used to mirror a locally-saved record to Firestore.
  factory PaddyProcurementCompanion.fromModel(PaddyProcurement p) {
    return PaddyProcurementCompanion(
      id: p.id,
      date: p.date,
      slipNo: p.slipNo,
      voucherNo: p.voucherNo,
      rstManual: p.rstManual,
      area: p.area,
      vType: p.vType,
      partyName: p.partyName,
      partyId: p.partyId,
      truckNo: p.truckNo,
      emptyWeight: p.emptyWeight,
      marketType: p.marketType,
      grossWeight: p.grossWeight,
      tareWeight: p.tareWeight,
      juteBags: p.juteBags,
      plasticBags: p.plasticBags,
      totalBags: p.totalBags,
      gnyWtLess: p.gnyWtLess,
      bagReturn: p.bagReturn,
      otherCut: p.otherCut,
      dustCut: p.dustCut,
      polCut: p.polCut,
      qualityGrade: p.qualityGrade,
      unloadTime: p.unloadTime,
      eBag: p.eBag,
      ePkt: p.ePkt,
      netWeight: p.netWeight,
      avgBagWeight: p.avgBagWeight,
      rateCalculation: p.rateCalculation,
      kgPerBag: p.kgPerBag,
      productId: p.productId,
      productName: p.productName,
      quantityNew: p.quantityNew,
      quantityQntl: p.quantityQntl,
      ratePerQntl: p.ratePerQntl,
      totalAmount: p.totalAmount,
      avgRate: p.avgRate,
      avgAmount: p.avgAmount,
      qrtCutAmt: p.qrtCutAmt,
      paddyAmt: p.paddyAmt,
      qualityCuts: p.qualityCuts,
      totalCutKg: p.totalCutKg,
      finalWeight: p.finalWeight,
      gunnyTransactions: p.gunnyTransactions,
      deliveryType: p.deliveryType,
      truckRentType: p.truckRentType,
      truckRent: p.truckRent,
      truckRentPaid: p.truckRentPaid,
      otherAmount: p.otherAmount,
      transportType: p.transportType,
      truckAccount: p.truckAccount,
      freightAmount: p.freightAmount,
      procurementType: p.procurementType,
      mandiInvoiceNo: p.mandiInvoiceNo,
      tenderNumber: p.tenderNumber,
      commissionAgentId: p.commissionAgentId,
      warehouseId: p.warehouseId,
      warehouseAllocations: p.warehouseAllocations,
      vehicleEntryId: p.vehicleEntryId,
      weighMode: p.weighMode,
      remainingStock: p.remainingStock,
      status: p.status,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    );
  }
}
