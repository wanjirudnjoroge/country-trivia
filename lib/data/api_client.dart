import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../core/result.dart';

/// Thin wrapper around `package:http`.
///
/// `package:http` is the only HTTP client that works unchanged on web and on
/// mobile, so no `dart:io` import and no `kIsWeb` branching is needed here.
///
/// Every failure mode is converted to a [Failure]; this class never throws.
class ApiClient {
  ApiClient(
    this._httpClient, {
    this.baseUrl = AppConfig.apiBaseUrl,
    this.timeout = AppConfig.requestTimeout,
  });

  final http.Client _httpClient;
  final String baseUrl;
  final Duration timeout;

  /// GETs [path] relative to [baseUrl] and decodes the JSON body.
  ///
  /// Returns [Ok] with the decoded body, or [Err] carrying a [Failure].
  Future<Result<Object?>> getJson(String path) async {
    final Uri uri = Uri.parse('$baseUrl$path');
    try {
      final http.Response response = await _httpClient
          .get(uri, headers: const <String, String>{'Accept': 'application/json'})
          .timeout(timeout);

      if (response.statusCode != 200) {
        return Err<Object?>(
          Failure(
            FailureKind.server,
            'The server replied with ${response.statusCode}.',
            statusCode: response.statusCode,
          ),
        );
      }

      return Ok<Object?>(jsonDecode(utf8.decode(response.bodyBytes)));
    } on TimeoutException {
      return const Err<Object?>(Failure.timeout());
    } on FormatException {
      return const Err<Object?>(Failure.parsing());
    } on http.ClientException catch (error) {
      return Err<Object?>(Failure(FailureKind.network, error.message, cause: error));
    } catch (error) {
      return Err<Object?>(Failure(FailureKind.unknown, 'Unexpected error.', cause: error));
    }
  }

  /// Releases the underlying connection pool.
  void close() => _httpClient.close();
}
