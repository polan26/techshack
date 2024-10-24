import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditSerialNumberScreen extends StatefulWidget {
  final String initialSerialNumber;
  final String category;
  final ValueChanged<String> onSave;

  const EditSerialNumberScreen({
    super.key,
    required this.initialSerialNumber,
    required this.category,
    required this.onSave,
  });

  @override
  EditSerialNumberScreenState createState() => EditSerialNumberScreenState();
}

class EditSerialNumberScreenState extends State<EditSerialNumberScreen> {
  final _serialNumberController = TextEditingController();
  final _nameController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final parts = widget.initialSerialNumber.split('(');
    if (parts.length == 2) {
      _serialNumberController.text = parts[0].trim();
      final namePart = parts[1].replaceAll(')', '').trim();
      _nameController.text = namePart;
    } else {
      _serialNumberController.text = widget.initialSerialNumber;
    }

    // Add listener to update the QR code when the serial number changes
    _serialNumberController.addListener(() {
      setState(() {}); // Trigger a rebuild to update the QR code
    });
  }

  Future<String> captureQrImage() async {
    RenderRepaintBoundary boundary =
        _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
    Uint8List imageBytes = byteData!.buffer.asUint8List();
    return uploadImageToFirebaseStorage(imageBytes);
  }

  Future<String> uploadImageToFirebaseStorage(Uint8List imageBytes) async {
    // Create a unique filename for the image and specify a folder
    String folderName = 'qr_images'; // Specify your folder name here
    String fileName = '${_serialNumberController.text}.png';
    Reference storageReference =
        FirebaseStorage.instance.ref().child('$folderName/$fileName');

    // Upload the image
    UploadTask uploadTask = storageReference.putData(imageBytes);
    TaskSnapshot taskSnapshot = await uploadTask;

    // Get the download URL of the uploaded image
    String downloadUrl = await taskSnapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  Future<void> uploadQrImageToFirestore(String serialNumber) async {
    final imageUrl = await captureQrImage();
    final docRef = FirebaseFirestore.instance
        .collection('Save_qr_image')
        .doc(serialNumber);

    await docRef.set({
      'serialNumber': serialNumber,
      'qrImage': imageUrl, // Store the image URL instead of base64
      // Add other fields as needed
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Serial Number'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _serialNumberController,
              decoration: const InputDecoration(labelText: 'Serial Number'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Generated QR Code:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Center(
              child: RepaintBoundary(
                key: _qrKey,
                child: SizedBox(
                  width: 200.0,
                  height: 200.0,
                  child: QrImageView(
                    data: _serialNumberController.text.isNotEmpty
                        ? _serialNumberController.text
                        : ' ', // Fallback to prevent empty QR code
                    size: 200.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final updatedSerialNumber = _serialNumberController.text;
                  final name = _nameController.text;
                  widget.onSave('$updatedSerialNumber ($name)');

                  // Upload QR image to Firestore
                  await uploadQrImageToFirestore(updatedSerialNumber);

                  // Check if the widget is still mounted before navigating
                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context, '$updatedSerialNumber ($name)');
                  }
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
