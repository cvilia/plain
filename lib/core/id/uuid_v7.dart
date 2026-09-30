/// UUID v7 (26-char lowercase Crockford Base32). See 04-5.2.
library;

import 'dart:math';
import 'dart:typed_data';

const String _alphabet = '0123456789abcdefghjkmnpqrstvwxyz';

class UuidV7 {
  UuidV7([Random? random]) : _random = random ?? Random.secure();
  final Random _random;

  String generate({DateTime? at}) {
    final ms = (at ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    final ts = Uint8List(6);
    var t = ms;
    for (var i = 5; i >= 0; i--) {
      ts[i] = t & 0xff;
      t >>= 8;
    }
    final rand = Uint8List(10);
    for (var i = 0; i < 10; i++) {
      rand[i] = _random.nextInt(256);
    }
    rand[0] = (rand[0] & 0x0f) | 0x70;
    rand[2] = (rand[2] & 0x3f) | 0x80;
    final bytes = Uint8List(16);
    bytes.setRange(0, 6, ts);
    bytes.setRange(6, 16, rand);
    return encodeBase32(bytes);
  }

  static String encodeBase32(Uint8List bytes) {
    final bits = StringBuffer();
    for (final b in bytes) {
      bits.write(b.toRadixString(2).padLeft(8, '0'));
    }
    final bitStr = '${bits}00';
    final out = StringBuffer();
    for (var i = 0; i < 26; i++) {
      out.write(_alphabet[int.parse(bitStr.substring(i * 5, i * 5 + 5), radix: 2)]);
    }
    return out.toString();
  }

  static bool isValid(String id) {
    if (id.length != 26) return false;
    for (var i = 0; i < id.length; i++) {
      if (!_alphabet.contains(id[i])) return false;
    }
    return true;
  }
}
