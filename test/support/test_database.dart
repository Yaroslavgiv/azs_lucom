import 'package:azs_app/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<AppDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  return AppDatabase.openForTesting(databaseFactoryFfi);
}
