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
  double scannerWidth = 300;
  double scannerHeight = 300;
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

  void _handleBarcodeDetection(BarcodeCapture barcodeCapture) {
    if (!isScanCompleted) {
      final barcode = barcodeCapture.barcodes.isNotEmpty
          ? barcodeCapture.barcodes.first
          : null;
      final code = barcode?.rawValue ?? '---';

      if (barcode != null) {
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
                    _saveSerialNumber('Graphics Card', code);
                  },
                ),
                TextButton(
                  child: const Text('Motherboard'),
                  onPressed: () {
                    _saveSerialNumber('Motherboard', code);
                  },
                ),
                TextButton(
                  child: const Text('Processor'),
                  onPressed: () {
                    _saveSerialNumber('Processor', code);
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

  void _saveSerialNumber(String category, String code) {
    Provider.of<SerialNumberModel>(context, listen: false)
        .addSerialNumber(category, code)
        .then((_) {
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

  void _toggleFlash() {
    if (_scannerController.value.isInitialized) {
      setState(() {
        isFlashOn = !isFlashOn;
        _scannerController.toggleTorch();
      });
    }
  }

  void _switchCamera() {
    if (_scannerController.value.isInitialized) {
      setState(() {
        _cameraFacing = _cameraFacing == CameraFacing.back
            ? CameraFacing.front
            : CameraFacing.back;
        _scannerController.switchCamera();
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: gbColor,
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: _toggleFlash,
            icon: Icon(
              isFlashOn ? Icons.flash_off : Icons.flash_on,
              color: Colors.grey,
            ),
          ),
          IconButton(
            onPressed: _switchCamera,
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
                Scaffold.of(context).openDrawer();
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
                  Text("Scanning will automatically start"),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Center(
                child: SizedBox(
                  width: scannerWidth,
                  height: scannerHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: scannerWidth,
                        height: scannerHeight,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      SizedBox(
                        width: scannerWidth,
                        height: scannerHeight,
                        child: MobileScanner(
                          controller: _scannerController,
                          onDetect: _handleBarcodeDetection,
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
                const Text("Width"),
                Expanded(
                  child: Slider(
                    value: scannerWidth,
                    min: 100,
                    max: 600,
                    onChanged: (value) {
                      setState(() {
                        scannerWidth = value;
                      });
                    },
                    label: 'Width: ${scannerWidth.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text("Height"),
                Expanded(
                  child: Slider(
                    value: scannerHeight,
                    min: 100,
                    max: 600,
                    onChanged: (value) {
                      setState(() {
                        scannerHeight = value;
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
              title: const Text('Graphics Card'),
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
              title: const Text('Motherboard'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SerialNumberHistoryScreen(
                      category: 'Motherboard',
                      initialSerialNumbers:
                          Provider.of<SerialNumberModel>(context)
                              .getSerialNumbers('Motherboard')
                              .map((map) => map['serialNumber']!)
                              .toList(),
                      serialNumbers: const [],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Processor'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SerialNumberHistoryScreen(
                      category: 'Processor',
                      initialSerialNumbers:
                          Provider.of<SerialNumberModel>(context)
                              .getSerialNumbers('Processor')
                              .map((map) => map['serialNumber']!)
                              .toList(),
                      serialNumbers: const [],
                    ),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Inventory'), // Add inventory option
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Inventory()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
