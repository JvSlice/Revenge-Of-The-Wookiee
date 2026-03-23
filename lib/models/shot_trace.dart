import 'package:flutter/material.dart';

class ShotTrace {
  ShotTrace({
    required this.start,
    required this.end,
  });

  Offset start;
  Offset end;
  double life = 0.08;
}
