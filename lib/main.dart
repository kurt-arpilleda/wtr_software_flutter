import 'package:flutter/material.dart';
import 'webview.dart';
import 'phorjapan.dart';
import 'japanFolder/webviewJP.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? phOrJp = prefs.getString('phorjp');

  String initialRoute = '/phorjapan'; // Default route

  if (phOrJp == "ph") {
    initialRoute = '/webView';
  } else if (phOrJp == "jp") {
    initialRoute = '/webViewJP';
  }

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  MyApp({required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WTR Software',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: initialRoute,
      routes: {
        '/phorjapan': (context) => PhOrJpScreen(),
        '/webView': (context) => SoftwareWebViewScreen(linkID: 5),
        '/webViewJP': (context) => SoftwareWebViewScreenJP(linkID: 5),
      },
    );
  }
}