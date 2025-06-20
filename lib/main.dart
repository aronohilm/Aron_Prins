import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'terminal_connection_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'simple_qr_scan.dart';
import 'terminal_setup_page.dart';
// Add these imports for the page classes used in the drawer

void main() => runApp(const PaymentApp());

class PaymentApp extends StatelessWidget {
  const PaymentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Payment',
      debugShowCheckedModeBanner: false,
      home: const PaymentScreen(), // Changed from LoginPage to PaymentScreen
    );
  }
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _amount = '';
  String _transactionStatus = ''; 
  bool _isLoading = false;
  int _saleCounter = 1;
  late Timer _timer;
  late String _currentTime;
  String _response = ''; // Add this line to define the _response variable
  
  String? _apiKey;
  final String _url = "https://terminal-api-live.adyen.com/sync";
  String? _poiId;
  String? _selectedTerminal;

Future<void> _loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _apiKey = prefs.getString('api_key');
    _poiId = prefs.getString('selected_terminal');
  });
}


@override
void initState() {
  super.initState();
  _loadCounter();
  _currentTime = _getTimeString();
  _timer = Timer.periodic(const Duration(seconds: 1), (_) {
    setState(() {
      _currentTime = _getTimeString();
    });
  });
  _loadSettings();  // 👈 Load API key, URL, and terminal
}


  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getTimeString() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _loadCounter() async {
    final file = await _getCounterFile();
    if (await file.exists()) {
      final content = await file.readAsString();
      setState(() => _saleCounter = int.tryParse(content.trim()) ?? 1);
    }
  }

  Future<void> _incrementCounter() async {
    final file = await _getCounterFile();
    _saleCounter++;
    await file.writeAsString(_saleCounter.toString());
  }

  Future<File> _getCounterFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/saleid_counter.txt');
  }

  Future<File> _getLogFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/adyen_log.txt');
  }

  void _appendDigit(String digit) {
    setState(() {
      // If the digit is "000", add three zeros
      if (digit == "000") {
        _amount += "000";
      } else {
        _amount += digit;
      }
      _transactionStatus = ''; // Clear status when entering a new amount
    });
  }

  void _backspace() {
    if (_amount.isNotEmpty) {
      setState(() => _amount = _amount.substring(0, _amount.length - 1));
    }
  }

  String _formatAmount(String amount) {
    if (amount.isEmpty) return '';
    final parsed = int.tryParse(amount);
    if (parsed == null) return amount;
    return parsed.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
  }

  Future<void> _sendPayment() async {
    if (_amount.isEmpty) {
      _showToast('Sláðu inn upphæð');
      return;
    }

    double? amount;
    try {
      amount = double.parse(_amount);
      if (amount <= 0) {
        _showToast('Upphæð verður að vera stærri en 0');
        return;
      }
    } catch (_) {
      _showToast('Ógild upphæð');
      return;
    }

    setState(() {
      _isLoading = true;
      _response = 'Sending...';
    });

    // Load saved settings
    final prefs = await SharedPreferences.getInstance();
    final endpoint = "https://terminal-api-live.adyen.com/sync";
    final apiKey = prefs.getString('api_key') ?? _apiKey;
    final poiId = prefs.getString('selected_terminal') ?? _poiId;
    
    final now = DateTime.now().toUtc();
    final saleId = 'FlutterTest${_saleCounter.toString().padLeft(3, '0')}';
    final serviceId = 'SID${now.millisecondsSinceEpoch % 1000000}';
    final transactionId = 'TX${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final timestamp = now.toIso8601String() + 'Z';

    final merchantAccount = prefs.getString('merchant_account');
    if (merchantAccount == null || merchantAccount.isEmpty) {
        // Show error, prompt user, or block further actions
        // e.g. showDialog(...), return, etc. 
        _showToast('Please configure terminal connection first.');
        return;
    }

    final payload = {
      "SaleToPOIRequest": {
        "MessageHeader": {
          "ProtocolVersion": "3.0",
          "MessageClass": "Service",
          "MessageCategory": "Payment",
          "MessageType": "Request",
          "SaleID": saleId,
          "ServiceID": serviceId,
          "POIID": poiId  // Changed from _poiId to poiId to use the selected terminal
        },
        "PaymentRequest": {
          "SaleData": {
            "SaleTransactionID": {
              "TransactionID": transactionId,
              "TimeStamp": timestamp
            },
            
          },
          "PaymentTransaction": {
            "AmountsReq": {
              "Currency": "EUR",
              "RequestedAmount": double.parse(amount.toStringAsFixed(2))
            }
          }
        }
      }
    };


// Remove or modify these lines in the _sendPayment method
if (apiKey == null || endpoint == null || poiId == null) {
  _showToast("Please configure terminal connection first.");
  return;
}

// Remove this check entirely
// if (_apiKey == null || _poiId == null) {
//   _showToast("Please configure terminal connection first.");
//   return;
// }

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: jsonEncode(payload),
      );
      print('PAYLOAD: ' + jsonEncode(payload));
      print('RESPONSE BODY: ' + response.body);

      if (response.statusCode != 200) {
        setState(() {
          _response = 'Error: ${response.statusCode}\n${response.body}';
          _isLoading = false;
          _amount = ''; // Clear the amount field on error
          _transactionStatus = 'Declined'; // Set status to declined on HTTP error
        });
        _showToast('Payment failed: ${response.statusCode}');
        return;
      }

      final responseJson = jsonDecode(response.body);
      
      // Determine transaction status
      String transactionStatus = 'Unknown';
      if (responseJson['SaleToPOIResponse'] != null && 
          responseJson['SaleToPOIResponse']['PaymentResponse'] != null &&
          responseJson['SaleToPOIResponse']['PaymentResponse']['Response'] != null) {
        
        final responseResult = responseJson['SaleToPOIResponse']['PaymentResponse']['Response']['Result'];
        transactionStatus = responseResult == 'Success' ? 'Approved' : 'Declined';
      }
      
      final logEntry = {
        'timestamp': now.toIso8601String(),
        'sale_id': saleId,
        'amount': amount,
        'status': response.statusCode,
        'response': responseJson,
      };

      final logFile = await _getLogFile();
      await logFile.writeAsString('${jsonEncode(logEntry)}\n', mode: FileMode.append);

      setState(() {
        _response = const JsonEncoder.withIndent('  ').convert(responseJson);
        _isLoading = false;
        _amount = ''; // Clear the amount field after successful response
        _transactionStatus = transactionStatus; // Set the transaction status
      });

      await _incrementCounter();
      _showToast('Sent to POS');
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _isLoading = false;
        _amount = ''; // Clear the amount field on exception
        _transactionStatus = 'Declined'; // Set status to declined on exception
      });
      _showToast('Network error: $e');
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFFE6EBEF), // Updated background color
      endDrawer: Drawer(
        child: Column(  // Changed from ListView to Column to allow for bottom positioning
          children: [
            Expanded(  // This will contain the scrollable list of menu items
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(
                      color: Color(0xFF002B5B),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/Straumur_Secondary_Neon.png',
                        fit: BoxFit.contain,
                        height: 50,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading image: $error');
                          return const Text(
                            'straumur',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                            ),
                          );
                        },
                      ),
                    ),
                  ), 
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.point_of_sale),
                    title: const Text('Tenging við Prins'),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer first
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TerminalConnectionPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.qr_code_scanner),
                    title: const Text('Simple QR Scan'),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer first
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ScanApiConfigPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.phone_iphone),
                    title: const Text('Samabla'),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer first
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TerminalSetupPage()),
                      );
                    },
                  ),

                ],
              ),
            ),
            // Exit button at the bottom of the drawer
            Container(
              width: double.infinity,
              color: const Color(0xFFE74C3C),  // Red background
              child: ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.white),
                title: const Text('LOKA APPI', 
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  )
                ),
                onTap: () {
                  Navigator.pop(context); // Close the drawer first
                  // Show confirmation dialog
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Loka Appi'),
                        content: const Text('Ertu viss um að þú viljir loka appinu?'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close the dialog
                            },
                            child: const Text('Hætta við'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close the dialog
                              // Exit the app
                              exit(0);
                            },
                            child: const Text('Loka', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header - fixed at top
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 250,
                    child: Image.asset(
                      'assets/images/LOGO.png',
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Builder(
                    builder: (context) => Container(
                      margin: const EdgeInsets.only(top: 20),
                      child: IconButton(
                        icon: Image.asset(
                          'assets/images/Sidebar.png',
                          height: 50,
                          width: 50,
                        ),
                        onPressed: () {
                          Scaffold.of(context).openEndDrawer();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8), // Small gap between header and input
            
            // Flexible content area that will adjust based on screen size
            Expanded(
              child: Column(
                children: [
                  // Input field - takes a percentage of available space
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenSize.width * 0.04,
                      vertical: 0, // No extra vertical padding
                    ),
                    child: Container(
                      height: screenSize.height * 0.10, // Slightly smaller height
                      decoration: BoxDecoration(
                        color: const Color(0xFFD6E2EE),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _amount.isEmpty ? '' : _formatAmount(_amount),
                        style: TextStyle(
                          fontSize: screenSize.width * 0.11, // Large font
                          color: const Color(0xFF002244),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  
                  // Status message
                  SizedBox(
                    height: screenSize.height * 0.025, // Reduce status message height
                    child: _transactionStatus.isNotEmpty
                      ? Text(
                          _transactionStatus,
                          style: TextStyle(
                            fontSize: screenSize.width * 0.06, // Responsive font size
                            fontWeight: FontWeight.bold,
                            color: _transactionStatus == 'Approved' ? Colors.green : Colors.red,
                          ),
                        )
                      : const SizedBox(), // Empty space if no status
                  ),
                  
                  // Keypad - takes most of the remaining space
                  Expanded(
                    flex: 5, // Give keypad more space
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenSize.width * 0.03, // Responsive padding
                        vertical: screenSize.height * 0.002, // Reduce vertical padding
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Evenly space the rows
                        children: [
                          for (var row in [
                            ['1', '2', '3'],
                            ['4', '5', '6'],
                            ['7', '8', '9'],
                            ['000', '0', '<']
                          ])
                            Expanded(
                              child: Row(
                                children: row.map((label) {
                                  if (label == '<') {
                                    return _buildKeypadButton(label, isBackspace: true, onTap: _backspace);
                                  } else {
                                    return _buildKeypadButton(label, onTap: () {
                                      _appendDigit(label);
                                    });
                                  }
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Send button - fixed at bottom
                  Padding(
                    padding: EdgeInsets.all(screenSize.width * 0.03), // Responsive padding
                    child: SizedBox(
                      width: double.infinity,
                      height: screenSize.height * 0.12, // Responsive height
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF002244),
                          foregroundColor: const Color(0xFFDAFDA3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.15),
                          padding: const EdgeInsets.symmetric(vertical: 18),

                        ),
                        onPressed: _isLoading ? null : _sendPayment,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text(
                                "Senda í posa",
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Update the keypad button to be responsive
  Widget _buildKeypadButton(String label, {VoidCallback? onTap, bool isBackspace = false}) {
    Color buttonColor = Colors.transparent;
    Widget child;
    if (isBackspace) {
      // Use delete_hidden if _amount is empty, else delete visable
      child = Image.asset(
        _amount.isEmpty
            ? 'assets/images/delete_hidden.png'
            : 'assets/images/delete_visible.png',
        height: 48,
        width: 48,
      );
    } else {
      child = Text(
        label,
        style: const TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w600,
          color: Color(0xFF002244),
        ),
      );
    }
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.transparent),
            ),
            padding: EdgeInsets.zero,
          ),
          onPressed: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}
