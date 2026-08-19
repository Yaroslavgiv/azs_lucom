const List<String> requestCategories = [
  'Срочная заявка',
  'Не срочная заявка',
  'Заявки с заказом оборудования',
  'Заявка со сметой',
];

const String requestTypeEquipmentOrder = 'Заявки с заказом оборудования';

String equipmentOrdersExportDateMetaKey(String region) =>
    'equipment_orders_export_date_$region';

const List<String> equipmentCategories = ['Пожарка', 'КТСБ'];

const String regionNovgorod = 'novgorod';
const String regionSpb = 'spb';

const String regionLabelNovgorod = 'Новгород';
const String regionLabelSpb = 'Санкт-Петербург';

const String mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String mapTileUserAgentPackageName = 'com.azs.azs_app';

/// Номера АЗС с красным маркером на карте (приоритет над статусом ТО).
const Set<String> highlightedStationNumbers = {
  '78007',
  '78054',
  '78024',
  '78040',
  '78138',
  '78001',
  '78052',
  '78159',
  '78167',
  '78168',
  '78013',
};

/// Центр Санкт-Петербурга (фокус на регион).
const double spbMapCenterLat = 59.9386;
const double spbMapCenterLon = 30.3141;
const double spbMapDefaultZoom = 10.5;

/// Обзор СПб + Новгород (стартовый центр карты, без Москвы).
const double brigadeMapCenterLat = 59.35;
const double brigadeMapCenterLon = 30.45;
const double brigadeMapDefaultZoom = 7.2;

String cityForRegion(String region) =>
    region == regionNovgorod ? 'Великий Новгород' : 'Санкт-Петербург';
