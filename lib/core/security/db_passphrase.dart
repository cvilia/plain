/// Database passphrase generation & storage (06-C2 / PRD C6).
/// 32-byte random key, hex-encoded, held in platform keystore/keychain.
/// Never log the passphrase; never sync it (INV-3 style local secret).
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String kDbPassphraseKey = 'plain.db.passphrase';

final FlutterSecureStorage _storage = const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

/// 64 hex chars = 32 bytes of entropy (SQLCipher key material).
String _randomHex() {
  final rnd = Random.secure();
  final bytes = Uint8List.fromList(List<int>.generate(32, (_) => rnd.nextInt(256)));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// 会话内缓存：避免 keystore 失败时每次调用生成不同密钥，
/// 导致「打开库的 key」与「导出时读到的 key」不一致（backup_rekey_failed）。
String? _cachedPassphrase;

/// Load existing passphrase, or create and persist a new one.
Future<String> loadOrCreateDbPassphrase() async {
  final cached = _cachedPassphrase;
  if (cached != null && cached.length == 64) return cached;

  try {
    final existing = await _storage.read(key: kDbPassphraseKey);
    if (existing != null && existing.length == 64) {
      _cachedPassphrase = existing;
      return existing;
    }
  } catch (_) {
    // Fall through and mint a new one.
  }
  final created = _randomHex();
  try {
    await _storage.write(key: kDbPassphraseKey, value: created);
    _cachedPassphrase = created;
    return created;
  } catch (_) {
    // Storage unavailable (e.g. unit tests / desktop without plugin):
    // session-cached key so open() and export() stay consistent.
    _cachedPassphrase = created;
    return created;
  }
}

/// Wipe passphrase (used by 「删除所有数据」 flows).
Future<void> wipeDbPassphrase() async {
  _cachedPassphrase = null;
  try {
    await _storage.delete(key: kDbPassphraseKey);
  } catch (_) {}
}

/// Debug helper — returns only whether a key is stored, never the value.
Future<bool> hasDbPassphrase() async {
  try {
    final v = await _storage.read(key: kDbPassphraseKey);
    return v != null && v.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// SQLCipher raw key 字面量（blob 形式）。
/// 历史库是用 `PRAGMA key = x'HEX'` 加密的，必须保持同一形式，
/// 否则 hmac check failed（表现为启动卡死 / 打不开库）。
String sqlcipherKeyLiteral(String hexPassphrase) =>
    "x'${hexPassphrase.toUpperCase()}'";

/// 文档推荐的带引号形式 `PRAGMA key = "x'HEX'"`（与 blob 形式 key 不同，
/// 仅作兼容探测用，不要用它打开已有库）。
String sqlcipherKeyQuotedLiteral(String hexPassphrase) =>
    "\"x'${hexPassphrase.toUpperCase()}'\"";
