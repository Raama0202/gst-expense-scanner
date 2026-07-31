import 'package:flutter/material.dart';

import 'package:gst_expense_scanner/shared/models/invoice_entity.dart';

/// Compact status badge for sync and approval states.
class StatusChip extends StatelessWidget {
  const StatusChip.sync(this.status, {super.key}) : approvalStatus = null;

  const StatusChip.approval(this.approvalStatus, {super.key}) : status = null;

  final SyncStatus? status;
  final ApprovalStatus? approvalStatus;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _resolve(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  (String, Color) _resolve(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (status != null) {
      return switch (status!) {
        SyncStatus.pending => ('Pending', scheme.tertiary),
        SyncStatus.uploading => ('Uploading', scheme.primary),
        SyncStatus.uploaded => ('Uploaded', Colors.green.shade700),
        SyncStatus.failed => ('Failed', scheme.error),
      };
    }
    return switch (approvalStatus!) {
      ApprovalStatus.pending => ('Review pending', scheme.outline),
      ApprovalStatus.uploaded => ('Submitted', scheme.primary),
      ApprovalStatus.approved => ('Approved', Colors.green.shade700),
      ApprovalStatus.rejected => ('Rejected', scheme.error),
      ApprovalStatus.returned => ('Returned', Colors.orange.shade800),
    };
  }
}
