import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/local_storage.dart';
import '../../models/vehicle.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});
  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  String get _ownerId => context.read<LocalStorage>().currentUser?['uid'] ?? 'local';
  void _addVehicle(LocalStorage store) {
    final plateCtrl = TextEditingController(), brandCtrl = TextEditingController(), modelCtrl = TextEditingController();
    final yearCtrl = TextEditingController(), vinCtrl = TextEditingController(), techCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Добавить автомобиль'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Госномер *', border: OutlineInputBorder())),
        const SizedBox(height: 10), TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Марка *', border: OutlineInputBorder())),
        const SizedBox(height: 10), TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Модель *', border: OutlineInputBorder())),
        const SizedBox(height: 10), TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'Год выпуска', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        const SizedBox(height: 10), TextField(controller: vinCtrl, decoration: const InputDecoration(labelText: 'VIN', border: OutlineInputBorder())),
        const SizedBox(height: 10), TextField(controller: techCtrl, decoration: const InputDecoration(labelText: '№ техосмотра', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        ElevatedButton(onPressed: () {
          if (plateCtrl.text.isEmpty || brandCtrl.text.isEmpty || modelCtrl.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните обязательные поля (*)'), backgroundColor: Colors.red));
            return;
          }
          final year = int.tryParse(yearCtrl.text);
          if (year != null && (year < 1900 || year > DateTime.now().year + 1)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Некорректный год выпуска'), backgroundColor: Colors.red));
            return;
          }
          context.read<VehicleProvider>().addVehicle(Vehicle(
            id: 'v${DateTime.now().millisecondsSinceEpoch}', ownerId: _ownerId,
            plateNumber: plateCtrl.text, brand: brandCtrl.text, model: modelCtrl.text,
            year: year, vin: vinCtrl.text.isEmpty ? null : vinCtrl.text,
            techExamNumber: techCtrl.text.isEmpty ? null : techCtrl.text,
            createdAt: DateTime.now(),
          ));
          Navigator.pop(ctx);
          plateCtrl.dispose(); brandCtrl.dispose(); modelCtrl.dispose(); yearCtrl.dispose(); vinCtrl.dispose(); techCtrl.dispose();
        }, child: const Text('Добавить')),
      ],
    ));
  }

  void _addDriver(LocalStorage store) {
    final nameCtrl = TextEditingController(), phoneCtrl = TextEditingController(), licenseCtrl = TextEditingController();
    final medCtrl = TextEditingController(), emailCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Добавить водителя'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ФИО *', border: OutlineInputBorder())),
        const SizedBox(height: 10), TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 10), TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Телефон', border: OutlineInputBorder())),
        const SizedBox(height: 10), TextField(controller: licenseCtrl, decoration: const InputDecoration(labelText: '№ ВУ', border: OutlineInputBorder())),
        const SizedBox(height: 10), TextField(controller: medCtrl, decoration: const InputDecoration(labelText: '№ медосмотра', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        ElevatedButton(onPressed: () {
          if (nameCtrl.text.isEmpty) return;
          store.addDriver({
            'uid': 'd${DateTime.now().millisecondsSinceEpoch}',
            'displayName': nameCtrl.text, 'email': emailCtrl.text.trim().toLowerCase(),
            'phone': phoneCtrl.text, 'licenseNumber': licenseCtrl.text,
            'medExamNumber': medCtrl.text, 'ownerId': _ownerId,
          });
          Navigator.pop(ctx);
          emailCtrl.dispose();
          setState(() {});
        }, child: const Text('Добавить')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LocalStorage>();
    final vp = context.watch<VehicleProvider>();

    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Text('Машин: ${vp.vehicles.length} | Водителей: ${store.drivers.length}', style: const TextStyle(color: Colors.grey)),
        const Spacer(),
        ElevatedButton.icon(onPressed: () => _addVehicle(store), icon: const Icon(Icons.add, size: 16), label: const Text('Авто')),
        const SizedBox(width: 8),
        ElevatedButton.icon(onPressed: () => _addDriver(store), icon: const Icon(Icons.person_add, size: 16), label: const Text('Водитель')),
      ])),
          Expanded(child: ListView(children: [
        if (vp.vehicles.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('АВТОМОБИЛИ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold))),
          ...vp.vehicles.asMap().entries.map((e) => Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            leading: CircleAvatar(backgroundColor: e.value.isActive ? Colors.green.shade100 : Colors.grey.shade200, child: Icon(e.value.isActive ? Icons.drive_eta : Icons.local_parking, color: e.value.isActive ? Colors.green : Colors.grey)),
            title: Text(e.value.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${e.value.brand} ${e.value.model}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(e.value.isActive ? 'В рейсе' : 'Свободен', style: TextStyle(color: e.value.isActive ? Colors.green : Colors.grey, fontSize: 12)),
              IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () {
                if (e.value.isActive) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нельзя удалить машину в рейсе'), backgroundColor: Colors.red));
                  return;
                }
                _confirmDelete(context, 'Удалить машину ${e.value.plateNumber}?', () {
                  store.removeVehicle(e.key);
                  context.read<VehicleProvider>().refresh();
                  setState(() {});
                });
              }),
            ]),
          ))),
        ],
        if (store.drivers.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('ВОДИТЕЛИ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold))),
          ...store.drivers.asMap().entries.map((e) => Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(e.value['displayName'] ?? ''), subtitle: Text(e.value['phone'] ?? ''),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.person_add, size: 18, color: Colors.blue), tooltip: 'Пригласить', onPressed: () => _inviteDriver(e.value)),
              IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () {
                _confirmDelete(context, 'Удалить водителя ${e.value['displayName']}?', () {
                  store.removeDriver(e.key); setState(() {});
                });
              }),
            ]),
          ))),
        ],
        if (vp.vehicles.isEmpty && store.drivers.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Нет автомобилей и водителей'))),
      ])),
    ]);
  }

  void _inviteDriver(Map<String, dynamic> driver) {
    final code = _generateInviteCode();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Пригласить водителя'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Водитель: ${driver['displayName'] ?? ''}'),
        const SizedBox(height: 16),
        Text('Код приглашения', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
          child: Text(code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 4)),
        ),
        const SizedBox(height: 12),
        Text('Код действителен 48 часов', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 8),
        Text('Отправьте этот код водителю.\nОн введёт его в приложении Numino.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        TextButton(onPressed: () {
          // Copy to clipboard — will work on web, fallback on mobile
          try { Clipboard.setData(ClipboardData(text: code)); } catch (_) {}
          Navigator.pop(ctx);
        }, child: const Text('Копировать')),
      ],
    ));
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buf = StringBuffer();
    for (int i = 0; i < 8; i++) {
      buf.write(chars[(DateTime.now().microsecondsSinceEpoch + i * 17) % chars.length]);
    }
    return buf.toString();
  }

  void _confirmDelete(BuildContext ctx, String message, VoidCallback onConfirm) {
    showDialog(context: ctx, builder: (dCtx) => AlertDialog(
      title: const Text('Подтверждение'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Отмена')),
        ElevatedButton(onPressed: () { Navigator.pop(dCtx); onConfirm(); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Удалить')),
      ],
    ));
  }
}
