import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'serial_number_model.dart';
import 'edit_serial_number.dart';

class SerialNumberHistoryScreen extends StatefulWidget {
  final String category;

  const SerialNumberHistoryScreen({
    super.key,
    required this.category,
    required List<String> initialSerialNumbers,
    required List<Map<String, String>> serialNumbers,
  });

  @override
  SerialNumberHistoryScreenState createState() =>
      SerialNumberHistoryScreenState();
}

class SerialNumberHistoryScreenState extends State<SerialNumberHistoryScreen> {
  late List<Map<String, String>> serialNumbers;
  List<Map<String, String>> filteredSerialNumbers = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadSerialNumbers();
    _searchController.addListener(_filterSerialNumbers);
  }

  void _loadSerialNumbers() {
    final model = Provider.of<SerialNumberModel>(context, listen: false);
    final dynamicSerialNumbers = model.getSerialNumbers(widget.category);

    // Convert dynamic to String safely
    serialNumbers = dynamicSerialNumbers.map((map) {
      return map.map((key, value) {
        return MapEntry(key, value.toString());
      });
    }).toList();

    filteredSerialNumbers = List.from(serialNumbers);
  }

  void _filterSerialNumbers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredSerialNumbers = serialNumbers.where((serialNumber) {
        final lowerCaseSerial = serialNumber['serialNumber']!.toLowerCase();
        return lowerCaseSerial.contains(query);
      }).toList();
    });
  }

  void _updateSerialNumber(int index, String updatedSerialNumber) {
    final originalSerialNumber = filteredSerialNumbers[index]['serialNumber']!;
    final currentTime = DateTime.now().toString(); // Get current date and time
    Provider.of<SerialNumberModel>(context, listen: false)
        .updateSerialNumber(widget.category, originalSerialNumber,
            updatedSerialNumber, currentTime) // Ensure this matches
        .then((_) {
      setState(() {
        filteredSerialNumbers[index]['serialNumber'] = updatedSerialNumber;
        filteredSerialNumbers[index]['timestamp'] =
            currentTime; // Update timestamp
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serial number updated successfully!')),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating serial number: $error')),
      );
    });
  }

  void _deleteSerialNumber(int index) {
    final serialNumberToDelete = filteredSerialNumbers[index]['serialNumber']!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Serial Number"),
          content:
              const Text("Are you sure you want to delete this serial number?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
              },
            ),
            TextButton(
              child: const Text("Delete"),
              onPressed: () {
                final model =
                    Provider.of<SerialNumberModel>(context, listen: false);
                model
                    .removeSerialNumber(widget.category, serialNumberToDelete)
                    .then((_) {
                  setState(() {
                    filteredSerialNumbers.removeAt(index);
                  });
                  Navigator.of(context).pop(); // Dismiss the dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Serial number deleted successfully!')),
                  );
                }).catchError((error) {
                  Navigator.of(context).pop(); // Dismiss the dialog
                  _showErrorSnackBar('Error deleting serial number: $error');
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${widget.category} History'),
            _isSearching
                ? Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        border: InputBorder.none,
                      ),
                    ),
                  )
                : Container(),
            IconButton(
              icon: _isSearching
                  ? const Icon(Icons.arrow_back)
                  : const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _loadSerialNumbers(); // Reload serial numbers
                  }
                });
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.category} Serial Numbers:',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredSerialNumbers.isEmpty
                  ? const Center(child: Text('No serial numbers available.'))
                  : ListView.builder(
                      itemCount: filteredSerialNumbers.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(
                            filteredSerialNumbers[index]['serialNumber']!,
                          ),
                          subtitle: Text(
                            'Scanned at: ${filteredSerialNumbers[index]['timestamp']!}',
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditSerialNumberScreen(
                                  initialSerialNumber:
                                      filteredSerialNumbers[index]
                                          ['serialNumber']!,
                                  category: widget.category,
                                  onSave: (updatedSerialNumber) {
                                    _updateSerialNumber(
                                        index, updatedSerialNumber);
                                  },
                                ),
                              ),
                            );
                          },
                          onLongPress: () {
                            _deleteSerialNumber(index);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
