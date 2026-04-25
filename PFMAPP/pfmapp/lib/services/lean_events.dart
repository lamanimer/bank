import 'dart:async';

class LeanEvents {
  static final StreamController<Map<String, dynamic>> _ctrl =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get stream => _ctrl.stream;

  static void emit(Map<String, dynamic> event) {
    if (!_ctrl.isClosed) _ctrl.add(event);
  }

  static void dispose() {
    _ctrl.close();
  }
}
