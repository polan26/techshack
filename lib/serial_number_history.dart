import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For Clipboard
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
  bool _isSelecting = false; // Toggle selection mode
  final Set<int> _selectedIndices = {}; // Track selected indices

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

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _copySelectedSerialNumbers() {
    final selectedSerialNumbers = _selectedIndices
        .map((index) => filteredSerialNumbers[index]['serialNumber']!)
        .join('\n'); // Join with newline for copying

    Clipboard.setData(ClipboardData(text: selectedSerialNumbers));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard!')),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedIndices.clear();
      _isSelecting = false;
    });
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
            if (_isSelecting)
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: _copySelectedSerialNumbers,
              ),
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
                          leading: _isSelecting
                              ? Checkbox(
                                  value: _selectedIndices.contains(index),
                                  onChanged: (value) {
                                    _toggleSelection(index);
                                  },
                                )
                              : null,
                          onTap: () {
                            if (_isSelecting) {
                              _toggleSelection(index);
                            } else {
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
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              _isSelecting = true;
                              _toggleSelection(index);
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isSelecting
          ? FloatingActionButton(
              onPressed: _clearSelection,
              child: const Icon(Icons.clear),
            )
          : null,
    );
  }
}
