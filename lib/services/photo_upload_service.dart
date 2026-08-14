import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PhotoUploadService {
  static const _bucket = 'product-photos';

  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  /// Abre la cámara, sube la foto tomada a Supabase Storage y devuelve su
  /// URL pública. Devuelve null si el usuario cancela.
  Future<String?> takeAndUploadPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final extension = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    final path = 'products/${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from(_bucket).getPublicUrl(path);
  }
}
