import 'package:flutter/material.dart';
import 'package:health_ok/src/services/guild_service.dart';
import 'package:health_ok/src/theme/app_colors.dart';

/// Guild leaderboard comparing player against simulated members.
class GuildScreen extends StatefulWidget {
  const GuildScreen({super.key});

  @override
  State<GuildScreen> createState() => _GuildScreenState();
}

class _GuildScreenState extends State<GuildScreen> {
  List<GuildMember> _members = [];
  bool _loading = true;
  int? _myPosition;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final members = await GuildService.getLeaderboard();
    final pos = await GuildService.getPlayerPosition();
    if (!mounted) return;
    setState(() {
      _members = members;
      _myPosition = pos;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:  BoxDecoration(gradient: AppColors.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon:  Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title:  Text(
            'Guild Leaderboard',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Text('⚔️', style: TextStyle(fontSize: 36)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Shadow Vanguard',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    '${_members.length} hunters • Rank: ${_getGuildRank()}'
                                    '${_myPosition != null ? '  •  You: #$_myPosition' : ''}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _members.length,
                          itemBuilder: (_, i) {
                            final m = _members[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _LeaderboardTile(
                                member: m,
                                rank: i + 1,
                                isTop3: i < 3,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  String _getGuildRank() {
    final avgLevel =
        _members.fold<int>(0, (s, m) => s + m.level) / _members.length;
    if (avgLevel >= 15) return 'S';
    if (avgLevel >= 10) return 'A';
    if (avgLevel >= 5) return 'B';
    return 'C';
  }
}

class _LeaderboardTile extends StatelessWidget {
  final GuildMember member;
  final int rank;
  final bool isTop3;

  const _LeaderboardTile({
    required this.member,
    required this.rank,
    required this.isTop3,
  });

  @override
  Widget build(BuildContext context) {
    final colors = {
      1: const Color(0xFFFBBF24), // gold
      2: const Color(0xFF94A3B8), // silver
      3: const Color(0xFFCD7F32), // bronze
    };
    final rankColor = colors[rank] ?? AppColors.textMuted;
    final bg = member.isPlayer
        ? AppColors.primary.withOpacity(0.08)
        : Theme.of(context).colorScheme.surface;
    final border = member.isPlayer
        ? AppColors.primary
        : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: border,
          width: member.isPlayer ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                rank <= 3 ? _medal(rank) : '$rank',
                style: TextStyle(
                  fontSize: rank <= 3 ? 22 : 14,
                  fontWeight: FontWeight.w800,
                  color: rankColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: member.isPlayer
                  ? AppColors.primary.withOpacity(0.15)
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                member.name[0],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: member.isPlayer ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: member.isPlayer ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    if (member.isPlayer) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('YOU',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Lv ${member.level} • ${_formatSteps(member.stepsPerDay)}/day • ${member.streakDays}d streak',
                  style:  TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              member.rank,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: rankColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _medal(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '$rank';
    }
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) return '${(steps / 1000).toStringAsFixed(1)}k';
    return '$steps';
  }
}