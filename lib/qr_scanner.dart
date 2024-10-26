import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'serial_number_model.dart';
import 'serial_number_history.dart';
import 'inventory.dart'; // Import the inventory file

const gbColor = Color.fromARGB(248, 248, 245, 245);

class QrScanner extends StatefulWidget {
  const QrScanner({super.key});

  @override
  State<QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<QrScanner> {
  bool isScanCompleted = false; // Track if a scan has been completed
  double scannerWidth = 300; // Initial width of the scanner
  double scannerHeight = 300; // Initial height of the scanner
  bool isFlashOn = false; // Track flashlight status
  CameraFacing _cameraFacing = CameraFacing.back; // Start with the back camera

  late MobileScannerController _scannerController; // Controller for the scanner
  late AudioPlayer _audioPlayer; // Audio player for scan sound

  @override
  void initState() {
    super.initState();
    _scannerController =
        MobileScannerController(); // Initialize scanner controller
    _audioPlayer = AudioPlayer(); // Initialize audio player
  }

  void _playScanSound() async {
    await _audioPlayer.play(AssetSource('scan.mp3')); // Play sound on scan
  }

  void _handleBarcodeDetection(Barcode barcode) {
    if (!isScanCompleted) {
      // Ensure scan is not already completed
      final code =
          barcode.rawValue ?? '---'; // Get the raw value of the barcode

      if (barcode.rawValue != null) {
        setState(() {
          isScanCompleted = true; // Mark scan as completed
        });

        _playScanSound(); // Play sound on successful scan

        // Show dialog to ask user where to save the serial number
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Save Serial Number'),
              content:
                  const Text('Where would you like to save the serial number?'),
              actions: [
                TextButton(
                  child: const Text('Graphics Card'),
                  onPressed: () {
                    _saveSerialNumber(
                        'Graphics Card', code); // Save to Graphics Card
                  },
                ),
                TextButton(
                  child: const Text('Motherboard'),
                  onPressed: () {
                    _saveSerialNumber(
                        'Motherboard', code); // Save to Motherboard
                  },
                ),
                TextButton(
                  child: const Text('Processor'),
                  onPressed: () {
                    _saveSerialNumber('Processor', code); // Save to Processor
                  },
                ),
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    _resetScanState(); // Reset scan state
                  },
                ),
              ],
            );
          },
        );
      }
    }
  }

  void _saveSerialNumber(String category, String code) {
    // Save the serial number to the selected category
    Provider.of<SerialNumberModel>(context, listen: false)
        .addSerialNumber(category, code)
        .then((_) {
      // Navigate to Serial Number History screen after saving
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
    });

    // Show snackbar notification for successful save
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Serial number saved to $category!')),
    );

    Navigator.pop(context); // Close dialog
    _resetScanState(); // Reset scan state
  }

  void _resetScanState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        isScanCompleted = false; // Reset scan completed status
      });
    });
  }

  void _toggleFlash() {
    // Toggle the flashlight only if the controller is initialized
    setState(() {
      isFlashOn = !isFlashOn; // Switch flashlight status
      // Check if the controller has a method for toggling the flash
      _scannerController.toggleTorch();
    });
  }

  void _switchCamera() {
    setState(() {
      // Switch camera without checking isInitialized
      _cameraFacing = _cameraFacing == CameraFacing.back
          ? CameraFacing.front // Switch to front camera
          : CameraFacing.back; // Switch to back camera
      _scannerController.switchCamera(); // Update camera controller
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Dispose audio player
    _scannerController.dispose(); // Dispose scanner controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: gbColor,
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: _toggleFlash, // Toggle flashlight
            icon: Icon(
              isFlashOn ? Icons.flash_off : Icons.flash_on,
              color: Colors.grey,
            ),
          ),
          IconButton(
            onPressed: _switchCamera, // Switch camera
            icon: const Icon(
              Icons.camera,
              color: Colors.grey,
            ),
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
        title: const Text(
          "QR Scanner",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer(); // Open drawer menu
              },
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
                    "Place the QR code",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text("Scanning will automatically start"), // Instructions
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Center(
                child: SizedBox(
                  width: scannerWidth, // Adjustable scanner width
                  height: scannerHeight, // Adjustable scanner height
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: scannerWidth,
                        height: scannerHeight,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.black, width: 2), // Scanner border
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      SizedBox(
                        width: scannerWidth,
                        height: scannerHeight,
                        child: MobileScanner(
                            controller: _scannerController,
                            onDetect: (BarcodeCapture barcodeCapture) {
                              _handleBarcodeDetection(barcodeCapture
                                  .barcodes.first); // Handle detected barcode
                            }),
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
                    color: Colors.black87,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text("Width"), // Slider for scanner width
                Expanded(
                  child: Slider(
                    value: scannerWidth,
                    min: 100,
                    max: 600,
                    onChanged: (value) {
                      setState(() {
                        scannerWidth = value; // Update scanner width
                      });
                    },
                    label: 'Width: ${scannerWidth.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text("Height"), // Slider for scanner height
                Expanded(
                  child: Slider(
                    value: scannerHeight,
                    min: 100,
                    max: 600,
                    onChanged: (value) {
                      setState(() {
                        scannerHeight = value; // Update scanner height
                      });
                    },
                    label: 'Height: ${scannerHeight.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'TechShack',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              title: const Text('Graphics Card'), // Option for Graphics Card
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Consumer<SerialNumberModel>(
                      builder: (context, serialNumberModel, child) {
                        return SerialNumberHistoryScreen(
                          category: 'Graphics Card',
                          initialSerialNumbers: serialNumberModel
                              .getSerialNumbers('Graphics Card')
                              .map((map) => map['serialNumber']!)
                              .toList(),
                          serialNumbers: const [],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Motherboard'), // Option for Motherboard
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Consumer<SerialNumberModel>(
                      builder: (context, serialNumberModel, child) {
                        return SerialNumberHistoryScreen(
                          category: 'Motherboard',
                          initialSerialNumbers: serialNumberModel
                              .getSerialNumbers('Motherboard')
                              .map((map) => map['serialNumber']!)
                              .toList(),
                          serialNumbers: const [],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Processor'), // Option for Processor
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Consumer<SerialNumberModel>(
                      builder: (context, serialNumberModel, child) {
                        return SerialNumberHistoryScreen(
                          category: 'Processor',
                          initialSerialNumbers: serialNumberModel
                              .getSerialNumbers('Processor')
                              .map((map) => map['serialNumber']!)
                              .toList(),
                          serialNumbers: const [],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Inventory'), // Option for Inventory
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const Inventory(), // Navigate to Inventory screen
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
