import 'package:flutter/foundation.dart';

import '../models/cash_session.dart';
import '../services/cash_session_repository.dart';

class CashSessionProvider extends ChangeNotifier {
  final CashSessionRepository _repository = CashSessionRepository();
  CashSession? _current;
  bool _loading = false;

  CashSession? get current => _current;
  bool get loading => _loading;
  bool get isOpen => _current?.isOpen ?? false;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    _current = await _repository.getOpenSession();
    _loading = false;
    notifyListeners();
  }

  Future<void> open(double openingAmount) async {
    _current = await _repository.open(openingAmount);
    notifyListeners();
  }

  Future<void> close({required double closingAmount, String? notes}) async {
    if (_current == null) return;
    await _repository.close(_current!.id, closingAmount: closingAmount, notes: notes);
    _current = null;
    notifyListeners();
  }
}
