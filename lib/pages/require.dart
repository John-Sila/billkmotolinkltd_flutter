import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

class Requirements extends StatefulWidget {
  const Requirements({super.key});

  @override
  State<Requirements> createState() => _RequirementsState();
}

class _RequirementsState extends State<Requirements> {
  String? selectedUserId;
  DateTime? selectedDate;
  List<Map<String, dynamic>> users = [];
  final TextEditingController previousBalanceController = TextEditingController();
  bool isPosting = false;

  @override
  void initState() {
    super.initState();
    fetchUsers();
    cleanOldNotifications();
    previousBalanceController.addListener(() {
      setState(() {}); // rebuild to update button state
    });
  }

  @override
  void dispose() {
    previousBalanceController.dispose();
    super.dispose();
  }

  Future<void> fetchUsers() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('users').get();

    final fetchedUsers = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        'name': data['userName'] ?? 'Unknown',
        'userRank': data['userRank'] ?? '',
      };
    }).toList();

    setState(() {
      users = fetchedUsers;
    });
  }

  Future<void> cleanOldNotifications() async {
    final firestore = FirebaseFirestore.instance;
    final usersCollection = firestore.collection('users');

    final now = DateTime.now();
    final threshold = now.subtract(const Duration(days: 7));

    final usersSnapshot = await usersCollection.get();

    for (final userDoc in usersSnapshot.docs) {
      final data = userDoc.data();

      if (!data.containsKey('notifications')) continue;
      if (data['notifications'] is! Map) continue;

      final Map<String, dynamic> notifications =
          Map<String, dynamic>.from(data['notifications']);

      final updates = <String, dynamic>{};

      notifications.forEach((key, value) {
        if (value is Map && value.containsKey('time')) {
          final ts = value['time'];
          if (ts is Timestamp) {
            final dt = ts.toDate();
            if (dt.isBefore(threshold)) {
              updates['notifications.$key'] = FieldValue.delete();
            }
          }
        }
      });

      if (updates.isNotEmpty) {
        await userDoc.reference.update(updates);
      }
    }
  }


  Future<void> handleRequire() async {
    if (selectedUserId == null || selectedDate == null) return;

    final firestore = FirebaseFirestore.instance;
    final previousBalance = double.tryParse(previousBalanceController.text) ?? 0;

    final date = selectedDate!;
    final dayOfWeek = DateFormat('EEEE').format(date); // full day name
    final formattedDate = DateFormat('dd MMM yyyy').format(date); // "08 Oct 2025"

    final monday = date.subtract(Duration(days: date.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final weekRange =
        'Week ${weekNumber(date)} (${DateFormat('dd MMM yyyy').format(monday)} to ${DateFormat('dd MMM yyyy').format(sunday)})';

    final appBalance = previousBalance;

    final userDocRef = firestore.collection('users').doc(selectedUserId);
    final requirementId = DateTime.now().millisecondsSinceEpoch.toString();
    final requirementEntry = {
      'appBalance': appBalance,
      'date': formattedDate,
      'dayOfWeek': dayOfWeek,
      'weekRange': weekRange,
    };

    final notificationId = DateTime.now().millisecondsSinceEpoch.toString();
    final notificationEntry = {
      'message': 'You have been required to correct $formattedDate.',
      'time': Timestamp.now(),
      'isRead': false,
    };

    try {
      // 1. Append requirement
      await userDocRef.update({
        'requirements.$requirementId': requirementEntry,
        'notifications.$notificationId': notificationEntry,
        'numberOfNotifications': FieldValue.increment(1),
      });

      Fluttertoast.showToast(
        msg: "Requirement created successfully!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      previousBalanceController.clear();
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Failed to create requirement. Please try again.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      debugPrint('handleRequire error: $e');
    }
  }

  // Helper function to get ISO week number
  int weekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysPassed = date.difference(firstDayOfYear).inDays;
    return ((daysPassed + firstDayOfYear.weekday) / 7).ceil();
  }


  bool get isRequireEnabled {
    return selectedUserId != null &&
        selectedDate != null &&
        previousBalanceController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              const Text(
                'Create Requirement',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select user, date and balance to create requirement',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),

              // User dropdown
              SizedBox(
                width: double.infinity,
                child: _buildDropdownField<String>(
                  value: selectedUserId,
                  label: 'Select User',
                  hint: 'Choose rider',
                  icon: Icons.person_outline,
                  items: users.map<DropdownMenuItem<String>>((user) {
                    final rank = user['userRank']?.toString() ?? '';
                    final isSelectable = rank == 'Manager' || rank == 'Rider';

                    return DropdownMenuItem<String>(
                      value: isSelectable ? user['uid'] as String? : null,
                      enabled: isSelectable,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              user['name'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isSelectable)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                rank,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedUserId = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Calendar / Date picker
              _buildTextField(
                controller: TextEditingController(),
                hint: selectedDate == null
                    ? 'Select Date'
                    : DateFormat('yyyy-MM-dd').format(selectedDate!),
                label: selectedDate == null
                    ? 'Select Date'
                    : "${DateFormat('yyyy-MM-dd').format(selectedDate!)} yyyy-MM-dd",
                icon: Icons.calendar_today_outlined,
                readOnly: true,
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(2000),
                    lastDate: now, // disable future dates
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Previous App Balance input
              _buildTextField(
                controller: previousBalanceController,
                label: 'Previous App Balance (A)',
                hint: 'Enter previous balance',
                icon: Icons.account_balance_wallet_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 32),



              // Require button // track posting state
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: isRequireEnabled
                      ? () async {
                          // Show confirmation dialog
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Confirm Requirement'),
                              content: const Text(
                                  'Are you sure you want to create this requirement?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Continue'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed != true) return;

                          setState(() => isPosting = true); // show spinner

                          try {
                            await handleRequire(); // your Firestore posting function
                          } finally {
                            setState(() => isPosting = false); // restore button
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: Colors.blue[200],
                  ),
                  child: isPosting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Create Requirement',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),




            ],
          ),
        ),
      ),
    );
  }

  // Your existing helper methods (add these)
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.blue[600]),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey[700]),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required String label,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.blue[600]),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}
