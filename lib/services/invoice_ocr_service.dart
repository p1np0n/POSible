import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'settings_repository.dart';

/// Lee el texto de la foto de una factura usando OCR.space (servicio
/// gratuito de reconocimiento de texto). Sin una clave propia configurada
/// en Configuración, usa la clave de prueba pública "helloworld" — sirve
/// para probar, pero tiene límites estrictos y compartidos entre todo el
/// mundo; para uso real conviene una clave propia (gratis en ocr.space).
class InvoiceOcrService {
  static const _demoApiKey = 'helloworld';
  final SettingsRepository _settingsRepository = SettingsRepository();

  /// Devuelve el texto reconocido, o lanza una excepción con un mensaje
  /// entendible si algo falla (clave inválida, límite alcanzado, imagen
  /// ilegible, etc.).
  Future<String> extractText(Uint8List imageBytes) async {
    final settings = await _settingsRepository.getSettings();
    final apiKey =
        (settings.ocrApiKey != null && settings.ocrApiKey!.trim().isNotEmpty) ? settings.ocrApiKey! : _demoApiKey;

    final request = http.MultipartRequest('POST', Uri.parse('https://api.ocr.space/parse/image'))
      ..fields['apikey'] = apiKey
      ..fields['language'] = 'spa'
      ..fields['isOverlayRequired'] = 'false'
      ..fields['OCREngine'] = '2'
      ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'factura.jpg'));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('El servicio de OCR respondió con error (código ${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['IsErroredOnProcessing'] == true) {
      final message = json['ErrorMessage'];
      final text = message is List ? message.join(', ') : message?.toString();
      throw Exception(text ?? 'No se pudo leer la imagen');
    }

    final results = json['ParsedResults'] as List?;
    if (results == null || results.isEmpty) {
      throw Exception('No se encontró texto en la imagen');
    }
    final parsedText = (results.first as Map<String, dynamic>)['ParsedText'] as String?;
    if (parsedText == null || parsedText.trim().isEmpty) {
      throw Exception('No se encontró texto en la imagen');
    }
    return parsedText;
  }
}
