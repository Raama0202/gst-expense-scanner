import 'package:gst_expense_scanner/shared/models/notification_entity.dart';

import 'notification_local_datasource.dart';
import 'notification_remote_datasource.dart';

/// Coordinates remote fetch and local notification cache.
class NotificationRepository {
  NotificationRepository({
    required NotificationRemoteDataSource remote,
    required NotificationLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  final NotificationRemoteDataSource _remote;
  final NotificationLocalDataSource _local;

  Future<List<AppNotification>> fetchAndCache() async {
    try {
      final remote = await _remote.fetchNotifications();
      await _local.saveAll(remote);
      return remote;
    } catch (_) {
      return _local.readAll();
    }
  }

  List<AppNotification> readCached() => _local.readAll();

  Future<void> markRead(String id) async {
    await _local.markReadLocal(id);
    try {
      await _remote.markRead(id);
    } catch (_) {
      // Local mark is sufficient offline.
    }
  }

  int unreadCount() => _local.unreadCount();
}
