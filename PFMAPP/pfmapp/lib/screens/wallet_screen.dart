import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session.dart';
import '../services/lean_api.dart';
import 'package:http/http.dart' as http;

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _identity;
  List<dynamic> _accounts = [];
  List<dynamic> _tx = [];
  bool _loading = true;
  List<dynamic> _banks = [];
  String? _selectedBankId;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await Session.loadUser();
    final selectedBankId = await Session.getSelectedBankId();

    Map<String, dynamic> identity = {};
    List<dynamic> accounts = [];
    List<dynamic> tx = [];
    List<dynamic> banks = [];

    final customerId = (user?["lean_customer_id"] ?? "").toString().trim();

    if (customerId.isNotEmpty) {
      try {
        final data = await LeanApi.fetchAll(customerId: customerId);

        banks = List<dynamic>.from((data["banks"] as List?) ?? []);
        accounts = List<dynamic>.from((data["accounts"] as List?) ?? []);
        tx = List<dynamic>.from((data["transactions"] as List?) ?? []);
        identity = Map<String, dynamic>.from((data["identity"] as Map?) ?? {});

        await Session.saveConnectedBanks(banks);
        await Session.saveLeanAccounts(accounts);
        await Session.saveLeanTransactions(tx);
        await Session.saveLeanIdentity(identity);
      } catch (e) {
        debugPrint("Wallet refresh error: $e");

        identity = await Session.getLeanIdentity();
        accounts = await Session.getLeanAccounts();
        tx = await Session.getLeanTransactions();
        banks = await Session.getConnectedBanks();
      }
    } else {
      identity = await Session.getLeanIdentity();
      accounts = await Session.getLeanAccounts();
      tx = await Session.getLeanTransactions();
      banks = await Session.getConnectedBanks();
    }

    String? bankId = selectedBankId;

    if ((bankId == null || bankId.isEmpty) && banks.isNotEmpty) {
      for (final b in banks) {
        if (b is Map) {
          final name = (b["name"] ?? "").toString().toLowerCase();
          if (name.contains("one")) {
            bankId = (b["id"] ?? "").toString();
            break;
          }
        }
      }

      bankId ??= (banks.first is Map)
          ? ((banks.first as Map)["id"] ?? "").toString()
          : null;

      if (bankId != null && bankId!.isNotEmpty) {
        await Session.saveSelectedBankId(bankId);
      }
    }

    final filteredAccounts = accounts
        .where(
          (a) =>
              (a is Map) &&
              (bankId == null || a["bank_id"]?.toString() == bankId),
        )
        .toList();

    final filteredTx = tx
        .where(
          (t) =>
              (t is Map) &&
              (bankId == null || t["bank_id"]?.toString() == bankId),
        )
        .toList();

    filteredTx.sort((a, b) {
      final bt = (b is Map ? (b["timestamp"] ?? b["date"] ?? "") : "")
          .toString();
      final at = (a is Map ? (a["timestamp"] ?? a["date"] ?? "") : "")
          .toString();
      return bt.compareTo(at);
    });

    await _syncDashboardTotalsFromSelectedBank(
      accounts: accounts,
      tx: tx,
      bankId: bankId,
    );

    if (!mounted) return;
    setState(() {
      _user = user;
      _identity = identity;
      _banks = banks;
      _selectedBankId = bankId;
      _accounts = filteredAccounts;
      _tx = filteredTx;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFD6E6);

    final Map idObj = (_identity?["identity"] is Map)
        ? Map.from(_identity?["identity"] as Map)
        : Map.from(_identity ?? {});

    // pick first account
    final acc = (_accounts.isNotEmpty && _accounts.first is Map)
        ? _accounts.first as Map
        : {};
    final rawBankName =
        (acc["bank_name"] ??
                acc["bank"] ??
                acc["account_name"] ??
                acc["name"] ??
                "Connected Bank")
            .toString();

    final lowerBankName = rawBankName.toLowerCase();

    final bankName = lowerBankName.contains("one")
        ? "Lean MB1"
        : lowerBankName.contains("two")
        ? "Lean MB2"
        : rawBankName;

    final ibanOrAcc =
        (acc["iban"] ?? acc["account_number"] ?? acc["number"] ?? "")
            .toString()
            .replaceAll(" ", "");

    final fallbackKey =
        (acc["bank_id"] ?? acc["id"] ?? acc["bank_name"] ?? bankName)
            .toString();

    final generatedLast4 = ((fallbackKey.hashCode.abs() % 9000) + 1000)
        .toString();

    final last4 = ibanOrAcc.length >= 4
        ? ibanOrAcc.substring(ibanOrAcc.length - 4)
        : generatedLast4;

    final balObj = (acc["balance"] is Map) ? (acc["balance"] as Map) : {};
    final balNum =
        balObj["available"] ?? balObj["current"] ?? acc["balance"] ?? null;
    final balance = (balNum is num)
        ? balNum
        : num.tryParse(balNum?.toString() ?? "");
    final first = (_user?["first_name"] ?? _user?["firstName"] ?? "")
        .toString()
        .trim();
    final last = (_user?["last_name"] ?? _user?["lastName"] ?? "")
        .toString()
        .trim();

    final full = ("$first $last").trim();

    final holder = full.isNotEmpty
        ? full
        : (_user?["name"] ??
                  idObj["full_name"] ??
                  idObj["name"] ??
                  "Card Holder")
              .toString();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: "Back to Dashboard",
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/dashboard');
          },
        ),
        title: Text(
          "Wallet",
          style: GoogleFonts.baloo2(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: "Go to Categories",
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/categories');
            },
          ),
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _load();
              setState(() {});
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView(
                      children: [
                        _VisaCard(
                          holder: holder,
                          bank: bankName,
                          last4: last4,
                          balance: balance != null
                              ? "AED ${balance.toStringAsFixed(2)}"
                              : null,
                        ),
                        const SizedBox(height: 14),

                        if (_banks.isNotEmpty) ...[
                          _ConnectedBanksSelector(
                            banks: _banks,
                            selectedBankId: _selectedBankId,
                            onSelect: (id) async {
                              await Session.saveSelectedBankId(id);
                              await _load();
                            },
                            onDisconnect: (id) async {
                              await Session.disconnectBank(id);
                              await _load();
                            },
                          ),
                          const SizedBox(height: 14),
                        ],

                        Text(
                          "Transactions",
                          style: GoogleFonts.baloo2(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF3A1B52),
                          ),
                        ),
                        const SizedBox(height: 8),

                        if (_tx.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              color: const Color.fromRGBO(255, 255, 255, 0.55),
                              border: Border.all(
                                color: const Color.fromRGBO(
                                  255,
                                  255,
                                  255,
                                  0.55,
                                ),
                              ),
                            ),
                            child: const Text("No transactions yet."),
                          )
                        else
                          ..._tx.map(
                            (t) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _TxTile(tx: t),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _VisaCard extends StatelessWidget {
  final String holder;
  final String bank;
  final String last4;
  final String? balance;

  const _VisaCard({
    required this.holder,
    required this.bank,
    required this.last4,
    this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF4F46E5)],
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 26,
            offset: Offset(0, 16),
            color: Color.fromRGBO(0, 0, 0, 0.22),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Text(
              "VISA",
              style: GoogleFonts.baloo2(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(0.92),
                letterSpacing: 1.2,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bank,
                style: GoogleFonts.baloo2(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "** ** ** $last4",
                style: GoogleFonts.baloo2(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      holder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.95),
                      ),
                    ),
                  ),
                  if (balance != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      balance!,
                      style: GoogleFonts.baloo2(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final dynamic tx;
  const _TxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final m = (tx is Map) ? tx : <String, dynamic>{};

    final title = (m["description"] ?? m["merchant_name"] ?? "Transaction")
        .toString();
    final date = (m["date"] ?? m["timestamp"] ?? "").toString();
    final amountRaw = m["amount"] ?? 0;
    final amount = (amountRaw is num)
        ? amountRaw
        : num.tryParse(amountRaw.toString()) ?? 0;

    final isExpense = amount < 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 255, 255, 0.60),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.55),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isExpense
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: isExpense ? Colors.red : Colors.green,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(date, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Text(
                amount.toStringAsFixed(2),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isExpense ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _syncDashboardTotalsFromSelectedBank({
  required List<dynamic> accounts,
  required List<dynamic> tx,
  required String? bankId,
}) async {
  final selectedAccounts = accounts
      .where(
        (a) =>
            (a is Map) &&
            (bankId == null || a["bank_id"]?.toString() == bankId),
      )
      .whereType<Map>()
      .toList();

  final selectedTx = tx
      .where(
        (t) =>
            (t is Map) &&
            (bankId == null || t["bank_id"]?.toString() == bankId),
      )
      .whereType<Map>()
      .toList();

  num balance = 0;
  if (selectedAccounts.isNotEmpty) {
    final acc = selectedAccounts.first;
    final balObj = (acc["balance"] is Map) ? (acc["balance"] as Map) : {};
    final balNum =
        balObj["available"] ?? balObj["current"] ?? acc["balance"] ?? 0;
    balance = (balNum is num) ? balNum : num.tryParse(balNum.toString()) ?? 0;
  }

  num income = 0;
  num expenses = 0;

  for (final t in selectedTx) {
    final amt = t["amount"];
    final v = (amt is num) ? amt : num.tryParse(amt.toString()) ?? 0;

    if (v > 0) {
      income += v;
    } else if (v < 0) {
      expenses += -v;
    }
  }

  await Session.saveTotals({
    "balance": balance,
    "income": income,
    "expenses": expenses,
  });
}

class _ConnectedBanksSelector extends StatelessWidget {
  final List<dynamic> banks;
  final String? selectedBankId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDisconnect;

  const _ConnectedBanksSelector({
    required this.banks,
    required this.selectedBankId,
    required this.onSelect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color.fromRGBO(255, 255, 255, 0.55),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Connected Banks",
            style: GoogleFonts.baloo2(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF3A1B52),
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: banks.map<Widget>((b) {
              final m = (b is Map) ? b : <String, dynamic>{};
              final id = (m["id"] ?? "").toString();
              final rawName = (m["name"] ?? id).toString();
              final lower = rawName.toLowerCase();
              final name = lower.contains("one")
                  ? "Lean MB1"
                  : lower.contains("two")
                  ? "Lean MB2"
                  : rawName;

              final selected = id.isNotEmpty && id == selectedBankId;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: selected
                        ? const Color.fromRGBO(143, 123, 255, 0.22)
                        : const Color.fromRGBO(255, 255, 255, 0.70),
                    border: Border.all(
                      color: selected
                          ? const Color.fromRGBO(143, 123, 255, 0.65)
                          : const Color.fromRGBO(0, 0, 0, 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: id.isEmpty ? null : () => onSelect(id),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                name,
                                style: GoogleFonts.baloo2(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF2B103C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == "disconnect" && id.isNotEmpty) {
                            onDisconnect(id);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: "disconnect",
                            child: Text("Disconnect"),
                          ),
                        ],
                        icon: const Icon(Icons.more_vert),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
