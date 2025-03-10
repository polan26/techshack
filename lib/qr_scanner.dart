import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:qr_scanner/monthly_summary.dart';
import 'package:qr_scanner/user_guide.dart';
import 'package:qr_scanner/weekly_summary.dart';
import 'serial_number_model.dart';
import 'serial_number_history.dart';
import 'inventory.dart';
import 'daily_sales.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:vibration/vibration.dart';

const backgroundColor = Color.fromARGB(248, 248, 245, 245);

class QrScanner extends StatefulWidget {
  const QrScanner({super.key});

  @override
  State<QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<QrScanner> {
  bool hasScanned = false;
  bool isFlashActive = false;
  bool isBulkScanning = false; // Add this flag
  List<String> bulkScannedCodes = []; // Store scanned codes
  CameraFacing cameraDirection = CameraFacing.back;
  late MobileScannerController scannerController;
  late AudioPlayer audioPlayer;

  @override
  void initState() {
    super.initState();
    scannerController = MobileScannerController();
    audioPlayer = AudioPlayer();
  }

  Future<void> playScanSound() async {
    await audioPlayer.play(AssetSource('scan.mp3'));
  }

  Future<void> onBarcodeDetected(Barcode barcode) async {
    final code = barcode.rawValue ?? 'Unknown Code';

    // Filter out unwanted barcodes
    if (code.toLowerCase().startsWith("wifi:") || code.startsWith("480")) {
      if (!hasScanned) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This QR code is not supported.')),
        );
      }
      return;
    }

    if (!hasScanned || isBulkScanning) {
      setState(() {
        hasScanned = true;
      });

      playScanSound(); // Play sound

      // **Add vibration when scanning in bulk mode**
      if (isBulkScanning) {
        HapticFeedback.heavyImpact(); // Simple vibration
        // OR use flutter_vibrate for more control
        // Vibrate.feedback(FeedbackType.success);
      }

      // Check if the serial number has been scanned before
      final previousScan =
          Provider.of<SerialNumberModel>(context, listen: false)
              .findSerialNumber(code);

      if (previousScan != null) {
        if (isBulkScanning) {
          if (!bulkScannedCodes.contains(code)) {
            bulkScannedCodes.add(code);
            debugPrint('Added code: $code');
            debugPrint('Total codes: ${bulkScannedCodes.length}');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Duplicate code detected: $code')),
            );
          }
        } else {
          showDuplicateScanPrompt(code, previousScan);
        }
      } else {
        if (isBulkScanning) {
          if (!bulkScannedCodes.contains(code)) {
            bulkScannedCodes.add(code);
            debugPrint('Added code: $code');
            debugPrint('Total codes: ${bulkScannedCodes.length}');
          }
        } else {
          showSaveDialog(code);
        }
        if (isBulkScanning) {
          if (await Vibration.hasVibrator()) {
            Vibration.vibrate(); // Uses the default vibration duration
          }
        }
      }
    }
  }

  void showDuplicateScanPrompt(String code, Map<String, dynamic> previousScan) {
    final previousCategory = previousScan['category'];
    final previousTimestamp = previousScan['timestamp'];

    // Format the timestamp to show only the date
    final formattedDate = _formatTimestampToDate(previousTimestamp);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Scan Detected!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This serial number was previously scanned:'),
            const SizedBox(height: 10),
            Text('Category: $previousCategory'),
            Text('Date: $formattedDate'), // Show only the date
          ],
        ),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
              resetScanState(); // Reset the scan state
            },
          ),
        ],
      ),
    );
  }

  String _formatTimestampToDate(dynamic timestamp) {
    if (timestamp is DateTime) {
      // If the timestamp is already a DateTime object
      return '${timestamp.year}-${timestamp.month}-${timestamp.day}';
    } else if (timestamp is String) {
      // If the timestamp is a string, parse it to DateTime first
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.year}-${dateTime.month}-${dateTime.day}';
    } else {
      // Handle other cases (e.g., if timestamp is in a different format)
      return 'Unknown Date';
    }
  }

  void showSaveDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Your Serial Number!'),
        content: const Text('Where would you like to keep this number?'),
        actions: [
          ...buildCategoryButtons(code),
          TextButton(
            child: const Text('No, thanks!'),
            onPressed: () {
              Navigator.pop(context);
              resetScanState(); // Reset the scan state
            },
          ),
        ],
      ),
    );
  }

  List<Widget> buildCategoryButtons(String code, {bool isBulk = false}) {
    final categories = ['Graphics Card', 'Motherboard', 'Processor'];
    return categories.map((category) {
      return TextButton(
        child: Text(category),
        onPressed: () async {
          if (!mounted) return;

          final serialNumberModel =
              Provider.of<SerialNumberModel>(context, listen: false);

          if (isBulk) {
            for (final code in bulkScannedCodes) {
              final previousScan = serialNumberModel.findSerialNumber(code);
              if (previousScan == null) {
                await saveSerialNumber(category, code);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Duplicate code skipped: $code')),
                  );
                }
              }
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Saved ${bulkScannedCodes.length} codes under $category!'),
                ),
              );
              setState(() {
                bulkScannedCodes.clear();
              });
            }
          } else {
            await saveSerialNumber(category, code);
          }

          if (mounted) {
            Navigator.pop(context);
          }
        },
      );
    }).toList();
  }

  Future<void> saveSerialNumber(String category, String code) async {
    try {
      await Provider.of<SerialNumberModel>(context, listen: false)
          .addSerialNumber(category, code);
      debugPrint('Saved code: $code under $category');
    } catch (e) {
      debugPrint('Error saving code: $e');
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved under $category!')),
    );

    // Reset the scan state after saving
    resetScanState();
  }

  void resetScanState() {
    debugPrint('Resetting scan state...');
    if (mounted) {
      setState(() {
        hasScanned = false;
      });
    }
  }

  Future<void> toggleFlash() async {
    setState(() {
      isFlashActive = !isFlashActive;
    });

    // Use the MobileScannerController to control flash
    if (isFlashActive) {
      scannerController.toggleTorch(); // Use toggleTorch instead
    } else {
      scannerController.toggleTorch(); // Use toggleTorch instead
    }
  }

  void switchCamera() {
    setState(() {
      cameraDirection = cameraDirection == CameraFacing.back
          ? CameraFacing.front // Switch to front camera
          : CameraFacing.back; // Switch to back camera
      scannerController.switchCamera();

      String cameraPosition =
          cameraDirection == CameraFacing.front ? 'front' : 'back';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to $cameraPosition camera')),
      );
    });
  }

  void toggleBulkScanning() {
    setState(() {
      isBulkScanning = !isBulkScanning;
      if (!isBulkScanning) {
        if (bulkScannedCodes.isNotEmpty) {
          saveBulkScannedCodes(); // Save or export the batch
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No codes scanned in bulk mode.')),
          );
        }
        resetScanState(); // Reset the scan state
      }
    });
  }

  void saveBulkScannedCodes() {
    if (bulkScannedCodes.isEmpty) {
      debugPrint('No codes to save.'); // Debug log
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No codes scanned in bulk mode.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Bulk Scanned Codes'),
        content: const Text('Choose a category to save these codes:'),
        actions: [
          ...buildCategoryButtons('', isBulk: true), // Pass isBulk: true
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: toggleFlash,
            icon: Icon(
              isFlashActive ? Icons.flash_off : Icons.flash_on,
              color: Colors.grey,
            ),
          ),
          IconButton(
            onPressed: switchCamera,
            icon: const Icon(Icons.camera, color: Colors.grey),
          ),
          IconButton(
            onPressed: toggleBulkScanning, // Add this button
            icon: Icon(
              isBulkScanning ? Icons.stop : Icons.play_arrow,
              color: Colors.grey,
            ),
          ),
        ],
        iconTheme: const IconThemeData(
          color: Color.fromARGB(221, 131, 97, 97),
        ),
        centerTitle: true,
        title: const Text(
          "QR Scanner",
          style: TextStyle(
            color: Color.fromARGB(221, 0, 0, 0),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Hold your device steady over the QR code.",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text("Scanning will start automatically."),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 400, // Fixed scanner height
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: MobileScanner(
                          controller: scannerController,
                          onDetect: (BarcodeCapture barcodeCapture) {
                            onBarcodeDetected(barcodeCapture.barcodes.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Expanded(
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  "TechShack",
                  style: TextStyle(
                    color: Color.fromARGB(221, 247, 228, 228),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 73, 167, 255),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TechShack',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Image.asset(
                    'assets/logo.png',
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                  ),
                ],
              ),
            ),
            buildDrawerItem('Graphics Card'),
            buildDrawerItem('Motherboard'),
            buildDrawerItem('Processor'),
            ListTile(
              title: const Text('Inventory'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Inventory(),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Daily Sales'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomePage(),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Weekly Summary'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WeeklySummaryPage(
                      weeklyData: const [],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Monthly Summary'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MonthlySummaryPage(
                      monthlyData: [],
                      weeklySales: [], // Pass appropriate data
                    ),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('User Guide'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserGuide(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDrawerItem(String category) {
    return ListTile(
      title: Text(category),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Consumer<SerialNumberModel>(
              builder: (context, serialNumberModel, child) {
                return SerialNumberHistoryScreen(
                  category: category,
                  initialSerialNumbers: serialNumberModel
                      .getSerialNumbers(category)
                      .map((map) => map['serialNumber']!)
                      .toList(),
                  serialNumbers: const [],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
