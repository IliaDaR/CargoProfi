import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/local_storage.dart';
import 'services/cloud_functions_service.dart';
import 'screens/driver/driver_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = LocalStorage();
  await storage.init();
  final cloudFn = CloudFunctionsService(storage);

  runApp(MaterialApp(
    title: 'Numino Driver',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0), brightness: Brightness.light),
      useMaterial3: true,
    ),
    home: DriverGateScreen(storage: storage, cloudFn: cloudFn),
  ));
}

/// Screen that checks auth and routes accordingly
class DriverGateScreen extends StatefulWidget {
  final LocalStorage storage;
  final CloudFunctionsService cloudFn;
  const DriverGateScreen({super.key, required this.storage, required this.cloudFn});

  @override
  State<DriverGateScreen> createState() => _DriverGateScreenState();
}

class _DriverGateScreenState extends State<DriverGateScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() {
    final user = widget.storage.currentUser;
    if (user != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => DriverHomeScreen(driverId: user['uid'] ?? 'driver'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _InviteCodeForm(
            storage: widget.storage,
            cloudFn: widget.cloudFn,
            onSuccess: (userId, name) {
              Navigator.pushReplacement(context, MaterialPageRoute(
                builder: (_) => DriverHomeScreen(driverId: userId),
              ));
            },
          ),
        ),
      ),
    );
  }
}

/// Invite code entry form (replaced email+password login)
class _InviteCodeForm extends StatefulWidget {
  final LocalStorage storage;
  final CloudFunctionsService cloudFn;
  final void Function(String userId, String name) onSuccess;
  const _InviteCodeForm({required this.storage, required this.cloudFn, required this.onSuccess});

  @override
  State<_InviteCodeForm> createState() => _InviteCodeFormState();
}

class _InviteCodeFormState extends State<_InviteCodeForm> {
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

    // Try cloud validation
    try {
      final result = await widget.cloudFn.validateInviteCode(code);
      if (result != null && result['success'] == true) {
        _login(result['ownerId'] ?? '', result['driverName'] ?? 'Водитель', code);
        return;
      }
    } catch (_) {}

    // Offline: check localStorage invites
    final invites = widget.storage.invites;
    final invite = invites.where((i) => i['code'] == code && i['used'] != true).firstOrNull;
    if (invite == null) {
      setState(() { _error = 'Код не найден или уже использован'; _loading = false; });
      return;
    }

    _login(invite['ownerId'] ?? '', invite['driverName'] ?? 'Водитель', code);
  }

  void _login(String ownerId, String driverName, String code) {
    widget.storage.setCurrentUser({
      'uid': 'driver-${DateTime.now().millisecondsSinceEpoch}',
      'role': 'driver',
      'ownerId': ownerId,
      'displayName': driverName,
      'inviteCode': code,
    });
    // Mark invite as used
    final invites = widget.storage.invites;
    final invite = invites.where((i) => i['code'] == code).firstOrNull;
    if (invite != null) {
      invite['used'] = true;
      widget.storage.saveInvites();
    }
    widget.onSuccess(widget.storage.currentUser?['uid'] ?? 'driver', driverName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.local_shipping, size: 64, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 16),
      Text('Numino Driver', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Введите код приглашения\nот владельца автопарка', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
      const SizedBox(height: 32),
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
    ]);
  }
}
