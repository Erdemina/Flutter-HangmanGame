import 'dart:convert';
import 'package:http/http.dart' as http;

class UserService {
  static const String _baseUrl =
      'https://5wcorlr6ic.execute-api.eu-north-1.amazonaws.com/v2';

  Future<Map<String, dynamic>> getUserData(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/fetchUser?userId=$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'username': data['username'],
          'trophies': data['trophies'],
          'email': data['email'],
          'userId': data['userId'],
        };
      } else {
        throw Exception('Failed to load user data');
      }
    } catch (e) {
      print('Error fetching user data: $e');
      rethrow;
    }
  }
}
