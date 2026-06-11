import 'package:flutter/material.dart';
import '../screens/auth/role_screen.dart';
import '../services/local_storage.dart';
import 'package:provider/provider.dart';

void goHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => RoleScreen(
      storage: context.read<LocalStorage>(),
    )),
    (_) => false,
  );
}
