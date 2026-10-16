/// Minimal WebDAV client using dart:io HttpClient.
/// Supports GET, PUT, PROPFIND, MKCOL for file sync.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class WebDavConfig {
  const WebDavConfig({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.remotePath = '/plain/sync',
  });

  final String baseUrl; // e.g. https://dav.example.com/dav
  final String username;
  final String password;
  final String remotePath; // directory for sync files

  String get _auth => 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  Map<String, String> get _headers => {
    'Authorization': _auth,
    'User-Agent': 'SuJi-Plain/1.0',
  };

  Uri _uri(String path) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$base$path');
  }

  String filePath(String name) => '$remotePath/$name';
}

/// 同步传输层接口。
///
/// 把「怎么把字节搬过去」与「搬什么、怎么合并」分开：当前实现是 WebDAV，
/// 换成官方云只替换这一层；测试里用内存实现即可跑通双端收敛。
abstract interface class SyncTransport {
  Future<bool> ensureCollection(WebDavConfig config);
  Future<bool> put(WebDavConfig config, String fileName, List<int> bytes);
  Future<List<int>?> get(WebDavConfig config, String fileName);
  Future<List<String>> list(WebDavConfig config);
  void dispose();
}

class WebDavClient implements SyncTransport {
  WebDavClient({HttpClient? httpClient}) : _http = httpClient ?? HttpClient();

  final HttpClient _http;

  /// Check if the remote directory exists. Creates it if missing.
  @override
  Future<bool> ensureCollection(WebDavConfig config) async {
    try {
      final exists = await _propfind(config, config.remotePath);
      if (exists) return true;
      return await _mkcol(config, config.remotePath);
    } on Exception {
      return false;
    }
  }

  /// Upload bytes to a remote file. Returns true on success.
  @override
  Future<bool> put(WebDavConfig config, String fileName, List<int> bytes) async {
    try {
      final req = await _http.putUrl(config._uri(config.filePath(fileName)));
      config._headers.forEach(req.headers.set);
      req.headers.contentType = ContentType.binary;
      req.contentLength = bytes.length;
      req.add(bytes);
      final resp = await req.close();
      await resp.drain<void>();
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } on Exception {
      return false;
    }
  }

  /// Download a remote file. Returns null on failure.
  @override
  Future<List<int>?> get(WebDavConfig config, String fileName) async {
    try {
      final req = await _http.getUrl(config._uri(config.filePath(fileName)));
      config._headers.forEach(req.headers.set);
      final resp = await req.close();
      if (resp.statusCode != 200) return null;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in resp) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } on Exception {
      return null;
    }
  }

  /// 增量同步用：列出同步目录下的文件名（PROPFIND Depth:1）。
  ///
  /// 返回**文件名**（不含目录），失败返回空列表——调用方按「没有别人的日志」处理。
  @override
  Future<List<String>> list(WebDavConfig config) async {
    try {
      final req = await _http.openUrl('PROPFIND', config._uri(config.remotePath));
      config._headers.forEach(req.headers.set);
      req.headers.set('Depth', '1');
      req.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
      req.write('<?xml version="1.0"?><a:propfind xmlns:a="DAV:"><a:prop>'
          '<a:resourcetype/></a:prop></a:propfind>');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 207 && resp.statusCode != 200) return const [];
      // href 可能是绝对 URL 或路径；统一取最后一段并去掉末尾的 '/'
      final names = <String>[];
      for (final m in RegExp(r'<(?:[A-Za-z0-9]+:)?href[^>]*>(.*?)</(?:[A-Za-z0-9]+:)?href>',
              caseSensitive: false)
          .allMatches(body)) {
        var href = Uri.decodeFull(m.group(1)!.trim());
        if (href.endsWith('/')) continue; // 目录
        final seg = href.split('/').where((s) => s.isNotEmpty).toList();
        if (seg.isEmpty) continue;
        names.add(seg.last);
      }
      return names;
    } on Exception {
      return const [];
    }
  }

  /// Check if a remote file exists (HEAD).
  Future<bool> exists(WebDavConfig config, String fileName) async {    try {
      final req = await _http.headUrl(config._uri(config.filePath(fileName)));
      config._headers.forEach(req.headers.set);
      final resp = await req.close();
      await resp.drain<void>();
      return resp.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  /// Test connection with a PROPFIND on the root.
  Future<bool> testConnection(WebDavConfig config) async {
    try {
      final req = await _http.openUrl('PROPFIND', config._uri('/'));
      config._headers.forEach(req.headers.set);
      req.headers.set('Depth', '0');
      req.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
      req.write('<?xml version="1.0"?><a:propfind xmlns:a="DAV:"><a:prop><a:resourcetype/></a:prop></a:propfind>');
      final resp = await req.close();
      await resp.drain<void>();
      return resp.statusCode == 207 || resp.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  Future<bool> _propfind(WebDavConfig config, String path) async {
    try {
      final req = await _http.openUrl('PROPFIND', config._uri(path));
      config._headers.forEach(req.headers.set);
      req.headers.set('Depth', '0');
      req.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
      req.write('<?xml version="1.0"?><a:propfind xmlns:a="DAV:"><a:prop><a:resourcetype/></a:prop></a:propfind>');
      final resp = await req.close();
      await resp.drain<void>();
      return resp.statusCode == 207;
    } on Exception {
      return false;
    }
  }

  Future<bool> _mkcol(WebDavConfig config, String path) async {
    try {
      final req = await _http.openUrl('MKCOL', config._uri(path));
      config._headers.forEach(req.headers.set);
      final resp = await req.close();
      await resp.drain<void>();
      return resp.statusCode == 201 || resp.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  @override
  void dispose() => _http.close(force: true);
}
