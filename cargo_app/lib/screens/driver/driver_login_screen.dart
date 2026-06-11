import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/local_storage.dart';
import '../../services/cloud_functions_service.dart';
import 'driver_home_screen.dart';

class DriverLoginScreen extends StatefulWidget {
  final LocalStorage storage;
  final CloudFunctionsService cloudFn;
  const DriverLoginScreen({super.key, required this.storage, required this.cloudFn});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _isRegister = false;
  bool _loading = false;
  String? _error;

  int _attempts = 0;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _attempts = 0;
      _cooldownSeconds = 60;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) {
          _cooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final name = _nameCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Введите корректный email');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Пароль должен быть не менее 6 символов');
      return;
    }

    if (_isRegister) {
      if (name.isEmpty) {
        setState(() => _error = 'Введите имя');
        return;
      }
    }

    setState(() { _loading = true; _error = null; });

    try {
      if (_isRegister) {
        final user = widget.storage.registerUser(email, password, name, 'driver');
        if (user == null) {
          setState(() { _error = 'Пользователь с таким email уже существует'; _loading = false; });
          return;
        }
        widget.storage.setCurrentUser(user);
        if (mounted) _goHome();
      } else {
        final user = widget.storage.findUser(email, password);
        if (user == null || user['role'] != 'driver') {
          _attempts++;
          if (_attempts >= 5 && _cooldownSeconds == 0) {
            _startCooldown();
          } else {
            setState(() { _error = 'Неверный email или пароль'; _loading = false; });
          }
          return;
        }

        widget.storage.setCurrentUser(user);
        if (mounted) _goHome();
      }
    } catch (e) {
      setState(() { _error = 'Ошибка: $e'; _loading = false; });
    }
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) {
      return DriverHomeScreen(driverId: widget.storage.currentUser?['uid'] ?? 'driver');
    }));
  }

  void _goToInviteCode() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      return _DriverInviteCodeWrapper(storage: widget.storage, cloudFn: widget.cloudFn);
    }));
  }

  bool get _isLocked => _cooldownSeconds > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_shipping, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                'Numino Driver',
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _isRegister ? 'Регистрация водителя' : 'Вход для водителей',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              if (_isRegister) ...[
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Имя',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: (_loading || _isLocked) ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : _isLocked
                          ? Text(
                              'Подождите ${_cooldownSeconds}с',
                              style: const TextStyle(fontSize: 16),
                            )
                          : Text(
                              _isRegister ? 'Зарегистрироваться' : 'Войти',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],

              const SizedBox(height: 20),

              GestureDetector(
                onTap: () {
                  setState(() {
                    _isRegister = !_isRegister;
                    _error = null;
                  });
                },
                child: Text(
                  _isRegister ? 'Уже есть аккаунт? Войти' : 'Зарегистрироваться',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: _goToInviteCode,
                child: const Text(
                  'Войти по коду приглашения',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverInviteCodeWrapper extends StatefulWidget {
  final LocalStorage storage;
  final CloudFunctionsService cloudFn;
  const _DriverInviteCodeWrapper({required this.storage, required this.cloudFn});

  @override
  State<_DriverInviteCodeWrapper> createState() => _DriverInviteCodeWrapperState();
}

class _DriverInviteCodeWrapperState extends State<_DriverInviteCodeWrapper> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  String get _rawCode => _codeCtrl.text.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  Future<void> _submit() async {
    final code = _rawCode;
    if (code.length < 6) {
      setState(() => _error = 'Введите код из 8 символов');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      try {
        final result = await widget.cloudFn.validateInviteCode(code);
        if (result != null && result['success'] == true) {
          widget.storage.setCurrentUser({
            'uid': 'driver-${DateTime.now().millisecondsSinceEpoch}',
            'role': 'driver',
            'ownerId': result['ownerId'] ?? '',
            'displayName': result['driverName'] ?? 'Водитель',
          });
          if (mounted) _goHome();
          return;
        }
      } catch (_) {}

      final invites = widget.storage.invites;
      final invite = invites.where((i) => i['code'] == code && i['used'] != true).firstOrNull;
      if (invite == null) {
        setState(() { _error = 'Код не найден или уже использован'; _loading = false; });
        return;
      }

      widget.storage.setCurrentUser({
        'uid': 'driver-${DateTime.now().millisecondsSinceEpoch}',
        'role': 'driver',
        'ownerId': invite['ownerId'] ?? '',
        'displayName': invite['driverName'] ?? 'Водитель',
      });
      invite['used'] = true;
      widget.storage.saveInvites();
      if (mounted) _goHome();
    } catch (e) {
      setState(() { _error = 'Ошибка: $e'; _loading = false; });
    }
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) {
      return DriverHomeScreen(driverId: widget.storage.currentUser?['uid'] ?? 'driver');
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Код приглашения')),
      body: Center(
        child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.vpn_key, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          const Text('Введите код приглашения\nот владельца автопарка', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 24),
          TextField(
            controller: _codeCtrl,
            textAlign: TextAlign.center,
            maxLength: 10,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\s-]'))],
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 6),
            decoration: InputDecoration(
              hintText: 'N7K3-M9P2',
              hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 24, fontFamily: 'monospace', letterSpacing: 6),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 52, child: FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Войти', style: TextStyle(fontSize: 16)),
          )),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ])),
      ),
    );
  }
}