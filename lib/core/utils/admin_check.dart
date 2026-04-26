import 'dart:convert';
import 'package:http/http.dart' as http;

/// 🔥 CHECK IF USER IS ADMIN (API)
Future<bool> isAdmin() async {
  try {
    final res = await http.get(
      Uri.parse("http://127.0.0.1:8000/users/me"),
      headers: {
        // 🔐 Add JWT token here later
        // "Authorization": "Bearer YOUR_TOKEN"
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data["role"] == "admin";
    }

    return false;
  } catch (e) {
    return false;
  }
}