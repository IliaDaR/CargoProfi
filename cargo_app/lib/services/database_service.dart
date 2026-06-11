import 'dart:convert';

/// Лёгкая замена sqflite на SharedPreferences для веба
/// (веб-версия Flutter не поддерживает sqflite)
class DatabaseService {
  static DatabaseService? _instance;
  Map<String, List<Map<String, dynamic>>> _store = {};

  DatabaseService._();
  static DatabaseService get instance => _instance ??= DatabaseService._();

  Future<void> init() async {
    _store = {
      'sync_commands': [],
      'pending_uploads': [],
    };
  }

  // Sync commands (startTrip, addTrackPoint, addExpense, endTrip)
  Future<List<Map<String, dynamic>>> getPendingCommands() async {
    return List.from(_store['sync_commands'] ?? []);
  }

  Future<void> enqueueCommand(String type, Map<String, dynamic> data) async {
    _store['sync_commands']!.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'data': jsonEncode(data),
      'createdAt': DateTime.now().toIso8601String(),
      'retryCount': 0,
      'status': 'pending',
    });
  }

  Future<void> markCommandDone(String id) async {
    _store['sync_commands']!.removeWhere((c) => c['id'] == id);
  }

  Future<void> markCommandFailed(String id) async {
    final cmd = _store['sync_commands']!.firstWhere((c) => c['id'] == id, orElse: () => {});
    if (cmd.isNotEmpty) cmd['status'] = 'failed';
  }

  // Photo upload queue
  Future<void> enqueueUpload(String localPath, String tripId) async {
    _store['pending_uploads']!.add({
      'path': localPath,
      'tripId': tripId,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingUploads() async {
    return List.from(_store['pending_uploads']!.where((u) => u['status'] == 'pending'));
  }

  Future<void> markUploadDone(String path) async {
    final idx = _store['pending_uploads']!.indexWhere((u) => u['path'] == path);
    if (idx != -1) _store['pending_uploads']![idx]['status'] = 'done';
  }

  Future<int> getPendingCount() async {
    return _store['sync_commands']!.where((c) => c['status'] == 'pending').length;
  }
}
