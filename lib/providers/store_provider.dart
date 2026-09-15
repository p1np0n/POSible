import 'package:flutter/foundation.dart';

import '../config/current_store.dart';
import '../models/employee_profile.dart';
import '../models/store.dart';
import '../services/profile_repository.dart';
import '../services/store_repository.dart';

class StoreProvider extends ChangeNotifier {
  final StoreRepository _repository = StoreRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  bool loaded = false;
  bool isSuperAdmin = false;
  Store? myStore;
  EmployeeProfile? myProfile;

  bool get showReports => myStore?.featureReports ?? false;
  bool get showCustomers => myStore?.featureCustomers ?? false;
  bool get showEmployees => myStore?.featureEmployees ?? false;

  /// true si el usuario actual es administrador de ESTA tienda (el dueño,
  /// o a quien le haya dado ese rol) — puede entrar a Configuración y
  /// Empleados, y ve todo sin importar los permisos activados.
  bool get isStoreAdmin => myProfile?.isAdmin ?? false;

  /// true si el usuario actual puede usar una sección restringida por
  /// permiso (Artículos, Reportes, Clientes): siempre para el
  /// administrador, o si se le activó ese permiso puntual.
  bool hasPermission(String key) => isStoreAdmin || (myProfile?.permissions.contains(key) ?? false);

  Future<void> load() async {
    final info = await _repository.getMyStoreInfo();
    isSuperAdmin = info.isSuperAdmin;
    myStore = info.store;
    CurrentStore.id = info.store?.id;
    myProfile = await _profileRepository.getMyProfile();
    loaded = true;
    notifyListeners();
  }

  void reset() {
    loaded = false;
    isSuperAdmin = false;
    myStore = null;
    myProfile = null;
    CurrentStore.id = null;
  }
}
