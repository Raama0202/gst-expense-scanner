import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gst_expense_scanner/features/home/presentation/providers/home_providers.dart';
import 'package:gst_expense_scanner/features/notifications/presentation/notification_providers.dart';
import 'package:gst_expense_scanner/features/sync/presentation/sync_providers.dart';
import 'package:gst_expense_scanner/shared/widgets/app_scaffold.dart';
import 'package:gst_expense_scanner/shared/widgets/primary_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final companyName = ref.watch(homeCompanyNameProvider);
    final employeeName = ref.watch(homeEmployeeNameProvider);
    final todayCount = ref.watch(homeTodayUploadCountProvider);
    final pendingSync = ref.watch(homePendingSyncCountProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return AppScaffold(
      title: companyName.isEmpty ? 'Home' : companyName,
      showBack: false,
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.push('/notifications'),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hello, $employeeName',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Capture GST invoices quickly and sync when online.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: "Today's uploads",
                    value: todayCount.when(
                      data: (v) => '$v',
                      loading: () => '…',
                      error: (_, __) => '—',
                    ),
                    icon: Icons.upload_file,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Pending sync',
                    value: '$pendingSync',
                    icon: Icons.sync,
                    highlight: pendingSync > 0,
                  ),
                ),
              ],
            ),
            if (syncStatus.state == SyncStatusView.syncing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text(
                'Syncing uploads…',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (syncStatus.lastError != null) ...[
              const SizedBox(height: 12),
              Text(
                syncStatus.lastError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const Spacer(),
            PrimaryButton(
              label: 'Scan Invoice',
              icon: Icons.document_scanner_outlined,
              onPressed: () => context.push('/scan-processing'),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'My Uploads',
              icon: Icons.folder_outlined,
              onPressed: () => context.push('/uploads'),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: syncStatus.state == SyncStatusView.syncing
                  ? 'Syncing…'
                  : 'Sync Now',
              icon: Icons.cloud_upload_outlined,
              loading: syncStatus.state == SyncStatusView.syncing,
              onPressed: syncStatus.state == SyncStatusView.syncing
                  ? null
                  : () => ref.read(syncStatusProvider.notifier).syncNow(),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push('/profile'),
              child: const Text('Profile'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: highlight
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium,
            ),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
