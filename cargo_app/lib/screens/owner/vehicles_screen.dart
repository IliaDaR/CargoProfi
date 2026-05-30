import 'package:flutter/material.dart';
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
  void _addVehicle(LocalStorage store) {
    final plateCtrl = TextEditingController(), brandCtrl = TextEditingController(), modelCtrl = TextEditingController();
    final yearCtrl = TextEditingController(), vinCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Добавить автомобиль'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Госномер *', border: OutlineInputBorder())),
        const SizedBox(height: 10), TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Марка *', border: OutlineInputBorder())),
        const SizedBox(height: 10), TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Модель *', border: OutlineInputBorder())),
        const SizedBox(height: 10), TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'Год выпуска', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        const SizedBox(height: 10), TextField(controller: vinCtrl, decoration: const InputDecoration(labelText: 'VIN', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        ElevatedButton(onPressed: () {
          if (plateCtrl.text.isEmpty || brandCtrl.text.isEmpty) return;
          context.read<VehicleProvider>().addVehicle(Vehicle(
            id: 'v${DateTime.now().millisecondsSinceEpoch}', ownerId: 'local',
            plateNumber: plateCtrl.text, brand: brandCtrl.text, model: modelCtrl.text,
            year: int.tryParse(yearCtrl.text), vin: vinCtrl.text.isEmpty ? null : vinCtrl.text,
            createdAt: DateTime.now(),
          ));
          Navigator.pop(ctx);
        }, child: const Text('Добавить')),
      ],
    ));
  }

  void _addDriver(LocalStorage store) {
    final nameCtrl = TextEditingController(), phoneCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Добавить водителя'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ФИО', border: OutlineInputBorder())),
        const SizedBox(height: 10), TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Телефон', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        ElevatedButton(onPressed: () {
          if (nameCtrl.text.isEmpty) return;
          store.addDriver({'uid': 'd${DateTime.now().millisecondsSinceEpoch}', 'displayName': nameCtrl.text, 'email': '', 'phone': phoneCtrl.text, 'ownerId': 'local'});
          Navigator.pop(ctx);
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
          ...vp.vehicles.map((v) => Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            leading: CircleAvatar(backgroundColor: v.isActive ? Colors.green.shade100 : Colors.grey.shade200, child: Icon(v.isActive ? Icons.drive_eta : Icons.local_parking, color: v.isActive ? Colors.green : Colors.grey)),
            title: Text(v.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${v.brand} ${v.model}'),
            trailing: Text(v.isActive ? 'В рейсе' : 'Свободен', style: TextStyle(color: v.isActive ? Colors.green : Colors.grey, fontSize: 12)),
          ))),
        ],
        if (store.drivers.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('ВОДИТЕЛИ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold))),
          ...store.drivers.map((d) => Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(d['displayName'] ?? ''), subtitle: Text(d['phone'] ?? ''),
          ))),
        ],
        if (vp.vehicles.isEmpty && store.drivers.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Нет автомобилей и водителей'))),
      ])),
    ]);
  }
}
