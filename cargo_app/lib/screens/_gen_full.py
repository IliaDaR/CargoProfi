#!/usr/bin/env python3
target = "/opt/CargoProfi/cargo_app/lib/screens/vehicles_screen.dart"

L = []
L.append("import 'package:flutter/material.dart';")
L.append("import 'package:provider/provider.dart';")
L.append("import '../providers/data_provider.dart';")
L.append("import '../models/vehicle.dart';")
L.append("import '../models/driver.dart';")
L.append("")

# Class definition
L.append("class VehiclesScreen extends StatefulWidget {")
L.append("  const VehiclesScreen({super.key});")
L.append("  @override")
L.append("  State<VehiclesScreen> createState() => _VehiclesScreenState();")
L.append("}")
L.append("")

# State class
L.append("class _VehiclesScreenState extends State<VehiclesScreen>")
L.append("    with SingleTickerProviderStateMixin {")
L.append("  late final TabController _tabController;")
L.append("")
L.append("  @override")
L.append("  void initState() {")
L.append("    super.initState();")
L.append("    _tabController = TabController(length: 2, vsync: this);")
L.append("  }")
L.append("")
L.append("  @override")
L.append("  void dispose() {")
L.append("    _tabController.dispose();")
L.append("    super.dispose();")
L.append("  }")

print("Base generated. Need to continue...")
