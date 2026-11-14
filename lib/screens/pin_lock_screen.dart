import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_controller.dart';
import '../theme/app_theme.dart';

/// PIN Lock Screen Produksi (Tanpa tombol demo, selector akun staff, numpad ergonomis, lockout 5x salah)
class PinLockScreen extends StatefulWidget {
  final PosController controller;

  const PinLockScreen({super.key, required this.controller});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  AppUser? _selectedUser;
  String _pin = '';
  String? _errorText;
  int _failedAttempts = 0;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    final activeUsers =
        widget.controller.users.where((u) => u.isActive).toList();
    if (activeUsers.isNotEmpty) {
      _selectedUser = activeUsers.first;
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _startLockout() {
    setState(() {
      _lockoutSeconds = 30;
      _errorText = 'Terlalu banyak percobaan gagal. Tunggu 30 detik.';
    });
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockoutSeconds--;
        if (_lockoutSeconds <= 0) {
          timer.cancel();
          _failedAttempts = 0;
          _errorText = null;
        } else {
          _errorText = 'Terminal terkunci. Coba lagi dalam $_lockoutSeconds dtk.';
        }
      });
    });
  }

  Future<void> _onDigitPressed(String digit) async {
    if (_lockoutSeconds > 0 || _isVerifying || _selectedUser == null) return;
    if (_pin.length >= 6) return;

    setState(() {
      _errorText = null;
      _pin += digit;
    });

    if (_pin.length == 6) {
      setState(() => _isVerifying = true);
      final ok = await widget.controller.loginWithPin(_selectedUser!, _pin);
      if (!mounted) return;
      if (!ok) {
        _failedAttempts++;
        setState(() {
          _isVerifying = false;
          _pin = '';
          if (_failedAttempts >= 5) {
            _startLockout();
          } else {
            _errorText =
                'PIN tidak sesuai. Sisa percobaan: ${5 - _failedAttempts}';
          }
        });
      }
    }
  }

  void _onBackspace() {
    if (_lockoutSeconds > 0 || _isVerifying || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorText = null;
    });
  }

  void _onClear() {
    if (_lockoutSeconds > 0 || _isVerifying) return;
    setState(() {
      _pin = '';
      _errorText = null;
    });
  }

  Future<void> _pickStaffAccount() async {
    final activeUsers =
        widget.controller.users.where((u) => u.isActive).toList();
    if (activeUsers.isEmpty) return;

    final chosen = await showModalBottomSheet<AppUser>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pilih Akun Staff / Kasir',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...activeUsers.map(
                (u) => ListTile(
                  leading: CircleAvatar(
                    child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?'),
                  ),
                  title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(u.role.toUpperCase()),
                  trailing: _selectedUser?.id == u.id
                      ? const Icon(Icons.check_circle_rounded)
                      : null,
                  onTap: () => Navigator.of(ctx).pop(u),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (chosen != null && mounted) {
      setState(() {
        _selectedUser = chosen;
        _pin = '';
        _errorText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.posColors;
    final isTablet = context.isTablet;
    final store = widget.controller.store;

    final brandingPane = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment:
          isTablet ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colors.brandPrimary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.point_of_sale_rounded,
              color: Colors.white, size: 34),
        ),
        const SizedBox(height: 16),
        Text(
          store?.name ?? 'POS Universal',
          textAlign: isTablet ? TextAlign.left : TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Terminal Kasir Terproteksi PIN • Offline-First SQLite',
          textAlign: isTablet ? TextAlign.left : TextAlign.center,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
      ],
    );

    final pinPane = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: _pickStaffAccount,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfacePrimary,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colors.surfaceHighlight,
                    child: Text(
                      (_selectedUser?.name ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                        color: colors.brandPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedUser?.name ?? 'Pilih User',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        (_selectedUser?.role ?? '-').toUpperCase(),
                        style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              final filled = i < _pin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? colors.brandPrimary : Colors.transparent,
                  border: Border.all(
                    color: _errorText != null
                        ? colors.statusDanger
                        : (filled ? colors.brandPrimary : colors.borderSubtle),
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 22,
            child: _isVerifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : (_errorText != null
                    ? Text(
                        _errorText!,
                        style: TextStyle(
                          color: colors.statusDanger,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : Text(
                        'Masukkan 6 digit PIN Anda',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 13),
                      )),
          ),
          const SizedBox(height: 18),
          _buildNumpad(colors, isTablet),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: isTablet
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 40),
                          child: brandingPane,
                        ),
                      ),
                      pinPane,
                    ],
                  )
                : Column(
                    children: [
                      brandingPane,
                      const SizedBox(height: 28),
                      pinPane,
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad(PosColors colors, bool isTablet) {
    final btnSize = isTablet ? 74.0 : 66.0;
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              return SizedBox(
                width: btnSize,
                height: btnSize,
                child: Material(
                  color: colors.surfacePrimary,
                  shape: CircleBorder(
                    side: BorderSide(color: colors.borderSubtle),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _lockoutSeconds > 0
                        ? null
                        : () {
                            if (key == 'C') {
                              _onClear();
                            } else if (key == '⌫') {
                              _onBackspace();
                            } else {
                              _onDigitPressed(key);
                            }
                          },
                    child: Center(
                      child: key == '⌫'
                          ? Icon(Icons.backspace_outlined,
                              color: colors.textPrimary)
                          : Text(
                              key,
                              style: AppTheme.tabular(
                                null,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: key == 'C'
                                    ? colors.statusDanger
                                    : colors.textPrimary,
                              ),
                            ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
