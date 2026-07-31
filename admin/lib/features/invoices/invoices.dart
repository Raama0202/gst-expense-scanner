import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/server_config.dart';
import '../../shared/widgets.dart';

class InvoiceRepository {
  InvoiceRepository(this._dio);
  final Dio _dio;
  Future<List<Map<String, dynamic>>> list(String status) async {
    final response = await _dio.get(
      ApiPaths.invoices,
      queryParameters: status == 'all' ? null : {'status': status},
    );
    return itemList(response.data);
  }

  Future<Map<String, dynamic>> detail(String id) async {
    final response = await _dio.get('${ApiPaths.invoices}/$id');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> decide(String id, String action, String? remarks) => _dio.post(
    '${ApiPaths.invoices}/$id/$action',
    data: {
      if (remarks != null && remarks.trim().isNotEmpty)
        'remarks': remarks.trim(),
    },
  );
}

final invoiceRepositoryProvider = Provider(
  (ref) => InvoiceRepository(ref.watch(dioProvider)),
);

class InvoiceStatusController extends Notifier<String> {
  @override
  String build() => 'pending';
  void select(String value) => state = value;
}

final invoiceStatusProvider = NotifierProvider<InvoiceStatusController, String>(
  InvoiceStatusController.new,
);
final invoicesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) {
    return ref
        .watch(invoiceRepositoryProvider)
        .list(ref.watch(invoiceStatusProvider));
  },
);
final invoiceDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, id) => ref.watch(invoiceRepositoryProvider).detail(id),
    );

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(invoiceStatusProvider);
    final invoices = ref.watch(invoicesProvider);
    return ContentPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Invoices',
            subtitle: 'Review uploaded invoices and track approval decisions.',
          ),
          const SizedBox(height: 24),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('All')),
              ButtonSegment(value: 'pending', label: Text('Pending')),
              ButtonSegment(value: 'approved', label: Text('Approved')),
              ButtonSegment(value: 'rejected', label: Text('Rejected')),
              ButtonSegment(value: 'returned', label: Text('Returned')),
            ],
            selected: {status},
            onSelectionChanged: (value) =>
                ref.read(invoiceStatusProvider.notifier).select(value.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 20),
          Card(
            child: invoices.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => ErrorPanel(
                message: apiError(error),
                onRetry: () => ref.invalidate(invoicesProvider),
              ),
              data: (items) => items.isEmpty
                  ? const EmptyPanel(
                      icon: Icons.receipt_long_outlined,
                      title: 'No invoices in this view',
                      message:
                          'Invoices will appear here as employees upload them.',
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final edited = item['editedData'] is Map
                            ? item['editedData'] as Map
                            : const {};
                        final date = item['uploadedAt'] ?? item['invoiceDate'];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(
                            (edited['vendorName'] ??
                                    item['vendorName'] ??
                                    item['invoiceNumber'] ??
                                    'Invoice')
                                .toString(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${item['employeeName'] ?? 'Employee'} • ${_formatDate(date)} • ₹${edited['totalAmount'] ?? edited['netAmount'] ?? item['amount'] ?? '—'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusPill(
                                (item['approvalStatus'] ??
                                        item['status'] ??
                                        'pending')
                                    .toString(),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => context.go('/invoices/${item['id']}'),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});
  final String invoiceId;

  Future<void> _decision(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final remarks = TextEditingController();
    final requiresRemarks = action != 'approve';
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} invoice'),
        content: TextField(
          controller: remarks,
          maxLines: 3,
          autofocus: requiresRemarks,
          decoration: InputDecoration(
            labelText: requiresRemarks
                ? 'Remarks (required)'
                : 'Remarks (optional)',
            hintText: 'Add context for the employee',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (requiresRemarks && remarks.text.trim().isEmpty) return;
              Navigator.pop(context, remarks.text);
            },
            child: Text(action[0].toUpperCase() + action.substring(1)),
          ),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      await ref
          .read(invoiceRepositoryProvider)
          .decide(invoiceId, action, result);
      ref.invalidate(invoiceDetailProvider(invoiceId));
      ref.invalidate(invoicesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice ${action}d successfully.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(invoiceDetailProvider(invoiceId));
    return ContentPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/invoices'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: PageHeader(
                  title: 'Invoice review',
                  subtitle:
                      'Compare captured and corrected values before deciding.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          detail.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => ErrorPanel(
              message: apiError(error),
              onRetry: () => ref.invalidate(invoiceDetailProvider(invoiceId)),
            ),
            data: (item) {
              final status =
                  (item['approvalStatus'] ?? item['status'] ?? 'pending')
                      .toString();
              final ocr = item['ocrData'] is Map
                  ? Map<String, dynamic>.from(item['ocrData'] as Map)
                  : <String, dynamic>{};
              final edited = item['editedData'] is Map
                  ? Map<String, dynamic>.from(item['editedData'] as Map)
                  : <String, dynamic>{};
              final image = ServerConfig.absoluteUrl(
                (item['imageUrl'] ??
                        item['originalImageUrl'] ??
                        item['thumbnailUrl'])
                    ?.toString(),
              );
              return Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final imagePanel = Card(
                        child: SizedBox(
                          height: 440,
                          child: image == null
                              ? const EmptyPanel(
                                  icon: Icons.image_not_supported_outlined,
                                  title: 'No image available',
                                  message:
                                      'The API did not return an invoice image URL.',
                                )
                              : InteractiveViewer(
                                  child: CachedNetworkImage(
                                    imageUrl: image,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    placeholder: (_, _) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    errorWidget: (_, _, _) => const Icon(
                                      Icons.broken_image_outlined,
                                      size: 48,
                                    ),
                                  ),
                                ),
                        ),
                      );
                      final dataPanel = Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Extracted data',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const Spacer(),
                                  StatusPill(status),
                                ],
                              ),
                              const SizedBox(height: 18),
                              _ComparisonTable(ocr: ocr, edited: edited),
                            ],
                          ),
                        ),
                      );
                      if (constraints.maxWidth < 850) {
                        return Column(
                          children: [
                            imagePanel,
                            const SizedBox(height: 16),
                            dataPanel,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: imagePanel),
                          const SizedBox(width: 16),
                          Expanded(child: dataPanel),
                        ],
                      );
                    },
                  ),
                  if (status == 'pending' || status == 'returned') ...[
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _decision(context, ref, 'return'),
                            icon: const Icon(Icons.undo),
                            label: const Text('Return'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _decision(context, ref, 'reject'),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                          ),
                          FilledButton.icon(
                            onPressed: () => _decision(context, ref, 'approve'),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.ocr, required this.edited});
  final Map<String, dynamic> ocr;
  final Map<String, dynamic> edited;
  @override
  Widget build(BuildContext context) {
    final keys = {...ocr.keys, ...edited.keys}.toList();
    if (keys.isEmpty) {
      return const EmptyPanel(
        icon: Icons.text_snippet_outlined,
        title: 'No extracted fields',
        message: 'OCR and edited data were empty in the API response.',
      );
    }
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      border: TableBorder.all(color: Theme.of(context).dividerColor),
      children: [
        const TableRow(
          children: [
            _Cell('Field', header: true),
            _Cell('OCR value', header: true),
            _Cell('Edited value', header: true),
          ],
        ),
        ...keys.map(
          (key) => TableRow(
            children: [
              _Cell(_label(key)),
              _Cell('${ocr[key] ?? '—'}'),
              _Cell('${edited[key] ?? '—'}'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.header = false});
  final String text;
  final bool header;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: Text(
      text,
      style: header ? const TextStyle(fontWeight: FontWeight.w700) : null,
    ),
  );
}

String _formatDate(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed == null
      ? '—'
      : DateFormat('dd MMM yyyy').format(parsed.toLocal());
}

String _label(String value) => value
    .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
    .split(' ')
    .map(
      (part) => part.isEmpty ? part : part[0].toUpperCase() + part.substring(1),
    )
    .join(' ');
