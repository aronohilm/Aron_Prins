import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ScanApiConfigPage extends StatefulWidget {
  const ScanApiConfigPage({super.key});

  @override
  State<ScanApiConfigPage> createState() => _ScanApiConfigPageState();
}

class _ScanApiConfigPageState extends State<ScanApiConfigPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  bool _isLoading = false;
  String _scanResult = '';

  @override
  void initState() {
    super.initState();
    _prefillTestValues();
  }

  Future<void> _prefillTestValues() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key');
    final merchantAccount = prefs.getString('merchant_account');
    if ((apiKey == null || apiKey.isEmpty) && (merchantAccount == null || merchantAccount.isEmpty)) {
      setState(() {
        _apiKeyController.text = 'AQEqhmfxL43JaxFCw0m/n3Q5qf3Ve59fDIZHTXfy5UT9AM9RlDqYku8lh1U2EMFdWw2+5HzctViMSCJMYAc=-iql6F+AYb1jkHn3zzDBcXZZvYzXFr9wd1iCR9y2JDU0=-i1i{=<;wFH*jLc94NQe';
        _merchantController.text = 'Straumur_POS_BJARNI_DEFAULT_TEST';
      });
    } else {
      setState(() {
        _apiKeyController.text = apiKey ?? '';
        _merchantController.text = merchantAccount ?? '';
      });
    }
  }

  Future<void> activateScanner() async {
    setState(() {
      _isLoading = true;
      _scanResult = '';
    });

    // Hardcoded values
    const apiKey = 'AQEqhmfxL43JaxFCw0m/n3Q5qf3Ve59fDIZHTXfy5UT9AM9RlDqYku8lh1U2EMFdWw2+5HzctViMSCJMYAc=-iql6F+AYb1jkHn3zzDBcXZZvYzXFr9wd1iCR9y2JDU0=-i1i{=<;wFH*jLc94NQe';
    const poiId = 'S1F2L-000158251517660';

    final sessionId = Random().nextInt(999999);
    final now = DateTime.now().toUtc();
    final saleId = 'ScanKey${now.millisecondsSinceEpoch % 1000000}';
    final serviceId = 'SID${now.millisecondsSinceEpoch % 1000000}';

    final scannerPayload = {
      "Session": {
        "Id": sessionId,
        "Type": "Once"
      },
      "Operation": [
        {
          "Type": "ScanBarcode",
          "TimeoutMs": 10000
        }
      ]
    };

    final base64Payload = base64Encode(utf8.encode(jsonEncode(scannerPayload)));

    final fullRequest = {
      "SaleToPOIRequest": {
        "MessageHeader": {
          "ProtocolVersion": "3.0",
          "MessageClass": "Service",
          "MessageCategory": "Admin",
          "MessageType": "Request",
          "ServiceID": serviceId,
          "SaleID": saleId,
          "POIID": poiId
        },
        "AdminRequest": {
          "ServiceIdentification": base64Payload
        }
      }
    };

    try {
      final response = await http.post(
        Uri.parse("https://terminal-api-test.adyen.com/sync"),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: jsonEncode(fullRequest),
      );

      final responseJson = jsonDecode(response.body);
      final additionalResponse = responseJson["SaleToPOIResponse"]?["AdminResponse"]?["Response"]?["AdditionalResponse"];

      if (additionalResponse != null) {
        final decoded = Uri.decodeComponent(additionalResponse);
        if (decoded.startsWith("additionalData=")) {
          final jsonPart = decoded.replaceFirst("additionalData=", "");
          final parsed = jsonDecode(jsonPart);
          final scannedData = parsed['Barcode']?['Data'];

          if (scannedData != null && scannedData is String) {
            String apiKey = '';
            String merchantAccount = '';

            // Try to parse as JSON first
            try {
              final parsed = jsonDecode(scannedData);
              apiKey = parsed['apiKey'] ?? '';
              merchantAccount = parsed['merchantAccount'] ?? '';
            } catch (_) {
              // If not JSON, try to parse as CSV
              final parts = scannedData.split(',');
              if (parts.length >= 2) {
                apiKey = parts[0].replaceAll('"', '').trim();
                merchantAccount = parts[1].replaceAll('"', '').trim();
              } else {
                apiKey = scannedData;
              }
            }

            setState(() {
              _apiKeyController.text = apiKey;
              _merchantController.text = merchantAccount;
              _scanResult = 'API Key scanned successfully';
            });
          } else {
            setState(() => _scanResult = 'No valid data scanned');
          }
        } else {
          setState(() => _scanResult = 'Unexpected format: $decoded');
        }
      } else {
        setState(() => _scanResult = 'No response received');
      }
    } catch (e) {
      setState(() => _scanResult = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan API Config"),
        backgroundColor: const Color(0xFF002244),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : activateScanner,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A3A6A),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("SCAN", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 20),
            Text(
              _scanResult,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(labelText: "API Key"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _merchantController,
              decoration: const InputDecoration(labelText: "Merchant Account"),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _saveConfig,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A3A6A),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          ),
          child: const Text('Save', style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
      ),
    );
  }

  Future<void> _saveConfig() async {
    final apiKey = _apiKeyController.text.trim();
    final merchantAccount = _merchantController.text.trim();

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', apiKey);
    await prefs.setString('merchant_account', merchantAccount);

    // Save to a text file
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/api_config.txt');
    final content = 'apiKey: $apiKey\nmerchantAccount: $merchantAccount';
    await file.writeAsString(content);

    setState(() {
      _scanResult = 'Saved to SharedPreferences and api_config.txt';
    });
  }
}
