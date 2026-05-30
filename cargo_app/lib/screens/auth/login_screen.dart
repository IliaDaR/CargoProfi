import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isReg = false;

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();
    bool ok;
    if (_isReg) {
      ok = await auth.register(_emailCtrl.text.trim(), _passCtrl.text, _nameCtrl.text.trim(), 'owner'); // по умолчанию — владелец
    } else {
      ok = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Ошибка'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.local_shipping, size: 64, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text('Numino', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(_isReg ? 'Регистрация' : 'Вход в кабинет', style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        if (_isReg) ...[
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Имя', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
          const SizedBox(height: 12),
        ],
        TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Пароль', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()), obscureText: true),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
          onPressed: auth.isLoading ? null : _submit,
          child: auth.isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_isReg ? 'Зарегистрироваться' : 'Войти', style: const TextStyle(fontSize: 16)),
        )),
        const SizedBox(height: 12),
        TextButton(onPressed: () => setState(() { _isReg = !_isReg; _emailCtrl.clear(); _passCtrl.clear(); _nameCtrl.clear(); }), child: Text(_isReg ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Зарегистрироваться')),
      ])))),
    );
  }
}
