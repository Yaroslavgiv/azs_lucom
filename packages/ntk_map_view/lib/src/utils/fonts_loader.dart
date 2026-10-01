import 'dart:convert';
import 'package:flutter/services.dart';

Future<String> loadFontAsBase64(String assetPath) async {
  final ByteData data = await rootBundle.load(assetPath);
  final Uint8List bytes = data.buffer.asUint8List();
  return base64Encode(bytes);
}