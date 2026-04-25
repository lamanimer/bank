import 'dart:math';

class SimpleUuid {
  static String generate() {
    final random = Random();

    final values = List<int>.generate(16, (i) => random.nextInt(256));

    // UUID version (4)
    values[6] = (values[6] & 0x0f) | 0x40;

    // UUID variant
    values[8] = (values[8] & 0x3f) | 0x80;

    return values
        .map((v) => v.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}