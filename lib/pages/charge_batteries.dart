import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

class ChargeBatteries extends StatefulWidget {
  const ChargeBatteries({super.key});

  @override
  State<ChargeBatteries> createState() => ChargeBatteriesState();
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


class ChargeBatteriesState extends State<ChargeBatteries> {
  bool scanning = false;

  List<String> scannedBatteries = [];
  List<String> scannedBatteryCodes = [];

  List<String> destinations = [];
  String? selectedDestination;

  static const int maxScans = 1;
  bool isCharging = false;

  bool? isClockedIn;
  String userName = "";
  String currentBike = "";
  String _timeString = "";
  late Timer _timer;
  bool? _isOnline;
  bool isLoading = true;

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
  void initState() {
    super.initState();

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    initializerFunctions();
    checkIsOnline();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeString = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}";
    });
  }

  Future<void> initializerFunctions() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    setState(() {
      isClockedIn = data['isClockedIn'] ?? false;
      userName = data['userName'] ?? "User";
      currentBike = data['currentBike'] ?? "None";
      isLoading = false;
    });

    // Fetch destinations
    final generalDoc =
        await FirebaseFirestore.instance.collection('general').doc('general_variables').get();
    destinations = List<String>.from(generalDoc.data()?['destinations'] ?? []);

  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
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
      Fluttertoast.showToast(msg: "You have reached the 1-battery limit");
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
        Fluttertoast.showToast(msg: "Battery already scanned");
        setState(() => scanning = false);
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection('batteries')
          .where('qr_code', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        Fluttertoast.showToast(msg: "Battery not found");
        setState(() => scanning = false);
        return;
      }

      final data = query.docs.first.data();
      final assignedRider = data['assignedRider']?.toString() ?? "None";
      final batteryName = data['batteryName'] ?? "Unknown Battery";

      if (assignedRider == userName) {
        setState(() {
          scannedBatteries.add(batteryName);
          scannedBatteryCodes.add(qrCode);
          scanning = false;
        });
      } else {
        Fluttertoast.showToast(
          msg: "Batttery needs to be assigned to you.",
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

  Future<void> chargeBatteries() async {
    if (scannedBatteries.isEmpty) {
      Fluttertoast.showToast(msg: "You need to scan at least one battery.");
      return;
    }

    setState(() => isCharging = true);

    final now = DateTime.now();
    final timeString =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final dateString =
        "${now.weekdayName()}_${now.day}${now.daySuffix()}_of_${now.monthName()}"; // e.g., Friday_5th_December
    final selectedLoc = selectedDestination;

    final batch = FirebaseFirestore.instance.batch();

    try {
      Future<void> updateBattery(String batteryName,
          {required bool onCharge}) async {
        final query = await FirebaseFirestore.instance
            .collection('batteries')
            .where('batteryName', isEqualTo: batteryName)
            .limit(1)
            .get();

        if (query.docs.isEmpty) return;

        final ref = query.docs.first.reference;
        final data = query.docs.first.data();
        final traces = Map<String, dynamic>.from(data['traces'] ?? {});

        // Use arrayUnion to append without fetching existing entries
        traces[dateString] = {
          'dateEdited': now,
          'entries': FieldValue.arrayUnion([
            onCharge
                ? "Dropped to charge by $userName at $selectedLoc at $timeString"
                : ""
          ])
        };

        batch.update(ref, {
          'assignedRider': "None",
          'assignedBike': "None",
          'batteryLocation': "Charging at $selectedLoc",
          'offTime': now,
          'traces': traces,
        });
      }

      // Queue all onload batteries
      for (final battery in scannedBatteries) {
        await updateBattery(battery, onCharge: true);
      }

      // Commit all updates at once
      await batch.commit();

      Fluttertoast.showToast(
          msg: "Batteries marked as charging!",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );

      setState(() => isCharging = false);
      resetScans();
    } catch (e) {
      Fluttertoast.showToast(msg: "Error swapping batteries: ${e.toString()}");
      setState(() => isCharging = false);
    }
  }

  /// Reset scanned batteries AND selected bike
  void resetScans() {
    setState(() {
      scannedBatteries.clear();
      scannedBatteryCodes.clear();
      scanning = false;
    });
    Fluttertoast.showToast(
      msg: "Scan list reset",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void showSwapConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Confirm Swap"),
          content: Text(
              "Confirm battery swap."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isCharging
                  ? null
                  : () async {
                      Navigator.pop(context);
                      setState(() => isCharging = true);
                      await chargeBatteries(); // your async clock-in function
                      setState(() => isCharging = false);
                    },
              child: isCharging
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

  String resolveChargeText({
    required bool isOnline,
    required bool isClockedIn,
    required bool isLoading,
    required bool isBlocked,
  }) {
    if (_isOnline == false) return "You are offline";
    if (!isClockedIn) return "You are not clocked in";
    if (isLoading) return "Processing...";
    if (isBlocked) return "Clock Out Disabled";

    return "Charge";
  }
  
  @override
  Widget build(BuildContext context) {
    if (isClockedIn == null) {
      // still fetching
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live clock
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _timeString, 
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // -----------------------
                // 1. OFFLOAD SECTION
                // -----------------------
                const Text(
                  "Charge Batteries",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),
                if (scannedBatteries.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: scannedBatteries.map((battery) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          "Charge $battery",
                          style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.w900),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 12),
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
                
                const SizedBox(height: 28),

                // Location dropdown
                _buildDropdownField<String>(
                    value: selectedDestination,
                    label: "Select Location",
                    hint: "Choose destination",
                    icon: Icons.location_on,
                    items: destinations.map((loc) {
                      return DropdownMenuItem<String>(
                        value: loc,
                        child: Text(loc),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => selectedDestination = val);
                    },
                  ),
                const SizedBox(height: 20),

                // -----------------------
                // Swap / Submit Button
                // -----------------------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (
                            scannedBatteries.isNotEmpty &&
                            selectedDestination != null &&
                            !isCharging)
                        ? showSwapConfirmationDialog
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (isCharging) ? Colors.red : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isCharging
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            resolveChargeText(
                              isOnline: (_isOnline == true) ? true : false,
                              isClockedIn: isClockedIn == true,
                              isLoading: isLoading,
                              isBlocked: false,
                            ),
                            style: const TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
  bool _torchOn = false;  // ✅ Manual torch state
  final MobileScannerController controller = MobileScannerController();
  late AnimationController _dotsController;
  late Animation<int> _dotsAnimation;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    controller.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  String _getDots() {
    final dotCount = _dotsAnimation.value;
    return '.' * dotCount;
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
        // ✅ FIXED TORCH BUTTON
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
          // Scanning frame
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green.withValues(alpha: 0.9), width: 3),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.5),
                    blurRadius: 25,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  const Positioned(top: 0, left: 0, child: _Corner()),
                  const Positioned(top: 0, right: 0, child: _Corner()),
                  const Positioned(bottom: 0, left: 0, child: _Corner()),
                  const Positioned(bottom: 0, right: 0, child: _Corner()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ TORCH TOGGLE METHOD
  void _toggleTorch() async {
    try {
      await controller.toggleTorch();
      setState(() {
        _torchOn = !_torchOn;
      });
    } catch (e) {
      // Handle torch error silently
    }
  }
}

// ✅ CORNER WIDGET (stateless)
class _Corner extends StatelessWidget {
  const _Corner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(15),
          topLeft: Radius.circular(15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.6),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
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
