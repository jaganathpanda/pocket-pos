enum StoreStatus { pending, approved, suspended, unknown }

StoreStatus storeStatusFromString(String? value) {
  switch (value) {
    case 'approved':
      return StoreStatus.approved;
    case 'suspended':
      return StoreStatus.suspended;
    case 'pending':
      return StoreStatus.pending;
    default:
      return StoreStatus.unknown;
  }
}

/// The signed-in store user (tenant context for the whole app).
class StoreSession {
  const StoreSession({
    required this.storeId,
    required this.storeName,
    required this.uid,
    required this.username,
    required this.role,
    required this.status,
    this.posCounterId,
  });

  final String storeId;
  final String storeName;
  final String uid;
  final String username;
  final String role;
  final StoreStatus status;

  /// The POS counter a cashier is bound to (null for owner/manager).
  final int? posCounterId;

  bool get isApproved => status == StoreStatus.approved;
}

/// A store awaiting (or granted) platform approval — used by the admin screen.
class StoreRecord {
  const StoreRecord({
    required this.storeId,
    required this.name,
    required this.ownerName,
    required this.status,
    this.mobile,
    this.email,
  });

  final String storeId;
  final String name;
  final String ownerName;
  final StoreStatus status;
  final String? mobile;
  final String? email;
}

/// A platform-level weighbridge operator (not tied to any store). Approved by
/// a platform admin, then logs in and selects a mill by Store ID.
class OperatorProfile {
  const OperatorProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.status,
  });

  final String uid;
  final String name;
  final String email;
  final StoreStatus status; // pending / approved / suspended

  bool get isApproved => status == StoreStatus.approved;
}

/// Where the app boots to, based on Firebase auth + store status.
/// [operator] = an approved weighbridge operator who hasn't entered a mill yet.
enum StoreAuthStage { unknown, loggedOut, pending, active, admin, operator }

class StoreAuthState {
  const StoreAuthState({
    required this.stage,
    this.session,
    this.operator,
    this.busy = false,
    this.error,
  });

  final StoreAuthStage stage;
  final StoreSession? session;
  final OperatorProfile? operator;
  final bool busy;
  final String? error;

  StoreAuthState copyWith({
    StoreAuthStage? stage,
    StoreSession? session,
    OperatorProfile? operator,
    bool? busy,
    String? error,
  }) {
    return StoreAuthState(
      stage: stage ?? this.stage,
      session: session ?? this.session,
      operator: operator ?? this.operator,
      busy: busy ?? this.busy,
      error: error,
    );
  }
}
