import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TerminalSetupPage extends StatefulWidget {
  const TerminalSetupPage({super.key});

  @override
  State<TerminalSetupPage> createState() => _TerminalSetupPageState();
}

class _TerminalSetupPageState extends State<TerminalSetupPage> {
  final TextEditingController _scanController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _endpointController = TextEditingController();
  List<String> _terminals = [];
  String? _selectedTerminal;
  bool _isLoading = false;
  String? _errorMessage;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _endpointController.text = prefs.getString('endpoint') ?? 'https://terminal-api-live.adyen.com/connectedTerminals';
        _apiKeyController.text = prefs.getString('api_key') ?? '';
        _merchantController.text = prefs.getString('merchant_account') ?? '';
        _selectedTerminal = prefs.getString('selected_terminal');
      });
      if (_endpointController.text.isNotEmpty && _apiKeyController.text.isNotEmpty && _merchantController.text.isNotEmpty) {
        await _fetchTerminals();
      }
    } catch (e) {
      _showStatus('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _parseScannedJson() {
    final scanned = _scanController.text.trim();
    try {
      int start = scanned.indexOf('{');
      int end = scanned.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        String jsonPart = scanned.substring(start, end + 1);
        final parsed = jsonDecode(jsonPart);
        setState(() {
          _apiKeyController.text = parsed['apiKey'] ?? '';
          _merchantController.text = parsed['merchantAccount'] ?? '';
          _status = 'API Key and Merchant Account parsed!';
        });
      } else {
        setState(() => _status = 'No valid JSON found in scanned data.');
      }
    } catch (e) {
      setState(() => _status = 'Error parsing scanned data: $e');
    }
  }

  Future<void> _fetchTerminals() async {
    if (_merchantController.text.trim().isEmpty) {
      _showStatus("Please enter a merchant account.");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final apiKey = _apiKeyController.text.trim();
      final merchantAccount = _merchantController.text.trim();
      final response = await http.post(
        Uri.parse(_endpointController.text.trim()),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: jsonEncode({
          "merchantAccount": merchantAccount,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['uniqueTerminalIds'] != null && data['uniqueTerminalIds'] is List) {
          final List<String> terminals = List<String>.from(data['uniqueTerminalIds']);
          setState(() {
            _terminals = terminals;
            if (_terminals.isNotEmpty && _selectedTerminal == null) {
              _selectedTerminal = _terminals[0];
            } else if (_selectedTerminal != null && !_terminals.contains(_selectedTerminal)) {
              _selectedTerminal = _terminals.isNotEmpty ? _terminals[0] : null;
            }
          });
          _showStatus('Found ${_terminals.length} terminals');
        } else {
          setState(() {
            _errorMessage = 'No terminal IDs found in the response';
            _terminals = [];
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Error: ${response.statusCode} - ${response.body}';
          _terminals = [];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
        _terminals = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('endpoint', _endpointController.text.trim());
      await prefs.setString('api_key', _apiKeyController.text.trim());
      await prefs.setString('merchant_account', _merchantController.text.trim());
      if (_selectedTerminal != null) {
        await prefs.setString('selected_terminal', _selectedTerminal!);
      }
      _showStatus('Settings saved successfully');
    } catch (e) {
      _showStatus('Error saving settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showStatus(String message) {
    setState(() {
      _status = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F5FA),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Scan input
                      TextField(
                        controller: _scanController,
                        decoration: const InputDecoration(
                          labelText: 'Scan or Paste JSON here',
                          hintText: '{ "apiKey": "...", "merchantAccount": "..." }',
                          border: OutlineInputBorder(),
                        ),
                        minLines: 1,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _parseScannedJson,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A3A6A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Parse', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _apiKeyController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'API Key',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _merchantController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Merchant Account',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _endpointController,
                        decoration: const InputDecoration(
                          labelText: 'Endpoint',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _fetchTerminals,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Fetch Terminals'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0A3A6A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: const BorderSide(color: Color(0xFF0A3A6A)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      if (_terminals.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedTerminal,
                          items: _terminals.map((terminal) => DropdownMenuItem(
                            value: terminal,
                            child: Text(terminal),
                          )).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTerminal = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'POS Terminal',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A3A6A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Save', style: TextStyle(fontSize: 16)),
                      ),
                      if (_status.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            _status,
                            style: TextStyle(color: theme.primaryColorDark),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 