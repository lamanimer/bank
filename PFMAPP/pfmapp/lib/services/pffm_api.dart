import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/goal.dart';
import '../../models/badge.dart';

class PffmApi {
  /// ✅ Works on Chrome + Android Emulator + Physical phone
  static String get baseUrl {
    if (kIsWeb) return "http://127.0.0.1:8001"; // Chrome
    return "http://10.0.2.2:8001"; // Android Emulator
    // For real phone: use your PC IP, e.g. "http://192.168.1.50:8000"
  }

  static Uri _u(String path) => Uri.parse('$baseUrl$path');

  static Map<String, dynamic> _decodeJson(String body) {
    final obj = jsonDecode(body);
    if (obj is Map<String, dynamic>) return obj;
    return {"data": obj};
  }

  static Exception _err(http.Response res, String label) {
    return Exception('$label failed: ${res.statusCode} ${res.body}');
  }

  // =========================
  // AUTH
  // =========================

  static Future<void> requestOtp({required String email}) async {
    final res = await http.post(
      _u('/auth/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _err(res, "requestOtp");
    }
  }

  /// ✅ Your backend requires: email + otp + name
  /// Returns: { ok: true, user: {...} }
  static Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
    required String name,
  }) async {
    final res = await http.post(
      _u('/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp, 'name': name}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('verifyOtp failed: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // =========================
  // USERS (optional)
  // =========================

  static Future<Map<String, dynamic>> createUser({
    required int userId,
    required String name,
    required String email,
  }) async {
    final res = await http.post(
      _u('/users/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'name': name, 'email': email}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _err(res, "createUser");
    }

    return _decodeJson(res.body);
  }

  static Future<Map<String, dynamic>> getUserByEmail(String email) async {
    final res = await http.get(
      _u('/users/by-email/$email'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode == 404) {
      throw Exception("Email not found");
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('getUserByEmail failed: ${res.statusCode} ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ========== GOALS ==========
  static Future<List<Goal>> getGoals({required String userId}) async {
    final res = await http.get(_u('/goals/user/$userId'));
    if (res.statusCode != 200) throw _err(res, 'getGoals');
    final List data = jsonDecode(res.body);
    return data.map<Goal>((json) => Goal.fromJson(json)).toList();
  }

  static Future<Map<String, dynamic>> createGoal({
    required String userId,
    required String name,
    required double targetAmount,
  }) async {
    final res = await http.post(
      _u('/goals/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': int.tryParse(userId) ?? 0,
        'name': name,
        'target_amt': targetAmount,
      }),
    );
    if (res.statusCode != 200) throw _err(res, 'createGoal');
    return jsonDecode(res.body);
  }

  static Future<bool> updateGoalStatus({required String goalId, required String status}) async {
    final res = await http.put(
      _u('/goals/$goalId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'status': status}),
    );
    if (res.statusCode != 200) throw _err(res, 'updateGoalStatus');
    return jsonDecode(res.body)['ok'] ?? false;
  }

  // ========== BADGES ==========
  static Future<List<Badge>> getBadges() async {
    final res = await http.get(_u('/badges/'));
    if (res.statusCode != 200) throw _err(res, 'getBadges');
    final List data = jsonDecode(res.body);
    return data.map<Badge>((json) => Badge.fromJson(json)).toList();
  }

  static Future<Map<String, dynamic>> createBadge({
    required String name,
    required String description,
    required int points,
  }) async {
    final res = await http.post(
      _u('/badges/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'description': description, 'points': points}),
    );
    if (res.statusCode != 200) throw _err(res, 'createBadge');
    return jsonDecode(res.body);
  }
}
