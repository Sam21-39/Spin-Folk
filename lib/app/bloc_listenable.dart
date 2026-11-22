import 'dart:async';

import 'package:flutter/foundation.dart';

class BlocListenable extends ChangeNotifier {
  BlocListenable(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
