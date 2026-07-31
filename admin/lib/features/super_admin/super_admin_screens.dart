import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../shared/widgets.dart';

final plansProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) async {
  final response = await ref.watch(dioProvider).get(ApiPaths.plans);
  return itemList(response.data);
});
final companiesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final response = await ref.watch(dioProvider).get(ApiPaths.companies);
      return itemList(response.data);
    });

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    Map<String, dynamic>? plan,
  ]) async {
    final name = TextEditingController(text: plan?['name']?.toString());
    final price = TextEditingController(
      text: (plan?['priceMonthly'] ?? plan?['price'])?.toString(),
    );
    final seats = TextEditingController(
      text: (plan?['seatLimit'] ?? plan?['seats'])?.toString(),
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(plan == null ? 'Create plan' : 'Edit plan'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Plan name'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monthly price'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: seats,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Seat limit'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final data = {
                  'name': name.text.trim(),
                  'priceMonthly': double.tryParse(price.text) ?? 0,
                  'seatLimit': int.tryParse(seats.text) ?? 0,
                };
                if (plan == null) {
                  await ref.read(dioProvider).post(ApiPaths.plans, data: data);
                } else {
                  await ref
                      .read(dioProvider)
                      .put('${ApiPaths.plans}/${plan['id']}', data: data);
                }
                if (context.mounted) Navigator.pop(context, true);
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(apiError(error))));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    price.dispose();
    seats.dispose();
    if (saved == true) ref.invalidate(plansProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    return ContentPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Plans',
            subtitle: 'Manage commercial plans, pricing and seat allowances.',
            action: FilledButton.icon(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Create plan'),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: plans.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => ErrorPanel(
                message: apiError(error),
                onRetry: () => ref.invalidate(plansProvider),
              ),
              data: (items) => items.isEmpty
                  ? const EmptyPanel(
                      icon: Icons.sell_outlined,
                      title: 'No plans created',
                      message: 'Create the first subscription plan.',
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          title: Text(
                            '${item['name']}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '₹${item['priceMonthly'] ?? item['price'] ?? 0}/month • ${item['seatLimit'] ?? item['seats'] ?? '—'} seats',
                          ),
                          trailing: IconButton(
                            onPressed: () => _edit(context, ref, item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
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

class CompaniesScreen extends ConsumerWidget {
  const CompaniesScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final industry = TextEditingController();
    final planId = TextEditingController();
    final seats = TextEditingController();
    String? activationCode;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              activationCode == null ? 'Create company' : 'Company created',
            ),
            content: SizedBox(
              width: 480,
              child: activationCode != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          size: 42,
                          color: Color(0xFF067647),
                        ),
                        const SizedBox(height: 16),
                        const Text('Activation code'),
                        const SizedBox(height: 8),
                        SelectableText(
                          activationCode!,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Copy this code now and share it securely with the company admin.',
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: name,
                          decoration: const InputDecoration(
                            labelText: 'Company name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: industry,
                          decoration: const InputDecoration(
                            labelText: 'Industry',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: planId,
                          decoration: const InputDecoration(
                            labelText: 'Plan ID',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: seats,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Seats'),
                        ),
                      ],
                    ),
            ),
            actions: [
              if (activationCode == null)
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              FilledButton(
                onPressed: activationCode != null
                    ? () => Navigator.pop(context, true)
                    : () async {
                        try {
                          final response = await ref
                              .read(dioProvider)
                              .post(
                                ApiPaths.companies,
                                data: {
                                  'name': name.text.trim(),
                                  'industry': industry.text.trim(),
                                  'planId': planId.text.trim(),
                                  'seats': int.tryParse(seats.text) ?? 0,
                                },
                              );
                          final data = Map<String, dynamic>.from(
                            response.data as Map,
                          );
                          setDialogState(() {
                            activationCode =
                                (data['activationCode'] ??
                                        data['activation_code'] ??
                                        'Created successfully')
                                    .toString();
                          });
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(apiError(error))),
                            );
                          }
                        }
                      },
                child: Text(activationCode == null ? 'Create company' : 'Done'),
              ),
            ],
          );
        },
      ),
    );
    name.dispose();
    industry.dispose();
    planId.dispose();
    seats.dispose();
    if (created == true) ref.invalidate(companiesProvider);
  }

  Future<void> _action(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> company,
    String action,
  ) async {
    Map<String, dynamic> data = {};
    if (action == 'extend') {
      final days = TextEditingController(text: '30');
      final result = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Extend subscription'),
          content: TextField(
            controller: days,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Number of days'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, int.tryParse(days.text)),
              child: const Text('Extend'),
            ),
          ],
        ),
      );
      days.dispose();
      if (result == null) return;
      data = {'days': result};
    } else {
      final confirmed = await confirmAction(
        context,
        title: '${action[0].toUpperCase()}${action.substring(1)} company?',
        message: action == 'suspend'
            ? 'All company users will lose access until reactivated.'
            : 'The company and its admins will gain access.',
        confirmLabel: action[0].toUpperCase() + action.substring(1),
      );
      if (!confirmed) return;
    }
    try {
      await ref
          .read(dioProvider)
          .post('${ApiPaths.companies}/${company['id']}/$action', data: data);
      ref.invalidate(companiesProvider);
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
    final companies = ref.watch(companiesProvider);
    return ContentPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Companies',
            subtitle: 'Provision tenants and control subscription access.',
            action: FilledButton.icon(
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.add_business),
              label: const Text('Create company'),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: companies.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => ErrorPanel(
                message: apiError(error),
                onRetry: () => ref.invalidate(companiesProvider),
              ),
              data: (items) => items.isEmpty
                  ? const EmptyPanel(
                      icon: Icons.apartment_outlined,
                      title: 'No companies yet',
                      message: 'Create a company to issue its activation code.',
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final status =
                            (item['status'] ??
                                    (item['active'] == true
                                        ? 'active'
                                        : 'inactive'))
                                .toString();
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 9,
                          ),
                          title: Text(
                            '${item['name']}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${item['industry'] ?? 'Industry not set'} • ${item['planName'] ?? item['planId'] ?? 'No plan'} • ${item['seats'] ?? item['seatLimit'] ?? '—'} seats',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) =>
                                _action(context, ref, item, action),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                enabled: false,
                                child: StatusPill(status),
                              ),
                              const PopupMenuDivider(),
                              if (status != 'active')
                                const PopupMenuItem(
                                  value: 'activate',
                                  child: Text('Activate'),
                                ),
                              if (status == 'active')
                                const PopupMenuItem(
                                  value: 'suspend',
                                  child: Text('Suspend'),
                                ),
                              const PopupMenuItem(
                                value: 'extend',
                                child: Text('Extend subscription'),
                              ),
                            ],
                          ),
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
