import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>> getLeanConfig(String customerId) async {
  final response = await http.get(
    Uri.parse("http://127.0.0.1:8001/lean/link-config?customer_id=$customerId"),
  );

  if (response.statusCode != 200) {
    throw Exception("Failed to get Lean config");
  }

  return jsonDecode(response.body);
}
