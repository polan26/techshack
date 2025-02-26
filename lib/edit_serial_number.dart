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
  List<Map<String, dynamic>> _productSuggestions = [];
  bool _isLoading = false;

  // Updated branch selection variables
  String _selectedBranch = 'Main';
  final List<String> _branches = ['Main', 'Upper SR', 'Urdaneta', 'La Union'];

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

    _serialNumberController.addListener(() {
      setState(() {});
    });

    _nameController.addListener(_fetchProductSuggestions);
  }

  Future<void> _fetchProductSuggestions() async {
    setState(() => _isLoading = true);
    String input = _nameController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _productSuggestions = [];
        _isLoading = false;
      });
      return;
    }

    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('inventory')
          .doc(_selectedBranch)
          .collection('items')
          .orderBy('name')
          .startAt([input])
          .endAt(['$input\uf8ff'])
          .limit(5)
          .get();

      List<Map<String, dynamic>> suggestions = querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                'name': doc['name'],
                'quantity': doc['quantity'],
              })
          .toList();

      setState(() {
        _productSuggestions = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProductQuantity(String docId, int currentQuantity) async {
    setState(() => _isLoading = true);
    try {
      int newQuantity = currentQuantity > 0 ? currentQuantity - 1 : 0;
      await FirebaseFirestore.instance
          .collection('inventory')
          .doc(_selectedBranch)
          .collection('items')
          .doc(docId)
          .update({'quantity': newQuantity});
      debugPrint('Product quantity updated to $newQuantity');
    } catch (e) {
      debugPrint('Error updating product quantity: $e');
    }
    setState(() => _isLoading = false);
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
    String folderName = 'qr_images';
    String fileName = '${_serialNumberController.text}.png';
    Reference storageReference =
        FirebaseStorage.instance.ref().child('$folderName/$fileName');

    UploadTask uploadTask = storageReference.putData(imageBytes);
    TaskSnapshot taskSnapshot = await uploadTask;
    return await taskSnapshot.ref.getDownloadURL();
  }

  Future<void> uploadQrImageToFirestore(String serialNumber) async {
    setState(() => _isLoading = true);
    final imageUrl = await captureQrImage();
    final docRef = FirebaseFirestore.instance
        .collection('Save_qr_image')
        .doc(serialNumber);

    await docRef.set({
      'serialNumber': serialNumber,
      'qrImage': imageUrl,
      'branch': _selectedBranch,
    }, SetOptions(merge: true));
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Serial Number')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedBranch,
              decoration: const InputDecoration(
                labelText: 'Select Branch',
                border: OutlineInputBorder(),
              ),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedBranch = newValue;
                    _productSuggestions = [];
                  });
                  _fetchProductSuggestions();
                }
              },
              items: _branches.map<DropdownMenuItem<String>>((String branch) {
                return DropdownMenuItem<String>(
                  value: branch,
                  child: Text(branch),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _serialNumberController,
              decoration: const InputDecoration(
                labelText: 'Serial Number',
                labelStyle: TextStyle(color: Colors.black),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Colors.black),
              ),
            ),
            if (_productSuggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black54),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _productSuggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_productSuggestions[index]['name']),
                      onTap: () async {
                        _nameController
                            .removeListener(_fetchProductSuggestions);
                        final selectedProduct = _productSuggestions[index];

                        setState(() {
                          _nameController.text = selectedProduct['name'];
                          _productSuggestions.clear();
                        });

                        _nameController.addListener(_fetchProductSuggestions);

                        await _updateProductQuantity(
                            selectedProduct['id'], selectedProduct['quantity']);
                      },
                    );
                  },
                ),
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
                        ? '${_serialNumberController.text} ($_selectedBranch)'
                        : ' ',
                    size: 200.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        final updatedSerialNumber =
                            _serialNumberController.text.trim();
                        final name = _nameController.text.trim();

                        if (updatedSerialNumber.isEmpty || name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Serial number and name cannot be empty')),
                          );
                          return;
                        }

                        final newSerial = '$updatedSerialNumber ($name)';

                        widget.onSave(newSerial);

                        await uploadQrImageToFirestore(updatedSerialNumber);

                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        Navigator.pop(context, newSerial);
                      },
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
