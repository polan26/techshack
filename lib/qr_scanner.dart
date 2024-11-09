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
  bool isScanCompleted = false;
  bool isFlashOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  late MobileScannerController _scannerController;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _audioPlayer = AudioPlayer();
  }

  void _playScanSound() async {
    await _audioPlayer.play(AssetSource('scan.mp3'));
  }

  void _handleBarcodeDetection(Barcode barcode) {
    if (!isScanCompleted) {
      final code = barcode.rawValue ?? '---';

      if (barcode.rawValue != null) {
        setState(() {
          isScanCompleted = true;
        });

        _playScanSound();

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
                    serialNumber('Graphics Card', code);
                  },
                ),
                TextButton(
                  child: const Text('Motherboard'),
                  onPressed: () {
                    serialNumber('Motherboard', code);
                  },
                ),
                TextButton(
                  child: const Text('Processor'),
                  onPressed: () {
                    serialNumber('Processor', code);
                  },
                ),
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.pop(context);
                    _resetScanState();
                  },
                ),
              ],
            );
          },
        );
      }
    }
  }

  void serialNumber(String category, String code) {
    Provider.of<SerialNumberModel>(context, listen: false)
        .addSerialNumber(category, code)
        .then((_) {
      Navigator.push(
        // ignore: use_build_context_synchronously
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Serial number saved to $category!')),
    );

    Navigator.pop(context);
    _resetScanState();
  }

  void _resetScanState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        isScanCompleted = false;
      });
    });
  }

  void _toggleFlash() async {
    setState(() {
      isFlashOn = !isFlashOn;
    });
    if (isFlashOn) {
      await isFlashOn.turnOn();
    } else {
      await isFlashOn.turnOff();
    }
  }

  void _switchCamera() {
    setState(() {
      _cameraFacing = _cameraFacing == CameraFacing.back
          ? CameraFacing.front // Switch to front camera
          : CameraFacing.back; // Switch to back camera
      _scannerController.switchCamera();
    });
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
                  width: 500, // Fixed scanner width
                  height: 500, // Fixed scanner height
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 500,
                        height: 500,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      SizedBox(
                        width: 500,
                        height: 500,
                        child: MobileScanner(
                            controller: _scannerController,
                            onDetect: (BarcodeCapture barcodeCapture) {
                              _handleBarcodeDetection(
                                  barcodeCapture.barcodes.first);
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

extension on bool {
  turnOn() {}
  turnOff() {}
}
