import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A custom HTTP client that tunnels every request through a public
/// proxy service.  Two **critical** fixes:
///
/// 1. **URL encoding** – the target URL is fed to the proxy gateway
///    as a single path segment, so we must *fully* encode it
///    (`Uri.encodeFull`) or spaces / Arabic letters break the request.
/// 2. **UTF‑8 decoding** – many responses omit a charset header,
///    so `http` defaults to ISO‑8859‑1. We read `bodyBytes` and decode
///    with UTF‑8 instead, which preserves Arabic / multibyte text.
///
class ProxyHttpClient extends YoutubeHttpClient {
  final String gateway;
  final http.Client _client = http.Client();

  ProxyHttpClient(this.gateway);

  /*-----------------------------------------------------------
  | helpers
  `-----------------------------------------------------------*/
  Uri _buildProxyUri(dynamic originalUrl) =>
      Uri.parse('$gateway${Uri.encodeFull(originalUrl.toString())}');

  Future<http.Response> _doGet(Uri uri, Map<String, String>? headers) =>
      _client.get(uri, headers: headers);

  /*-----------------------------------------------------------
  | YoutubeHttpClient overrides
  `-----------------------------------------------------------*/
  @override
  Future<String> getString(
    dynamic url, {
    Map<String, String>? headers,
    bool validate = true,
    bool raw = false,
  }) async {
    try {
      final response = await _doGet(_buildProxyUri(url), headers);

      if (validate && response.statusCode != 200) {
        throw Exception('Proxy request failed → HTTP ${response.statusCode}');
      }

      // ALWAYS decode manually with UTF‑8
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (e) {
      throw Exception('Proxy request error: $e');
    }
  }

  // youtube_explode_dart sometimes needs the raw bytes
  @override
  Future<http.Response> get(
    dynamic url, {
    Map<String, String>? headers,
    bool validate = true,
    bool raw = false,
  }) async {
    final response = await _doGet(_buildProxyUri(url), headers);

    if (validate && response.statusCode != 200) {
      throw Exception('Proxy request failed → HTTP ${response.statusCode}');
    }

    return response;
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}
