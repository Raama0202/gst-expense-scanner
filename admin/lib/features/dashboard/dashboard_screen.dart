import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../shared/widgets.dart';

final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final response = await ref.watch(dioProvider).get(ApiPaths.dashboard);
  return Map<String, dynamic>.from(response.data as Map);
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    return ContentPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Dashboard',
            subtitle: 'A live view of invoice activity and review workload.',
          ),
          const SizedBox(height: 28),
          state.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => ErrorPanel(
              message: apiError(error),
              onRetry: () => ref.invalidate(dashboardProvider),
            ),
            data: (data) {
              final metrics = [
                (
                  'Pending review',
                  data['pendingInvoices'] ?? data['pending'] ?? 0,
                  Icons.pending_actions,
                ),
                (
                  "Today's uploads",
                  data['todayUploads'] ?? data['uploadedToday'] ?? 0,
                  Icons.upload_file,
                ),
                (
                  'Approved',
                  data['approvedCount'] ?? data['approved'] ?? 0,
                  Icons.check_circle_outline,
                ),
                (
                  'Rejected',
                  data['rejectedCount'] ?? data['rejected'] ?? 0,
                  Icons.cancel_outlined,
                ),
              ];
              return LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth < 650
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 48) / 4;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: metrics
                        .map(
                          (m) => SizedBox(
                            width: width,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(22),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      m.$3,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      '${m.$2}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.displaySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      m.$1,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
