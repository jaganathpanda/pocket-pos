import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/referral.dart';
import '../providers/referral_providers.dart';

class ReferralSettingsPage extends ConsumerStatefulWidget {
  const ReferralSettingsPage({super.key});

  @override
  ConsumerState<ReferralSettingsPage> createState() =>
      _ReferralSettingsPageState();
}

class _ReferralSettingsPageState extends ConsumerState<ReferralSettingsPage> {
  late TextEditingController _rewardAmountCtrl;
  late TextEditingController _expiryDaysCtrl;
  late TextEditingController _maxReferralsCtrl;
  bool _enabled = true;
  RewardType _rewardType = RewardType.credit;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _rewardAmountCtrl = TextEditingController();
    _expiryDaysCtrl = TextEditingController();
    _maxReferralsCtrl = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _rewardAmountCtrl.dispose();
    _expiryDaysCtrl.dispose();
    _maxReferralsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await ref.read(referralSettingsProvider.future);
    setState(() {
      _enabled = settings.enabled;
      _rewardType = settings.rewardType;
      _rewardAmountCtrl.text = settings.rewardAmount.toString();
      _expiryDaysCtrl.text = settings.expiryDays.toString();
      _maxReferralsCtrl.text = settings.maxReferrals?.toString() ?? '';
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = ReferralSettings(
        enabled: _enabled,
        rewardType: _rewardType,
        rewardAmount: double.tryParse(_rewardAmountCtrl.text) ?? 100,
        expiryDays: int.tryParse(_expiryDaysCtrl.text) ?? 30,
        maxReferrals: _maxReferralsCtrl.text.isNotEmpty
            ? int.tryParse(_maxReferralsCtrl.text)
            : null,
      );
      await ref.read(referralRepositoryProvider).updateSettings(settings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Settings'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // ── Enable/Disable ──
            SwitchListTile(
              title: const Text('Enable Referral Program'),
              subtitle: const Text('Toggle the referral program on/off'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const Divider(),
            // ── Reward Type ──
            DropdownButtonFormField<RewardType>(
              value: _rewardType,
              decoration: const InputDecoration(
                labelText: 'Reward Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: RewardType.credit,
                  child: Text('Store Credit'),
                ),
                DropdownMenuItem(
                  value: RewardType.discount,
                  child: Text('Discount Coupon'),
                ),
                DropdownMenuItem(
                  value: RewardType.cash,
                  child: Text('Cash'),
                ),
                DropdownMenuItem(
                  value: RewardType.points,
                  child: Text('Loyalty Points'),
                ),
              ],
              onChanged: (v) => setState(() => _rewardType = v!),
            ),
            const SizedBox(height: 12),
            // ── Reward Amount ──
            TextFormField(
              controller: _rewardAmountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reward Amount',
                border: OutlineInputBorder(),
                helperText: 'Amount to give per successful referral',
              ),
            ),
            const SizedBox(height: 12),
            // ── Expiry Days ──
            TextFormField(
              controller: _expiryDaysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Expiry Days',
                border: OutlineInputBorder(),
                helperText: 'Days after which referral expires',
              ),
            ),
            const SizedBox(height: 12),
            // ── Max Referrals ──
            TextFormField(
              controller: _maxReferralsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max Referrals (Optional)',
                border: OutlineInputBorder(),
                helperText: 'Leave empty for unlimited',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _saveSettings,
                child: const Text('Save Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
