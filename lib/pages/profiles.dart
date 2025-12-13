import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Profiles extends StatefulWidget {
  const Profiles({super.key});

  @override
  State<Profiles> createState() => _ProfilesState();
}

class _ProfilesState extends State<Profiles> {
  late final Stream<QuerySnapshot> _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
  }

  Future<void> _updateField(String uid, String field, dynamic value) async {
    final now = Timestamp.now();
    final notificationId =
        DateTime.now().millisecondsSinceEpoch.toString();
        
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
        'notifications.$notificationId': {
          'isRead': false,
          'message': 'Your account has been altered by an admin.',
          'time': now,
        },
        "numberOfNotifications": FieldValue.increment(1),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update $field: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _settlePendingAmounts() async {
    final theme = Theme.of(context);
    final confirmed = await _showConfirmDialog(
      title: 'Settle All Pending Amounts',
      content: 'This will clear all pending amounts and add them to company income. This action cannot be undone.',
      action: 'Proceed',
    );

    if (!confirmed) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final usersSnapshot = await firestore.collection('users').get();
      
      int totalPending = 0;
      final batch = firestore.batch();

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final pending = _safeNum(data['pendingAmount'], 0).toInt();
        
        if (pending > 0) {
          totalPending += pending;
          batch.update(doc.reference, {'pendingAmount': 0});
        }
      }

      if (totalPending > 0) {
        batch.update(
          firestore.collection('general').doc('general_variables'),
          {'companyIncome': FieldValue.increment(totalPending)},
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No pending amounts to settle.'),
              backgroundColor: theme.colorScheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.onPrimary),
                const SizedBox(width: 12),
                Text('Settlement completed: KSh $totalPending'),
              ],
            ),
            backgroundColor: theme.colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Settlement failed: $e'),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Perfiles e ingresos',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              icon: Icon(Icons.account_balance_wallet, size: 18),
              label: Text('Settle All', style: TextStyle(fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 2,
              ),
              onPressed: _settlePendingAmounts,
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final visibleUsers = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final rank = _safeToString(data['userRank'], '').toLowerCase();
            return rank != 'ceo' && rank != 'systems, it';
          }).toList();

          if (visibleUsers.isEmpty) {
            return _buildNoEligibleUsers(context);
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(context).bottom + 32),
            itemCount: visibleUsers.length,
            itemBuilder: (_, index) {
              final doc = visibleUsers[index];
              final user = doc.data() as Map<String, dynamic>;
              return _buildUserCard(doc.id, user, theme);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(
            'No users found',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Users will appear here when added',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoEligibleUsers(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.admin_panel_settings,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(
            'No eligible users',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Only non-admin users are shown',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(String uid, Map<String, dynamic> user, ThemeData theme) {
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceColor = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 8,
      shadowColor: theme.colorScheme.primary.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: surfaceColor,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              surfaceColor,
              theme.colorScheme.surfaceVariant ?? surfaceColor,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.person, 
                           color: theme.colorScheme.primary, 
                           size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _safeToString(user['userName'], 'Unnamed User'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: onSurfaceColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _safeToString(user['email'], 'No email'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Rank: ${_safeToString(user['userRank'], 'Unknown')}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(
                height: 1, 
                color: theme.colorScheme.outlineVariant,
                thickness: 1,
              ),
              const SizedBox(height: 24),

              // Editable Fields
              _EditableNumberField(
                label: 'Daily Target',
                value: _safeNum(user['dailyTarget'], 0).toInt(),
                icon: Icons.trending_up,
                color: theme.colorScheme.primary,
                theme: theme,
                onUpdate: (v) => _updateField(uid, 'dailyTarget', v),
              ),
              const SizedBox(height: 12),
              _EditableNumberField(
                label: 'Sunday Target',
                value: _safeNum(user['sundayTarget'], 0).toInt(),
                icon: Icons.calendar_today,
                color: theme.colorScheme.tertiary,
                theme: theme,
                onUpdate: (v) => _updateField(uid, 'sundayTarget', v),
              ),
              const SizedBox(height: 12),
              _EditableNumberField(
                label: 'Pending Amount',
                value: _safeNum(user['pendingAmount'], 0).toInt(),
                icon: Icons.payment,
                color: theme.colorScheme.secondary,
                theme: theme,
                onUpdate: (v) => _updateField(uid, 'pendingAmount', v),
              ),
              const SizedBox(height: 12),
              _EditableNumberField(
                label: 'In-App Balance',
                value: _safeNum(user['currentInAppBalance'], 0).toInt(),
                icon: Icons.account_balance_wallet,
                color: Colors.green,
                theme: theme,
                onUpdate: (v) => _updateField(uid, 'currentInAppBalance', v),
              ),
              const SizedBox(height: 20),

              // Status Toggles
              Column(
                children: [
                  _EditableBoolField(
                    label: 'Active',
                    value: _toBool(user['isActive']),
                    icon: Icons.power_settings_new,
                    color: Colors.green,
                    theme: theme,
                    onUpdate: (v) => _updateField(uid, 'isActive', v),
                  ),
                  const SizedBox(height: 12),
                  _EditableBoolField(
                    label: 'Verified',
                    value: _toBool(user['isVerified']),
                    icon: Icons.verified,
                    color: theme.colorScheme.primary,
                    theme: theme,
                    onUpdate: (v) => _updateField(uid, 'isVerified', v),
                  ),
                ],
              ),
                            
              
              const SizedBox(height: 12),
              _EditableBoolField(
                label: 'Working on Sunday',
                value: _toBool(user['isWorkingOnSunday']),
                icon: Icons.calendar_month,
                color: theme.colorScheme.tertiary,
                theme: theme,
                onUpdate: (v) => _updateField(uid, 'isWorkingOnSunday', v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ... rest of methods unchanged (settlePendingAmounts, updateField, etc.)

  Future<bool> _showConfirmDialog({
    required String title,
    required String content,
    required String action,
  }) async {
    final theme = Theme.of(context);
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, 
                 color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Text(title, 
                 style: theme.textTheme.titleMedium?.copyWith(
                   fontWeight: FontWeight.w600,
                 )),
          ],
        ),
        content: Text(content, style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ?? false;
  }
}

// Updated Editable Widgets with Theme Support
class _EditableNumberField extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final ThemeData theme;
  final Function(int) onUpdate;

  const _EditableNumberField({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.theme,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showEditDialog(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant?.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant ?? Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, 
                       style: theme.textTheme.bodyMedium?.copyWith(
                         color: theme.colorScheme.onSurfaceVariant,
                         fontWeight: FontWeight.w500,
                       )),
                  const SizedBox(height: 4),
                  Text(
                    value.toString(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, 
                 color: theme.colorScheme.onSurfaceVariant, 
                 size: 20),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: value.toString());
    showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(label, style: theme.textTheme.titleMedium),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: theme.textTheme.bodyMedium),
          ),
          ElevatedButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text) ?? value;
              Navigator.pop(context, newValue);
            },
            child: Text('Update'),
          ),
        ],
      ),
    ).then((newValue) {
      if (newValue != null && newValue != value) {
        onUpdate(newValue);
      }
    });
  }
}

class _EditableBoolField extends StatelessWidget {
  final String label;
  final bool value;
  final IconData icon;
  final Color color;
  final ThemeData theme;
  final Function(bool) onUpdate;

  const _EditableBoolField({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.theme,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = value ? color : theme.colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: () => onUpdate(!value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value 
            ? color.withOpacity(0.1) 
            : theme.colorScheme.surfaceVariant?.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value 
              ? color.withOpacity(0.3) 
              : theme.colorScheme.outlineVariant ?? Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(value ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, 
                       style: theme.textTheme.bodyMedium?.copyWith(
                         color: theme.colorScheme.onSurfaceVariant,
                         fontWeight: FontWeight.w500,
                       )),
                  Text(
                    value ? 'Enabled' : 'Disabled',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: value ? Colors.green.shade700 : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              value ? Icons.toggle_on : Icons.toggle_off,
              color: value ? Colors.green : theme.colorScheme.onSurfaceVariant,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

// Safe conversion helpers (unchanged)
String _safeToString(dynamic value, [String defaultValue = '']) {
  return value?.toString() ?? defaultValue;
}

num _safeNum(dynamic value, [num defaultValue = 0]) {
  if (value == null) return defaultValue;
  return value is num ? value : num.tryParse(value.toString()) ?? defaultValue;
}

bool _toBool(dynamic value) {
  if (value == null) return false;
  return value is bool ? value : value.toString().toLowerCase() == 'true';
}

// ... rest of methods unchanged
