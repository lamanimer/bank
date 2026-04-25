import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/session.dart';
import '../../models/badge.dart' as app_badge;

class GamificationScreen extends StatefulWidget {
  const GamificationScreen({super.key});

  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen> {
  int points = 0;
  int streak = 0;
  int level = 0;
  List<String> unlockedBadges = [];
  List<app_badge.Badge> allBadges = [];
  bool loading = true;

  final Map<int, String> levels = {
    0: 'Beginner',
    1: 'Saver',
    2: 'Smart Spender',
    3: 'Budget Master',
    4: 'Finance Hero',
  };

  final List<int> thresholds = [0, 100, 500, 2000, 5000];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await Session.loadUser();
    final userId = Session.getUserId(user);

    if (userId == null) {
      if (mounted) {
        setState(() {
          loading = false;
          allBadges = app_badge.Badge.predefined;
        });
      }
      return;
    }

    final pts = await Session.getPoints(userId: userId);
    final strk = await Session.getStreak(userId: userId);
    final badges = await Session.getUnlockedBadges(userId: userId);
    final lvl = await Session.getUserLevel(userId: userId);

    if (!mounted) return;

    setState(() {
      points = pts;
      streak = strk;
      unlockedBadges = badges;
      level = lvl;
      allBadges = app_badge.Badge.predefined;
      loading = false;
    });
  }

  int get pointsToNextLevel {
    if (level >= thresholds.length - 1) return 0;
    return thresholds[level + 1] - points;
  }

  double get levelProgress {
    if (level >= thresholds.length - 1) return 1.0;

    final currentMin = thresholds[level];
    final nextMin = thresholds[level + 1];
    final range = nextMin - currentMin;
    if (range <= 0) return 1.0;

    final progress = (points - currentMin) / range;
    return progress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFD6E6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Rewards & Achievements',
          style: GoogleFonts.baloo2(
            fontWeight: FontWeight.w900,
            color: const Color(0xFF3A1B52),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF3A1B52)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _PointsCard(points: points),
                    const SizedBox(height: 16),
                    _LevelCard(
                      level: level,
                      levelName: levels[level] ?? 'Beginner',
                      pointsToNext: pointsToNextLevel,
                      progress: levelProgress,
                    ),
                    const SizedBox(height: 16),
                    _StreakCard(streak: streak),
                    const SizedBox(height: 16),
                    _BadgesGrid(
                      allBadges: allBadges,
                      unlockedBadges: unlockedBadges,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  final int points;

  const _PointsCard({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8FAB), Color(0xFF8F7BFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8F7BFF).withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, size: 32, color: Colors.white.withOpacity(0.9)),
              const SizedBox(width: 12),
              Text(
                '$points',
                style: GoogleFonts.baloo2(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Total Points',
            style: GoogleFonts.baloo2(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final int level;
  final String levelName;
  final int pointsToNext;
  final double progress;

  const _LevelCard({
    required this.level,
    required this.levelName,
    required this.pointsToNext,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Current Level',
            style: GoogleFonts.baloo2(
              fontSize: 14,
              color: const Color(0xFF3A1B52).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            levelName,
            style: GoogleFonts.baloo2(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF2B103C),
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF8F7BFF),
                  ),
                ),
              ),
              Column(
                children: [
                  const Icon(
                    Icons.trending_up,
                    size: 32,
                    color: Color(0xFF8F7BFF),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Level $level',
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF2B103C),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (pointsToNext > 0) ...[
            const SizedBox(height: 16),
            Text(
              '$pointsToNext points to Level ${level + 1}',
              style: GoogleFonts.baloo2(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3A1B52).withOpacity(0.8),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              'Highest level reached!',
              style: GoogleFonts.baloo2(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3A1B52).withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;

  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade400,
            Colors.red.shade400,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade200.withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_fire_department,
            size: 36,
            color: Colors.white.withOpacity(0.95),
          ),
          const SizedBox(width: 16),
          Column(
            children: [
              Text(
                '$streak',
                style: GoogleFonts.baloo2(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              Text(
                'Day Streak',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgesGrid extends StatelessWidget {
  final List<app_badge.Badge> allBadges;
  final List<String> unlockedBadges;

  const _BadgesGrid({
    required this.allBadges,
    required this.unlockedBadges,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Achievements',
              style: GoogleFonts.baloo2(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF3A1B52),
              ),
            ),
            Text(
              '${unlockedBadges.length}/${allBadges.length}',
              style: GoogleFonts.baloo2(
                fontSize: 14,
                color: const Color(0xFF3A1B52).withOpacity(0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: allBadges.length,
          itemBuilder: (context, index) {
            final badge = allBadges[index];
            final unlocked = unlockedBadges.contains(badge.id);
            return _BadgeTile(
              badge: badge,
              unlocked: unlocked,
            );
          },
        ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final app_badge.Badge badge;
  final bool unlocked;

  const _BadgeTile({
    required this.badge,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked ? Colors.green.shade200 : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events,
            size: 32,
            color: unlocked ? Colors.green.shade600 : Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            badge.title,
            style: GoogleFonts.baloo2(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: unlocked ? Colors.green.shade800 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            unlocked ? '${badge.points} pts' : 'Locked',
            style: GoogleFonts.baloo2(
              fontSize: 10,
              color: unlocked ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (unlocked)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade400,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Unlocked',
                style: GoogleFonts.baloo2(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}