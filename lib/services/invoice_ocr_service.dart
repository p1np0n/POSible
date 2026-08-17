import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'settings_repository.dart';

/// Lee el texto de una foto o PDF de una factura usando OCR.space (servicio
/// gratuito de reconocimiento de texto). Sin una clave propia configurada
/// en Configuración, usa la clave de prueba pública "helloworld" — sirve
/// para probar, pero tiene límites estrictos y compartidos entre todo el
/// mundo (y de tamaño de archivo); para uso real conviene una clave propia
/// (gratis en ocr.space).
class InvoiceOcrService {
  static const _demoApiKey = 'helloworld';
  final SettingsRepository _settingsRepository = SettingsRepository();

  /// Devuelve el texto reconocido (de todas las páginas si es un PDF), o
  /// lanza una excepción con un mensaje entendible si algo falla (clave
  /// inválida, límite alcanzado, archivo ilegible o demasiado pesado, etc.).
  Future<String> extractText(Uint8List bytes, {bool isPdf = false}) async {
    final settings = await _settingsRepository.getSettings();
    final apiKey =
        (settings.ocrApiKey != null && settings.ocrApiKey!.trim().isNotEmpty) ? settings.ocrApiKey! : _demoApiKey;

    final request = http.MultipartRequest('POST', Uri.parse('https://api.ocr.space/parse/image'))
      ..fields['apikey'] = apiKey
      ..fields['language'] = 'spa'
      ..fields['isOverlayRequired'] = 'false'
      ..fields['OCREngine'] = '2'
      ..fields['filetype'] = isPdf ? 'PDF' : 'JPG'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: isPdf ? 'factura.pdf' : 'factura.jpg',
      ));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('El servicio de OCR respondió con error (código ${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['IsErroredOnProcessing'] == true) {
      final message = json['ErrorMessage'];
      final text = message is List ? message.join(', ') : message?.toString();
      throw Exception(text ?? 'No se pudo leer el archivo');
    }

    final results = json['ParsedResults'] as List?;
    if (results == null || results.isEmpty) {
      throw Exception('No se encontró texto en el archivo');
    }
    // Un PDF de varias páginas trae un resultado por página; se juntan todos.
    final parsedText = results
        .map((r) => (r as Map<String, dynamic>)['ParsedText'] as String? ?? '')
        .where((t) => t.trim().isNotEmpty)
        .join('\n');
    if (parsedText.trim().isEmpty) {
      throw Exception('No se encontró texto en el archivo');
    }
    return parsedText;
  }
}
