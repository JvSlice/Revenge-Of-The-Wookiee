import 'package:flutter/material.dart';

class StickState {
  int? pointerId;
  Offset center = Offset.zero;
  Offset current = Offset.zero;
  bool active = false;

  void start(int id, Offset position) {
    pointerId = id;
    center = position;
    current = position;
    active = true;
  }

  void update(Offset position) {
    current = position;
  }

  void stop() {
    pointerId = null;
    center = Offset.zero;
    current = Offset.zero;
    active = false;
  }

  Offset get delta => active ? current - center : Offset.zero;
}
