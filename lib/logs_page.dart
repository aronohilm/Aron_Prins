import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});
  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  List<Map<String, dynamic>> _parsedLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });
    
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/adyen_log.txt');
    if (await file.exists()) {
      final lines = await file.readAsLines();
      final parsedLogs = <Map<String, dynamic>>[];
      
      for (final line in lines) {
        try {
          final logEntry = jsonDecode(line) as Map<String, dynamic>;
          
          // Extract response status
          String status = 'Unknown';
          String responseCode = 'N/A';
          
          if (logEntry['response'] != null && 
              logEntry['response']['SaleToPOIResponse'] != null &&
              logEntry['response']['SaleToPOIResponse']['PaymentResponse'] != null &&
              logEntry['response']['SaleToPOIResponse']['PaymentResponse']['Response'] != null) {
            
            final response = logEntry['response']['SaleToPOIResponse']['PaymentResponse']['Response'];
            responseCode = response['Result'] ?? 'N/A';
            
            if (responseCode == 'Success') {
              status = 'Approved';
            } else {
              status = 'Declined';
            }
          }
          
          parsedLogs.add({
            'timestamp': logEntry['timestamp'] ?? '',
            'amount': logEntry['amount'] ?? 0.0,
            'status': status,
            'responseCode': responseCode,
          });
        } catch (e) {
          // Skip invalid entries
          print('Error parsing log entry: $e');
        }
      }
      
      setState(() {
        _parsedLogs = parsedLogs.reversed.toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
    } catch (e) {
      return timestamp;
    }
  }

  String _formatAmount(dynamic amount) {
    if (amount is num) {
      return '€${amount.toStringAsFixed(2)}';
    }
    return '€0.00';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Logs'),
        backgroundColor: Colors.blue[800],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _parsedLogs.isEmpty
              ? const Center(child: Text('No transaction logs found'))
              : ListView.separated(
                  itemCount: _parsedLogs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final log = _parsedLogs[index];
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Time: ${_formatTimestamp(log['timestamp'])}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text('Amount: ${_formatAmount(log['amount'])}'),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('Status: '),
                              Text(
                                log['status'],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: log['status'] == 'Approved'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Response code: ${log['responseCode']}'),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}