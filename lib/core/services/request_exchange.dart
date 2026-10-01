import 'package:azs_domain/azs_domain.dart';

import '../database/app_database.dart';
import '../repositories/request_repository.dart';

class ExternalRequest {
  const ExternalRequest({
    required this.externalId,
    required this.stationNumber,
    required this.description,
    this.category = '',
    this.requestType = 'Внешняя заявка',
  });

  final String externalId;
  final String stationNumber;
  final String description;
  final String category;
  final String requestType;
}

abstract class RequestSource {
  String get sourceId;

  Future<List<ExternalRequest>> fetchChanges({DateTime? since});
}

class InternalRequestSource implements RequestSource {
  const InternalRequestSource();

  @override
  String get sourceId => 'internal';

  @override
  Future<List<ExternalRequest>> fetchChanges({DateTime? since}) async {
    return const [];
  }
}

class RequestExchangeResult {
  const RequestExchangeResult({
    required this.imported,
    required this.sourceAvailable,
    this.message = '',
  });

  final int imported;
  final bool sourceAvailable;
  final String message;
}

class RequestExchange {
  const RequestExchange(this._db, this._requests);

  final AppDatabase _db;
  final RequestRepository _requests;

  Future<RequestExchangeResult> importNew(RequestSource source) async {
    final List<ExternalRequest> changes;
    try {
      changes = await source.fetchChanges();
    } catch (error) {
      return RequestExchangeResult(
        imported: 0,
        sourceAvailable: false,
        message: redactLog('$error'),
      );
    }
    var imported = 0;
    for (final change in changes) {
      final existing = await _db.db.query(
        'requests',
        where: 'source = ? AND source_external_id = ?',
        whereArgs: [source.sourceId, change.externalId],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      await _requests.add(
        stationNumber: change.stationNumber,
        requestType: change.requestType,
        description: change.description,
        category: change.category,
        source: source.sourceId,
        sourceExternalId: change.externalId,
      );
      imported += 1;
    }
    return RequestExchangeResult(imported: imported, sourceAvailable: true);
  }
}
