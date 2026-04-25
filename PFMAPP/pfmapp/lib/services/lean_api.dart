import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class LeanApi {
  static String _baseUrl() =>
      kIsWeb ? "http://127.0.0.1:8001" : "http://10.0.2.2:8001";

  static Future<Map<String, dynamic>> fetchAll({
    required String customerId,
  }) async {
    final res = await http.get(
      Uri.parse("${_baseUrl()}/lean/data?customer_id=$customerId"),
    );

    if (res.statusCode != 200) {
      throw Exception("lean/data failed ${res.statusCode}: ${res.body}");
    }

    final obj = jsonDecode(res.body);
    if (obj is Map<String, dynamic>) return obj;
    throw Exception("Invalid response from backend");
  }

  /// For mobile: backend should create a link session and return link_url
  static Future<String> createLinkUrl({required String customerId}) async {
    final res = await http.post(
      Uri.parse("${_baseUrl()}/lean/link-session?customer_id=$customerId"),
    );

    if (res.statusCode != 200) {
      throw Exception("link-session failed ${res.statusCode}: ${res.body}");
    }

    final obj = jsonDecode(res.body);
    if (obj is Map<String, dynamic>) {
      final url = (obj["link_url"] ?? "").toString().trim();
      if (url.isEmpty) throw Exception("Backend did not return link_url");
      return url;
    }

    throw Exception("Invalid response from backend");
  }
}
