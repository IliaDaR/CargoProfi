import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../models/vehicle.dart';

/// Экран списка автомобилей с индикатором статуса (в рейсе/свободен).
class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();

    if (vehicleProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vehicleProvider.vehicles.isEmpty) {
      return const Center(child: Text('Нет автомобилей в парке'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: vehicleProvider.vehicles.length,
      itemBuilder: (ctx, i) {
        final vehicle = vehicleProvider.vehicles[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: vehicle.isActive ? Colors.green.shade100 : Colors.grey.shade200,
              child: Icon(
                vehicle.isActive ? Icons.drive_eta : Icons.local_parking,
                color: vehicle.isActive ? Colors.green : Colors.grey,
              ),
            ),
            title: Text(vehicle.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('${vehicle.brand} ${vehicle.model}${vehicle.year != null ? ' (${vehicle.year})' : ''}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: vehicle.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: vehicle.isActive ? Colors.green : Colors.grey),
              ),
              child: Text(
                vehicle.isActive ? 'В рейсе' : 'Свободен',
                style: TextStyle(
                  color: vehicle.isActive ? Colors.green.shade700 : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
