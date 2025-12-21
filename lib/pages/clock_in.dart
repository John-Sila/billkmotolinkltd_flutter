import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

class ClockIn extends StatefulWidget {
  const ClockIn({super.key});

  @override
  State<ClockIn> createState() => _ClockInState();
}

extension DateTimeFormatting on DateTime {
  String weekdayName() {
    return ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"][weekday-1];
  }

  String monthName() {
    return ["January","February","March","April","May","June","July","August","September","October","November","December"][month-1];
  }

  String daySuffix() {
    if (day >= 11 && day <= 13) return "th";
    switch (day % 10) {
      case 1: return "st";
      case 2: return "nd";
      case 3: return "rd";
      default: return "th";
    }
  }
}


class _ClockInState extends State<ClockIn> {
  String? selectedBike;
  bool scanning = false;

  List<String> scannedBatteries = [];      // Stores battery names
  List<String> scannedBatteryCodes = [];   // Stores cleaned QR codes
  static const int maxScans = 2;
  final TextEditingController mileageController = TextEditingController();
  bool isClockingIn = false;

  bool? isClockedIn;
  String userName = "";
  String _timeString = "";
  late Timer _timer;
  bool? _isOnline;
  bool isLoading = true;


  @override
  void initState() {
    super.initState();

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
 

    mileageController.addListener(() {
      setState(() {}); // rebuild button when text changes
    });

    checkClockInStatus();
    checkIsOnline();
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


  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeString = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}";
    });
  }

  Future<void> checkClockInStatus() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    setState(() {
      isClockedIn = data['isClockedIn'] ?? false;
      userName = data['userName'] ?? "User";
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    mileageController.dispose(); // only this controller exists here
    super.dispose();
  }

  /// Fetch all bikes
  Future<Map<String, dynamic>> fetchBikes() async {
    
    final doc = await FirebaseFirestore.instance
        .collection('general')
        .doc('general_variables')
        .get();

    final bikes = doc.data()?['bikes'] as Map<String, dynamic>? ?? {};
    return bikes;
  }

  /// Clean QR code extract
  String cleanExtract(String raw) {
    return raw
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();
  }

  /// Scan battery
  Future<void> scanBattery() async {
    if (scannedBatteries.length >= maxScans) {
      Fluttertoast.showToast(msg: "You have reached the 2-battery limit");
      return;
    }

    try {
      setState(() => scanning = true);

      final qrCodeRaw = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const _QRScannerPage()),
      );

      if (qrCodeRaw == null) {
        Fluttertoast.showToast(
          msg: "Scan cancelled",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        setState(() => scanning = false);
        return;
      }

      final qrCode = cleanExtract(qrCodeRaw);

      // Prevent duplicate scans
      if (scannedBatteryCodes.contains(qrCode)) {
        Fluttertoast.showToast(
          msg: "Battery already scanned ",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        setState(() => scanning = false);
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection('batteries')
          .where('qr_code', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        Fluttertoast.showToast(
          msg: "Battery not found",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        setState(() => scanning = false);
        return;
      }

      final data = query.docs.first.data();
      final assignedRider = data['assignedRider']?.toString() ?? "None";
      final assignedBike = data['assignedBike']?.toString() ?? "None";
      final batteryName = data['batteryName'] ?? "Unknown Battery";

      final isBooked = data['isBooked'] ?? false;
      final bookedBy = data['bookedBy'] ?? "another rider.";

      if (isBooked && bookedBy != userName) {
        Fluttertoast.showToast(
          msg: "Battery is booked by ${bookedBy.toString()}",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        return;
      }

      if (assignedRider == "None" && assignedBike == "None") {
        Fluttertoast.showToast(
          msg: "Battery usable",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        setState(() {
          scannedBatteries.add(batteryName);
          scannedBatteryCodes.add(qrCode);
          scanning = false;
        });
      } else {
        Fluttertoast.showToast(
          msg: "Battery unavailable for loading",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        setState(() => scanning = false);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
      setState(() => scanning = false);
    }
  }

  Future<void> clockIn() async {
    final mileageText = mileageController.text.trim();
    if (selectedBike == null || scannedBatteries.isEmpty || mileageText.isEmpty) {
      Fluttertoast.showToast(
          msg: "Select a bike, scan at least one battery, and input mileage");
      return;
    }

    final int? mileage = int.tryParse(mileageText);

    try {
      final now = DateTime.now();
      final timeString = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}";
      final dateString = "${now.weekdayName()}_${now.day}${now.daySuffix()}_of_${now.monthName()}"; // e.g., Friday_5th_December

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // Step 1: Update user document
      final userSnapshot = await userDocRef.get();
      final userName = userSnapshot.data()?['userName'] ?? "Unknown";
      final notificationId =
        DateTime.now().millisecondsSinceEpoch.toString();
        

      await userDocRef.update({
        'currentBike': selectedBike,
        'clockInTime': now,
        'clockinMileage': mileage,
        'isClockedIn': true,
        'notifications.$notificationId': {
          'isRead': false,
          'message': 'You\'re now clocked in.',
          'time': now,
        },
        "numberOfNotifications": FieldValue.increment(1),
      });

      // Step 2: Update each scanned battery
      for (String batteryName in scannedBatteries) {
        final batteryQuery = await FirebaseFirestore.instance
            .collection('batteries')
            .where('batteryName', isEqualTo: batteryName)
            .limit(1)
            .get();

        if (batteryQuery.docs.isEmpty) continue;

        final batteryRef = batteryQuery.docs.first.reference;
        final batteryData = batteryQuery.docs.first.data();

        // Prepare traces entry for today
        final traces = Map<String, dynamic>.from(batteryData['traces'] ?? {});
        traces[dateString] = {
          'dateEdited': now,
          'entries': [
            "Clocked in with $userName at $timeString",
            ...(traces[dateString]?['entries'] ?? [])
          ]
        };

        await batteryRef.update({
          'assignedRider': userName,
          'assignedBike': selectedBike,
          'batteryLocation': "In Motion",
          'offTime': now,
          'traces': traces,
        });
      }

      // Step 3: Update bike in general_variables
      final generalRef = FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables');

      final generalSnapshot = await generalRef.get();
      final bikes = Map<String, dynamic>.from(generalSnapshot.data()?['bikes'] ?? {});
      if (selectedBike != null && bikes.containsKey(selectedBike)) {
        bikes[selectedBike!] = {
          ...bikes[selectedBike]!,
          'isAssigned': true,
          'assignedRider': userName,
        };
      }


      await generalRef.update({'bikes': bikes});
      Fluttertoast.showToast(
        msg: "Clocked in successfully with bike: $selectedBike, batteries: ${scannedBatteries.join(', ')}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      setState(() {
        isClockedIn = true;
      });
      await _postClockInNotification(userName);
      // Clear scans after clock-in
      resetScans();
      mileageController.clear();
    } catch (e) {
      Fluttertoast.showToast(msg: "Error clocking in: ${e.toString()}");
    }
  }

  Future<void> _postClockInNotification(String userName) async {
    try {
      final now = Timestamp.now();
      final notifRef = FirebaseFirestore.instance.collection('notifications').doc('latest');

      await notifRef.set({
        'body': "$userName just clocked in.",
        'targetRoles': ["Manager", "CEO", "Systems, IT"],
        'timestamp': now,
        'title': "Clockins",
      });
    } catch (e) {
      debugPrint("Error posting clock-in notification: $e");
    }
  }

  /// Reset scanned batteries AND selected bike
  void resetScans() {
    setState(() {
      scannedBatteries.clear();
      scannedBatteryCodes.clear();
      selectedBike = null;  // ADD THIS LINE
      scanning = false;
    });
    Fluttertoast.showToast(
      msg: "Scans reset",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void showClockInConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Clock-In"),
          content: Text(
              "Confirm clock-in with bike $selectedBike, batteries: ${scannedBatteries.join(', ')} and a mileage of ${mileageController.text.trim()} km."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isClockingIn
                  ? null
                  : () async {
                      Navigator.pop(context);
                      setState(() => isClockingIn = true);
                      await clockIn(); // your async clock-in function
                      setState(() => isClockingIn = false);
                    },
              child: isClockingIn
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
  

  String resolveClockInText({
    required bool isOnline,
    required bool isClockedIn,
    required bool isLoading,
    required bool isBlocked,
  }) {
    if (_isOnline == false) return "You are offline";
    if (isClockedIn) return "You are clocked in already";
    if (isLoading) return "Processing...";
    if (isBlocked) return "Clock Out Disabled";

    return "Clock In";
  }


  @override
  Widget build(BuildContext context) {
    if (isClockedIn == null || isLoading) {
      // still fetching
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchBikes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bikes = snapshot.data!;
          final bikeNames = bikes.keys.toList();

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Replace the static text with live clock
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _timeString, // This updates every second
                      style: const TextStyle(
                        fontSize: 28, // Larger font for visibility
                        fontWeight: FontWeight.w700,
                        color: Colors.blue, // Optional: add color
                      ),
                    ),
                    // Optional: Add a refresh icon or AM/PM indicator
                    // Icon(Icons.access_time, size: 24),
                  ],
                ),

                  const SizedBox(height: 28),

                  /// Bike dropdown
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedBike,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: "Select Bike",
                        hintText: "Choose available bike",
                        prefixIcon: Icon(Icons.two_wheeler_outlined, color: Colors.blue[600]),
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
                        labelStyle: TextStyle(color: Colors.grey[700]),
                      ),
                      items: bikeNames.map((bikeName) {
                        final bike = bikes[bikeName];
                        final disabled = bike['isAssigned'] == true;

                        return DropdownMenuItem<String>(
                          value: disabled ? null : bikeName,
                          enabled: !disabled,
                          child: Row(
                            children: [
                              Expanded(child: Text(bikeName)),
                              if (disabled)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    "Assigned",
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedBike = value);
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  /// Scan Battery button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: scanning || scannedBatteries.length >= maxScans
                          ? null
                          : scanBattery,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        scannedBatteries.length >= maxScans
                            ? "Scan Limit Reached"
                            : (scanning ? "Scanning..." : "Scan Battery QR"),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// Reset button (red, borderless)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: resetScans,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.all(0),
                      ),
                      child: const Text("Reset"),
                    ),
                  ),

                  const SizedBox(height: 22),

                  /// Display scanned batteries
                  if (scannedBatteries.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: scannedBatteries.asMap().entries.map((entry) {
                        final index = entry.key;
                        final battery = entry.value;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.withValues(alpha: 0.1),
                                Colors.blue.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Number badge
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue,
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    "${index + 1}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Battery text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      battery,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      height: 2,
                                      width: 60,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.blue.withValues(alpha: 0.6), Colors.blue.withValues(alpha: 0.2)],
                                        ),
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),


                    
                  const SizedBox(height: 20),

                  _buildTextField(
                    enabled: true,
                    controller: mileageController,
                    label: 'Clock-In Mileage',
                    hint: '',
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.number,
                    icon: Icons.history,
                    validator: (v) => v == null || v.isEmpty 
                        ? 'Enter mileage' 
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // clock in button
                  const SizedBox(height: 24),

                  SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (selectedBike != null && scannedBatteries.isNotEmpty && mileageController.text.trim().isNotEmpty && !isClockingIn)
                        ? showClockInConfirmationDialog
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (isClockedIn ?? false) ? Colors.red : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isClockingIn
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            resolveClockInText(
                              isOnline: (_isOnline == true) ? true : false,
                              isClockedIn: isClockedIn == true,
                              isLoading: isLoading,
                              isBlocked: false,
                            ),
                            style: const TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                )

                
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Safe QR Scanner page
class _QRScannerPage extends StatefulWidget {
  const _QRScannerPage({super.key});

  @override
  State<_QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<_QRScannerPage> with TickerProviderStateMixin {
  bool _isProcessing = false;
  bool _torchOn = false; // ✅ Manual torch state
  final MobileScannerController controller = MobileScannerController();
  late AnimationController _dotsController;
  late Animation<int> _dotsAnimation;
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    
    // Dots animation
    _dotsController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
    
    _dotsAnimation = IntTween(begin: 1, end: 3).animate(
      CurvedAnimation(
        parent: _dotsController,
        curve: const Interval(0.0, 0.9, curve: Curves.easeInOut),
      ),
    );

    // Scanning line animation
    _scanLineController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scanLineController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    _dotsController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  String _getDots() {
    final dotCount = _dotsAnimation.value;
    return '.' * dotCount;
  }

  void _toggleTorch() async {
    try {
      await controller.toggleTorch();
      setState(() => _torchOn = !_torchOn);
    } catch (e) {
      // Silent fail
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: _dotsController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.withValues(alpha: 0.3), Colors.green.withValues(alpha: 0.1)],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.green.withValues(alpha: 0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.green, blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Scanner${_getDots()}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        backgroundColor: Colors.black87,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        // ✅ Premium Torch Button
        actions: [
          GestureDetector(
            onTap: _toggleTorch,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withValues(alpha: 0.3),
                    Colors.yellow.withValues(alpha: 0.2),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _torchOn ? Colors.yellow.withValues(alpha: 0.5) : Colors.orange.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                color: _torchOn ? Colors.yellow[300] : Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          MobileScanner(
            controller: controller,
            fit: BoxFit.cover,
            onDetect: (capture) async {
              if (_isProcessing) return;
              _isProcessing = true;

              final barcode = capture.barcodes.first;
              final raw = barcode.rawValue ?? "";
              await controller.stop();

              if (mounted) {
                Navigator.pop(context, raw);
              }
            },
          ),
          
          // Vignette overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.2, -0.4),
                radius: 0.7,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
          
          // ✅ Animated Scanning Line
          AnimatedBuilder(
            animation: _scanLineController,
            builder: (context, child) {
              return CustomPaint(
                painter: ScanningLinePainter(scanPosition: _scanLineAnimation.value),
                size: Size.infinite,
              );
            },
          ),
          
          // ✅ Premium Scanning Frame
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green.withValues(alpha: 0.9), width: 3),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  const Positioned(top: 0, left: 0, child: _Corner()),
                  const Positioned(top: 0, right: 0, child: _Corner()),
                  const Positioned(bottom: 0, left: 0, child: _Corner()),
                  const Positioned(bottom: 0, right: 0, child: _Corner()),
                  
                  // Center instruction
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Position QR code here",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Fixed Scanning Line Painter
class ScanningLinePainter extends CustomPainter {
  final double scanPosition;

  ScanningLinePainter({required this.scanPosition});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.green.withValues(alpha: 0.3), Colors.green.withValues(alpha: 0.8)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 6))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0);

    final lineHeight = 6.0;
    final scanY = size.height * 0.25 + (size.height * 0.5 * scanPosition);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(30, scanY - lineHeight/2, size.width - 60, lineHeight),
        const Radius.circular(6),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Corner Widget
class _Corner extends StatelessWidget {
  const _Corner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(18),
          topLeft: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.7),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
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
