import 'package:flutter/material.dart';

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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final updatedSerialNumber = _serialNumberController.text;
                final name = _nameController.text;
                widget.onSave('$updatedSerialNumber ($name)');
                Navigator.pop(context,
                    '$updatedSerialNumber ($name)'); // Pass updated data
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
