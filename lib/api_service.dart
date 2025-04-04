import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:unique_identifier/unique_identifier.dart';

class ApiService {
  static const List<String> apiUrls = [
    "http://192.168.254.163/",
    "http://126.209.7.246/"
  ];

  static const Duration requestTimeout = Duration(seconds: 2);
  static const int maxRetries = 6;
  static const Duration initialRetryDelay = Duration(seconds: 1);

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
    );
  }

  Future<String> fetchSoftwareLink(int linkID) async {
    String? deviceId = await UniqueIdentifier.serial;
    if (deviceId == null) {
      throw Exception("Unable to get device ID");
    }

    // First get the ID number associated with this device
    final deviceResponse = await getLastIdNumber(deviceId);
    if (deviceResponse == null || deviceResponse.isEmpty) {
      // Return a special URL that shows "Please provide ID Number" message
      return "data:text/html;charset=utf-8,"
          "<html>"
          "<head>"
          "<meta name='viewport' content='width=device-width, initial-scale=1.0'>"
          "<style>"
          "body { display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background-color: #f5f5f5; }"
          ".container { text-align: center; }"
          "h1 { color: #2053B3; font-size: 24px; margin-top: 20px; }"
          "</style>"
          "</head>"
          "<body>"
          "<div class='container'>"
          "<svg xmlns='http://www.w3.org/2000/svg' width='80' height='80' viewBox='0 0 24 24' fill='none' stroke='#2053B3' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>"
          "<path d='M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2'></path>"
          "<circle cx='8.5' cy='7' r='4'></circle>"
          "<line x1='20' y1='8' x2='20' y2='14'></line>"
          "<line x1='23' y1='11' x2='17' y2='11'></line>"
          "</svg>"
          "<h1>Please provide ID Number</h1>"
          "</div>"
          "</body>"
          "</html>";
    }
    String idNumber = deviceResponse;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      for (int i = 0; i < apiUrls.length; i++) {
        String apiUrl = apiUrls[i];
        try {
          final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_fetchLink.php?linkID=$linkID");
          final response = await http.get(uri).timeout(requestTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data.containsKey("softwareLink")) {
              String relativePath = data["softwareLink"];
              String fullUrl = Uri.parse(apiUrl).resolve(relativePath).toString();
              fullUrl += "?idNumber=$idNumber";
              return fullUrl;
            } else {
              throw Exception(data["error"]);
            }
          }
        } catch (e) {
          String errorMessage = "Error accessing $apiUrl on attempt $attempt";
          print(errorMessage);

          if (i == 0 && apiUrls.length > 1) {
            print("Falling back to ${apiUrls[1]}");
          }
        }
      }

      if (attempt < maxRetries) {
        final delay = initialRetryDelay * (1 << (attempt - 1));
        print("Waiting for ${delay.inSeconds} seconds before retrying...");
        await Future.delayed(delay);
      }
    }

    String finalError = "All API URLs are unreachable after $maxRetries attempts";
    _showToast(finalError);
    throw Exception(finalError);
  }

  Future<void> updateLanguageFlag(String idNumber, int languageFlag) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      for (String apiUrl in apiUrls) {
        try {
          final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLinkAPI/kurt_updateLanguage.php");
          final response = await http.post(
            uri,
            body: {
              'idNumber': idNumber,
              'languageFlag': languageFlag.toString(),
            },
          ).timeout(requestTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data["success"] == true) {
              return;
            } else {
              throw Exception(data["message"]);
            }
          }
        } catch (e) {
          print("Error accessing $apiUrl on attempt $attempt: $e");
        }
      }
      if (attempt < maxRetries) {
        final delay = initialRetryDelay * (1 << (attempt - 1));
        await Future.delayed(delay);
      }
    }
    throw Exception("Both API URLs are unreachable after $maxRetries attempts");
  }

  // New methods for login integration
  Future<String> insertIdNumber(String idNumber, {required String deviceId}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      for (String apiUrl in apiUrls) {
        try {
          final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLogAPI/kurt_idLog.php");
          final response = await http.post(
            uri,
            body: {
              'idNumber': idNumber,
              'deviceId': deviceId,
            },
          ).timeout(requestTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data["success"] == true) {
              return data["idNumber"] ?? idNumber;
            } else {
              throw Exception(data["message"] ?? "Unknown error occurred");
            }
          }
        } catch (e) {
          if (e is Exception && e.toString().contains("ID number does not exist")) {
            throw e;
          }
        }
      }
      if (attempt < maxRetries) {
        final delay = initialRetryDelay * (1 << (attempt - 1));
        await Future.delayed(delay);
      }
    }
    throw Exception("Both API URLs are unreachable after $maxRetries attempts");
  }

  Future<Map<String, dynamic>> fetchProfile(String idNumber) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      for (String apiUrl in apiUrls) {
        try {
          final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLogAPI/kurt_fetchProfile.php?idNumber=$idNumber");
          final response = await http.get(uri).timeout(requestTimeout);

          if (response.statusCode == 200) {
            return jsonDecode(response.body);
          }
        } catch (e) {
          print("Error accessing $apiUrl on attempt $attempt: $e");
        }
      }
      if (attempt < maxRetries) {
        final delay = initialRetryDelay * (1 << (attempt - 1));
        await Future.delayed(delay);
      }
    }
    throw Exception("Both API URLs are unreachable after $maxRetries attempts");
  }

  Future<String?> getLastIdNumber(String deviceId) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      for (String apiUrl in apiUrls) {
        try {
          final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLogAPI/kurt_getLastId.php?deviceId=$deviceId");
          final response = await http.get(uri).timeout(requestTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data["success"] == true) {
              return data["idNumber"];
            }
            return null;
          }
        } catch (e) {
          print("Error accessing $apiUrl on attempt $attempt: $e");
        }
      }
      if (attempt < maxRetries) {
        final delay = initialRetryDelay * (1 << (attempt - 1));
        await Future.delayed(delay);
      }
    }
    throw Exception("Both API URLs are unreachable after $maxRetries attempts");
  }

  Future<void> logout(String deviceId) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      for (String apiUrl in apiUrls) {
        try {
          final uri = Uri.parse("${apiUrl}V4/Others/Kurt/ArkLogAPI/kurt_logout.php");
          final response = await http.post(
            uri,
            body: {'deviceId': deviceId},
          ).timeout(requestTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data["success"] == true) {
              return;
            } else {
              throw Exception(data["message"]);
            }
          }
        } catch (e) {
          print("Error accessing $apiUrl on attempt $attempt: $e");
        }
      }
      if (attempt < maxRetries) {
        final delay = initialRetryDelay * (1 << (attempt - 1));
        await Future.delayed(delay);
      }
    }
    throw Exception("Both API URLs are unreachable after $maxRetries attempts");
  }
}