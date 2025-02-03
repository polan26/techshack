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

    serialNumbers = dynamicSerialNumbers.map((serialData) {
      return serialData
          .map((field, value) => MapEntry(field, value.toString()));
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

  Future<void> _updateSerialNumber(
      int index, String updatedSerialNumber) async {
    final originalSerialNumber = filteredSerialNumbers[index]['serialNumber']!;
    final currentTime = DateTime.now().toString();

    await Provider.of<SerialNumberModel>(context, listen: false)
        .updateSerialNumber(widget.category, originalSerialNumber,
            updatedSerialNumber, currentTime);

    setState(() {
      filteredSerialNumbers[index]['serialNumber'] = updatedSerialNumber;
      filteredSerialNumbers[index]['timestamp'] = currentTime;
    });
  }

  /// Deletes a serial number from both the provider and the displayed list.
  void _deleteSerialNumber(int index) async {
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
                Navigator.of(context).pop(); // Close dialog without action
              },
            ),
            TextButton(
              child: const Text("Delete"),
              onPressed: () async {
                final model =
                    Provider.of<SerialNumberModel>(context, listen: false);
                await model.removeSerialNumber(
                    widget.category, serialNumberToDelete);

                setState(() {
                  filteredSerialNumbers
                      .removeAt(index); // Remove from displayed list
                });

                // ignore: use_build_context_synchronously
                Navigator.of(context).pop(); // Close dialog after deletion
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Successfully deleted the serial number!')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose(); // Clean up the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
                  ? const Icon(Icons.close)
                  : const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _loadSerialNumbers(); // Reset to initial load
                  }
                });
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.category} Serial Numbers',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color.fromARGB(255, 27, 27, 27),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Divider(color: Colors.grey.shade300, thickness: 1),
            const SizedBox(height: 16),
            Expanded(
              child: filteredSerialNumbers.isEmpty
                  ? const Center(child: Text('No serial numbers available.'))
                  : ListView.builder(
                      itemCount: filteredSerialNumbers.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(
                              filteredSerialNumbers[index]['serialNumber']!),
                          subtitle: Text(
                              'Scanned at: ${filteredSerialNumbers[index]['timestamp']!}'),
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
