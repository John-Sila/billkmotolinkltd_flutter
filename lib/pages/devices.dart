import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Devices extends StatefulWidget {
  const Devices({super.key});

  @override
  State<Devices> createState() => _DevicesState();
}

class _DevicesState extends State<Devices> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('device_info', isNotEqualTo: null)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No device data found',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.6),
                ),
              ),
            );
          }

          final devices = snapshot.data!.docs;

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            color: Theme.of(context).primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final doc = devices[index];
                final data = doc.data() as Map<String, dynamic>?;
                final deviceInfo = data?['device_info'] as Map<String, dynamic>?;

                if (deviceInfo == null) return const SizedBox.shrink();

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(doc.id)
                      .get(),
                  builder: (context, userSnap) {
                    String userName = 'N/A';
                    if (userSnap.hasData) {
                      final userData = userSnap.data!.data() as Map<String, dynamic>?;
                      userName = userData?['userName'] ?? 'N/A';
                    }

                    return DeviceCardFull(
                      deviceInfo: deviceInfo,
                      uid: doc.id,
                      userName: userName,
                      userEmail: data?['userEmail'] ?? 'N/A',
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class DeviceCardFull extends StatelessWidget {
  final Map<String, dynamic> deviceInfo;
  final String uid;
  final String userName;
  final String userEmail;

  const DeviceCardFull({
    super.key,
    required this.deviceInfo,
    required this.uid,
    required this.userName,
    required this.userEmail,
  });

  String _safeString(dynamic value, [String defaultValue = 'N/A']) => 
      value?.toString() ?? defaultValue;
  
  double? _safeDouble(dynamic value) => value is num ? (value as num).toDouble() : null;
  
  String _formatBattery(dynamic level) {
    final battery = _safeDouble(level);
    return battery != null ? '${battery.toInt()}%' : 'N/A';
  }

  Color _getAdaptiveColor(BuildContext context, Color light, Color dark) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  List<Widget> _buildAllFields(BuildContext context) {
    final fields = <Widget>[];
    
    final fieldData = {
      'Platform': _safeString(deviceInfo['platform']),
      'Model': _safeString(deviceInfo['model']),
      'Manufacturer': _safeString(deviceInfo['manufacturer']),
      'Brand': _safeString(deviceInfo['brand']),
      'Device ID': _safeString(deviceInfo['deviceId']),
      'Product': _safeString(deviceInfo['product']),
      'Hardware': _safeString(deviceInfo['hardware']),
      'Display': _safeString(deviceInfo['display']),
      'Host': _safeString(deviceInfo['host']),
      'OS Version': _safeString("Android ${deviceInfo['osVersion']}"),
      'API Level': _safeString(deviceInfo['apiLevel']),
      'Battery': _formatBattery(deviceInfo['batteryLevel']),
      'Battery State': _safeString(deviceInfo['batteryState']),
      'Network': _safeString(deviceInfo['networkType']),
      'Physical Device': _safeString(deviceInfo['isPhysicalDevice']),
      'Screen': '${_safeDouble(deviceInfo['screenWidth'])?.toInt()}x${_safeDouble(deviceInfo['screenHeight'])?.toInt()}',
      'Pixel Ratio': _safeString(deviceInfo['pixelRatio']),
      'Supported ABIs': _safeString(deviceInfo['supportedAbis']),
    };

    fieldData.forEach((key, value) {
      fields.add(_buildFieldRow(context, key, value));
    });

    final padding = deviceInfo['screenPadding'] as Map<String, dynamic>?;
    if (padding != null) {
      fields.add(_buildFieldRow(context, 'Padding Top', _safeString(padding['top'])));
      fields.add(_buildFieldRow(context, 'Padding Bottom', _safeString(padding['bottom'])));
      fields.add(_buildFieldRow(context, 'Padding Left', _safeString(padding['left'])));
      fields.add(_buildFieldRow(context, 'Padding Right', _safeString(padding['right'])));
    }

    return fields;
  }

  @override
  Widget build(BuildContext context) {
    final platform = _safeString(deviceInfo['platform']);
    final model = _safeString(deviceInfo['model']);
    final timestamp = deviceInfo['lastUploadTimestamp'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _getAdaptiveColor(context, 
                Colors.black.withValues(alpha: 0.1), 
                Colors.black.withValues(alpha: 0.3)
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.all(20),
        leading: CircleAvatar(
          backgroundColor: _getAdaptiveColor(context,
              platform == 'android' ? Colors.green[500]! : Colors.blue[500]!,
              platform == 'android' ? Colors.green[700]! : Colors.blue[700]!
          ),
          child: Icon(
            platform == 'android' ? Icons.android : Icons.phone_iphone,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          model,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ) ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '👤 $userName', 
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ) ?? const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              userEmail, 
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
        trailing: timestamp != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getAdaptiveColor(context, 
                      Colors.blue[50]!, 
                      Colors.blue[900]!
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year} ${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: _getAdaptiveColor(context, 
                        Colors.blue[800]!, 
                        Colors.blue[200]!
                    ),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[850] 
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person, 
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User: $userName', 
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ) ?? const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'UID: ${uid.substring(0, 12)}...', 
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._buildAllFields(context),
        ],
      ),
    );
  }

  Widget _buildFieldRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[850] 
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getAdaptiveColor(context, 
                      Colors.grey[200]!, 
                      Colors.grey[700]!
                  ),
                ),
              ),
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
