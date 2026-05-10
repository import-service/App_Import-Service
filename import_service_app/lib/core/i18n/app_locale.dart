import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';

/// Глобальная локаль приложения (используется для refresh GoRouter).
final ValueNotifier<Locale> appLocale = ValueNotifier<Locale>(const Locale('ru'));
