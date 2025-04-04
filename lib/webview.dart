import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'auto_update.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:unique_identifier/unique_identifier.dart';

class SoftwareWebViewScreen extends StatefulWidget {
  final int linkID;

  SoftwareWebViewScreen({required this.linkID});

  @override
  _SoftwareWebViewScreenState createState() => _SoftwareWebViewScreenState();
}

class _SoftwareWebViewScreenState extends State<SoftwareWebViewScreen> {
  late final WebViewController _controller;
  final ApiService apiService = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _webUrl;
  final TextEditingController _idController = TextEditingController();
  String? _profilePictureUrl;
  String? _firstName;
  String? _surName;
  bool _isLoading = true;
  int? _currentLanguageFlag;
  double _progress = 0;
  String? _phOrJp;
  bool _isLoggedIn = false;
  String? _deviceId;
  String? _currentIdNumber;
  bool _isProfileLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _progress = 0;
            });
          },
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _progress = 1;
            });
          },
        ),
      );

    _initializeDeviceId();
    _fetchAndLoadUrl();
    _loadPhOrJp();
    _loadCurrentLanguageFlag();
    AutoUpdate.checkForUpdate(context);
  }

  Future<void> _initializeDeviceId() async {
    try {
      _deviceId = await UniqueIdentifier.serial;
      if (_deviceId != null) {
        _loadLastIdNumber();
      }
    } catch (e) {
      print("Error getting device ID: $e");
    }
  }

  Future<void> _loadLastIdNumber() async {
    try {
      String? lastIdNumber = await apiService.getLastIdNumber(_deviceId!);
      if (lastIdNumber != null && lastIdNumber.isNotEmpty) {
        _idController.text = lastIdNumber;
        await _fetchProfile(lastIdNumber);
        setState(() {
          _isLoggedIn = true;
          _currentIdNumber = lastIdNumber;
        });
      }
    } catch (e) {
      print('Error loading last ID number: $e');
    }
  }

  Future<void> _loadPhOrJp() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _phOrJp = prefs.getString('phorjp');
    });
  }

  Future<void> _fetchProfile(String idNumber) async {
    setState(() {
      _isProfileLoading = true;
    });

    try {
      final profileData = await apiService.fetchProfile(idNumber);
      if (profileData["success"] == true) {
        String profilePictureFileName = profileData["picture"];

        String primaryUrl = "${ApiService.apiUrls[0]}V4/11-A%20Employee%20List%20V2/profilepictures/$profilePictureFileName";
        bool isPrimaryUrlValid = await _isImageAvailable(primaryUrl);

        String fallbackUrl = "${ApiService.apiUrls[1]}V4/11-A%20Employee%20List%20V2/profilepictures/$profilePictureFileName";
        bool isFallbackUrlValid = await _isImageAvailable(fallbackUrl);

        setState(() {
          _firstName = profileData["firstName"];
          _surName = profileData["surName"];
          _profilePictureUrl = isPrimaryUrlValid ? primaryUrl : isFallbackUrlValid ? fallbackUrl : null;
          _currentIdNumber = idNumber;
          _isLoggedIn = true;
        });
      }
    } catch (e) {
      print("Error fetching profile: $e");
    } finally {
      setState(() {
        _isProfileLoading = false;
      });
    }
  }

  Future<bool> _isImageAvailable(String url) async {
    try {
      final response = await http.head(Uri.parse(url)).timeout(Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveIdNumber() async {
    String newIdNumber = _idController.text.trim();

    if (newIdNumber.isEmpty) {
      Fluttertoast.showToast(
        msg: "ID Number cannot be empty!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    if (newIdNumber == _currentIdNumber) {
      Fluttertoast.showToast(
        msg: "Edit the ID number first!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final actualIdNumber = await apiService.insertIdNumber(
        newIdNumber,
        deviceId: _deviceId!,
      );

      await _fetchProfile(actualIdNumber);

      Fluttertoast.showToast(
        msg: "ID Number saved successfully!",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      // Reload the webview with new ID
      _fetchAndLoadUrl();
    } catch (e) {
      Fluttertoast.showToast(
        msg: e.toString().replaceFirst("Exception: ", ""),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      setState(() {
        _idController.text = _currentIdNumber ?? '';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _logout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Logout"),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Logout"),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      try {
        await apiService.logout(_deviceId!);
        setState(() {
          _isLoggedIn = false;
          _firstName = null;
          _surName = null;
          _profilePictureUrl = null;
          _currentIdNumber = null;
          _idController.clear();
        });
        // Reload the webview to show the "Please provide ID Number" message
        _fetchAndLoadUrl();

        Fluttertoast.showToast(
          msg: "Logged out successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } catch (e) {
        Fluttertoast.showToast(
          msg: "Error logging out: ${e.toString()}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    }
  }

  Future<void> _fetchAndLoadUrl() async {
    try {
      String url = await apiService.fetchSoftwareLink(widget.linkID);
      if (mounted) {
        setState(() {
          _webUrl = url;
        });
        _controller.loadRequest(Uri.parse(url));
      }
    } catch (e) {
      debugPrint("Error fetching link: $e");
      Fluttertoast.showToast(
        msg: "Error loading content: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> _loadCurrentLanguageFlag() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLanguageFlag = prefs.getInt('languageFlag');
    });
  }

  Future<void> _updateLanguageFlag(int flag) async {
    if (_currentIdNumber == null) return;

    setState(() {
      _currentLanguageFlag = flag;
    });

    try {
      await apiService.updateLanguageFlag(_currentIdNumber!, flag);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('languageFlag', flag);

      String? currentUrl = await _controller.currentUrl();
      if (currentUrl != null) {
        _controller.loadRequest(Uri.parse(currentUrl));
      } else {
        _controller.reload();
      }
    } catch (e) {
      print("Error updating language flag: $e");
    }
  }

  Future<void> _updatePhOrJp(String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('phorjp', value);
    setState(() {
      _phOrJp = value;
    });

    if (value == "ph") {
      Navigator.pushReplacementNamed(context, '/webView');
    } else if (value == "jp") {
      Navigator.pushReplacementNamed(context, '/webViewJP');
    }
  }

  Future<void> _showInputMethodPicker() async {
    try {
      if (Platform.isAndroid) {
        const MethodChannel channel = MethodChannel('input_method_channel');
        await channel.invokeMethod('showInputMethodPicker');
      } else {
        Fluttertoast.showToast(
          msg: "Keyboard selection is only available on Android",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      debugPrint("Error showing input method picker: $e");
    }
  }

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    } else {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight - 20),
          child: SafeArea(
            child: AppBar(
              backgroundColor: Color(0xFF2053B3),
              centerTitle: true,
              toolbarHeight: kToolbarHeight - 20,
              leading: Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: IconButton(
                  icon: Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: IconButton(
                    icon: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      alignment: Alignment.center,
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onPressed: () {
                      if (Platform.isIOS) {
                        exit(0);
                      } else {
                        SystemNavigator.pop();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        drawer: SizedBox(
          width: MediaQuery.of(context).size.width * 0.70,
          child: Drawer(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            color: Color(0xFF2053B3),
                            padding: EdgeInsets.only(top: 20, bottom: 20),
                            child: Column(
                              children: [
                                Container(
                                  width: 130,
                                  height: 130,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blue[50],
                                    border: Border.all(
                                      color: Color(0xFF2053B3),
                                      width: 3,
                                    ),
                                  ),
                                  child: _isLoggedIn && _profilePictureUrl != null
                                      ? ClipOval(
                                    child: Image.network(
                                      _profilePictureUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Icon(
                                        Icons.person,
                                        size: 70,
                                        color: Color(0xFF2053B3),
                                      ),
                                    ),
                                  )
                                      : Icon(
                                    Icons.person,
                                    size: 70,
                                    color: Color(0xFF2053B3),
                                  ),
                                ),
                                if (_isLoggedIn) ...[
                                  SizedBox(height: 10),
                                  Text(
                                    _firstName != null && _surName != null
                                        ? "$_firstName $_surName"
                                        : "User Profile",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_currentIdNumber != null) ...[
                                    SizedBox(height: 5),
                                    Text(
                                      "ID: $_currentIdNumber",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!_isLoggedIn) ...[
                                  Text(
                                    "ID Number",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  TextField(
                                    controller: _idController,
                                    decoration: InputDecoration(
                                      hintText: "Enter ID Number",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                ],
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSaving
                                        ? null
                                        : _isLoggedIn
                                        ? _logout
                                        : () async {
                                      setState(() {
                                        _isSaving = true;
                                      });
                                      try {
                                        final actualIdNumber = await apiService.insertIdNumber(
                                          _idController.text.trim(),
                                          deviceId: _deviceId!,
                                        );
                                        await _fetchProfile(actualIdNumber);
                                        Fluttertoast.showToast(
                                          msg: "Logged in successfully!",
                                          toastLength: Toast.LENGTH_SHORT,
                                          gravity: ToastGravity.BOTTOM,
                                          backgroundColor: Colors.green,
                                          textColor: Colors.white,
                                        );
                                        _fetchAndLoadUrl();
                                      } catch (e) {
                                        Fluttertoast.showToast(
                                          msg: e.toString().replaceFirst("Exception: ", ""),
                                          toastLength: Toast.LENGTH_SHORT,
                                          gravity: ToastGravity.BOTTOM,
                                          backgroundColor: Colors.red,
                                          textColor: Colors.white,
                                        );
                                      } finally {
                                        setState(() {
                                          _isSaving = false;
                                        });
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isLoggedIn ? Colors.red : Color(0xFF2053B3),
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: _isSaving
                                        ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                        : Text(
                                      _isLoggedIn ? "LOGOUT" : "LOGIN",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                Text(
                                  "Language",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 25),
                                GestureDetector(
                                  onTap: () => _updateLanguageFlag(1),
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        'assets/images/americanFlag.gif',
                                        width: 40,
                                        height: 40,
                                      ),
                                      if (_currentLanguageFlag == 1)
                                        Container(
                                          height: 2,
                                          width: 40,
                                          color: Colors.blue,
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 30),
                                GestureDetector(
                                  onTap: () => _updateLanguageFlag(2),
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        'assets/images/japaneseFlag.gif',
                                        width: 40,
                                        height: 40,
                                      ),
                                      if (_currentLanguageFlag == 2)
                                        Container(
                                          height: 2,
                                          width: 40,
                                          color: Colors.blue,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                Text(
                                  "Keyboard",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Spacer(),
                                IconButton(
                                  icon: Icon(Icons.keyboard, size: 28),
                                  onPressed: _showInputMethodPicker,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Text(
                          "Country",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 25),
                        GestureDetector(
                          onTap: () => _updatePhOrJp("ph"),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/philippines.png',
                                width: 40,
                                height: 40,
                              ),
                              if (_phOrJp == "ph")
                                Container(
                                  height: 2,
                                  width: 40,
                                  color: Colors.blue,
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: 30),
                        GestureDetector(
                          onTap: () => _updatePhOrJp("jp"),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/japan.png',
                                width: 40,
                                height: 40,
                              ),
                              if (_phOrJp == "jp")
                                Container(
                                  height: 2,
                                  width: 40,
                                  color: Colors.blue,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              if (_webUrl != null)
                WebViewWidget(controller: _controller),
              if (_isLoading)
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
            ],
          ),
        ),
      ),
    );
  }
}