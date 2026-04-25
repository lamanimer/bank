import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../services/lean_launcher.dart';
import '../services/lean_events.dart';
import '../services/lean_api.dart';
import '../models/goal.dart';
import '../services/uuid.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'upload_receipt_screen.dart';
import 'goals_section.dart';

// Web-only JS bridge (safe because we will call it only when kIsWeb == true)

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<void> _showReceiptUploadDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: UploadReceiptScreen(
            onTransactionSaved: (tx) async {
              if (!mounted) return;

              setState(() {
                _recentTx.insert(0, tx);
                if (_recentTx.length > 5) {
                  _recentTx = _recentTx.take(5).toList();
                }
              });

              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  Map<String, dynamic>? _user;
  bool _loading = true;

  num _balance = 0;
  num _income = 0;
  num _expenses = 0;
  StreamSubscription? _leanEventsSub;
  List<dynamic> _recentTx = [];
  String _cardTitle = "";

  String? _selectedBankId;
  List<dynamic> _banks = [];
  bool _connectingBank = false;
  String? _pendingBankKey;

  List<Goal> _goals = [];
  int? _editingGoalIndex;

  String _aiInsightTitle = "AI Spending Insight";
  String _aiInsightText =
      "Analyzing your wallet activity to generate insights...";
  String _aiRiskLevel = "low";
  List<String> _aiActions = [];
  bool _loadingAiInsight = false;

  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _boot();

    _leanEventsSub = LeanEvents.stream.listen((event) async {
      if (!mounted) return;

      final status = (event["status"] ?? "").toString();

      if (status == "SUCCESS") {
        await _refreshFromLean();
        if (!mounted) return;

        await _loadAiInsight();
        if (!mounted) return;

        Navigator.pushReplacementNamed(context, '/wallet');
      }
    });
  }

  Future<void> _loadAiInsight() async {
    if (_loadingAiInsight) return;
    if (!mounted) return;

    setState(() {
      _loadingAiInsight = true;
    });

    try {
      final baseUrl = kIsWeb ? "http://127.0.0.1:8001" : "http://10.0.2.2:8001";

      final user = await Session.loadUser();
      if (!mounted) return;

      final customerId = (user?["lean_customer_id"] ?? "").toString().trim();

      final bankId = await Session.getSelectedBankId();
      if (!mounted) return;

      if (customerId.isEmpty) {
        setState(() {
          _aiInsightTitle = "AI Spending Insight";
          _aiInsightText =
              "Connect or load a bank first to generate personalized insights.";
          _aiRiskLevel = "low";
          _aiActions = [];
          _loadingAiInsight = false;
        });
        return;
      }

      final uri = Uri.parse(
        "$baseUrl/ai/spending-insight?customer_id=$customerId"
        "${(bankId != null && bankId.isNotEmpty) ? "&bank_id=$bankId" : ""}",
      );

      final res = await http.get(uri);
      if (!mounted) return;

      if (res.statusCode != 200) {
        throw Exception("AI insight failed: ${res.body}");
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (!mounted) return;

      setState(() {
        _aiInsightTitle = (data["headline"] ?? "AI Spending Insight")
            .toString();
        _aiInsightText = (data["summary"] ?? "No insight available.")
            .toString();
        _aiRiskLevel = (data["risk_level"] ?? "low").toString();
        _aiActions = ((data["actions"] as List?) ?? [])
            .map((e) => e.toString())
            .toList();
        _loadingAiInsight = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _aiInsightTitle = "AI Spending Insight";
        _aiInsightText = "Unable to generate insight right now.";
        _aiRiskLevel = "low";
        _aiActions = [];
        _loadingAiInsight = false;
      });
    }
  }

  Future<void> _boot() async {
    await _ensureAutoLeanMb1();
    if (!mounted) return;

    await _loadAll();
    if (!mounted) return;

    await _loadAiInsight();
  }

  @override
  void dispose() {
    _leanEventsSub?.cancel();
    super.dispose();
  }

 Future<void> _loadAll() async {
  final user = await Session.loadUser();
  final userId = Session.getUserId(user);
  final goals = (userId == null)
      ? <Goal>[]
      : await Session.getGoalsForUser(userId: userId);

  final banks = await Session.getConnectedBanks();
  final accounts = await Session.getLeanAccounts();
  final leanTx = await Session.getLeanTransactions();
  final manualTx = userId == null
      ? <dynamic>[]
      : await Session.getManualTransactions(userId: userId);
  final tx = [...manualTx, ...leanTx];

  String? selectedBankId = await Session.getSelectedBankId();

  if ((selectedBankId == null || selectedBankId.isEmpty) &&
      banks.isNotEmpty) {
      for (final b in banks) {
        if (b is Map) {
          final name = (b["name"] ?? "").toString().toLowerCase();
          if (name.contains("one")) {
            selectedBankId = (b["id"] ?? "").toString();
            break;
          }
        }
      }

      selectedBankId ??= (banks.first is Map)
          ? ((banks.first as Map)["id"] ?? "").toString()
          : null;

      if (selectedBankId != null && selectedBankId!.isNotEmpty) {
        await Session.saveSelectedBankId(selectedBankId);
      }
    }

    num balance = 0;
    num income = 0;
    num expenses = 0;
    List<dynamic> recentTx = [];

    if (banks.isNotEmpty && accounts.isNotEmpty) {
      final bankId =
          (selectedBankId != null &&
              banks.any(
                (b) => (b is Map) && b["id"]?.toString() == selectedBankId,
              ))
          ? selectedBankId
          : (banks.first is Map
                ? (banks.first as Map)["id"]?.toString()
                : null);

      final bankAccounts = accounts
          .where(
            (a) =>
                (a is Map) &&
                (bankId == null || a["bank_id"]?.toString() == bankId),
          )
          .whereType<Map>()
          .toList();

      final bankTx = tx
          .where(
            (t) =>
                (t is Map) &&
                (bankId == null || t["bank_id"]?.toString() == bankId),
          )
          .whereType<Map>()
          .toList();

      bankTx.sort((a, b) {
        final bt = (b["timestamp"] ?? b["date"] ?? "").toString();
        final at = (a["timestamp"] ?? a["date"] ?? "").toString();
        return bt.compareTo(at);
      });

      if (bankAccounts.isNotEmpty) {
        final acc = bankAccounts.first;
        final balObj = (acc["balance"] is Map) ? (acc["balance"] as Map) : {};
        final balNum =
            balObj["available"] ?? balObj["current"] ?? acc["balance"] ?? 0;
        balance = (balNum is num)
            ? balNum
            : num.tryParse(balNum.toString()) ?? 0;
      }

      for (final t in bankTx) {
        final amt = t["amount"];
        final v = (amt is num) ? amt : num.tryParse(amt.toString()) ?? 0;
        if (v > 0) income += v;
        if (v < 0) expenses += -v;
      }

      recentTx = bankTx.take(5).toList();

      await Session.saveTotals({
        "balance": balance,
        "income": income,
        "expenses": expenses,
      });
    } else {
      final totals = await Session.getTotals();
      balance = totals["balance"] ?? 0;
      income = totals["income"] ?? 0;
      expenses = totals["expenses"] ?? 0;
      recentTx = tx.take(5).toList();
    }

    if (!mounted) return;
    setState(() {
      _user = user;
      _goals = goals;
      _banks = banks;
      _selectedBankId = selectedBankId;
      _balance = balance;
      _income = income;
      _expenses = expenses;
      _recentTx = recentTx;
      _loading = false;
    });
    if (!mounted) return;
    await _loadAiInsight();
  }

  // Persist selection
  Future<void> _connectBank(String bankId) async {
    if (_connectingBank) return;

    setState(() {
      _connectingBank = true;
    });

    try {
      // persist which bank user chose
      await Session.saveSelectedBankId(bankId);

      final user = await Session.loadUser();
      final customerId = (user?["lean_customer_id"] ?? "").toString().trim();
      if (customerId.isEmpty) {
        throw Exception("Missing lean_customer_id. Press Connect Bank first.");
      }
    } catch (e) {
      debugPrint("Connect error $e");
    }

    if (!mounted) return;
    setState(() {
      _connectingBank = false;
    });
  }

  Future<void> _disconnectBank(String bankId) async {
    await Session.disconnectBank(bankId);

    final banks = await Session.getConnectedBanks();

    if (!mounted) return;

    setState(() {
      _banks = banks;
      if (_selectedBankId == bankId) {
        _selectedBankId = null;
      }
    });
  }

  Future<void> _refreshFromLean() async {
    try {
      final freshUser = await Session.loadUser(); // ✅ get latest saved user
      final customerId =
          (freshUser?["lean_customer_id"] ?? _user?["lean_customer_id"] ?? "")
              .toString()
              .trim();

      print("✅ REFRESH customerId = $customerId"); // optional debug

      if (customerId.isEmpty) {
        throw Exception("Missing lean_customer_id. Connect bank first.");
      }

      final data = await LeanApi.fetchAll(customerId: customerId);
      final backendSummary = (data["summary"] ?? {}) as Map<String, dynamic>;

      final override = await Session.getWalletSummaryOverride();

      final summary = override ?? backendSummary;

      final accounts = List<dynamic>.from((data["accounts"] as List?) ?? []);
      final transactions = List<dynamic>.from(
        (data["transactions"] as List?) ?? [],
      );
      final identity = Map<String, dynamic>.from(
        (data["identity"] as Map?) ?? {},
      );

      await Session.saveLeanAccounts(accounts);
      await Session.saveLeanTransactions(transactions);
      await Session.saveLeanIdentity(identity);
      final banks = List<dynamic>.from((data["banks"] as List?) ?? []);
      await Session.saveConnectedBanks(banks);

      // Auto-select bank based on which MB button was pressed
      String? selectedBankId = await Session.getSelectedBankId();
      if (_pendingBankKey != null) {
        final matchId = _findBankIdByKey(_pendingBankKey!, banks);
        if (matchId != null && matchId.isNotEmpty) {
          selectedBankId = matchId;
          await Session.saveSelectedBankId(matchId);
        }
        _pendingBankKey = null;
      }
      // Filter tx by selected bank
     final currentUser = await Session.loadUser();
final currentUserId = Session.getUserId(currentUser);
final manualTx = currentUserId == null
    ? <dynamic>[]
    : await Session.getManualTransactions(userId: currentUserId);

final allTransactions = [...manualTx, ...transactions];

final filteredTx = allTransactions
    .where(
      (t) =>
          (t is Map) &&
          (selectedBankId == null ||
              t["bank_id"]?.toString() == selectedBankId),
    )
    .whereType<Map>()
    .toList();

      filteredTx.sort((a, b) {
        final bt = (b["timestamp"] ?? b["date"] ?? "").toString();
        final at = (a["timestamp"] ?? a["date"] ?? "").toString();
        return bt.compareTo(at);
      });

      // ✅ Recompute totals from selected bank transactions

      num income = 0;
      num expenses = 0;
      for (final t in filteredTx) {
        final amt = t["amount"];
        final v = (amt is num) ? amt : num.tryParse(amt.toString()) ?? 0;
        if (v > 0) income += v;
        if (v < 0) expenses += -v;
      }
      num newBalance = 0;
      final selectedAccounts = accounts
          .where(
            (a) =>
                (a is Map) &&
                (selectedBankId == null ||
                    a["bank_id"]?.toString() == selectedBankId),
          )
          .whereType<Map>()
          .toList();

      if (selectedAccounts.isNotEmpty) {
        final acc = selectedAccounts.first;
        final bal = (acc["balance"] as Map?) ?? {};
        final balNum = bal["available"] ?? bal["current"] ?? 0;
        newBalance = (balNum is num)
            ? balNum
            : num.tryParse(balNum.toString()) ?? 0;
      }
      // Use first account balance (you already do newBalance)
      await Session.saveTotals({
        "balance": newBalance,
        "income": income,
        "expenses": expenses,
      });

      if (!mounted) return;
      setState(() {
        _banks = banks;
        _selectedBankId = selectedBankId;

        _balance = newBalance;
        _income = income;
        _expenses = expenses;

        _recentTx = filteredTx.take(5).toList(); // ✅ last 5 only

        final fullName = (identity["full_name"] ?? "").toString();
        final bankName = accounts.isNotEmpty
            ? ((accounts.first as Map)["bank_name"] ?? "").toString()
            : "";
        _cardTitle = fullName.isNotEmpty
            ? fullName
            : (bankName.isNotEmpty ? bankName : "Connected Account");
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Refresh error: $e")));
    }
  }

  String _nameFromUser() {
    final name = (_user?["name"] ?? "").toString().trim();
    if (name.isNotEmpty) return name;
    final email = (_user?["email"] ?? "").toString();
    if (email.contains('@')) return email.split('@').first;
    return "there";
  }

  String _fmtNoDecimals(num v) {
    // Remove .0 etc:
    final asInt = v.round();
    return asInt.toString();
  }

  String? _findBankIdByKey(String key, List<dynamic> banks) {
    for (final b in banks) {
      if (b is! Map) continue;
      final name = (b["name"] ?? "").toString().toLowerCase();
      if (key == "mb1" && name.contains("one"))
        return (b["id"] ?? "").toString();
      if (key == "mb2" && name.contains("two"))
        return (b["id"] ?? "").toString();
    }
    return null;
  }

  Future<void> _ensureAutoLeanMb1() async {
    final baseUrl = kIsWeb ? "http://127.0.0.1:8001" : "http://10.0.2.2:8001";

    final currentUser = await Session.loadUser();
    if (currentUser == null) return;

    final userId = Session.getUserId(currentUser);
    if (userId == null) return;

    String customerId = (currentUser["lean_customer_id"] ?? "")
        .toString()
        .trim();

    try {
      // 1) Create customer automatically if missing
      if (customerId.isEmpty) {
        final createRes = await http.post(
          Uri.parse("$baseUrl/lean/customer?app_user_id=$userId"),
        );

        if (createRes.statusCode == 200) {
          final created = jsonDecode(createRes.body) as Map<String, dynamic>;
          customerId = (created["customer_id"] ?? "").toString().trim();

          if (customerId.isNotEmpty) {
            final updatedUser = Map<String, dynamic>.from(currentUser);
            updatedUser["lean_customer_id"] = customerId;
            await Session.saveUser(updatedUser);
            _user = updatedUser;
          }
        } else {
          debugPrint("Auto customer create failed: ${createRes.body}");
          return;
        }
      }

      if (customerId.isEmpty) return;

      // 2) Fetch Lean/mock data
      final data = await LeanApi.fetchAll(customerId: customerId);

      final banks = List<dynamic>.from((data["banks"] as List?) ?? []);
      final accounts = List<dynamic>.from((data["accounts"] as List?) ?? []);
      final transactions = List<dynamic>.from(
        (data["transactions"] as List?) ?? [],
      );
      final identity = Map<String, dynamic>.from(
        (data["identity"] as Map?) ?? {},
      );

      await Session.saveConnectedBanks(banks);
      await Session.saveLeanAccounts(accounts);
      await Session.saveLeanTransactions(transactions);
      await Session.saveLeanIdentity(identity);

      // 3) Auto-select MB1 if it exists
      String? mb1Id;
      for (final b in banks) {
        if (b is Map) {
          final name = (b["name"] ?? "").toString().toLowerCase();
          if (name.contains("one")) {
            mb1Id = (b["id"] ?? "").toString();
            break;
          }
        }
      }

      if (mb1Id != null && mb1Id.isNotEmpty) {
        await Session.saveSelectedBankId(mb1Id);
      } else if (banks.isNotEmpty && banks.first is Map) {
        await Session.saveSelectedBankId(
          ((banks.first as Map)["id"] ?? "").toString(),
        );
      }

      // 4) Save dashboard totals based on selected bank
      final selectedBankId = await Session.getSelectedBankId();

      num balance = 0;
      num income = 0;
      num expenses = 0;

      final selectedAccounts = accounts
          .where(
            (a) =>
                (a is Map) &&
                (selectedBankId == null ||
                    a["bank_id"]?.toString() == selectedBankId),
          )
          .whereType<Map>()
          .toList();

      final selectedTx = transactions
          .where(
            (t) =>
                (t is Map) &&
                (selectedBankId == null ||
                    t["bank_id"]?.toString() == selectedBankId),
          )
          .whereType<Map>()
          .toList();

      if (selectedAccounts.isNotEmpty) {
        final acc = selectedAccounts.first;
        final balObj = (acc["balance"] is Map) ? (acc["balance"] as Map) : {};
        final balNum =
            balObj["available"] ?? balObj["current"] ?? acc["balance"] ?? 0;
        balance = (balNum is num)
            ? balNum
            : num.tryParse(balNum.toString()) ?? 0;
      }

      for (final t in selectedTx) {
        final amt = t["amount"];
        final v = (amt is num) ? amt : num.tryParse(amt.toString()) ?? 0;
        if (v > 0) income += v;
        if (v < 0) expenses += -v;
      }

      await Session.saveTotals({
        "balance": balance,
        "income": income,
        "expenses": expenses,
      });
    } catch (e) {
      debugPrint("Auto Lean MB1 load failed: $e");
    }
  }

  Future<void> _editNumber({
    required String title,
    required num current,
    required void Function(num) onSave,
  }) async {
    final ctrl = TextEditingController(text: _fmtNoDecimals(current));

    final result = await showDialog<num>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: "Enter number"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final raw = ctrl.text.trim();
                final value = num.tryParse(raw) ?? current;
                Navigator.pop(ctx, value);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    onSave(result);
    await Session.saveTotals({
      "balance": _balance,
      "income": _income,
      "expenses": _expenses,
    });

    if (!mounted) return;
    setState(() {});
  }



Future<void> _showAddGoalDialog() async {
  final userId = Session.getUserId(_user);
  if (userId == null) return;

  final nameController = TextEditingController();
  final targetController = TextEditingController();
  final savedController = TextEditingController();
  DateTime targetDate = DateTime.now().add(const Duration(days: 30));

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Add New Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Goal Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target Amount (AED)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: savedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount Saved (AED)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(targetDate),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: targetDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (date != null) {
                      setDialogState(() => targetDate = date);
                    }
                  },
                  child: const Text('Pick Date'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final targetAmt = double.tryParse(targetController.text) ?? 0.0;
              final savedAmt = double.tryParse(savedController.text) ?? 0.0;

              if (nameController.text.trim().isEmpty || targetAmt <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill name and valid target amount'),
                  ),
                );
                return;
              }

              final createdGoal = await Session.createGoal(
                userId: userId,
                name: nameController.text.trim(),
                targetAmount: targetAmt,
                targetDate: targetDate,
              );

              if (createdGoal != null) {
                final updatedGoal = createdGoal.copyWith(
                  savedAmount: savedAmt.clamp(0.0, targetAmt),
                );
                await Session.updateGoal(
                  userId: userId,
                  updatedGoal: updatedGoal,
                );
              }

              final updatedGoals = await Session.getGoalsForUser(userId: userId);

              if (!mounted) return;

              setState(() {
                _goals = updatedGoals;
              });

              Navigator.pop(ctx);
            },
            child: const Text('Add Goal'),
          ),
        ],
      ),
    ),
  );
}



Future<void> _showEditGoalDialog(Goal goal) async {
    final userId = Session.getUserId(_user);
    if (userId == null) return;

    final nameController = TextEditingController(text: goal.name);
    final savedController = TextEditingController(text: goal.savedAmount.toString());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${goal.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Goal Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: savedController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount Saved (AED)',
                border: OutlineInputBorder(),
              ),
            ),
            Text('Target: AED ${goal.targetAmount.toStringAsFixed(0)} by ${DateFormat("MMM dd, yyyy").format(goal.targetDate)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final savedAmt = double.tryParse(savedController.text) ?? goal.savedAmount;
              final updatedGoal = goal.copyWith(
                name: nameController.text.trim(),
                savedAmount: savedAmt.clamp(0.0, goal.targetAmount),
              );
              await Session.updateGoal(userId: userId, updatedGoal: updatedGoal);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

void _onNav(int i) {
    setState(() => _navIndex = i);

    switch (i) {
      case 0:
        // already dashboard
        return;
      case 1:
        Navigator.pushNamed(context, '/wallet').then((_) async {
          await _loadAll();
        });
        return;
      case 2:
  Navigator.pushNamed(context, '/categories');
  return;
      case 3:
        Navigator.pushNamed(context, '/gamification');
        return;
      case 4:
        Navigator.pushNamed(context, '/assistant');
        return;
    }
  }

  Future<void> _connectLean() async {
    final baseUrl = kIsWeb ? "http://127.0.0.1:8001" : "http://10.0.2.2:8001";

    final userId = Session.getUserId(_user);
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User id not found. Please login again.")),
      );
      return;
    }

    String customerId = (_user?["lean_customer_id"] ?? "").toString().trim();
    print("Using CustomerID= $customerId");

    try {
      // 1) Create customer if missing
      if (customerId.isEmpty) {
        final createRes = await http.post(
          Uri.parse("$baseUrl/lean/customer?app_user_id=$userId"),
        );

        if (createRes.statusCode != 200) {
          throw Exception("Create customer failed: ${createRes.body}");
        }

        final created = jsonDecode(createRes.body) as Map<String, dynamic>;
        customerId = (created["customer_id"] ?? "").toString().trim();

        if (customerId.isEmpty)
          throw Exception("Backend did not return customer_id");

        // Save into session user object
        final updatedUser = Map<String, dynamic>.from(_user ?? {});
        updatedUser["lean_customer_id"] = customerId;
        await Session.saveUser(updatedUser);
        if (mounted) setState(() => _user = updatedUser);
      }

      // 2) link-config
      final res = await http.get(
        Uri.parse("$baseUrl/lean/link-config?customer_id=$customerId"),
      );

      if (res.statusCode != 200)
        throw Exception("link-config failed: ${res.body}");

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      final appToken = (data["app_token"] ?? "").toString();
      final accessToken = (data["access_token"] ?? "").toString();
      final custId = (data["customer_id"] ?? customerId).toString();

      if (appToken.isEmpty || accessToken.isEmpty || custId.isEmpty) {
        throw Exception("Missing app_token / access_token / customer_id");
      }

      // 3) Open Lean (WEB only)
      final config = {
        "access_token": accessToken,
        "app_token": appToken,
        "customer_id": custId,
        "customer_token": accessToken,
        "permissions": ["identity", "accounts", "transactions", "balance"],
        "sandbox": true,
      };

      openLean(config);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lean error: $e")));
    }
  }
@override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFD6E6); // lighter pink than before

    final name = _nameFromUser();

    return Scaffold(
      backgroundColor: bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                const Positioned.fill(child: _SoftPinkBackground()),

                SafeArea(
                  child: Center(
                    // ✅ Not full screen: limit the dashboard width
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                        child: ListView(
                          children: [

                            // ---------------- TOP BAR ----------------
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(0xFF8F7BFF),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Hello, $name",
                                    style: GoogleFonts.baloo2(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF3A1B52),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _logout,
                                  icon: const Icon(Icons.logout_rounded),
                                  color: const Color(0xFF3A1B52),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // ---------------- TOTAL BALANCE (CENTER) ----------------
                            _MetricCard(
                              label: "TOTAL BALANCE",
                              value: "AED ${_fmtNoDecimals(_balance)}",
                              subtitle: "Tap to edit",
                              big: true,
                              onEdit: () => _editNumber(
                                title: "Edit Total Balance",
                                current: _balance,
                                onSave: (v) => _balance = v,
                              ),
                            ),

                            const SizedBox(height: 12),

                            // ---------------- INCOME / EXPENSES (same size) ----------------
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricCard(
                                    label: "INCOME",
                                    value: "AED ${_fmtNoDecimals(_income)}",
                                    subtitle: "Tap to edit",
                                    onEdit: () => _editNumber(
                                      title: "Edit Income",
                                      current: _income,
                                      onSave: (v) => _income = v,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _MetricCard(
                                    label: "EXPENSES",
                                    value: "AED ${_fmtNoDecimals(_expenses)}",
                                    subtitle: "Tap to edit",
                                    onEdit: () => _editNumber(
                                      title: "Edit Expenses",
                                      current: _expenses,
                                      onSave: (v) => _expenses = v,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // ---------------- INSIGHT CARD ----------------
                            _InsightCard(
                              title: _aiInsightTitle,
                              text: _aiInsightText,
                              riskLevel: _aiRiskLevel,
                              actions: _aiActions,
                              loading: _loadingAiInsight,
                              onTap: () async {
                                await _loadAiInsight();
                              },
                            ),

                            const SizedBox(height: 14),
                            // 1) Connect Bank (ONLY creates customer / opens setup, does NOT show Visa/Tx)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _connectLean,
                                child: const Text("Connect Bank"),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 2) Bank Tiles (Lean MB1 / Lean MB2) - show connected state + disconnect

                            // ---------------- GOALS (professional) ----------------
                            Text(
                              "Your Goals",
                              style: GoogleFonts.baloo2(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF3A1B52),
                              ),
                            ),
                            const SizedBox(height: 8),

                            GoalsSection(
                              goals: _goals,
                              onGoalAdded: _showAddGoalDialog,
                              onGoalsUpdated: () async {
                                final user = await Session.loadUser();
                                final userId = Session.getUserId(user);
                                if (userId != null) {
                                  final updatedGoals = await Session.getGoalsForUser(userId: userId);
                                  if (mounted) {
                                    setState(() {
                                      _goals = updatedGoals;
                                    });
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                           ElevatedButton.icon(
  onPressed: _showReceiptUploadDialog,
  icon: const Icon(Icons.receipt_long),
  label: const Text("Upload Receipt"),
),

const SizedBox(height: 14),
                       Text(
  "Recent Activity",
  style: GoogleFonts.baloo2(
    fontSize: 16,
    fontWeight: FontWeight.w900,
    color: const Color(0xFF3A1B52),
  ),
),

const SizedBox(height: 8),

_RecentActivityCard(transactions: _recentTx),

const SizedBox(height: 16),


                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ---------------- BOTTOM NAV ----------------
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: _BottomNav(index: _navIndex, onTap: _onNav),
                ),
              ],
            ),
    );
  }
}

// ---------------- BACKGROUND ----------------
class _SoftPinkBackground extends StatelessWidget {
  const _SoftPinkBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE6F0), Color(0xFFFFD3E6), Color(0xFFFFCBE2)],
        ),
      ),
      child: CustomPaint(painter: _GlowDotsPainter()),
    );
  }
}

class _GlowDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color.fromRGBO(180, 140, 255, 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);

    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.18), 140, p);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.25), 160, p);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.78), 180, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------- METRIC CARD ----------------
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final bool big;
  final VoidCallback onEdit;

  const _MetricCard({
    required this.label,
    required this.value,
    this.subtitle = "",
    this.big = false,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final h = big ? 130.0 : 110.0;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onEdit,
      child: Container(
        height: h,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromRGBO(255, 255, 255, 0.65),
              Color.fromRGBO(210, 190, 255, 0.55),
            ],
          ),
          border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.55)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 26,
              offset: Offset(0, 16),
              color: Color.fromRGBO(60, 20, 90, 0.12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              child: Icon(
                Icons.edit,
                size: 18,
                color: const Color(0xFF3A1B52).withOpacity(0.7),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.baloo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF3A1B52).withOpacity(0.85),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: GoogleFonts.baloo2(
                    fontSize: big ? 30 : 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2B103C),
                    height: 1.0,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.baloo2(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3A1B52).withOpacity(0.65),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- INSIGHT ----------------
class _InsightCard extends StatelessWidget {
  final String title;
  final String text;
  final String riskLevel;
  final List<String> actions;
  final bool loading;
  final VoidCallback onTap;

  const _InsightCard({
    required this.title,
    required this.text,
    required this.riskLevel,
    required this.actions,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = riskLevel == "high"
        ? const Color(0xFFFFB4B4)
        : riskLevel == "moderate"
        ? const Color(0xFFFFE08A)
        : const Color(0xFFB9F6CA);

    final String badgeText = riskLevel.toUpperCase();
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFBFA7FF), Color(0xFF8F7BFF)],
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 28,
              offset: Offset(0, 16),
              color: Color.fromRGBO(70, 30, 160, 0.25),
            ),
          ],
          border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color.fromRGBO(255, 255, 255, 0.22),
              ),
              child: const Icon(Icons.auto_awesome, color: Color(0xFFFFF3B0)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: badgeColor,
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.baloo2(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF2B103C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    loading ? "Refreshing insight..." : text,
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color.fromRGBO(255, 255, 255, 0.94),
                      height: 1.25,
                    ),
                  ),
                  if (!loading && actions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: actions.take(3).map((a) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: const Color.fromRGBO(255, 255, 255, 0.18),
                          ),
                          child: Text(
                            a,
                            style: GoogleFonts.baloo2(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _BankTile extends StatelessWidget {
  final String label;
  final bool connected;
  final VoidCallback onTap;
  final VoidCallback onDisconnect;

  const _BankTile({
    required this.label,
    required this.connected,
    required this.onTap,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color.fromRGBO(255, 255, 255, 0.60),
          border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.55)),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.baloo2(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2B103C),
                ),
              ),
            ),
            if (connected)
              TextButton(
                onPressed: onDisconnect,
                child: const Text("DISCONNECT"),
              )
            else
              const Text("CONNECT"),
          ],
        ),
      ),
    );
  }
}

// ---------------- GOALS ----------------
class _GoalsCard extends StatelessWidget {
  final TextEditingController controller;
  final List<String> goals;
  final VoidCallback onAdd;
  final Future<void> Function(int idx) onRemove;

  const _GoalsCard({
    required this.controller,
    required this.goals,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color.fromRGBO(255, 255, 255, 0.55),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.55)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 20,
            offset: Offset(0, 14),
            color: Color.fromRGBO(60, 20, 90, 0.10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: "Add a new goal…",
                    hintStyle: GoogleFonts.baloo2(
                      fontWeight: FontWeight.w700,
                      color: const Color.fromRGBO(58, 27, 82, 0.55),
                    ),
                    filled: true,
                    fillColor: const Color.fromRGBO(255, 255, 255, 0.75),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  style: GoogleFonts.baloo2(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2B103C),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 46,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE06B), Color(0xFFFFC928)],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 16,
                        offset: Offset(0, 10),
                        color: Color.fromRGBO(0, 0, 0, 0.14),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, color: Color(0xFF1E1E1E)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (goals.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "No goals yet. Add your first goal ✨",
                style: GoogleFonts.baloo2(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: const Color.fromRGBO(58, 27, 82, 0.70),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: goals.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color.fromRGBO(255, 255, 255, 0.75),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        size: 18,
                        color: Color(0xFF8F7BFF),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          goals[i],
                          style: GoogleFonts.baloo2(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2B103C),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => onRemove(i),
                        icon: const Icon(Icons.close_rounded),
                        color: const Color.fromRGBO(58, 27, 82, 0.60),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ---------------- BOTTOM NAV ----------------
class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color.fromRGBO(120, 80, 255, 0.18),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: "Home",
                selected: index == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.account_balance_wallet_rounded,
                label: "Wallet",
                selected: index == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.grid_view_rounded,
                label: "Categories",
                selected: index == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.emoji_events_rounded,
                label: "Rewards",
                selected: index == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.smart_toy_rounded,
                label: "Assistant",
                selected: index == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? const Color(0xFF2B103C)
        : const Color.fromRGBO(43, 16, 60, 0.55);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.baloo2(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- RECENT ACTIVITY ----------------
class _RecentActivityCard extends StatelessWidget {
  final List<dynamic> transactions;

  const _RecentActivityCard({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        child: const Text("No transactions yet."),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color.fromRGBO(255, 255, 255, 0.55),
      ),
      child: Column(
        children: transactions.take(5).map((tx) {
          final amount = (tx["amount"] ?? 0);
          final title = tx["description"] ?? "Transaction";
          final date = tx["date"] ?? "";
          final isExpense = amount < 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ActivityItem(
              title: title,
              time: date.toString(),
              amount: "${amount.toString()} AED",
              isExpense: isExpense,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String title;
  final String time;
  final String amount;
  final bool isExpense;

  const _ActivityItem({
    required this.title,
    required this.time,
    required this.amount,
    required this.isExpense,
  });

  @override
  Widget build(BuildContext context) {
    final amountColor = isExpense ? Colors.red : Colors.green;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color.fromRGBO(180, 140, 255, 0.20),
          ),
          child: Icon(
            isExpense
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            color: amountColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2B103C),
                ),
              ),
              Text(
                time,
                style: GoogleFonts.baloo2(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color.fromRGBO(58, 27, 82, 0.60),
                ),
              ),
            ],
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.baloo2(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: amountColor,
          ),
        ),
      ],
    );
  }
}
