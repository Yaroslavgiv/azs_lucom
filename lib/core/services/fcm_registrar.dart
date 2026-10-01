import 'package:firebase_messaging/firebase_messaging.dart';

import '../database/app_database.dart';

class FcmRegistrar {
  const FcmRegistrar(this._messaging);

  final FirebaseMessaging _messaging;

  Future<String?> currentToken() async {
    await _messaging.requestPermission();
    return _messaging.getToken();
  }

  Future<void> remember(AppDatabase database, String userId) async {
    final token = await currentToken();
    if (token == null || token.isEmpty) return;
    await database.db.update(
      'user_profiles',
      {'fcm_token': token},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}
