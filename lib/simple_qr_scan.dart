import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanApiConfigPage extends StatefulWidget {
  const ScanApiConfigPage({super.key});

  @override
  State<ScanApiConfigPage> createState() => _ScanApiConfigPageState();
}

class _ScanApiConfigPageState extends State<ScanApiConfigPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final FocusNode _apiKeyFocusNode = FocusNode();
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
    setState(() {
      _apiKeyController.text = apiKey ?? '';
      _merchantController.text = merchantAccount ?? '';
    });
  }

  void _parseScannedJson() {
    final scanned = _apiKeyController.text.trim();
    try {
      int start = scanned.indexOf('{');
      int end = scanned.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        String jsonPart = scanned.substring(start, end + 1);
        final parsed = jsonDecode(jsonPart);
        setState(() {
          _apiKeyController.text = parsed['apiKey'] ?? '';
          _merchantController.text = parsed['merchantAccount'] ?? '';
          _scanResult = 'API Key and Merchant Account parsed!';
        });
      } else {
        setState(() => _scanResult = 'No valid JSON found in scanned data.');
      }
    } catch (e) {
      setState(() => _scanResult = 'Error parsing scanned data: $e');
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  FocusScope.of(context).requestFocus(_apiKeyFocusNode);
                  setState(() {
                    _scanResult = 'Ready to scan! Focus the Scan/Paste field and scan the QR code.';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A3A6A),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                ),
                child: const Text("Ready to Scan", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                _scanResult,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Scan or Paste JSON here",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _apiKeyController,
              focusNode: _apiKeyFocusNode,
              decoration: const InputDecoration(
                hintText: '{ "apiKey": "...", "merchantAccount": "..." }',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton(
                onPressed: _parseScannedJson,
                child: const Text('Parse'),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "API Key",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Merchant Account",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _merchantController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            /*const SizedBox(height: 10),
            const Text(
              "Terminal POIID (last 3 digits)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _poiIdSuffixController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 3,
            ),*/
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
    setState(() {
      _scanResult = 'Saved!';
    });
  }
}
