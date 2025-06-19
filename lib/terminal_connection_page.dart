// TerminalConnectionPage with merchantAccount input wired into _fetchTerminals
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

class TerminalConnectionPage extends StatefulWidget {
  const TerminalConnectionPage({super.key});

  @override
  State<TerminalConnectionPage> createState() => _TerminalConnectionPageState();
}

class _TerminalConnectionPageState extends State<TerminalConnectionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _merchantAccountController = TextEditingController();

  List<String> _terminals = [];
  String? _selectedTerminal;
  bool _isLoading = false;
  String? _errorMessage;

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
        _merchantAccountController.text = prefs.getString('merchant_account') ?? '';
        _selectedTerminal = prefs.getString('selected_terminal');
      });
      if (_endpointController.text.isNotEmpty && _apiKeyController.text.isNotEmpty && _merchantAccountController.text.isNotEmpty) {
        await _fetchTerminals();
      }
    } catch (e) {
      _showToast('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTerminals() async {
    if (_merchantAccountController.text.trim().isEmpty) {
      _showToast("Please enter a merchant account.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('api_key');
      final merchantAccount = _merchantAccountController.text.trim();
      final response = await http.post(
        Uri.parse('https://terminal-api-live.adyen.com/connectedTerminals'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey ?? '',
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

          _showToast('Found ${_terminals.length} terminals');
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
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isLoading = true);
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('endpoint', _endpointController.text.trim());
    await prefs.setString('api_key', _apiKeyController.text.trim());
    await prefs.setString('merchant_account', _merchantAccountController.text.trim());
    if (_selectedTerminal != null) {
      await prefs.setString('selected_terminal', _selectedTerminal!);
    }
    _showToast('Settings saved successfully');
    if (!mounted) return;
    Navigator.pop(context);
  } catch (e) {
    _showToast('Error saving settings: \$e');
  } finally {
    setState(() => _isLoading = false);
  }
}

void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Terminal Connection'),
        backgroundColor: Colors.blue[800],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'API Connection Settings',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _merchantAccountController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Merchant Account',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _apiKeyController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'API Key',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _fetchTerminals,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Fetch Terminals'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_terminals.isNotEmpty)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Terminal',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
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
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'POS Terminal',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () async {
                    setState(() => _isLoading = true);
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      if (_selectedTerminal != null) {
                        await prefs.setString('selected_terminal', _selectedTerminal!);
                        _showToast('Terminal saved successfully');
                        if (!mounted) return;
                        Navigator.pop(context);
                      } else {
                        _showToast('Please select a terminal');
                      }
                    } catch (e) {
                      _showToast('Error saving terminal: $e');
                    } finally {
                      setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
