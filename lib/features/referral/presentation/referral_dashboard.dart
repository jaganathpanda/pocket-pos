import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pocket_pos/features/referral/domain/referral.dart';
import 'package:pocket_pos/features/store/presentation/store_auth_controller.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utilities/money.dart';
import '../providers/referral_providers.dart';

class ReferralDashboard extends ConsumerStatefulWidget {
  const ReferralDashboard({super.key});

  @override
  ConsumerState<ReferralDashboard> createState() => _ReferralDashboardState();
}

class _ReferralDashboardState extends ConsumerState<ReferralDashboard> {
  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(storeSessionProvider)?.uid ?? '';
    final cs = Theme.of(context).colorScheme;

    if (uid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please login to view referrals.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Refer & Earn'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primary.withOpacity(0.06),
              cs.surface,
              cs.surface,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildReferralCodeCard(context, uid, cs),
              const SizedBox(height: 16),
              _buildStatsCards(uid, cs),
              const SizedBox(height: 16),
              _buildHowItWorks(cs),
              const SizedBox(height: 16),
              _buildReferralList(uid, cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferralCodeCard(
    BuildContext context,
    String uid,
    ColorScheme cs,
  ) {
    final codeAsync = ref.watch(referralCodeProvider(uid));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'MYPOCKETPOS REFERRAL CLUB',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your Referral Code',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            codeAsync.when(
              data: (code) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      code,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: code));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Referral code copied.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy Code'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        onPressed: () => _shareReferral(code),
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Share'),
                      ),
                    ],
                  ),
                ],
              ),
              loading: () =>
                  const CircularProgressIndicator(color: Colors.white),
              error: (e, _) => Text(
                'Error: $e',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share your code and earn rewards from first purchase.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(String uid, ColorScheme cs) {
    final statsAsync = ref.watch(userReferralStatsProvider(uid));

    return statsAsync.when(
      data: (stats) => LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth < 620
              ? (constraints.maxWidth - 12) / 2
              : (constraints.maxWidth - 36) / 4;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: cardWidth,
                child: _StatCard(
                  label: 'Total Referrals',
                  value: stats.totalReferrals.toString(),
                  color: cs.primary,
                  icon: Icons.group_add_rounded,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _StatCard(
                  label: 'Completed',
                  value: stats.completedReferrals.toString(),
                  color: Colors.teal,
                  icon: Icons.task_alt_rounded,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _StatCard(
                  label: 'Earned',
                  value: formatInr(stats.totalRewards),
                  color: Colors.orange,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: _StatCard(
                  label: 'Pending Reward',
                  value: formatInr(stats.pendingRewards),
                  color: Colors.indigo,
                  icon: Icons.timelapse_rounded,
                ),
              ),
            ],
          );
        },
      ),
      loading: () => const Row(
        children: [
          Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
      error: (e, _) => Row(
        children: [
          Expanded(
            child: Center(
              child:
                  Text('Error: $e', style: const TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How It Works',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Simple 4-step flow to unlock rewards for every successful referral.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            _StepItem(
              icon: Icons.share_rounded,
              title: 'Share Your Code',
              description: 'Share your referral code with friends.',
              color: cs.primary,
            ),
            const _StepItem(
              icon: Icons.person_add_alt_1_rounded,
              title: 'They Sign Up',
              description: 'Friend signs up using your referral code.',
              color: Colors.teal,
            ),
            const _StepItem(
              icon: Icons.shopping_bag_rounded,
              title: 'They Make a Purchase',
              description:
                  'When they make their first purchase, you earn rewards.',
              color: Colors.orange,
            ),
            const _StepItem(
              icon: Icons.workspace_premium_rounded,
              title: 'Get Rewarded',
              description: 'Earn rewards for every successful referral!',
              color: Colors.indigo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralList(String uid, ColorScheme cs) {
    final referralsAsync = ref.watch(userReferralsProvider(uid));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt_rounded, color: cs.primary),
                const SizedBox(width: 8),
                const Text(
                  'Your Referrals',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            referralsAsync.when(
              data: (referrals) {
                if (referrals.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No referrals yet. Share your code to get started!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: referrals.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final referral = referrals[index];
                    return _ReferralTile(referral: referral);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
  }

  void _shareReferral(String code) {
    final message = '''
Join MyPocketPOS and get started.

Use my referral code: $code

Download the app and enter this code to get exclusive rewards.

#MyPocketPOS #Referral
''';
    Share.share(message);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  const _StepItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.14),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralTile extends StatelessWidget {
  const _ReferralTile({required this.referral});

  final Referral referral;

  @override
  Widget build(BuildContext context) {
    final statusColor = referral.isRewarded
        ? Colors.green
        : referral.isCompleted
            ? Colors.orange
            : Colors.grey;

    final statusLabel = referral.status.name.toUpperCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.15),
        child: Icon(
          referral.isRewarded
              ? Icons.check_circle_rounded
              : referral.isCompleted
                  ? Icons.hourglass_bottom_rounded
                  : Icons.schedule_rounded,
          color: statusColor,
          size: 18,
        ),
      ),
      title: Text(
        referral.referredName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        DateFormat('dd MMM yyyy').format(referral.createdAt),
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (referral.isRewarded)
            Text(
              '+${formatInr(referral.rewardAmount)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
