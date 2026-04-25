import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/goal.dart';
import 'uuid.dart';

class Session {
  // ---------------- USER SESSION ----------------
  static const _kUser = "pfm_user";

  static String _manualTxKeyForUser(String userId) =>
      "pfm_manual_transactions_$userId";

  static Future<void> saveManualTransactions({
    required String userId,
    required List<dynamic> tx,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_manualTxKeyForUser(userId), jsonEncode(tx));
  }

  static Future<List<dynamic>> getManualTransactions({
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_manualTxKeyForUser(userId));
    if (s == null) return <dynamic>[];
    final v = jsonDecode(s);
    return (v is List) ? List<dynamic>.from(v) : <dynamic>[];
  }

  static Future<void> addManualTransaction({
    required String userId,
    required Map<String, dynamic> tx,
  }) async {
    final existing = await getManualTransactions(userId: userId);
    final updated = List<dynamic>.from(existing);
    updated.insert(0, tx);
    await saveManualTransactions(userId: userId, tx: updated);
  }

  static dynamic _jsonSafe(dynamic v) {
    if (v == null) return null;
    if (v is String || v is num || v is bool) return v;
    if (v is DateTime) return v.toIso8601String();

    if (v is List) {
      return v.map(_jsonSafe).toList();
    }

    if (v is Map) {
      final out = <String, dynamic>{};
      v.forEach((key, value) {
        out[key.toString()] = _jsonSafe(value);
      });
      return out;
    }

    return v.toString();
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final safeUser = Map<String, dynamic>.from(_jsonSafe(user) as Map);
    final encoded = jsonEncode(safeUser);
    await prefs.setString(_kUser, encoded);
    print("✅ Session.saveUser() saved: $safeUser");
  }

  static Future<Map<String, dynamic>?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kUser);

    if (s == null) {
      print("⚠️ Session.loadUser(): no user in SharedPreferences");
      return null;
    }

    final decoded = jsonDecode(s);

    if (decoded is Map<String, dynamic>) {
      print("✅ Session.loadUser() loaded: $decoded");
      return decoded;
    }

    print("❌ Session.loadUser(): stored user is not a Map");
    return null;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUser);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kUser);
  }

  static String? getUserId(Map<String, dynamic>? user) {
  if (user == null) return null;

  final email = (user["email"] ?? "").toString().trim().toLowerCase();
  if (email.isNotEmpty) return email;

  final id = (user["user_id"] ?? user["id"] ?? user["uid"] ?? user["userId"])
      ?.toString()
      .trim();

  if (id != null && id.isNotEmpty) return id;

  return null;
}

  // ---------------- REGISTERED USERS ----------------
  static const _kRegistered = "pfm_registered_users";

  static String _normEmail(String email) => email.trim().toLowerCase();

  static Future<Map<String, dynamic>> _loadRegisteredMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRegistered);
    if (raw == null || raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  }

  static Future<void> _saveRegisteredMap(Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRegistered, jsonEncode(map));
  }

  static Future<void> addRegisteredUser({
    required String email,
    required String name,
  }) async {
    final map = await _loadRegisteredMap();
    final e = _normEmail(email);
    map[e] = {"email": e, "name": name.trim()};
    await _saveRegisteredMap(map);
  }

  static Future<bool> isRegisteredEmail(String email) async {
    final map = await _loadRegisteredMap();
    final e = _normEmail(email);
    return map.containsKey(e);
  }

  static Future<String?> getRegisteredName(String email) async {
    final map = await _loadRegisteredMap();
    final e = _normEmail(email);
    final v = map[e];
    if (v is Map<String, dynamic>) {
      final n = (v["name"] ?? "").toString().trim();
      return n.isEmpty ? null : n;
    }
    return null;
  }

  // ---------------- GAMIFICATION ----------------
  static String _gamificationKeyForUser(String userId) =>
      "pfm_gamification_$userId";

  static Future<Map<String, dynamic>> _getGamificationMap({
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_gamificationKeyForUser(userId));

    if (s == null) {
      return {
        'points': 0,
        'badges': <String>[],
        'streak': 0,
        'level': 0,
        'lastActivity': DateTime.now().toIso8601String(),
      };
    }

    final obj = jsonDecode(s);
    if (obj is Map<String, dynamic>) {
      return {
        'points': obj['points'] ?? 0,
        'badges': List<String>.from(obj['badges'] ?? []),
        'streak': obj['streak'] ?? 0,
        'level': obj['level'] ?? 0,
        'lastActivity':
            (obj['lastActivity'] ?? DateTime.now().toIso8601String())
                .toString(),
      };
    }

    return {
      'points': 0,
      'badges': <String>[],
      'streak': 0,
      'level': 0,
      'lastActivity': DateTime.now().toIso8601String(),
    };
  }

  static Future<void> _saveGamificationMap({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gamificationKeyForUser(userId), jsonEncode(data));
  }

  static Future<int> getPoints({required String userId}) async {
    final data = await _getGamificationMap(userId: userId);
    return (data['points'] ?? 0) as int;
  }

  static Future<int> getUserPoints({required String userId}) async {
    return getPoints(userId: userId);
  }

  static Future<List<String>> getUnlockedBadges({required String userId}) async {
    final data = await _getGamificationMap(userId: userId);
    return List<String>.from(data['badges'] ?? []);
  }

  static Future<int> getStreak({required String userId}) async {
    final data = await _getGamificationMap(userId: userId);
    return (data['streak'] ?? 0) as int;
  }

  static int getLevel(int points) {
    if (points < 100) return 0;
    if (points < 500) return 1;
    if (points < 2000) return 2;
    if (points < 5000) return 3;
    return 4;
  }

  static Future<int> getUserLevel({required String userId}) async {
    final points = await getUserPoints(userId: userId);
    return getLevel(points);
  }

  static Future<void> _awardPoints({
    required String userId,
    required int amount,
    required String reason,
  }) async {
    final data = await _getGamificationMap(userId: userId);
    final newPoints = ((data['points'] ?? 0) as int) + amount;

    data['points'] = newPoints;
    data['level'] = getLevel(newPoints);

    await _saveGamificationMap(userId: userId, data: data);
    print("🎉 Awarded $amount pts to $userId ($reason) | Total: $newPoints");
    await _updateStreak(userId: userId);
  }

  static Future<void> unlockBadgeForUser({
    required String userId,
    required String badgeId,
  }) async {
    final data = await _getGamificationMap(userId: userId);
    final badges = List<String>.from(data['badges'] ?? []);

    if (!badges.contains(badgeId)) {
      badges.add(badgeId);
      data['badges'] = badges;
      await _saveGamificationMap(userId: userId, data: data);
      print("🏆 Unlocked badge '$badgeId' for $userId");
    }
  }

  static Future<void> _updateStreak({required String userId}) async {
    final data = await _getGamificationMap(userId: userId);
    final now = DateTime.now();
    final last = DateTime.tryParse(
          (data['lastActivity'] ?? DateTime.now().toIso8601String()).toString(),
        ) ??
        now;

    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(last.year, last.month, last.day);

    if (today.difference(lastDay).inDays == 0) {
      // same day
    } else if (today.difference(lastDay).inDays == 1) {
      data['streak'] = ((data['streak'] ?? 0) as int) + 1;
    } else {
      data['streak'] = 1;
    }

    data['lastActivity'] = now.toIso8601String();
    await _saveGamificationMap(userId: userId, data: data);
  }

  // ---------------- TOTALS ----------------
  static const _kTotals = "pfm_totals";

  static Future<void> saveTotals(Map<String, dynamic> totals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTotals, jsonEncode(totals));
  }

  static Future<Map<String, dynamic>> getTotals() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kTotals);
    if (s == null) return {"balance": 0, "income": 0, "expenses": 0};
    final obj = jsonDecode(s);
    if (obj is Map<String, dynamic>) return obj;
    return {"balance": 0, "income": 0, "expenses": 0};
  }

  // ---------------- GOALS ----------------
  static String _goalsKeyForUser(String userId) => "pfm_goals_$userId";

  static Future<List<Goal>> getGoalsForUser({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_goalsKeyForUser(userId)) ?? [];
    final goals =
        jsonList.map((jsonStr) => Goal.fromJson(jsonDecode(jsonStr))).toList();

    for (int i = 0; i < goals.length; i++) {
      if (goals[i].id.isEmpty) {
        goals[i] = Goal(
          id: SimpleUuid.generate(),
          name: goals[i].name,
          targetAmount: 1000,
          savedAmount: 0,
          targetDate: DateTime.now().add(const Duration(days: 30)),
        );
      }
    }
    return goals;
  }

  static Future<void> saveGoalsForUser({
    required String userId,
    required List<Goal> goals,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = goals.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList(_goalsKeyForUser(userId), jsonList);
    print("Saved ${goals.length} goals for $userId");
  }

  static Future<Goal?> createGoal({
    required String userId,
    required String name,
    required double targetAmount,
    DateTime? targetDate,
  }) async {
    final id = SimpleUuid.generate();
    final goal = Goal(
      id: id,
      name: name,
      targetAmount: targetAmount,
      savedAmount: 0,
      targetDate: targetDate ?? DateTime.now().add(const Duration(days: 30)),
    );

    final goals = await getGoalsForUser(userId: userId);
    goals.insert(0, goal);
    await saveGoalsForUser(userId: userId, goals: goals);

    await _awardPoints(
      userId: userId,
      amount: 10,
      reason: 'goal_created',
    );
    await unlockBadgeForUser(
      userId: userId,
      badgeId: 'first_goal',
    );

    return goal;
  }

  static Future<bool> updateGoal({
    required String userId,
    required Goal updatedGoal,
  }) async {
    final goals = await getGoalsForUser(userId: userId);
    final index = goals.indexWhere((g) => g.id == updatedGoal.id);
    if (index == -1) return false;

    final wasCompleted = goals[index].isCompleted;
    final newGoals = List<Goal>.from(goals)..[index] = updatedGoal;

    await saveGoalsForUser(userId: userId, goals: newGoals);
    await _awardPoints(
      userId: userId,
      amount: 5,
      reason: 'goal_updated',
    );

    if (!wasCompleted && updatedGoal.isCompleted) {
      await _awardPoints(
        userId: userId,
        amount: 50,
        reason: 'goal_completed',
      );
      await unlockBadgeForUser(
        userId: userId,
        badgeId: 'goal_complete',
      );
    }

    return true;
  }

  static Future<bool> deleteGoal({
    required String userId,
    required String goalId,
  }) async {
    final goals = await getGoalsForUser(userId: userId);
    final newGoals = goals.where((g) => g.id != goalId).toList();
    await saveGoalsForUser(userId: userId, goals: newGoals);
    return true;
  }

  // ---------------- LEAN DATA ----------------
  static const _kLeanAccounts = "pfm_lean_accounts";
  static const _kLeanTransactions = "pfm_lean_transactions";
  static const _kLeanIdentity = "pfm_lean_identity";
  static const _kConnectedBanks = "pfm_connected_banks";
  static const _kSelectedBankId = "pfm_selected_bank_id";

  static Future<void> saveSelectedBankId(String? bankId) async {
    final prefs = await SharedPreferences.getInstance();
    if (bankId == null || bankId.trim().isEmpty) {
      await prefs.remove(_kSelectedBankId);
    } else {
      await prefs.setString(_kSelectedBankId, bankId.trim());
    }
  }

  static Future<String?> getSelectedBankId() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_kSelectedBankId);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  static Future<void> disconnectBank(String bankId) async {
    final banks = await getConnectedBanks();
    final accounts = await getLeanAccounts();
    final tx = await getLeanTransactions();

    final remainingBanks = banks
        .where((b) => (b is Map) && (b["id"]?.toString() != bankId))
        .toList();

    final remainingAccounts = accounts
        .where((a) => (a is Map) && (a["bank_id"]?.toString() != bankId))
        .toList();

    final remainingTx = tx
        .where((t) => (t is Map) && (t["bank_id"]?.toString() != bankId))
        .toList();

    await saveConnectedBanks(remainingBanks);
    await saveLeanAccounts(remainingAccounts);
    await saveLeanTransactions(remainingTx);

    final selected = await getSelectedBankId();
    if (selected == bankId) {
      final nextId = remainingBanks.isNotEmpty
          ? (remainingBanks.first as Map)["id"]?.toString()
          : null;
      await saveSelectedBankId(nextId);
    }
  }

  static Future<void> saveLeanAccounts(List<dynamic> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLeanAccounts, jsonEncode(accounts));
  }

  static Future<List<dynamic>> getLeanAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kLeanAccounts);
    if (s == null) return [];
    final v = jsonDecode(s);
    return (v is List) ? v : [];
  }

  static Future<void> saveLeanTransactions(List<dynamic> tx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLeanTransactions, jsonEncode(tx));
  }

  static Future<List<dynamic>> getLeanTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kLeanTransactions);
    if (s == null) return [];
    final v = jsonDecode(s);
    return (v is List) ? v : [];
  }

  static Future<void> saveLeanIdentity(Map<String, dynamic> identity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLeanIdentity, jsonEncode(identity));
  }

  static Future<Map<String, dynamic>> getLeanIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLeanIdentity);
    if (raw == null || raw.isEmpty) return {};
    final obj = jsonDecode(raw);
    if (obj is Map) return Map<String, dynamic>.from(obj);
    return {};
  }

  static Future<void> saveConnectedBanks(List<dynamic> banks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConnectedBanks, jsonEncode(banks));
  }

  static Future<List<dynamic>> getConnectedBanks() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kConnectedBanks);
    if (s == null) return [];
    final v = jsonDecode(s);
    return (v is List) ? v : [];
  }

  static const _walletSummaryOverride = "pfm_wallet_summary_override";

  static Future<void> saveWalletSummary(Map<String, dynamic> summary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_walletSummaryOverride, jsonEncode(summary));
  }

  static Future<Map<String, dynamic>?> getWalletSummaryOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_walletSummaryOverride);
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> getWalletSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_walletSummaryOverride);
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  static Future<void> clearWalletSummaryOverride() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_walletSummaryOverride);
  }
}