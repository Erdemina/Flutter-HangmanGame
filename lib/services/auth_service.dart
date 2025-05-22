import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'https://5wcorlr6ic.execute-api.eu-north-1.amazonaws.com'; // Eğer stage varsa ekle

  static Future<bool> login(String username, String password) async {
    final response = await http.get(
      Uri.parse('$baseUrl/login?username=$username&password=$password'),
    );

    if (response.statusCode == 200) {
      // response.body başarılıysa true döner
      return true;
    } else {
      return false;
    }
  }

  static Future<bool> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    return response.statusCode == 200;
  }
}
