import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PhotoUploadService {
  static const _bucket = 'product-photos';

  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  /// Abre la cámara o la galería (según [source]), sube la foto elegida a
  /// Supabase Storage y devuelve su URL pública junto con los bytes ya
  /// redimensionados (por si el que llama quiere reutilizarlos, ej. para
  /// reconocer texto con OCR sin tener que volver a pedir la foto).
  /// Devuelve null si el usuario cancela.
  ///
  /// Se limita el ancho/alto a 1024px además de la calidad JPEG: una foto
  /// de cámara sin redimensionar puede pesar varios MB por sus dimensiones
  /// (ej. 4000x3000), mucho más de lo que hace falta para mostrarla como
  /// miniatura en las listas — esto baja el peso final a unos cientos de
  /// KB como mucho, para que cargue rápido.
  Future<(String url, Uint8List bytes)?> pickAndUploadPhoto(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final extension = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    final path = 'products/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final url = _client.storage.from(_bucket).getPublicUrl(path);
    return (url, bytes);
  }
}
