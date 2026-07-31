import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'server_config.dart';
import 'storage.dart';

final secureStoreProvider = Provider(
  (ref) => SecureStore(
    const FlutterSecureStorage(
      aOptions: AndroidOptions(),
      webOptions: WebOptions(
        dbName: 'gst_expense_admin',
        publicKey: 'gst-expense-admin-session',
      ),
    ),
  ),
);

/// Free Render services can take 30–60s to wake after idle.
final dioProvider = Provider<Dio>((ref) {
  final store = ref.watch(secureStoreProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: ServerConfig.baseUrl,
      connectTimeout: const Duration(seconds: 90),
      receiveTimeout: const Duration(seconds: 90),
      sendTimeout: const Duration(seconds: 120),
      headers: const {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await store.token;
        final companyId = await store.companyId;
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        if (companyId != null) options.headers['X-Company-Id'] = companyId;
        handler.next(options);
      },
    ),
  );
  return dio;
});

void updateAdminBaseUrl(WidgetRef ref, String baseUrl) {
  ref.read(dioProvider).options.baseUrl = baseUrl;
}

String apiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Cannot reach the server. Check the API URL and connection.';
    }
    return error.message ?? 'Request failed';
  }
  return error.toString().replaceFirst('Exception: ', '');
}

List<Map<String, dynamic>> itemList(dynamic data) {
  final raw = data is Map
      ? (data['items'] ?? data['data'] ?? data['results'])
      : data;
  if (raw is! List) return const [];
  return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}
