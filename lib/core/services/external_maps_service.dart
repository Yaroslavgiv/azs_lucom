import 'package:url_launcher/url_launcher.dart';

/// Ссылки на внешние карты (Яндекс, 2ГИС).
class ExternalMapsService {
  /// Маршрут до точки от текущего местоположения.
  static Uri yandexRouteUri(double lat, double lon) =>
      Uri.parse('https://yandex.ru/maps/?rtext=~$lat,$lon&rtt=auto');

  static Uri yandexPointUri(double lat, double lon) =>
      Uri.parse('https://yandex.ru/maps/?pt=$lon,$lat&z=16&l=map');

  /// Маршрут до точки (| — откуда «моё местоположение» в 2ГИС).
  static Uri twoGisRouteUri(double lat, double lon) =>
      Uri.parse('https://2gis.ru/directions/points/|$lon,$lat');

  static Uri twoGisPointUri(double lat, double lon) =>
      Uri.parse('https://2gis.ru/geo/$lon,$lat');

  static Future<bool> open(Uri uri) async {
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openYandexRoute(double lat, double lon) =>
      open(yandexRouteUri(lat, lon));

  static Future<bool> openTwoGisRoute(double lat, double lon) =>
      open(twoGisRouteUri(lat, lon));
}
