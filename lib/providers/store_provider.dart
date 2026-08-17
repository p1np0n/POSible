import 'package:flutter/foundation.dart';

import '../config/current_store.dart';
import '../models/store.dart';
import '../services/store_repository.dart';

class StoreProvider extends ChangeNotifier {
  final StoreRepository _repository = StoreRepository();

  bool loaded = false;
  bool isSuperAdmin = false;
  Store? myStore;

  bool get showReports => myStore?.featureReports ?? false;
  bool get showCustomers => myStore?.featureCustomers ?? false;
  bool get showEmployees => myStore?.featureEmployees ?? false;

  Future<void> load() async {
    final info = await _repository.getMyStoreInfo();
    isSuperAdmin = info.isSuperAdmin;
    myStore = info.store;
    CurrentStore.id = info.store?.id;
    loaded = true;
    notifyListeners();
  }

  void reset() {
    loaded = false;
    isSuperAdmin = false;
    myStore = null;
    CurrentStore.id = null;
  }
}
