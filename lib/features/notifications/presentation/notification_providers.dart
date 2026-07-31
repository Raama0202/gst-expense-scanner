import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gst_expense_scanner/core/di/providers.dart';
import 'package:gst_expense_scanner/shared/models/notification_entity.dart';

import '../data/notification_local_datasource.dart';
import '../data/notification_remote_datasource.dart';
import '../data/notification_repository.dart';

final notificationLocalDataSourceProvider =
    Provider<NotificationLocalDataSource>((ref) {
  return NotificationLocalDataSource(ref.watch(localDatabaseProvider));
});

final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
  return NotificationRemoteDataSource(ref.watch(apiClientProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    remote: ref.watch(notificationRemoteDataSourceProvider),
    local: ref.watch(notificationLocalDataSourceProvider),
  );
});

final notificationsListProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.fetchAndCache();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  ref.watch(notificationsListProvider);
  return ref.watch(notificationRepositoryProvider).unreadCount();
});
