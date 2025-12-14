import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class Corrections extends StatefulWidget {
  const Corrections({super.key});

  @override
  State<Corrections> createState() => _Correctionstate();
}

class _Correctionstate extends State<Corrections> {
  final TextEditingController grossIncomeController = TextEditingController();
  final TextEditingController todaysIABController = TextEditingController();
  final TextEditingController prevIABController = TextEditingController();
  final TextEditingController clockInMileageController = TextEditingController();
  final TextEditingController otherExpenseController = TextEditingController();

  Map<String, bool> expensesChecked = {
    'Battery Swap': false,
    'Data Bundles': false,
    'Lunch': false,
    'Police': false,
    'Other': false,
  };

  Map<String, TextEditingController> expenseControllers = {};
  List<String> destinations = [];
  double commissionPercentage = 0.0;
  double target = 0.0;
  bool hasClockedOutToday = false;
  bool isClockingOut = false;
  bool? _isOnline;

  double deviation = 0.0;
  double netIncome = 0.0;
  double totalExpenses = 0.0;
  bool isLoading = true;
  String userName = "";

  String todayHumanKey() {
    return DateFormat("dd MMM yyyy", "en_US").format(DateTime.now());
  }

  String weekdayName() {
    return DateFormat("EEEE", "en_US").format(DateTime.now());
  }

  String traceDateString() {
    return DateFormat("EEEE_d_MMMM", "en_US").format(DateTime.now());
  }

  String timeNow() {
    return DateFormat("HH:mm:ss").format(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    fetchInitialData();
    checkIsOnline();

    // Initialize expense controllers
    expensesChecked.forEach((key, value) {
      expenseControllers[key] = TextEditingController();
      expenseControllers[key]!.addListener(updateNetIncome);
    });

    grossIncomeController.addListener(updateDeviation);
    todaysIABController.addListener(updateNetIncome);
    prevIABController.addListener(updateNetIncome);


    // Rebuild whenever any input changes
    grossIncomeController.addListener(_updateState);
    todaysIABController.addListener(_updateState);
    prevIABController.addListener(_updateState);
    clockInMileageController.addListener(_updateState);
    expenseControllers.forEach((key, ctrl) => ctrl.addListener(_updateState));
    otherExpenseController.addListener(_updateState);
  }

  void _updateState() => setState(() {});

  @override
  void dispose() {
    grossIncomeController.dispose();
    todaysIABController.dispose();
    prevIABController.dispose();
    clockInMileageController.dispose();
    otherExpenseController.dispose();
    expenseControllers.forEach((key, ctrl) => ctrl.dispose());
    super.dispose();
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning, $userName";
    if (hour < 17) return "Good afternoon, $userName";
    return "Good evening, $userName";
  }

  String? selectedKey;
  Map<String, dynamic> requirements = {}; // Will hold the fetched requirements
  int appBalance = 0;
  String dayOfWeek = "";
  String weekRange = "";
  String selectedDate = "";

  void _updateVariables(String key) {
    final data = Map<String, dynamic>.from(requirements[key]!);
    setState(() {
      selectedKey = key; // <- This updates the dropdown
      appBalance = ((data['appBalance'] ?? 0) as num).toInt();
      dayOfWeek = data['dayOfWeek'] ?? "";
      weekRange = data['weekRange'] ?? "";
      selectedDate = data['date'] ?? "";

      // Update the TextFormField controller
      prevIABController.text = appBalance.toString();
    });
  }


  Future<void> fetchInitialData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};

      userName = userData['userName'] ?? "User";

      clockInMileageController.text =
          ((userData['clockinMileage'] ?? 0) as num).toDouble().toString();

      // Fetch commission
      final generalDoc = await FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables')
          .get();
      commissionPercentage =
          ((generalDoc.data()?['commissionPercentage'] ?? 0) as num).toDouble() / 100.0;

      // Fetch destinations
      destinations = List<String>.from(generalDoc.data()?['destinations'] ?? []);

      // Fetch targets
      target = ((userData['dailyTarget']) ?? 0).toDouble();

      // --- Fetch requirements ---
      final reqMap = Map<String, dynamic>.from(userData['requirements'] ?? {});
      if (reqMap.isNotEmpty) {
        requirements = reqMap;
        selectedKey = requirements.keys.first;

        final firstEntry = Map<String, dynamic>.from(requirements[selectedKey]!);

        // Safely parse numeric values
        appBalance = ((firstEntry['appBalance'] ?? 0) as num).toInt();
        dayOfWeek = firstEntry['dayOfWeek'] ?? "";
        weekRange = firstEntry['weekRange'] ?? "";

        // Update the controller
        prevIABController.text = appBalance.toString();
      }


      setState(() => isLoading = false);
    } catch (e) {
      Fluttertoast.showToast(msg: "Error fetching data: $e");
      setState(() => isLoading = false);
    }
  }

  void updateDeviation() {
    final gross = double.tryParse(grossIncomeController.text) ?? 0.0;
    setState(() {
      deviation = gross - target;
    });
    updateNetIncome();
    
  }

  void updateNetIncome() {
    final gross = double.tryParse(grossIncomeController.text) ?? 0.0;
    final todayIAB = double.tryParse(todaysIABController.text) ?? 0.0;
    final prevIAB = double.tryParse(prevIABController.text) ?? 0.0;

    totalExpenses = 0.0;
    expenseControllers.forEach((key, ctrl) {
      if (expensesChecked[key] == true) {
        totalExpenses += double.tryParse(ctrl.text) ?? 0.0;
      }
    });

    setState(() {
      netIncome = gross * (1 - commissionPercentage) - (todayIAB - prevIAB) - totalExpenses;
    });
  }

  bool get canCorrect {
    if (grossIncomeController.text.isEmpty ||
        todaysIABController.text.isEmpty ||
        prevIABController.text.isEmpty) {
      return false;
    }

    // All checked expenses must have a value
    for (var key in expensesChecked.keys) {
      if (!expensesChecked[key]!) continue;

      if (key == 'Other') {
        // Other must have both amount AND description
        if (expenseControllers[key]!.text.isEmpty || otherExpenseController.text.isEmpty) {
          return false;
        }
      } else {
        if (expenseControllers[key]!.text.isEmpty) return false;
      }
    }

    return true;
  }

  String getWeekLabel(DateTime date) {
    // Compute ISO week number
    int dayOfYear = int.parse(DateFormat("D").format(date));
    int weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();

    // Compute start and end of week (Monday to Sunday)
    final firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));

    final formatter = DateFormat("dd MMM yyyy");
    return "Week $weekNumber (${formatter.format(firstDayOfWeek)} to ${formatter.format(lastDayOfWeek)})";
  }

  void showCorrectionsConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Correction"),
          content: Text(
              "Confirm to correct and overwrite the current data for this day."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isClockingOut
                  ? null
                  : () async {
                      Navigator.pop(context);
                      setState(() => isClockingOut = true);
                      await correct(); // your async clock-out function
                      await fetchInitialData(); // refresh data after clock-out
                      setState(() => isClockingOut = false);
                    },
              child: isClockingOut
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  Future<void> correct() async {
    if (!canCorrect) {
      Fluttertoast.showToast(msg: "Complete all required fields");
      return;
    }

    final ourDate = selectedDate;

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final now = DateTime.now();

      final fs = FirebaseFirestore.instance;
      final userRef = fs.collection('users').doc(uid);
      final deviationsRef = fs.collection('deviations')
          .doc(weekRange);

      // --- PULL USER PROFILE FIRST ---
      final userSnap = await userRef.get();
      if (!userSnap.exists) {
        Fluttertoast.showToast(msg: "User not found");
        return;
      }
      final userName = userSnap.get('userName');
      final pendingAmountOld = userSnap.get('pendingAmount') ?? 0.0;
      final prevInApp = double.parse(prevIABController.text);
      final todaysIAB = double.parse(todaysIABController.text);
      // userSnap.get('currentBike');

      // --- EXPENSE MAP ---
      Map<String, dynamic> expenseData = {};
      expenseControllers.forEach((key, ctrl) {
        if (expensesChecked[key]!) {
          expenseData[key] = double.parse(ctrl.text);
        }
      });

      if (expensesChecked['Other']! && otherExpenseController.text.trim().isNotEmpty) {
        final description = otherExpenseController.text.trim();
        final value = double.parse(expenseControllers['Other']!.text);
        expenseData[description] = value; // description as key, numeric value
      }


      // --- NET INCOME CALC ---
      final gross = double.parse(grossIncomeController.text);
      final commission = commissionPercentage; // already fetched on load
      final netIncome = gross * (1 - commission)
          - (todaysIAB - prevInApp)
          - expenseData.values.whereType<num>().fold(0.0, (s, v) => s + v);                   // Saturday

      // -----------------------------------------------------------------------
      // 1. UPDATE USER PROFILE WITH Corrections DATA
      // -----------------------------------------------------------------------
      final correctionsData = {
        "grossIncome": gross,
        "todaysInAppBalance": todaysIAB,
        "previousInAppBalance": prevInApp,
        "inAppDifference": todaysIAB - prevInApp,
        "expenses": expenseData,
        "netIncome": netIncome,
        "clockinMileage": 0,
        "clockoutMileage": 0,
        "mileageDifference": 0,
        "posted_at": now,
        "timeElapsed": "Void due to correction",
      };

      await userRef.update({
        "clockouts.$selectedDate": correctionsData,
        "pendingAmount": pendingAmountOld + netIncome,
      });

      // -----------------------------------------------------------------------
      // 2. WRITE DEVATION TO: deviations/weekName/userName/weekday
      // -----------------------------------------------------------------------
      final deviationData = {
        "grossIncome": gross,
        "netIncome": netIncome,
        "grossDeviation": gross - target,
        "netGrossDifference": netIncome - gross,
      };

      await deviationsRef.set({
        userName: {dayOfWeek: deviationData}
      }, SetOptions(merge: true));

      // -----------------------------------------------------------------------
      // 5. UPDATE netIncomes.thisMonth AND workedDays.thisMonth
      // -----------------------------------------------------------------------
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(userRef);

        final now = DateTime.now();
        final monthName = DateFormat("MMMM").format(now);
        final nextMonth = DateFormat("MMMM")
            .format(DateTime(now.year, now.month + 1, now.day));

        // Safely read netIncomes and workedDays maps
        final netIncomes = Map<String, dynamic>.from(snap.data()?['netIncomes'] ?? {});
        final workedDays = Map<String, dynamic>.from(snap.data()?['workedDays'] ?? {});

        final currentIncome = (netIncomes[monthName] ?? 0.0) as num;
        final currentDays = (workedDays[monthName] ?? 0.0) as num;

        transaction.update(userRef, {
          "netIncomes.$monthName": currentIncome + netIncome,
          "workedDays.$monthName": currentDays + 1,
          "netIncomes.$nextMonth": FieldValue.delete(),
          "workedDays.$nextMonth": FieldValue.delete(),
        });
      });

      Fluttertoast.showToast(
          msg: "Correction successful!",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      await deleteThisRequirement(uid: uid, targetDate: ourDate, );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Correction Failed"),
          content: SingleChildScrollView(
            child: SelectableText(
              e.toString(), // full exception string, now copiable
              style: const TextStyle(fontSize: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Dismiss"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> deleteThisRequirement({
  required String uid,
  required String targetDate, // e.g. "09 Dec 2025"
}) async {
  final firestore = FirebaseFirestore.instance;
  final userDocRef = firestore.collection('users').doc(uid);

  try {
    // Get current requirements map
    final docSnap = await userDocRef.get();
    if (!docSnap.exists) {
      throw Exception('User document not found');
    }

    final data = docSnap.data();
    final requirements = data?['requirements'] as Map<String, dynamic>?;
    
    if (requirements == null) {
      throw Exception('No requirements found');
    }

    // Find the timestamp key with matching date
    String? timestampKeyToDelete;
    requirements.forEach((timestampKey, requirementData) {
      if (requirementData['date'] == targetDate) {
        timestampKeyToDelete = timestampKey;
      }
    });

    if (timestampKeyToDelete == null) {
      throw Exception('No requirement found for date: $targetDate');
    }
    // Delete the specific timestamp key
    await userDocRef.update({
      'requirements.$timestampKeyToDelete': FieldValue.delete(),
    });

    Fluttertoast.showToast(
      msg: "Deleted requirement for $targetDate",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.orange,
      textColor: Colors.white,
      fontSize: 16.0,
    );
    grossIncomeController.clear();
    todaysIABController.clear();
    await fetchInitialData(); // refresh UI

  } catch (e) {
    Fluttertoast.showToast(msg: 'Error: $e');
  }
}

  String resolveCorrectionsText({
    required bool isLoading,
    required bool isOnline,
    required bool isBlocked,
  }) {
    if (_isOnline == false) return "You are offline";
    if (isLoading) return "Processing...";
    if (isBlocked) return "Clock Out Disabled";

    return "Correct";
  }

  Future<void> checkIsOnline() async {
    final online = await isOnline();
    setState(() {
      _isOnline = online;
    });
  }

  Future<bool> isOnline() async {
    try {
      final response = await http.get(
        Uri.parse("https://clients3.google.com/generate_204"),
      ).timeout(const Duration(seconds: 3));

      return response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await fetchInitialData();
        await checkIsOnline();
      },
      child:Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // greeting
                Text(
                  getGreeting(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),


                Text(
                  "Deviation: KSh ${deviation.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: deviation < 0 ? Colors.red : Colors.green,
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: _buildDropdownField<String>(
                    value: selectedKey,
                    label: 'Select Date',
                    hint: 'Choose a date',
                    icon: Icons.calendar_today_outlined,
                    items: requirements.entries.map((entry) {
                      final key = entry.key;
                      final data = Map<String, dynamic>.from(entry.value);
                      return DropdownMenuItem(
                        value: key,
                        child: Text(data['date'] ?? "Unknown Date"),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) _updateVariables(value);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                

                // Gross Income
                _buildTextField(
                  controller: grossIncomeController,
                  label: 'Gross Income',
                  hint: 'Enter total income',
                  icon: Icons.account_balance_wallet_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                // Commission (uneditable)
                _buildTextField(
                  enabled: false,
                  controller: TextEditingController(), // Empty controller for disabled display
                  label: '${(commissionPercentage * 100).toStringAsFixed(0)}% Commission',
                  hint: 'Commission calculated',
                  icon: Icons.percent_outlined,
                ),
                const SizedBox(height: 12),


                // Today's IAB
                _buildTextField(
                  controller: todaysIABController,
                  label: "In-App Balance",
                  hint: 'Enter IAB for that day',
                  icon: Icons.analytics_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                // Previous IAB (uneditable)
                _buildTextField(
                  enabled: false,
                  controller: prevIABController,
                  label: 'Previous IAB',
                  hint: 'Auto-filled from records',
                  icon: Icons.history_outlined,
                ),
                const SizedBox(height: 20),

                const Text("Expenses", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // Expenses checkboxes
                ...expensesChecked.keys.map((key) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6), // extra space
                    child: Row(
                      children: [
                        Checkbox(
                          value: expensesChecked[key],
                          onChanged: (val) {
                            setState(() {
                              expensesChecked[key] = val!;
                              if (!val) expenseControllers[key]!.clear();
                              updateNetIncome();
                            });
                          },
                        ),
                        Text(key),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: expenseControllers[key],
                              enabled: expensesChecked[key] ?? false,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: (expensesChecked[key] ?? false) ? Colors.black87 : Colors.grey[500],
                              ),
                              decoration: InputDecoration(
                                hintText: "Enter amount",
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                  color: (expensesChecked[key] ?? false) ? Colors.grey[400]! : Colors.grey[500]!,
                                ),
                                prefixIcon: Icon(
                                  Icons.attach_money_outlined,
                                  color: (expensesChecked[key] ?? false) ? Colors.blue[600]! : Colors.grey[400]!,
                                  size: 24,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.grey[400]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.transparent,  // No fixed background
                              ),
                            ),
                          ),
                        ),

                      ],
                    ),
                  );
                }),

                // Other description
                if (expensesChecked['Other']!)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextField(
                      controller: otherExpenseController,
                      decoration: const InputDecoration(
                        labelText: "Other Expense Description",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Net Income
                Text(
                  "Net Income: KSh ${netIncome.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Correct Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (!hasClockedOutToday && canCorrect && !isClockingOut && (_isOnline == true))
                        ? showCorrectionsConfirmationDialog
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasClockedOutToday ? Colors.red : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isClockingOut
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            resolveCorrectionsText(
                              isLoading: isLoading,
                              isBlocked: false,
                              isOnline: (_isOnline == true) ? true : false,
                            ),
                            style: const TextStyle(fontSize: 18, color: Colors.white),
                          ),

                  ),
                )


              ],
            ),
          ),
        ),
      )

      );
  }
}


Widget _buildTextField({
  required TextEditingController controller,
  bool enabled = true,
  required String label,
  required String hint,
  required IconData icon,
  TextInputType? keyboardType,
  bool obscureText = false,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    enabled: enabled,
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

// Reusable Dropdown Widget
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
