import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/local_storage.dart';
import '../../providers/vehicle_provider.dart';
import '../owner/owner_dashboard_screen.dart';
import '../driver/driver_home_screen.dart';

/// Экран: две кнопки (Владелец / Водитель).
/// При нажатии — форма логина/пароля для выбранной роли.
class RoleScreen extends StatelessWidget {
  final LocalStorage storage;
  const RoleScreen({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_shipping, size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('Numino', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Рабочий кабинет перевозчика', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 40),
          SizedBox(width: 280, height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _showLogin(context, 'owner', 'Владелец автопарка'),
              icon: const Icon(Icons.business, size: 24),
              label: const Text('Владелец автопарка', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(width: 280, height: 56,
            child: OutlinedButton.icon(
              onPressed: () => _showLogin(context, 'driver', 'Водитель'),
              icon: const Icon(Icons.person, size: 24),
              label: const Text('Водитель', style: TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: Colors.grey.shade400)),
            ),
          ),
        ]),
      ),
    );
  }

  void _showLogin(BuildContext context, String role, String roleLabel) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _LoginDialog(storage: storage, role: role, roleLabel: roleLabel),
    );
  }
}

/// Диалог входа/регистрации для выбранной роли.
class _LoginDialog extends StatefulWidget {
  final LocalStorage storage;
  final String role;
  final String roleLabel;
  const _LoginDialog({required this.storage, required this.role, required this.roleLabel});

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isReg = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) { setState(() => _error = 'Заполните все поля'); return; }
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 400));

    if (_isReg) {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) { setState(() { _error = 'Введите имя'; _loading = false; }); return; }
      if (widget.storage.findUser(email, pass) != null) {
        setState(() { _error = 'Пользователь уже существует'; _loading = false; });
        return;
      }
      widget.storage.registerUser(email, pass, name, widget.role);
    }

    final user = widget.storage.findUser(email, pass);
    if (user != null) {
      widget.storage.setCurrentUser(user);
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) {
        if (widget.role == 'driver') return DriverHomeScreen(driverId: user['uid'] ?? 'driver');
        return const OwnerDashboardScreen();
      }));
    } else {
      setState(() { _error = 'Неверный email или пароль'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isReg ? 'Регистрация' : 'Вход — ${widget.roleLabel}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_isReg) ...[
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder())),
          const SizedBox(height: 10),
        ],
        TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 10),
        TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder()), obscureText: true),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
      ])),
      actions: [
        TextButton(onPressed: () { setState(() { _isReg = !_isReg; _error = null; _nameCtrl.clear(); _emailCtrl.clear(); _passCtrl.clear(); }); }, child: Text(_isReg ? 'Назад ко входу' : 'Зарегистрироваться')),
        ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_isReg ? 'Зарегистрироваться' : 'Войти')),
      ],
    );
  }
}
