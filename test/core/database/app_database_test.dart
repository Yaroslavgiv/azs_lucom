import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  test('stores and replaces application metadata', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);

    expect(await database.getMeta('seed_version'), isNull);

    await database.setMeta('seed_version', '1');
    await database.setMeta('seed_version', '2');

    expect(await database.getMeta('seed_version'), '2');
  });

  test('tracks seed completion', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);

    expect(await database.isSeeded(), isFalse);

    await database.markSeeded();

    expect(await database.isSeeded(), isTrue);
  });
}
