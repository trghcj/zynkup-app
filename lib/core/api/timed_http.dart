/// `package:http` with a timeout on every plain request.
///
/// Without one, a dropped connection or a server that never answers left
/// spinners running indefinitely. The limit is generous because the backend
/// runs on Render's free plan, which can take ~50s to wake up after idling.
///
/// Import it in place of `package:http/http.dart` (`as http`). Multipart
/// uploads (`MultipartRequest.send`) are not wrapped: large files can
/// legitimately take longer than this.
library;

import 'package:http/http.dart' as base;

export 'package:http/http.dart' hide get, post, put, delete, patch;

const Duration requestTimeout = Duration(seconds: 60);

Future<base.Response> get(Uri url, {Map<String, String>? headers}) =>
    base.get(url, headers: headers).timeout(requestTimeout);

Future<base.Response> post(Uri url, {Map<String, String>? headers, Object? body}) =>
    base.post(url, headers: headers, body: body).timeout(requestTimeout);

Future<base.Response> put(Uri url, {Map<String, String>? headers, Object? body}) =>
    base.put(url, headers: headers, body: body).timeout(requestTimeout);

Future<base.Response> patch(Uri url, {Map<String, String>? headers, Object? body}) =>
    base.patch(url, headers: headers, body: body).timeout(requestTimeout);

Future<base.Response> delete(Uri url, {Map<String, String>? headers, Object? body}) =>
    base.delete(url, headers: headers, body: body).timeout(requestTimeout);
