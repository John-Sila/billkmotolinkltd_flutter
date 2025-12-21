import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class ClockOut extends StatefulWidget {
  const ClockOut({super.key});

  @override
  State<ClockOut> createState() => _ClockOutState();
}

class _ClockOutState extends State<ClockOut> {
  final TextEditingController grossIncomeController = TextEditingController();
  final TextEditingController todaysIABController = TextEditingController();
  final TextEditingController prevIABController = TextEditingController();
  final TextEditingController clockInMileageController = TextEditingController();
  final TextEditingController clockOutMileageController = TextEditingController();
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
  String? selectedDestination;
  double commissionPercentage = 0.0;
  double target = 0.0;
  bool isClockedIn = false;
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
    clockOutMileageController.addListener(_updateState);
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
    clockOutMileageController.dispose();
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

  // Fetch initial data
  Future<void> fetchInitialData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};

      isClockedIn = userData['isClockedIn'] ?? false;

      final dateKey = DateFormat("dd MMM yyyy", "en_US").format(DateTime.now());

      // Check if today's clockout exists
      final clockouts = Map<String, dynamic>.from(userData['clockouts'] ?? {});
      hasClockedOutToday = clockouts.containsKey(dateKey);

      if (!isClockedIn || hasClockedOutToday) {
        setState(() => isLoading = false);
        return;
      }

      userName = userData['userName'] ?? "User";

      clockInMileageController.text =
          ((userData['clockinMileage'] ?? 0) as num).toDouble().toString();

      // Fetch commission
      final generalDoc =
          await FirebaseFirestore.instance.collection('general').doc('general_variables').get();
      commissionPercentage =
          ((generalDoc.data()?['commissionPercentage'] ?? 0) as num).toDouble() / 100.0;


      // Fetch destinations
      destinations = List<String>.from(generalDoc.data()?['destinations'] ?? []);

      // Fetch targets
      final now = DateTime.now();
      final weekday = now.weekday; // 1 = Monday, 7 = Sunday
      target = ((weekday == 7 ? userData['sundayTarget'] : userData['dailyTarget']) ?? 0)
          .toDouble();

      prevIABController.text =
          ((userData['currentInAppBalance'] ?? 0) as num).toDouble().toString();

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

  bool get canClockOut {
    if (isClockedIn != true) return false; // handle nullable

    if (grossIncomeController.text.isEmpty ||
        todaysIABController.text.isEmpty ||
        prevIABController.text.isEmpty ||
        clockInMileageController.text.isEmpty ||
        clockOutMileageController.text.isEmpty ||
        selectedDestination == null) {
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

  void showClockOutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Clock-Out"),
          content: Text(
              "Confirm to end this shift."),
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
                      await clockOut(); // your async clock-out function
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

  
  // Helper function
  bool _clockOutMileageValid() {
    final clockOutVal = double.tryParse(clockOutMileageController.text) ?? 0.0;
    final clockInVal = double.tryParse(clockInMileageController.text) ?? 0.0;
    return clockOutVal >= clockInVal;
  }

  String formatTimeElapsed(int timeElapsedMs) {
    int hours = timeElapsedMs ~/ 3600000; // 3600 * 1000 ms per hour
    int minutes = (timeElapsedMs % 3600000) ~/ 60000; // 60 * 1000 ms per minute
    
    return '${hours.toString().padLeft(1)} hrs ${minutes.toString().padLeft(2)} mins';
  }




  Future<void> clockOut() async {
    if (!canClockOut) {
      Fluttertoast.showToast(msg: "Complete all required fields");
      return;
    }

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final now = DateTime.now();

      final fs = FirebaseFirestore.instance;
      final userRef = fs.collection('users').doc(uid);
      final batteriesRef = fs.collection('batteries');
      final bikesRef = fs.collection('general').doc('general_variables');
      final weekLabel = getWeekLabel(now);
      final deviationsRef = fs.collection('deviations')
          .doc(weekLabel);

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
      final clockinMileage = userSnap.get('clockinMileage');
      final selectedLoc = selectedDestination;
      if (double.parse(clockOutMileageController.text) < clockinMileage) {
        Fluttertoast.showToast(
          msg: "Clockout mileage too low",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }
      // userSnap.get('currentBike');

      // --- EXPENSE MAP --- (Fixed)
      Map<String, dynamic> expenseData = {};
      expenseControllers.forEach((key, ctrl) {
        // Skip 'Other' when processing standard checkboxes
        if (expensesChecked[key]! && key != 'Other') {
          expenseData[key] = double.parse(ctrl.text);
        }
      });

      // Handle 'Other' separately - ONLY if checked and has description
      if (expensesChecked['Other']! && otherExpenseController.text.trim().isNotEmpty) {
        final description = otherExpenseController.text.trim();
        final value = double.parse(expenseControllers['Other']!.text);
        expenseData[description] = value; // Only custom description as key
      }

      // --- NET INCOME CALC ---
      final gross = double.parse(double.parse(grossIncomeController.text).toStringAsFixed(2));
      final commission = commissionPercentage; // already fetched on load
      final netIncome = double.parse((gross * (1 - commission)
          - (todaysIAB - prevInApp)
          - expenseData.values.whereType<num>().fold(0.0, (s, v) => s + v)).toStringAsFixed(2));

      // --- DATE KEYS ---
      final dateKey = todayHumanKey();                   // e.g. 06 Dec 2025
      final traceKey = traceDateString();                // Saturday_6_December
      final weekDay = weekdayName();                     // Saturday

      // -----------------------------------------------------------------------
      // 1. RELEASE BIKE (general/general_variables/bikes)
      // -----------------------------------------------------------------------
      final generalSnap = await bikesRef.get();
      final bikes = Map<String, dynamic>.from(generalSnap.get('bikes'));

      bikes.updateAll((key, value) {
        final m = Map<String, dynamic>.from(value);
        if (m['assignedRider'] == userName) {
          m['assignedRider'] = "None";
          m['isAssigned'] = false;
        }
        return m;
      });

      // -----------------------------------------------------------------------
      // 2. RELEASE BATTERIES + TRACE APPEND
      // -----------------------------------------------------------------------
      final batteryQuery = await batteriesRef
          .where('assignedRider', isEqualTo: userName)
          .get();

      for (var b in batteryQuery.docs) {
        final bData = b.data();
        final traces = Map<String, dynamic>.from(bData['traces'] ?? {});

        List<dynamic> entries = [];
        if (traces.containsKey(traceKey)) {
          entries = List<dynamic>.from(traces[traceKey]['entries'] ?? []);
        }

        entries.add("Clocked out with $userName at ${timeNow()}");

        traces[traceKey] = {
          'dateEdited': now,
          'entries': entries,
        };

        await b.reference.update({
          'assignedRider': "None",
          'assignedBike': "None",
          'batteryLocation': selectedLoc,
          'offTime': now,
          'traces': traces,
        });
      }

      // -----------------------------------------------------------------------
      // 3. UPDATE USER PROFILE WITH CLOCKOUT DATA
      // -----------------------------------------------------------------------
      int timeElapsed = (now.millisecondsSinceEpoch - userSnap.get('clockInTime').millisecondsSinceEpoch) as int;
      final clockoutData = {
        "grossIncome": gross,
        "todaysInAppBalance": double.parse(todaysIAB.toStringAsFixed(2)),
        "previousInAppBalance": double.parse((prevInApp).toStringAsFixed(2)),
        "inAppDifference": todaysIAB - prevInApp,
        "expenses": expenseData,
        "netIncome": netIncome,
        "clockinMileage": clockinMileage,
        "clockoutMileage": double.parse(clockOutMileageController.text),
        "mileageDifference":
            double.parse(clockOutMileageController.text) - clockinMileage,
        "posted_at": now,
        "timeElapsed": formatTimeElapsed(timeElapsed)
      };

      final notificationId =
        DateTime.now().millisecondsSinceEpoch.toString();
        
      await userRef.update({
        "clockouts.$dateKey": clockoutData,
        "currentInAppBalance": todaysIAB,
        "isClockedIn": false,
        "netClockedLastly": netIncome,
        "pendingAmount": double.parse((pendingAmountOld + netIncome).toStringAsFixed(2)),
        "lastClockDate": now,
        "currentBike": "None",
        'notifications.$notificationId': {
          'isRead': false,
          'message': 'You\'re clocked out for today.',
          'time': now,
        },
        "numberOfNotifications": FieldValue.increment(1),
      });

      // -----------------------------------------------------------------------
      // 4. WRITE DEVATION TO: deviations/weekName/userName/weekday
      // -----------------------------------------------------------------------
      final deviationData = {
        "grossIncome": gross,
        "netIncome": netIncome,
        "grossDeviation": gross - target,
        "netGrossDifference": netIncome - gross,
      };

      await deviationsRef.set({
        userName: {weekDay: deviationData}
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

      // -----------------------------------------------------------------------
      // APPLY BIKE UPDATE
      // -----------------------------------------------------------------------
      await bikesRef.update({"bikes": bikes});
      setState(() {
        hasClockedOutToday = true;
      });


      Fluttertoast.showToast(
        msg: "Clock-out successful!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      await _postClockOutNotification(userName);
    } catch (e) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Clock-Out Failed"),
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

  Future<void> _postClockOutNotification(String userName) async {
    try {
      final now = Timestamp.now();
      final notifRef = FirebaseFirestore.instance.collection('notifications').doc('latest');

      await notifRef.set({
        'body': "$userName just clocked out.",
        'targetRoles': ["Manager", "CEO", "Systems, IT"],
        'timestamp': now,
        'title': "Clockouts",
      });
    } catch (e) {
      debugPrint("Error posting clock-out notification: $e");
    }
  }


  String resolveClockoutText({
    required bool isClockedIn,
    required bool isLoading,
    required bool isOnline,
    required bool isBlocked,
    required bool hasClockedOutToday,
  }) {
    if (_isOnline == false) return "You are offline";
    if (!isClockedIn) return "You are not clocked in";
    if (hasClockedOutToday) return "You are clocked out";
    if (isLoading) return "Processing...";
    if (isBlocked) return "Clock Out Disabled";

    return "Clock Out";
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

                // gross
                _buildTextField(
                  enabled: true,
                  controller: grossIncomeController,
                  label: 'Gross Income',
                  onChanged: (_) => setState(() {}),
                  hint: 'Enter gross income',
                  icon: Icons.monetization_on,
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty 
                      ? 'Gross income is required' 
                      : null,
                ),
                const SizedBox(height: 20),


                // Commission (uneditable)
                _buildTextField(
                  enabled: false,
                  controller: TextEditingController(
                    text: (commissionPercentage * 100).toStringAsFixed(0),
                  ),
                  label: '${(commissionPercentage * 100).toStringAsFixed(0)}% Commission',
                  hint: '',
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  icon: Icons.percent,
                  validator: (v) => v == null || v.isEmpty 
                      ? 'Auto-filled' 
                      : null,
                ),
                const SizedBox(height: 20),

                // Today's IAB
                _buildTextField(
                  enabled: true,
                  controller: todaysIABController,
                  label: 'Today\'s In-App Balance',
                  hint: 'Enter today\'s IAB',
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  icon: Icons.account_balance_wallet,
                  validator: (v) => v == null || v.isEmpty 
                      ? 'In-app balance is required' 
                      : null,
                ),
                const SizedBox(height: 20),

                // Previous IAB (uneditable)
                _buildTextField(
                  enabled: false,
                  controller: prevIABController,
                  label: 'Previous IAB',
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  hint: 'Enter previous IAB',
                  icon: Icons.history,
                  validator: (v) => v == null || v.isEmpty 
                      ? 'Auto-filled' 
                      : null,
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
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: expenseControllers[key],
                              enabled: expensesChecked[key],
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: "Enter amount",
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                ),
                                prefixIcon: Icon(
                                  Icons.attach_money_outlined,
                                  color: expensesChecked[key] ?? false ? Colors.blue[600]! : Colors.grey[400]!,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 20,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: expensesChecked[key] ?? false ? Colors.grey[300]! : Colors.grey[400]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: expensesChecked[key] ?? false ? Colors.grey[300]! : Colors.grey[400]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.blue,
                                    width: 2,
                                  ),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey[400]!,
                                    width: 1.5,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
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
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: TextField(
                      controller: otherExpenseController,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: "Other Expense Description",
                        hintText: "Enter description...",
                        labelStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                        ),
                        prefixIcon: Icon(
                          Icons.description_outlined,
                          color: Colors.blue[600],
                          size: 24,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
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
                          borderSide: BorderSide(
                            color: Colors.blue[600]!,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.transparent,  // No fixed background
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Clock-In Mileage (uneditable)
                _buildTextField(
                  enabled: false,
                  controller: clockInMileageController,
                  label: 'Clock-In Mileage',
                  hint: '',
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  icon: Icons.history,
                  validator: (v) => v == null || v.isEmpty 
                      ? 'Auto-filled' 
                      : null,
                ),
                const SizedBox(height: 20),

                // Clock-Out Mileage
                _buildTextField(
                  enabled: true,
                  controller: clockOutMileageController,
                  label: 'Clock-Out Mileage',
                  hint: 'Enter clock-out mileage',
                  icon: Icons.directions_bike,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty 
                      ? 'Mileage is required' 
                      : null,
                ),
                const SizedBox(height: 20),



                // Location dropdown
                _buildDropdownField<String>(
                  value: selectedDestination,
                  label: 'Select Location',
                  hint: 'Choose destination',
                  icon: Icons.location_on_outlined,
                  items: destinations.map((loc) {
                    return DropdownMenuItem(value: loc, child: Text(loc));
                  }).toList(),
                  onChanged: (val) {
                    setState(() => selectedDestination = val);
                  },
                ),
                const SizedBox(height: 20),


                // Net Income
                Text(
                  "Net Income: KSh ${netIncome.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                // Clock-Out Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (!hasClockedOutToday && canClockOut && !isClockingOut && _clockOutMileageValid() && isClockedIn && (_isOnline == true))
                        ? showClockOutConfirmationDialog
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
                            resolveClockoutText(
                              isClockedIn: isClockedIn,
                              hasClockedOutToday: hasClockedOutToday,
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
  required bool enabled,
  required TextEditingController controller,
  required String label,
  required String hint,
  void Function(String)? onChanged,
  required IconData icon,
  TextInputType? keyboardType,
  bool obscureText = false,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    enabled: enabled,
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
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
    value: value,
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

