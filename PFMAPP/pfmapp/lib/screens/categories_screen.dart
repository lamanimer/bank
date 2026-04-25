import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/session.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _loading = true;

  // raw tx loaded from session
  List<dynamic> _tx = [];
  List<dynamic> _accounts = [];
  // computed
  Map<String, double> _byCategory = {};
  List<_MonthAgg> _months = [];
  double _thisMonthSpent = 0;
  double _selectedBankBalance = 0;
  double _selectedBankIncome = 0;
  double _selectedBankExpenses = 0;
  int _selectedDonutIndex = -1;
  int _selectedBarIndex = -1;
  int _selectedLineIndex = -1;

  // Budget (simple fixed monthly budget – adjust if you want)
  final double _monthlyBudget = 2000;

  @override
  void initState() {
    super.initState();
    _loadAndCompute();
  }
Future<void> _loadAndCompute() async {
  final user = await Session.loadUser();
  final userId = Session.getUserId(user);
  final leanTx = await Session.getLeanTransactions();
  final manualTx = userId == null
      ? <dynamic>[]
      : await Session.getManualTransactions(userId: userId);
  final allTx = [...manualTx, ...leanTx];

  final allAccounts = await Session.getLeanAccounts();
  final selectedBankId = await Session.getSelectedBankId();

  _tx = allTx.where((t) {
    if (t is! Map) return false;
    if (selectedBankId == null || selectedBankId.isEmpty) return true;
    return t["bank_id"]?.toString() == selectedBankId;
  }).toList();

  _accounts = allAccounts.where((a) {
    if (a is! Map) return false;
    if (selectedBankId == null || selectedBankId.isEmpty) return true;
    return a["bank_id"]?.toString() == selectedBankId;
  }).toList();

  _computeEverything();

  if (!mounted) return;
  setState(() {
    _loading = false;
  });
}


  // ---------------- COMPUTATION ----------------
  void _computeEverything() {
    final now = DateTime.now();
    final thisMonthKey = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    final cat = <String, double>{};
    final monthMap = <String, _MonthAgg>{};

    double thisMonthSpent = 0;
    double totalIncome = 0;
    double totalExpenses = 0;
    double balance = 0;

    _byCategory = cat;

    _thisMonthSpent = thisMonthSpent;
    _selectedBankBalance = balance;
    _selectedBankIncome = totalIncome;
    _selectedBankExpenses = totalExpenses;

    if (_accounts.isNotEmpty && _accounts.first is Map) {
      final acc = _accounts.first as Map;
      final balObj = (acc["balance"] is Map) ? (acc["balance"] as Map) : {};
      final balNum =
          balObj["available"] ?? balObj["current"] ?? acc["balance"] ?? 0;
      balance = (balNum is num)
          ? balNum.toDouble()
          : double.tryParse(balNum.toString()) ?? 0;
    }

    for (final t in _tx) {
      if (t is! Map) continue;

      final amount = _parseAmount(t["amount"]);
      final dt = _parseDate(t["date"] ?? t["timestamp"]);
      if (dt == null) continue;

      final isExpense = amount < 0;
      final absAmount = amount.abs();
      final monthKey = "${dt.year}-${dt.month.toString().padLeft(2, '0')}";

      monthMap.putIfAbsent(
        monthKey,
        () => _MonthAgg(date: DateTime(dt.year, dt.month, 1)),
      );

      if (isExpense) {
        monthMap[monthKey]!.expenses += absAmount;
        totalExpenses += absAmount;

        final category = _getCategoryFromTx(t);
        cat[category] = (cat[category] ?? 0) + absAmount;

        if (monthKey == thisMonthKey) {
          thisMonthSpent += absAmount;
        }
      } else {
        monthMap[monthKey]!.income += absAmount;
        totalIncome += absAmount;
      }
    }

    final months = monthMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final last6 = months.length <= 6
        ? months
        : months.sublist(months.length - 6);

    for (int i = 0; i < last6.length; i++) {
      if (i == 0) {
        last6[i].forecast = last6[i].expenses;
      } else if (i == 1) {
        last6[i].forecast = (last6[i].expenses + last6[i - 1].expenses) / 2;
      } else {
        last6[i].forecast =
            (last6[i - 1].expenses +
                last6[i - 2].expenses +
                last6[i].expenses) /
            3;
      }
    }
    final fixedIncome = last6.isEmpty
        ? 0.0
        : last6.map((m) => m.income).reduce(max);

    for (final m in last6) {
      m.income = fixedIncome;
    }

    _byCategory = cat;
    _months = last6;
    _thisMonthSpent = thisMonthSpent;
    _selectedBankBalance = balance;
    _selectedBankIncome = totalIncome;
    _selectedBankExpenses = totalExpenses;
  }

  double _parseAmount(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  bool _isExpenseTx(Map t, double amount) {
    if (amount < 0) return true;
    if (amount > 0) {
      final text =
          "${t["description"] ?? ""} ${t["merchant_name"] ?? ""} ${t["category"] ?? ""}"
              .toLowerCase();

      const incomeHints = [
        "salary",
        "freelance",
        "refund",
        "income",
        "payment received",
        "transfer in",
        "deposit",
      ];

      if (incomeHints.any(text.contains)) return false;
    }

    final type = (t["type"] ?? t["direction"] ?? "").toString().toLowerCase();
    if (type.contains("credit") || type.contains("in")) return false;
    if (type.contains("debit") || type.contains("out")) return true;

    final desc = (t["description"] ?? t["merchant_name"] ?? "")
        .toString()
        .toLowerCase();

    const expenseHints = [
      "uber",
      "careem",
      "netflix",
      "amazon",
      "noon",
      "talabat",
      "deliveroo",
      "fuel",
      "restaurant",
      "bill",
      "dewa",
      "du",
      "etisalat",
      "shopping",
      "cinema",
      "store",
    ];

    if (expenseHints.any(desc.contains)) return true;

    return amount < 0;
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;

    // ISO attempt
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;

    // If Lean sends "2026-02-27" this also works above.
    return null;
  }

  String _getCategoryFromTx(Map t) {
    final aiCategory = (t["ai_category"] ?? "").toString().trim();
    if (aiCategory.isNotEmpty) return aiCategory;

    final backendCategory = (t["category"] ?? "").toString().trim();
    if (backendCategory.isNotEmpty) return backendCategory;

    return _mapCategoryFromTx(t);
  }

  String _mapCategoryFromTx(Map t) {
    final text = "${t["description"] ?? ""} ${t["merchant_name"] ?? ""}"
        .toLowerCase();

    if (text.contains("uber") ||
        text.contains("careem") ||
        text.contains("metro") ||
        text.contains("taxi") ||
        text.contains("fuel") ||
        text.contains("rta")) {
      return "Transportation";
    }

    if (text.contains("du") ||
        text.contains("etisalat") ||
        text.contains("electric") ||
        text.contains("water") ||
        text.contains("bill") ||
        text.contains("dewa")) {
      return "Bills";
    }

    if (text.contains("netflix") ||
        text.contains("spotify") ||
        text.contains("cinema") ||
        text.contains("game") ||
        text.contains("vox")) {
      return "Entertainment";
    }

    if (text.contains("restaurant") ||
        text.contains("cafe") ||
        text.contains("talabat") ||
        text.contains("deliveroo") ||
        text.contains("coffee") ||
        text.contains("kfc") ||
        text.contains("mcdonald")) {
      return "Food";
    }

    if (text.contains("amazon") ||
        text.contains("noon") ||
        text.contains("ikea") ||
        text.contains("mall") ||
        text.contains("store") ||
        text.contains("zara") ||
        text.contains("h&m") ||
        text.contains("shein") ||
        text.contains("apple")) {
      return "Shopping";
    }

    if (text.contains("emirates") ||
        text.contains("booking") ||
        text.contains("air arabia") ||
        text.contains("travel")) {
      return "Travel";
    }

    return "Other";
  }

  String _fmtMoney(double v) => v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFD6E6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,

        // LEFT ARROW → WALLET
        leading: IconButton(
          tooltip: "Back to Wallet",
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/wallet');
          },
        ),

        title: Text(
          "Categories",
          style: GoogleFonts.baloo2(fontWeight: FontWeight.w900),
        ),

        actions: [
          // RIGHT ARROW → GAMIFICATION
          IconButton(
            tooltip: "Go to Rewards",
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/gamification');
            },
          ),

          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() => _loading = true);
              await _loadAndCompute();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _SectionCard(
                      title: "Spending Breakdown",
                      subtitle:
                          "Interactive category distribution for your expenses",
                      child: _byCategory.isEmpty
                          ? _Empty("No expense transactions yet.")
                          : _DonutBreakdown(
                              byCategory: _byCategory,
                              selectedIndex: _selectedDonutIndex,
                              onTouched: (index) {
                                setState(() {
                                  _selectedDonutIndex = index;
                                });
                              },
                            ),
                    ),
                    const SizedBox(height: 12),

                    _SectionCard(
                      title: "Budget Gauge",
                      subtitle: "Current month spending versus monthly budget",
                      child: _BudgetGauge(
                        spent: _selectedBankExpenses,
                        budget: _selectedBankBalance <= 0
                            ? _monthlyBudget
                            : _selectedBankBalance,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _SectionCard(
                      title: "Monthly Comparison",
                      subtitle:
                          "6-month comparsion of income, expenses, and forecast",
                      child: _months.isEmpty
                          ? _Empty("No monthly data yet.")
                          : _MonthlyBars(
                              months: _months,
                              selectedIndex: _selectedBarIndex,
                              onTouched: (index) {
                                setState(() {
                                  _selectedBarIndex = index;
                                });
                              },
                            ),
                    ),
                    const SizedBox(height: 12),

                    _SectionCard(
                      title: "12-Month Expense Trend",
                      subtitle: "Interactive trend of monthly spending",
                      child: _months.isEmpty
                          ? _Empty("No trend yet.")
                          : _TrendLine(
                              months: _months,
                              selectedIndex: _selectedLineIndex,
                              onTouched: (index) {
                                setState(() {
                                  _selectedLineIndex = index;
                                });
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ---------------- UI HELPERS ----------------

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color.fromRGBO(255, 255, 255, 0.60),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.55)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 22,
            offset: Offset(0, 14),
            color: Color.fromRGBO(60, 20, 90, 0.10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: GoogleFonts.baloo2(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF3A1B52),
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle!,
                style: GoogleFonts.baloo2(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: const Color.fromRGBO(58, 27, 82, 0.65),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text, style: GoogleFonts.baloo2(fontWeight: FontWeight.w700)),
    );
  }
}

// ---------------- DATA MODELS ----------------

class _MonthAgg {
  final DateTime date;
  double income;
  double expenses;
  double forecast;

  _MonthAgg({
    required this.date,
    this.income = 0,
    this.expenses = 0,
    this.forecast = 0,
  });
}

// ---------------- CHARTS ----------------

class _DonutBreakdown extends StatelessWidget {
  final Map<String, double> byCategory;
  final int selectedIndex;
  final ValueChanged<int> onTouched;

  const _DonutBreakdown({
    required this.byCategory,
    required this.selectedIndex,
    required this.onTouched,
  });

  @override
  Widget build(BuildContext context) {
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = entries.fold<double>(0, (p, e) => p + e.value);
    final top = entries.take(6).toList();

    if (entries.length > 6) {
      final rest = entries.skip(6).fold<double>(0, (p, e) => p + e.value);
      top.add(MapEntry("Other", rest));
    }

    const palette = [
      Color(0xFF8F7BFF),
      Color(0xFFFF8FAB),
      Color(0xFF7BDCB5),
      Color(0xFFFFD166),
      Color(0xFF6EC6FF),
      Color(0xFFB8A1FF),
      Color(0xFFFFB4A2),
    ];

    final touchedIndex = selectedIndex >= 0 && selectedIndex < top.length
        ? selectedIndex
        : -1;

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < top.length; i++) {
      final e = top[i];
      final pct = total == 0 ? 0 : (e.value / total);
      final isTouched = i == touchedIndex;

      sections.add(
        PieChartSectionData(
          color: palette[i % palette.length],
          value: e.value,
          title: "${(pct * 100).toStringAsFixed(0)}%",
          radius: isTouched ? 72 : 60,
          titleStyle: GoogleFonts.baloo2(
            fontWeight: FontWeight.w900,
            fontSize: isTouched ? 13 : 11,
            color: Colors.white,
          ),
        ),
      );
    }

    final selectedLabel = touchedIndex == -1 ? "Total" : top[touchedIndex].key;
    final selectedValue = touchedIndex == -1 ? total : top[touchedIndex].value;

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions ||
                      response == null ||
                      response.touchedSection == null) {
                    onTouched(-1);
                    return;
                  }
                  onTouched(response.touchedSection!.touchedSectionIndex);
                },
              ),
              sections: sections,
              sectionsSpace: 3,
              centerSpaceRadius: 72,
              startDegreeOffset: -90,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -150),
          child: Column(
            children: [
              Text(
                selectedLabel,
                style: GoogleFonts.baloo2(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: const Color(0xFF3A1B52),
                ),
              ),
              Text(
                "AED ${selectedValue.toStringAsFixed(0)}",
                style: GoogleFonts.baloo2(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: const Color(0xFF2B103C),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: List.generate(top.length, (i) {
            final e = top[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: const Color.fromRGBO(255, 255, 255, 0.70),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette[i % palette.length],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    e.key,
                    style: GoogleFonts.baloo2(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BudgetGauge extends StatelessWidget {
  final double spent;
  final double budget;

  const _BudgetGauge({required this.spent, required this.budget});

  @override
  Widget build(BuildContext context) {
    final ratio = budget <= 0 ? 0.0 : (spent / budget);
    final clamped = ratio.clamp(0.0, 1.0);

    Color activeColor;
    Color softColor;
    String label;

    if (ratio <= 0.60) {
      activeColor = const Color(0xFF22C55E);
      softColor = const Color.fromRGBO(34, 197, 94, 0.16);
      label = "On Budget";
    } else if (ratio <= 1.0) {
      activeColor = const Color(0xFFF59E0B);
      softColor = const Color.fromRGBO(245, 158, 11, 0.16);
      label = "Moderate";
    } else {
      activeColor = const Color(0xFFEF4444);
      softColor = const Color.fromRGBO(239, 68, 68, 0.16);
      label = "Exceeded";
    }

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 220,
                width: 220,
                child: PieChart(
                  PieChartData(
                    startDegreeOffset: 180,
                    sectionsSpace: 0,
                    centerSpaceRadius: 78,
                    pieTouchData: PieTouchData(enabled: false),
                    sections: [
                      PieChartSectionData(
                        color: activeColor,
                        value: clamped * 100,
                        radius: 22,
                        title: "",
                      ),
                      PieChartSectionData(
                        color: softColor,
                        value: (1 - clamped) * 100,
                        radius: 22,
                        title: "",
                      ),
                      PieChartSectionData(
                        color: Colors.transparent,
                        value: 100,
                        radius: 0,
                        title: "",
                      ),
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: activeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "AED ${spent.toStringAsFixed(0)}",
                    style: GoogleFonts.baloo2(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF2B103C),
                    ),
                  ),
                  Text(
                    "of AED ${budget.toStringAsFixed(0)}",
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color.fromRGBO(58, 27, 82, 0.65),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: clamped,
            backgroundColor: softColor,
            valueColor: AlwaysStoppedAnimation<Color>(activeColor),
          ),
        ),
      ],
    );
  }
}

class _MonthlyBars extends StatelessWidget {
  final List<_MonthAgg> months;
  final int selectedIndex;
  final ValueChanged<int> onTouched;

  const _MonthlyBars({
    required this.months,
    required this.selectedIndex,
    required this.onTouched,
  });

  @override
  Widget build(BuildContext context) {
    final last = months.length <= 6
        ? months
        : months.sublist(months.length - 6);

    final maxY = last.fold<double>(
      0,
      (p, m) => max(p, max(m.income, max(m.expenses, m.forecast))),
    );

    final roundedMaxY = maxY <= 0
        ? 100
        : ((maxY / 100).ceil() * 100).toDouble();

    final groups = <BarChartGroupData>[];

    for (int i = 0; i < last.length; i++) {
      final m = last[i];
      final touched = i == selectedIndex;

      groups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 8,
          showingTooltipIndicators: touched ? [0, 1, 2] : [],
          barRods: [
            BarChartRodData(
              toY: m.income,
              width: 14,
              borderRadius: BorderRadius.circular(5),
              color: const Color(0xFF22C55E),
            ),
            BarChartRodData(
              toY: m.expenses,
              width: 14,
              borderRadius: BorderRadius.circular(5),
              color: const Color(0xFFEF4444),
            ),
            BarChartRodData(
              toY: m.forecast,
              width: 14,
              borderRadius: BorderRadius.circular(5),
              color: const Color(0xFF8F7BFF),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 320,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: roundedMaxY * 1.1,
              alignment: BarChartAlignment.spaceAround,
              groupsSpace: 18,
              barGroups: groups,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                horizontalInterval: roundedMaxY / 5,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: Color.fromRGBO(58, 27, 82, 0.10),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: roundedMaxY / 5,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(0),
                        style: GoogleFonts.baloo2(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3A1B52),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= last.length) {
                        return const SizedBox.shrink();
                      }
                      final d = last[i].date;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          "${d.month}/${d.year.toString().substring(2)}",
                          style: GoogleFonts.baloo2(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF3A1B52),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions ||
                      response == null ||
                      response.spot == null) {
                    onTouched(-1);
                    return;
                  }
                  onTouched(response.spot!.touchedBarGroupIndex);
                },
                touchTooltipData: BarTouchTooltipData(
                  tooltipRoundedRadius: 14,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final m = last[group.x.toInt()];
                    final label = rodIndex == 0
                        ? "Income"
                        : rodIndex == 1
                        ? "Expenses"
                        : "Forecast";

                    return BarTooltipItem(
                      "${m.date.month}/${m.date.year.toString().substring(2)}\n$label\nAED ${rod.toY.toStringAsFixed(0)}",
                      GoogleFonts.baloo2(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: const [
            _LegendChip(label: "Income", color: Color(0xFF22C55E)),
            _LegendChip(label: "Expenses", color: Color(0xFFEF4444)),
            _LegendChip(label: "Forecast", color: Color(0xFF8F7BFF)),
          ],
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color.fromRGBO(255, 255, 255, 0.72),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.baloo2(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TrendLine extends StatelessWidget {
  final List<_MonthAgg> months;
  final int selectedIndex;
  final ValueChanged<int> onTouched;

  const _TrendLine({
    required this.months,
    required this.selectedIndex,
    required this.onTouched,
  });

  @override
  Widget build(BuildContext context) {
    final last12 = months.length <= 12
        ? months
        : months.sublist(months.length - 12);

    final points = <FlSpot>[];
    for (int i = 0; i < last12.length; i++) {
      points.add(FlSpot(i.toDouble(), last12[i].expenses));
    }

    final maxY = last12.isEmpty
        ? 0.0
        : last12.map((m) => m.expenses).reduce(max);

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY == 0 ? 10 : maxY * 1.15,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            horizontalInterval: maxY == 0 ? 10 : maxY / 5,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: Color.fromRGBO(58, 27, 82, 0.08),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: maxY == 0 ? 10 : maxY / 4,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(0),
                    style: GoogleFonts.baloo2(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3A1B52),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= last12.length) {
                    return const SizedBox.shrink();
                  }
                  final d = last12[i].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "${d.month}/${d.year.toString().substring(2)}",
                      style: GoogleFonts.baloo2(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF3A1B52),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchCallback: (event, response) {
              if (!event.isInterestedForInteractions ||
                  response == null ||
                  response.lineBarSpots == null ||
                  response.lineBarSpots!.isEmpty) {
                onTouched(-1);
                return;
              }
              onTouched(response.lineBarSpots!.first.x.toInt());
            },
            getTouchedSpotIndicator: (barData, indicators) {
              return indicators.map((index) {
                return TouchedSpotIndicatorData(
                  const FlLine(
                    color: Color.fromRGBO(143, 123, 255, 0.25),
                    strokeWidth: 2,
                  ),
                  FlDotData(
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                          radius: 5,
                          color: const Color(0xFF8F7BFF),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                  ),
                );
              }).toList();
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final d = last12[spot.x.toInt()].date;
                  return LineTooltipItem(
                    "${d.month}/${d.year.toString().substring(2)}\nAED ${spot.y.toStringAsFixed(0)}",
                    GoogleFonts.baloo2(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              color: const Color(0xFF8F7BFF),
              barWidth: 4,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, barData) =>
                    spot.x.toInt() == selectedIndex,
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.fromRGBO(143, 123, 255, 0.24),
                    Color.fromRGBO(143, 123, 255, 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
