import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/contact.dart';
import '../models/call.dart';
import '../models/call_log.dart';
import 'auth_interceptor.dart';

class ApiClient {
  static const String baseUrl = 'https://shared-contact-crm.ramzarznegaran.workers.dev';

  late final Dio dio;
  final FlutterSecureStorage storage;

  ApiClient({FlutterSecureStorage? storage})
      : storage = storage ?? const FlutterSecureStorage() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    dio.interceptors.add(AuthInterceptor(this.storage));
  }

  // Authentication
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await dio.post('/login', data: {
        'email': email,
        'password': password,
      });

      final token = response.data['token'] as String;
      final user = User.fromJson(response.data['user']);

      await storage.write(key: 'jwt_token', value: token);

      return {'token': token, 'user': user};
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    await storage.delete(key: 'jwt_token');
  }

  Future<bool> isLoggedIn() async {
    final token = await storage.read(key: 'jwt_token');
    return token != null;
  }

  // Contacts
  Future<List<Contact>> getContacts() async {
    try {
      final response = await dio.get('/contacts');
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((json) => Contact.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Contact> createContact(Contact contact) async {
    try {
      final response = await dio.post('/contacts', data: contact.toJson());
      return Contact.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Contact> updateContact(int id, Contact contact) async {
    try {
      final response = await dio.put('/contacts/$id', data: contact.toJson());
      return Contact.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteContact(int id) async {
    try {
      await dio.delete('/contacts/$id');
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Calls
  Future<List<Call>> getCalls() async {
    try {
      final response = await dio.get('/calls', queryParameters: {'limit': 10000});
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((json) => Call.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Call Logs (alias for getCalls, returns CallLog format)
  Future<List<CallLog>> getCallLogs() async {
    try {
      final response = await dio.get('/calls', queryParameters: {'limit': 10000});
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((json) => CallLog.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Call> createCall(Call call) async {
    try {
      final response = await dio.post('/calls', data: call.toJson());
      return Call.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Admin - User Management
  Future<User> createUser(String email, String password, String role) async {
    try {
      final response = await dio.post('/admin/users', data: {
        'email': email,
        'password': password,
        'role': role,
      });
      return User.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<User>> getUsers() async {
    try {
      final response = await dio.get('/admin/users');
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      await dio.delete('/admin/users/$id');
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getUserStats(int userId) async {
    try {
      final response = await dio.get('/admin/users/$userId/stats');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getUserContacts(int userId) async {
    try {
      final response = await dio.get('/admin/users/$userId/contacts');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getUserCallLogs(int userId) async {
    try {
      final response = await dio.get('/admin/users/$userId/calls');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> flushUserData(int userId) async {
    try {
      final response = await dio.delete('/admin/users/$userId/data');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Selective flushing (for now, using full flush - could be enhanced with selective endpoints)
  Future<Map<String, dynamic>> flushContactsOnly(int userId) async {
    // For now, we'll flush all data since we don't have a selective contacts-only endpoint
    // In the future, we could add separate endpoints for selective flushing
    try {
      final response = await dio.delete('/admin/users/$userId/data');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> flushCallsOnly(int userId) async {
    // For now, we'll flush all data since we don't have a selective calls-only endpoint
    // In the future, we could add separate endpoints for selective flushing
    try {
      final response = await dio.delete('/admin/users/$userId/data');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        final message = error.response?.data['error'] ?? error.response?.statusMessage;
        return message ?? 'An error occurred';
      } else {
        return 'Network error. Please check your connection.';
      }
    }
    return error.toString();
  }
}
