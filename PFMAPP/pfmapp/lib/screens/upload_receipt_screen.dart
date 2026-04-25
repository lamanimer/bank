import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/session.dart';

class UploadReceiptScreen extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> tx) onTransactionSaved;

  const UploadReceiptScreen({
    super.key,
    required this.onTransactionSaved,
  });

  @override
  State<UploadReceiptScreen> createState() => _UploadReceiptScreenState();
}

class _UploadReceiptScreenState extends State<UploadReceiptScreen> {
  Uint8List? _imageBytes;
  String? _fileName;
  bool _loading = false;
  bool _saving = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);

      if (file == null) return;

      final bytes = await file.readAsBytes();

      setState(() {
        _imageBytes = bytes;
        _fileName = file.name;
        _result = null;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to pick image: $e";
      });
    }
  }

  Future<void> _extractReceipt() async {
    if (_imageBytes == null || _fileName == null) {
      setState(() {
        _error = "Please choose a receipt image first.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final baseUrl = kIsWeb ? "http://127.0.0.1:8001" : "http://10.0.2.2:8001";
      final uri = Uri.parse("$baseUrl/receipts/extract");
      final request = http.MultipartRequest("POST", uri);

      request.files.add(
        http.MultipartFile.fromBytes(
          "file",
          _imageBytes!,
          filename: _fileName!,
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        throw Exception(response.body);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      setState(() {
        _result = data;
      });
    } catch (e) {
      setState(() {
        _error = "Extraction failed: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveTransaction() async {
    if (_result == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = await Session.loadUser();
      final userIdStr = Session.getUserId(user);

      if (userIdStr == null || userIdStr.isEmpty) {
        throw Exception("User not found. Please log in again.");
      }

      final merchant = (_result!["merchant"] ?? "").toString().trim();
      final note = (_result!["note"] ?? "").toString().trim();
      final categoryName =
          (_result!["category_name"] ?? "Other").toString().trim();
      final txnDate = (_result!["txn_date"] ??
              DateTime.now().toIso8601String().split('T').first)
          .toString()
          .trim();

      final rawAmount = _result!["amount"];
      final parsedAmount = rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse(rawAmount.toString()) ?? 0.0;

      if (parsedAmount <= 0) {
        throw Exception("Invalid receipt amount.");
      }

      final description = merchant.isNotEmpty
          ? merchant
          : (note.isNotEmpty ? note : "Receipt transaction");

      final selectedBankId = await Session.getSelectedBankId();

      final localTx = <String, dynamic>{
        "amount": -parsedAmount,
        "date": txnDate,
        "timestamp": txnDate,
        "description": description,
        "merchant_name": merchant,
        "note": note,
        "ai_category": categoryName,
        "category": categoryName,
        "type": "debit",
        "txn_type": "EXPENSE",
        "source": "receipt_ai",
        "bank_id": selectedBankId,
      };

      await Session.addManualTransaction(
        userId: userIdStr,
        tx: localTx,
      );

      await widget.onTransactionSaved(localTx);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Transaction saved")),
      );
    } catch (e) {
      setState(() {
        _error = "Save failed: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _buildResultCard() {
    if (_result == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Extracted Receipt Data",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text("Merchant: ${_result!["merchant"] ?? "-"}"),
            Text("Amount: ${_result!["amount"] ?? "-"}"),
            Text("Date: ${_result!["txn_date"] ?? "-"}"),
            Text("Category: ${_result!["category_name"] ?? "-"}"),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveTransaction,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Save"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const Text(
            "Upload Receipt",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _imageBytes!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            )
          else
            Container(
              height: 180,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text("No image selected"),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading || _saving ? null : _pickImage,
            child: const Text("Choose Image"),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading || _saving ? null : _extractReceipt,
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Extract Receipt Data"),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          _buildResultCard(),
        ],
      ),
    );
  }
}