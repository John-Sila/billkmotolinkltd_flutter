import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

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
          - expenseData.values.whereType<num>().fold(0.0, (s, v) => s + v);

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
      final clockoutData = {
        "grossIncome": gross,
        "todaysInAppBalance": todaysIAB,
        "previousInAppBalance": prevInApp,
        "inAppDifference": todaysIAB - prevInApp,
        "expenses": expenseData,
        "netIncome": netIncome,
        "clockinMileage": clockinMileage,
        "clockoutMileage": double.parse(clockOutMileageController.text),
        "mileageDifference":
            double.parse(clockOutMileageController.text) - clockinMileage,
        "posted_at": now,
        "timeElapsed": now.millisecondsSinceEpoch -
            userSnap.get('clockInTime').millisecondsSinceEpoch
      };

      await userRef.update({
        "clockouts.$dateKey": clockoutData,
        "currentInAppBalance": todaysIAB,
        "isClockedIn": false,
        "netClockedLastly": netIncome,
        "pendingAmount": pendingAmountOld + netIncome,
        "lastClockDate": now,
        "currentBike": "None",
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


      Fluttertoast.showToast(msg: "Clocked out successfully");
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // if (!isClockedIn) {
    //   return const Center(
    //     child: Text(
    //       "You must clock in first.",
    //       style: TextStyle(fontSize: 18),
    //     ),
    //   );
    // }


    return RefreshIndicator(
      onRefresh: () async {
        await fetchInitialData();
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

                // Gross Income
                TextFormField(
                  controller: grossIncomeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Gross Income",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Commission (uneditable)
                TextFormField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: "${(commissionPercentage * 100).toStringAsFixed(0)}% Commission",
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Today's IAB
                TextFormField(
                  controller: todaysIABController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Today's IAB",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Previous IAB (uneditable)
                TextFormField(
                  controller: prevIABController,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: "Previous IAB",
                    border: OutlineInputBorder(),
                  ),
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
                          child: TextField(
                            controller: expenseControllers[key],
                            enabled: expensesChecked[key],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: "Amount",
                              border: OutlineInputBorder(),
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

                // Clock-In Mileage (uneditable)
                TextFormField(
                  controller: clockInMileageController,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: "Clock-In Mileage",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Clock-Out Mileage
                TextFormField(
                  controller: clockOutMileageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Clock-Out Mileage",
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: (_clockOutMileageValid()) ? Colors.grey : Colors.red,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: (_clockOutMileageValid()) ? Colors.blue : Colors.red,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}), // rebuilds to update button state and border
                ),

                const SizedBox(height: 12),

                // Location dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedDestination,
                  decoration: const InputDecoration(
                    labelText: "Select Location",
                    border: OutlineInputBorder(),
                  ),
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
                    onPressed: (!hasClockedOutToday && canClockOut && !isClockingOut && _clockOutMileageValid() && isClockedIn)
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
                            hasClockedOutToday ? "You are clocked out" : "Clock Out",
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
