import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/pos_models.dart';

enum PosPermission {
  accessPos,
  manageShift,
  viewAllShiftsAndVoid,
  manageInventory,
  viewInventory,
  manageCustomersAndDebt,
  manageSuppliersAndExpenses,
  viewReports,
  manageSettingsAndStaff,
  accessKitchen,
}

class PinAuthResult {
  final bool success;
  final bool lockedOut;
  final int remainingAttempts;
  final int lockoutSecondsRemaining;
  final String message;

  const PinAuthResult({
    required this.success,
    this.lockedOut = false,
    this.remainingAttempts = 5,
    this.lockoutSecondsRemaining = 0,
    this.message = '',
  });
}

class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;

  static const int maxFailedAttempts = 5;
  static const Duration lockoutDuration = Duration(seconds: 30);

  AppUser? _currentUser;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  int get failedAttempts => _failedAttempts;

  bool get isLockedOut {
    if (_lockedUntil == null) return false;
    if (DateTime.now().isAfter(_lockedUntil!)) {
      _lockedUntil = null;
      _failedAttempts = 0;
      return false;
    }
    return true;
  }

  int get remainingLockoutSeconds {
    if (!isLockedOut || _lockedUntil == null) return 0;
    final diff = _lockedUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Menghasilkan salt acak kriptografis (hex)
  String generateSalt([int byteLength = 16]) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Salted SHA-256 hash untuk PIN
  String hashPin(String pin, String salt) {
    final input = utf8.encode('$salt:$pin');
    return sha256.convert(input).toString();
  }

  /// Verifikasi PIN dengan perbandingan waktu-konstan
  bool verifyPin(String pin, String salt, String expectedHash) {
    final computed = hashPin(pin, salt);
    if (computed.length != expectedHash.length) return false;
    var diff = 0;
    for (var i = 0; i < computed.length; i++) {
      diff |= computed.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// Autentikasi user dengan proteksi lockout 5x salah
  PinAuthResult authenticate(AppUser user, String pin) {
    if (isLockedOut) {
      final secs = remainingLockoutSeconds;
      return PinAuthResult(
        success: false,
        lockedOut: true,
        remainingAttempts: 0,
        lockoutSecondsRemaining: secs,
        message: 'Terlalu banyak percobaan. Coba lagi dalam $secs detik.',
      );
    }

    if (!user.isActive) {
      return const PinAuthResult(
        success: false,
        message: 'Akun staf ini sedang dinonaktifkan.',
      );
    }

    final ok = verifyPin(pin, user.pinSalt, user.pinHash);
    if (ok) {
      _failedAttempts = 0;
      _lockedUntil = null;
      _currentUser = user;
      return const PinAuthResult(
        success: true,
        remainingAttempts: maxFailedAttempts,
        message: 'Login berhasil',
      );
    }

    _failedAttempts++;
    if (_failedAttempts >= maxFailedAttempts) {
      _lockedUntil = DateTime.now().add(lockoutDuration);
      return PinAuthResult(
        success: false,
        lockedOut: true,
        remainingAttempts: 0,
        lockoutSecondsRemaining: lockoutDuration.inSeconds,
        message:
            'PIN salah 5x. Layar dikunci selama ${lockoutDuration.inSeconds} detik.',
      );
    }

    final remaining = maxFailedAttempts - _failedAttempts;
    return PinAuthResult(
      success: false,
      remainingAttempts: remaining,
      message: 'PIN tidak sesuai. Sisa percobaan: $remaining',
    );
  }

  void setCurrentUser(AppUser user) {
    _currentUser = user;
  }

  void logout() {
    _currentUser = null;
  }

  void resetLockout() {
    _failedAttempts = 0;
    _lockedUntil = null;
  }

  // =========================================================================
  // RBAC HELPERS (owner, admin, cashier, kitchen)
  // =========================================================================

  bool hasPermission(AppUser? user, PosPermission permission) {
    if (user == null || !user.isActive) return false;
    final role = user.role;
    switch (permission) {
      case PosPermission.accessPos:
        return role == 'owner' || role == 'admin' || role == 'cashier';
      case PosPermission.manageShift:
        return role == 'owner' || role == 'admin' || role == 'cashier';
      case PosPermission.viewAllShiftsAndVoid:
        return role == 'owner' || role == 'admin';
      case PosPermission.manageInventory:
        return role == 'owner' || role == 'admin';
      case PosPermission.viewInventory:
        return role == 'owner' || role == 'admin' || role == 'cashier';
      case PosPermission.manageCustomersAndDebt:
        return role == 'owner' || role == 'admin' || role == 'cashier';
      case PosPermission.manageSuppliersAndExpenses:
        return role == 'owner' || role == 'admin';
      case PosPermission.viewReports:
        return role == 'owner' || role == 'admin';
      case PosPermission.manageSettingsAndStaff:
        return role == 'owner';
      case PosPermission.accessKitchen:
        return role == 'owner' ||
            role == 'admin' ||
            role == 'cashier' ||
            role == 'kitchen';
    }
  }

  bool canAccessPos([AppUser? user]) =>
      hasPermission(user ?? _currentUser, PosPermission.accessPos);

  bool canManageShift([AppUser? user]) =>
      hasPermission(user ?? _currentUser, PosPermission.manageShift);

  bool canViewAllShiftsAndVoid([AppUser? user]) =>
      hasPermission(user ?? _currentUser, PosPermission.viewAllShiftsAndVoid);

  bool canManageInventory([AppUser? user]) =>
      hasPermission(user ?? _currentUser, PosPermission.manageInventory);

  bool canViewInventory([AppUser? user]) =>
      hasPermission(user ?? _currentUser, PosPermission.viewInventory);

  bool canManageCustomersAndDebt([AppUser? user]) =>
      hasPermission(user ?? _currentUser, PosPermission.manageCustomersAndDebt);

  bool canManageSuppliersAndExpenses([AppUser? user]) => hasPermission(
      user ?? _currentUser, PosPermission.manageSuppliersAndExpenses);

  bool canViewReports([AppUser? user]) =>
      hasPermission(user ?? _currentUser, PosPermission.viewReports);

  bool canManageSettingsAndStaff([AppUser? user]) =>
      hasPermission(user ?? _currentUser, PosPermission.manageSettingsAndStaff);

  bool canAccessKitchen([AppUser? user]) =>
      hasPermission(user ?? _currentUser, PosPermission.accessKitchen);
}
