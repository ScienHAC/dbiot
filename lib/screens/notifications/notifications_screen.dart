import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../models/notification.dart';
import '../../services/database_service.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              final databaseService = ref.read(databaseServiceProvider);
              
              switch (value) {
                case 'mark_all_read':
                  await databaseService.markAllNotificationsAsRead();
                  break;
                case 'clear_all':
                  _showClearAllDialog(context, ref);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read),
                    SizedBox(width: 8),
                    Text('Mark All as Read'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) => notifications.isEmpty
            ? _buildEmptyState(context)
            : _buildNotificationsList(context, ref, notifications),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildErrorState(context, error.toString()),
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
              Icons.notifications_none,
              size: 80,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              'No Notifications',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'re all caught up! Notifications about your medications and dispenser will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
              'Error Loading Notifications',
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

  Widget _buildNotificationsList(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> notifications,
  ) {
    // Group notifications by date
    final groupedNotifications = <String, List<AppNotification>>{};
    final now = DateTime.now();
    
    for (final notification in notifications) {
      final key = _getDateKey(notification.timestamp, now);
      groupedNotifications.putIfAbsent(key, () => []).add(notification);
    }
    
    // Sort groups by date
    final sortedKeys = groupedNotifications.keys.toList()
      ..sort((a, b) {
        if (a == 'Today') return -1;
        if (b == 'Today') return 1;
        if (a == 'Yesterday') return -1;
        if (b == 'Yesterday') return 1;
        return b.compareTo(a); // Newest first
      });

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(notificationsProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedKeys.length,
        itemBuilder: (context, index) {
          final dateKey = sortedKeys[index];
          final dayNotifications = groupedNotifications[dateKey]!;
          
          // Sort notifications within each day by time (newest first)
          dayNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateHeader(context, dateKey, dayNotifications),
              const SizedBox(height: 12),
              ...dayNotifications.map((notification) => 
                  _buildNotificationItem(context, ref, notification)),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(
    BuildContext context,
    String dateKey,
    List<AppNotification> notifications,
  ) {
    final theme = Theme.of(context);
    final unreadCount = notifications.where((n) => !n.read).length;

    return Row(
      children: [
        Text(
          dateKey,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (unreadCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$unreadCount new',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) {
    final theme = Theme.of(context);
    final timeText = DateFormat('HH:mm').format(notification.timestamp);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: notification.read 
          ? theme.cardColor 
          : theme.colorScheme.primary.withOpacity(0.05),
      child: InkWell(
        onTap: () async {
          if (!notification.read) {
            final databaseService = ref.read(databaseServiceProvider);
            await databaseService.markNotificationAsRead(notification.id);
          }
          // TODO: Handle notification tap based on type
          _handleNotificationTap(context, notification);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getNotificationColor(notification.type).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Notification content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.typeDisplayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _getNotificationColor(notification.type),
                            ),
                          ),
                        ),
                        Text(
                          timeText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: notification.read 
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                        fontWeight: notification.read 
                            ? FontWeight.normal 
                            : FontWeight.w500,
                      ),
                    ),
                    // Additional data if available
                    if (notification.data != null && notification.data!.isNotEmpty)
                      _buildNotificationData(context, notification),
                  ],
                ),
              ),
              // Action menu
              PopupMenuButton<String>(
                onSelected: (value) async {
                  final databaseService = ref.read(databaseServiceProvider);
                  
                  switch (value) {
                    case 'mark_read':
                      await databaseService.markNotificationAsRead(notification.id);
                      break;
                    case 'delete':
                      await databaseService.deleteNotification(notification.id);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (!notification.read)
                    const PopupMenuItem(
                      value: 'mark_read',
                      child: Row(
                        children: [
                          Icon(Icons.mark_email_read),
                          SizedBox(width: 8),
                          Text('Mark as Read'),
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
                child: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationData(BuildContext context, AppNotification notification) {
    final theme = Theme.of(context);
    final data = notification.data!;
    
    String dataText = '';
    switch (notification.type) {
      case NotificationType.lowPillAlert:
        if (data.containsKey('chamber') && data.containsKey('pillCount')) {
          dataText = 'Chamber ${data['chamber']}: ${data['pillCount']} pills remaining';
        }
        break;
      case NotificationType.dispenserOffline:
        if (data.containsKey('lastActive')) {
          final lastActive = DateTime.fromMillisecondsSinceEpoch(data['lastActive']);
          dataText = 'Last seen: ${DateFormat('MMM dd, HH:mm').format(lastActive)}';
        }
        break;
      default:
        break;
    }
    
    if (dataText.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          dataText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.doseDispensed:
        return Icons.check_circle;
      case NotificationType.missedDose:
        return Icons.warning;
      case NotificationType.lowPillAlert:
        return Icons.battery_0_bar;
      case NotificationType.dispenserOffline:
        return Icons.wifi_off;
      case NotificationType.general:
        return Icons.info;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.doseDispensed:
        return Colors.green;
      case NotificationType.missedDose:
        return Colors.orange;
      case NotificationType.lowPillAlert:
        return Colors.red;
      case NotificationType.dispenserOffline:
        return Colors.grey;
      case NotificationType.general:
        return Colors.blue;
    }
  }

  void _handleNotificationTap(BuildContext context, AppNotification notification) {
    // TODO: Implement navigation based on notification type
    switch (notification.type) {
      case NotificationType.doseDispensed:
      case NotificationType.missedDose:
        // Navigate to medication schedule
        break;
      case NotificationType.lowPillAlert:
      case NotificationType.dispenserOffline:
        // Navigate to dashboard
        Navigator.of(context).pop();
        break;
      case NotificationType.general:
        // No specific action
        break;
    }
  }

  void _showClearAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // TODO: Implement clear all notifications
              final notificationsAsync = ref.read(notificationsProvider);
              notificationsAsync.whenData((notifications) async {
                final databaseService = ref.read(databaseServiceProvider);
                for (final notification in notifications) {
                  await databaseService.deleteNotification(notification.id);
                }
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  String _getDateKey(DateTime timestamp, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final notificationDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (notificationDate.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (notificationDate.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    } else {
      return DateFormat('EEEE, MMM dd').format(notificationDate);
    }
  }
}
