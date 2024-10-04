import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart'; // Import for Clipboard functionality

class ResultScreen extends StatelessWidget {
  final String code;
  final Function() closeScreen;

  const ResultScreen({
    super.key,
    required this.closeScreen,
    required this.code,
  });

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: closeScreen, // Call the closeScreen function when pressed
          icon: const Icon(Icons.arrow_back), // Replace with your desired icon
        ),
        backgroundColor:
            const Color.fromARGB(255, 26, 1, 1), // Background color
        centerTitle: true,
        title: const Text(
          "QR Scanner",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center, // Center content vertically
          children: [
            // Show QR code here
            QrImageView(
              data: code,
              size: 150,
              version: QrVersions.auto,
            ),
            const SizedBox(height: 20), // Add space between elements
            Text(
              code,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              code,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _copyToClipboard(context),
              child: const Text('Copy to Clipboard'),
            ),
          ],
        ),
      ),
    );
  }
}
