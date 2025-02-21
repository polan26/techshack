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
import 'home_page.dart';

const backgroundColor = Color.fromARGB(248, 248, 245, 245);

class QrScanner extends StatefulWidget {
  const QrScanner({super.key});

  @override
  State<QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<QrScanner> {
  bool hasScanned = false;
  bool isFlashActive = false;
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

  void onBarcodeDetected(Barcode barcode) {
    final code = barcode.rawValue ?? 'Unknown Code';

    // Filter out unwanted barcodes
    if (code.toLowerCase().startsWith("wifi:") || code.startsWith("480")) {
      if (!hasScanned) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This QR code is not supported.')),
        );
        resetScanState(); // Allow scanning again
      }
      return;
    }

    if (!hasScanned) {
      setState(() {
        hasScanned = true;
      });

      playScanSound();

      // Check if the serial number has been scanned before
      final previousScan =
          Provider.of<SerialNumberModel>(context, listen: false)
              .findSerialNumber(code);

      if (previousScan != null) {
        // Show a prompt with previous scan details
        showDuplicateScanPrompt(code, previousScan);
      } else {
        // Proceed to save the new serial number
        showSaveDialog(code);
      }
    }
  }

  void showDuplicateScanPrompt(String code, Map<String, dynamic> previousScan) {
    final previousCategory = previousScan['category'];
    final previousTimestamp = previousScan['timestamp'];

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
            Text('Timestamp: ${previousTimestamp.toString()}'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
              resetScanState();
            },
          ),
        ],
      ),
    );
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
              resetScanState();
            },
          ),
        ],
      ),
    );
  }

  List<Widget> buildCategoryButtons(String code) {
    final categories = ['Graphics Card', 'Motherboard', 'Processor'];
    return categories.map((category) {
      return TextButton(
        child: Text(category),
        onPressed: () {
          saveSerialNumber(category, code);
          Navigator.pop(context); // Close the dialog
        },
      );
    }).toList();
  }

  Future<void> saveSerialNumber(String category, String code) async {
    await Provider.of<SerialNumberModel>(context, listen: false)
        .addSerialNumber(category, code);
    if (!mounted) return; // Check if the widget is still mounted

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SerialNumberHistoryScreen(
          category: category,
          initialSerialNumbers: Provider.of<SerialNumberModel>(context)
              .getSerialNumbers(category)
              .map((map) => map['serialNumber']!)
              .toList(),
          serialNumbers: const [],
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved under $category!')),
    );
    resetScanState(); // Reset scan state after saving
  }

  void resetScanState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        hasScanned = false;
      });
    });
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
