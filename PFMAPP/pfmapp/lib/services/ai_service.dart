import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class AiService {
  static Future<String> askAssistant({
    required String userId,
    required String question,
    required List<dynamic> transactions,
    required List<dynamic> goals,
    required Map<String, dynamic> totals,
  }) async {
    final baseUrl =
        kIsWeb ? "http://127.0.0.1:8001" : "http://10.0.2.2:8001";

    final res = await http.post(
      Uri.parse("$baseUrl/ai/chat"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": userId,
        "question": question,
        "transactions": transactions,
        "goals": goals,
        "totals": totals,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("AI failed: ${res.body}");
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data["answer"] ?? "No response").toString();
  }
}