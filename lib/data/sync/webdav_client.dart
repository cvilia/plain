/// Minimal WebDAV client using dart:io HttpClient.
/// Supports GET, PUT, PROPFIND, MKCOL for file sync.
library;

import 'dart:convert';
import 'dart:io';

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

class WebDavClient {
  WebDavClient({HttpClient? httpClient}) : _http = httpClient ?? HttpClient();

  final HttpClient _http;

  /// Check if the remote directory exists. Creates it if missing.
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
  Future<bool> put(WebDavConfig config, String fileName, List<int> bytes) async {
    try {
      final req = await _http.putUrl(config._uri(config.filePath(fileName)));
      config._headers.forEach(req.headers.set);
      req.headers.contentType = ContentType.binary;
      req.contentLength = bytes.length;
      req.add(bytes);
      final resp = await req.close();
      await resp.drain();
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } on Exception {
      return false;
    }
  }

  /// Download a remote file. Returns null on failure.
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

  /// Check if a remote file exists (HEAD).
  Future<bool> exists(WebDavConfig config, String fileName) async {
    try {
      final req = await _http.headUrl(config._uri(config.filePath(fileName)));
      config._headers.forEach(req.headers.set);
      final resp = await req.close();
      await resp.drain();
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
      await resp.drain();
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
      await resp.drain();
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
      await resp.drain();
      return resp.statusCode == 201 || resp.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  void dispose() => _http.close(force: true);
}
