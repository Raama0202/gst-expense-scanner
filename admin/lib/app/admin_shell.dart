import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.location);
  final String label;
  final IconData icon;
  final String location;
}

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.session, required this.child});
  final AdminSession session;
  final Widget child;

  List<_Destination> get _destinations => session.role == AdminRole.superAdmin
      ? const [
          _Destination('Companies', Icons.apartment_outlined, '/companies'),
          _Destination('Plans', Icons.sell_outlined, '/plans'),
          _Destination('Profile', Icons.account_circle_outlined, '/profile'),
        ]
      : const [
          _Destination('Dashboard', Icons.dashboard_outlined, '/dashboard'),
          _Destination('Invoices', Icons.receipt_long_outlined, '/invoices'),
          _Destination('ITC', Icons.compare_arrows_outlined, '/itc'),
          _Destination('Employees', Icons.people_outline, '/employees'),
          _Destination('Categories', Icons.category_outlined, '/categories'),
          _Destination('Branches', Icons.location_on_outlined, '/branches'),
          _Destination(
            'Announcements',
            Icons.campaign_outlined,
            '/announcements',
          ),
          _Destination('Settings', Icons.settings_outlined, '/settings'),
          _Destination('Profile', Icons.account_circle_outlined, '/profile'),
        ];

  int _selected(String path) {
    final index = _destinations.indexWhere(
      (d) => path == d.location || path.startsWith('${d.location}/'),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final selected = _selected(path);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final compactDestinations = _destinations.take(5).toList();
    final compactSelected = selected >= compactDestinations.length
        ? 0
        : selected;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: (index) =>
                  context.go(_destinations[index].location),
              extended: MediaQuery.sizeOf(context).width >= 1180,
              minExtendedWidth: 220,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long, color: Color(0xFF0B5FFF)),
                    if (MediaQuery.sizeOf(context).width >= 1180) ...[
                      const SizedBox(width: 10),
                      const Text(
                        'GST Expense Admin',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('GST Expense Admin')),
      drawer: NavigationDrawer(
        selectedIndex: selected,
        onDestinationSelected: (index) {
          Navigator.pop(context);
          context.go(_destinations[index].location);
        },
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 24, 16, 12),
            child: Text(
              'Navigation',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final d in _destinations)
            NavigationDrawerDestination(
              icon: Icon(d.icon),
              label: Text(d.label),
            ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: compactSelected,
        onDestinationSelected: (index) =>
            context.go(compactDestinations[index].location),
        destinations: [
          for (final d in compactDestinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
