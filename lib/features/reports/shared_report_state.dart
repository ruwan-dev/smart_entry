import 'package:flutter/foundation.dart';

class SharedReportState {
  static final ValueNotifier<int> selectedMonth = ValueNotifier<int>(DateTime.now().month);
}
