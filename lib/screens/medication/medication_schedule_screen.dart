import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../models/dose.dart';
import '../../services/database_service.dart';
import 'add_edit_dose_screen.dart';

class MedicationScheduleScreen extends ConsumerWidget {
  const MedicationScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dosesAsync = ref.watch(dosesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Schedule'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: dosesAsync.when(
        data: (doses) => doses.isEmpty
            ? _buildEmptyState(context)
            : _buildDosesList(context, ref, doses),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildErrorState(context, error.toString()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddEditDoseScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              'No Medications Scheduled',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first medication to get started with your pill schedule.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddEditDoseScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Medication'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Medications',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDosesList(BuildContext context, WidgetRef ref, List<Dose> doses) {
    // Group doses by date
    final groupedDoses = <String, List<Dose>>{};
    final now = DateTime.now();
    
    for (final dose in doses) {
      final key = _getDateKey(dose, now);
      groupedDoses.putIfAbsent(key, () => []).add(dose);
    }
    
    // Sort groups by date
    final sortedKeys = groupedDoses.keys.toList()
      ..sort((a, b) {
        if (a == 'Today') return -1;
        if (b == 'Today') return 1;
        if (a == 'Tomorrow') return -1;
        if (b == 'Tomorrow') return 1;
        if (a == 'Overdue') return -1;
        if (b == 'Overdue') return 1;
        return a.compareTo(b);
      });

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dosesProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final dateKey = sortedKeys[index];
          final dayDoses = groupedDoses[dateKey]!;
          
          // Sort doses within each day by time
          dayDoses.sort((a, b) => a.time.compareTo(b.time));
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateHeader(context, dateKey, dayDoses),
              const SizedBox(height: 12),
              ...dayDoses.map((dose) => _buildDoseItem(context, ref, dose)),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(BuildContext context, String dateKey, List<Dose> doses) {
    final theme = Theme.of(context);
    final takenCount = doses.where((d) => d.status == DoseStatus.taken).length;
    final totalCount = doses.length;
    
    Color? headerColor;
    if (dateKey == 'Overdue') {
      headerColor = Colors.red;
    } else if (dateKey == 'Today') {
      headerColor = theme.colorScheme.primary;
    }

    return Row(
      children: [
        Text(
          dateKey,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: headerColor,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (headerColor ?? theme.colorScheme.outline).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$takenCount/$totalCount',
            style: TextStyle(
              color: headerColor ?? theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoseItem(BuildContext context, WidgetRef ref, Dose dose) {
    final theme = Theme.of(context);
    final timeText = DateFormat('HH:mm').format(dose.time);
    final isOverdue = dose.isOverdue();
    
    Color? statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (dose.status) {
      case DoseStatus.taken:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = dose.takenAt != null 
            ? 'Taken at ${DateFormat('HH:mm').format(dose.takenAt!)}'
            : 'Taken';
        break;
      case DoseStatus.missed:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Missed';
        break;
      case DoseStatus.upcoming:
        if (isOverdue) {
          statusColor = Colors.orange;
          statusIcon = Icons.warning;
          statusText = 'Overdue';
        } else {
          statusColor = Colors.grey;
          statusIcon = Icons.schedule;
          statusText = 'Scheduled';
        }
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddEditDoseScreen(dose: dose),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    statusIcon,
                    color: statusColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dose.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Chamber ${['A', 'B', 'C', 'D'][dose.chamber]} • $timeText • ${dose.count} pill${dose.count > 1 ? 's' : ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDoseActions(context, ref, dose),
                    ],
                  ),
                ],
              ),
              if (dose.conditions != null && dose.conditions!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dose.conditions!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoseActions(BuildContext context, WidgetRef ref, Dose dose) {
    if (dose.status != DoseStatus.upcoming) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      child: const Icon(Icons.more_vert, size: 20),
      onSelected: (value) async {
        final databaseService = ref.read(databaseServiceProvider);
        
        switch (value) {
          case 'taken':
            await databaseService.markDoseAsTaken(dose.id);
            break;
          case 'missed':
            await databaseService.markDoseAsMissed(dose.id);
            break;
          case 'edit':
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddEditDoseScreen(dose: dose),
              ),
            );
            break;
          case 'delete':
            _showDeleteDialog(context, ref, dose);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'taken',
          child: Row(
            children: [
              Icon(Icons.check, color: Colors.green),
              SizedBox(width: 8),
              Text('Mark as Taken'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'missed',
          child: Row(
            children: [
              Icon(Icons.close, color: Colors.red),
              SizedBox(width: 8),
              Text('Mark as Missed'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit),
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete'),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, Dose dose) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication'),
        content: Text('Are you sure you want to delete "${dose.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final databaseService = ref.read(databaseServiceProvider);
              await databaseService.deleteDose(dose.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    // TODO: Implement filter dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Medications'),
        content: const Text('Filter options coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getDateKey(Dose dose, DateTime now) {
    if (dose.isOverdue()) {
      return 'Overdue';
    }
    
    final today = DateTime(now.year, now.month, now.day);
    final doseDate = DateTime(dose.time.year, dose.time.month, dose.time.day);
    
    if (doseDate.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (doseDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      return 'Tomorrow';
    } else if (doseDate.isAfter(today)) {
      return DateFormat('EEEE, MMM dd').format(doseDate);
    } else {
      return DateFormat('EEEE, MMM dd').format(doseDate);
    }
  }
}
