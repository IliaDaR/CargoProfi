import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../models/vehicle.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});
  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  void _showAddDialog() {
    final plateCtrl = TextEditingController();
    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Добавить автомобиль'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Госномер', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: brandCtrl, decoration: const InputDecoration(labelText: 'Марка', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Модель', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        ElevatedButton(onPressed: () {
          if (plateCtrl.text.isEmpty || brandCtrl.text.isEmpty) return;
          context.read<VehicleProvider>().addVehicle(Vehicle(
            id: 'v${DateTime.now().millisecondsSinceEpoch}',
            ownerId: 'demo', plateNumber: plateCtrl.text,
            brand: brandCtrl.text, model: modelCtrl.text,
            createdAt: DateTime.now(),
          ));
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавлено!'), backgroundColor: Colors.green));
        }, child: const Text('Добавить')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VehicleProvider>();
    if (vp.isLoading) return const Center(child: CircularProgressIndicator());

    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: Text('Автомобили в парке: ${vp.vehicles.length}', style: const TextStyle(fontSize: 14, color: Colors.grey))),
        ElevatedButton.icon(onPressed: _showAddDialog, icon: const Icon(Icons.add, size: 18), label: const Text('Добавить авто'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white)),
      ])),
      Expanded(child: vp.vehicles.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Нет автомобилей в парке'), const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: _showAddDialog, icon: const Icon(Icons.add), label: const Text('Добавить первый автомобиль')),
          ]))
        : ListView.builder(padding: const EdgeInsets.all(12), itemCount: vp.vehicles.length, itemBuilder: (ctx, i) {
            final v = vp.vehicles[i];
            return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
              leading: CircleAvatar(backgroundColor: v.isActive ? Colors.green.shade100 : Colors.grey.shade200, child: Icon(v.isActive ? Icons.drive_eta : Icons.local_parking, color: v.isActive ? Colors.green : Colors.grey)),
              title: Text(v.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text('${v.brand} ${v.model}${v.year != null ? ' (${v.year})' : ''}'),
              trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: v.isActive ? Colors.green.shade50 : Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: v.isActive ? Colors.green : Colors.grey)), child: Text(v.isActive ? 'В рейсе' : 'Свободен', style: TextStyle(color: v.isActive ? Colors.green.shade700 : Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 12))),
            ));
          })),
    ]);
  }
}
