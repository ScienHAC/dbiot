import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../models/dose.dart';
import '../../models/dispenser.dart';
import '../medication/medication_schedule_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../services/database_service.dart';
import '../auth/login_screen.dart';
import '../../services/auth_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greeting = ref.watch(greetingProvider);
    final dispenserAsync = ref.watch(dispenserProvider);
    final todaysDosesAsync = ref.watch(todaysDosesProvider);
    final upcomingDoses = ref.watch(upcomingDosesProvider);
    final overdueDoses = ref.watch(overdueDosesProvider);
    final unreadNotificationCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // Notifications icon with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
              ),
              if (unreadNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadNotificationCount > 99 ? '99+' : '$unreadNotificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Settings menu
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  // TODO: Navigate to profile screen
                  break;
                case 'settings':
                  // TODO: Navigate to settings screen
                  break;
                case 'logout':
                  _showLogoutDialog(context, ref);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh data
          ref.invalidate(dispenserProvider);
          ref.invalidate(todaysDosesProvider);
          ref.invalidate(notificationsProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting and overdue alerts
              _buildGreetingSection(context, greeting, overdueDoses),
              const SizedBox(height: 24),
              
              // Dispenser status card
              dispenserAsync.when(
                data: (dispenser) => _buildDispenserStatusCard(context, ref, dispenser),
                loading: () => const _LoadingCard(),
                error: (error, _) => _ErrorCard(error: error.toString()),
              ),
              const SizedBox(height: 16),
              
              // Pill counts card
              dispenserAsync.when(
                data: (dispenser) => _buildPillCountsCard(context, dispenser),
                loading: () => const _LoadingCard(),
                error: (error, _) => _ErrorCard(error: error.toString()),
              ),
              const SizedBox(height: 16),
              
              // Today's medications
              todaysDosesAsync.when(
                data: (doses) => _buildTodaysMedicationsCard(context, doses),
                loading: () => const _LoadingCard(),
                error: (error, _) => _ErrorCard(error: error.toString()),
              ),
              const SizedBox(height: 16),
              
              // Upcoming doses
              if (upcomingDoses.isNotEmpty)
                _buildUpcomingDosesCard(context, upcomingDoses),
              
              const SizedBox(height: 80), // Space for FAB
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const MedicationScheduleScreen(),
            ),
          );
        },
        icon: const Icon(Icons.medication),
        label: const Text('Medications'),
      ),
    );
  }

  Widget _buildGreetingSection(BuildContext context, String greeting, List<Dose> overdueDoses) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (overdueDoses.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${overdueDoses.length} overdue medication${overdueDoses.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDispenserStatusCard(BuildContext context, WidgetRef ref, Dispenser dispenser) {
    final theme = Theme.of(context);
    final isOnline = dispenser.isOnline;
    final lastSeenText = dispenser.lastSeen != null
        ? DateFormat('MMM dd, yyyy \'at\' HH:mm').format(dispenser.lastSeen!)
        : 'Never';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.router,
                  color: isOnline ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Dispenser Status',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Last Seen: $lastSeenText',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (dispenser.lastDispenseTime != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last Dispense: ${dispenser.lastDispenseTime} (${dispenser.lastDispenseSuccessful ? 'Success' : 'Failed'})',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: dispenser.lastDispenseSuccessful ? Colors.green : Colors.red,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final databaseService = ref.read(databaseServiceProvider);
                  await databaseService.syncDispenserCommand();
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sync command sent to dispenser'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.sync),
                label: const Text('Sync Dispenser'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillCountsCard(BuildContext context, Dispenser dispenser) {
    final theme = Theme.of(context);
    final chambers = [0, 1, 2, 3];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.medication,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pills Remaining',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...chambers.map((chamber) {
              final count = dispenser.chambers[chamber] ?? 0;
              final percentage = count / 50; // Assuming max 50 pills per chamber
              final isLow = count <= 5;
              final chamberName = dispenser.getChamberDisplayName(chamber);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chamber $chamberName',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$count pills',
                          style: TextStyle(
                            color: isLow ? Colors.red : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage.clamp(0.0, 1.0),
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isLow ? Colors.red : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaysMedicationsCard(BuildContext context, List<Dose> doses) {
    final theme = Theme.of(context);
    final takenCount = doses.where((d) => d.status == DoseStatus.taken).length;
    final totalCount = doses.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.today,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Today\'s Medications',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '$takenCount/$totalCount',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (totalCount > 0) ...[
              LinearProgressIndicator(
                value: totalCount > 0 ? takenCount / totalCount : 0,
                backgroundColor: theme.colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (doses.isEmpty)
              Text(
                'No medications scheduled for today',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...doses.take(3).map((dose) => _buildDoseListItem(context, dose)),
            if (doses.length > 3) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MedicationScheduleScreen(),
                    ),
                  );
                },
                child: Text('View all ${doses.length} medications'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingDosesCard(BuildContext context, List<Dose> doses) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Doses',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...doses.map((dose) => _buildDoseListItem(context, dose)),
          ],
        ),
      ),
    );
  }

  Widget _buildDoseListItem(BuildContext context, Dose dose) {
    final theme = Theme.of(context);
    final timeText = DateFormat('HH:mm').format(dose.time);
    final isOverdue = dose.isOverdue();
    
    Color? statusColor;
    IconData statusIcon;
    
    switch (dose.status) {
      case DoseStatus.taken:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case DoseStatus.missed:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case DoseStatus.upcoming:
        if (isOverdue) {
          statusColor = Colors.orange;
          statusIcon = Icons.warning;
        } else {
          statusColor = Colors.grey;
          statusIcon = Icons.schedule;
        }
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            statusIcon,
            size: 20,
            color: statusColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),                    Text(
                      'Chamber ${['A', 'B', 'C', 'D'][dose.chamber]} • $timeText',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
              ],
            ),
          ),
          if (isOverdue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'OVERDUE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final authService = ref.read(authServiceProvider);
              await authService.signOut();
              
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        height: 120,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  
  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Error: $error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
