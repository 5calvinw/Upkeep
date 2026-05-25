import 'package:flutter/foundation.dart';

class PropertyContext {
  static final ValueNotifier<String?> selectedPropertyId =
      ValueNotifier<String?>(null);

  static final ValueNotifier<String?> selectedPropertyName =
      ValueNotifier<String?>(null);

  static void selectProperty(String? id, String? name) {
    selectedPropertyId.value = id;
    selectedPropertyName.value = name;
  }
}
