import 'dart:async';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'apiConfig.dart';
// Event bus equivalent for window.dispatchEvent
class TrialExpiredEvent {
  final Map<String, dynamic> data;
  TrialExpiredEvent(this.data);
}
final StreamController<TrialExpiredEvent> trialEventController = StreamController<TrialExpiredEvent>.broadcast();

final Dio dioClient = Dio(
  BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    // Equivalent to credentials: "include" for cookies
    extra: {'withCredentials': true},
    headers: {
      'X-Requested-With': 'XMLHttpRequest',
    },
  ),
)..interceptors.add(
  InterceptorsWrapper(
    onResponse: (response, handler) {
      final data = response.data;
      if (data != null && data is Map<String, dynamic>) {
        if (data['subscriptionStatus'] == 'EXPIRED' || data['code'] == 'TRIAL_EXPIRED') {
          trialEventController.add(TrialExpiredEvent(data));
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              error: 'TRIAL_EXPIRED',
            ),
          );
        }
      }
      return handler.next(response);
    },
    onError: (DioException e, handler) {
      if (e.response?.statusCode == 402 && e.response?.data?['code'] == 'TRIAL_EXPIRED') {
         trialEventController.add(TrialExpiredEvent(e.response?.data ?? {}));
      }
      return handler.next(e);
    },
  ),
);

late PersistCookieJar cookieJar;

Future<void> initCookies() async {
  final appDocDir = await getApplicationDocumentsDirectory();
  cookieJar = PersistCookieJar(storage: FileStorage("${appDocDir.path}/.cookies/"));
  dioClient.interceptors.add(CookieManager(cookieJar));
}

// Helper function to mimic `apiFetch`
Future<dynamic> apiFetch(String url, {String method = 'GET', dynamic data}) async {
  try {
    final response = await dioClient.request(
        url,
        data: data,
        options: Options(method: method)
    );
    return response.data;
  } on DioException catch (e) {
    if (e.response?.data != null) {
      final errorData = e.response?.data;
      if (errorData is Map) {
         throw Exception(errorData['message'] ?? errorData['error'] ?? 'Request failed');
      }
      throw Exception('Request failed with status ${e.response?.statusCode}: $errorData');
    }
    throw Exception('API ERROR: ${e.message}');
  }
}
