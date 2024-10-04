import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:logger/logger.dart';

class SerialNumberModel with ChangeNotifier {
  // Map to hold serial numbers and their timestamps.
  final Map<String, List<Map<String, String>>> _serialNumbersMap = {
    'Graphics Card': [],
    'Motherboard': [],
    'Processor': [],
  };

  // Create a logger instance
  final Logger _logger = Logger();

  SerialNumberModel() {
    _loadSerialNumbers();
  }

  // Get serial numbers for a given category
  List<Map<String, String>> getSerialNumbers(String category) {
    return _serialNumbersMap[category] ?? [];
  }

  // Load serial numbers from SharedPreferences
  Future<void> _loadSerialNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    for (var category in _serialNumbersMap.keys) {
      final serializedList = prefs.getString(category) ?? '[]';
      _logger.d(
          'Serialized List for $category: $serializedList'); // Log the serialized data
      try {
        _serialNumbersMap[category] = List<Map<String, String>>.from(
          jsonDecode(serializedList).map((item) {
            return Map<String, String>.from(item);
          }),
        );
        _logger.d('Loaded $category: ${_serialNumbersMap[category]}');
      } catch (e) {
        _logger.e('Error loading serial numbers for $category: $e');
        _serialNumbersMap[category] = []; // Reset to an empty list on error
      }
    }
    notifyListeners();
  }

  // Save serial numbers to SharedPreferences
  Future<void> _saveSerialNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    for (var category in _serialNumbersMap.keys) {
      final serializedList = jsonEncode(_serialNumbersMap[category]);
      final success = await prefs.setString(category, serializedList);
      _logger.d(
          'Saved $category: ${_serialNumbersMap[category]}'); // Log the saved data
      _logger.d(
          'Save success for $category: $success'); // Log if save was successful
    }
  }

  // Add serial number with the current timestamp
  Future<void> addSerialNumber(String category, String serialNumber) async {
    if (_serialNumbersMap.containsKey(category)) {
      final now = DateTime.now().toString(); // Get current time
      final entry = {'serialNumber': serialNumber, 'timestamp': now};

      if (!_serialNumbersMap[category]!
          .any((item) => item['serialNumber'] == serialNumber)) {
        _serialNumbersMap[category]?.add(entry);
        _logger.d(
            'Added $serialNumber with timestamp $now to $category'); // Log addition
        await _saveSerialNumbers(); // Save to SharedPreferences
        notifyListeners(); // Notify listeners to update the UI
      } else {
        _logger.w('$serialNumber already exists in $category'); // Log warning
      }
    } else {
      _logger.e('Category $category does not exist'); // Log error
    }
  }

  // Remove serial number
  Future<void> removeSerialNumber(String category, String serialNumber) async {
    if (_serialNumbersMap.containsKey(category)) {
      _serialNumbersMap[category]
          ?.removeWhere((item) => item['serialNumber'] == serialNumber);
      _logger.d('Removed $serialNumber from $category'); // Log removal
      await _saveSerialNumbers(); // Save to SharedPreferences
      notifyListeners(); // Notify listeners to update the UI
    } else {
      _logger.e('Category $category does not exist'); // Log error
    }
  }

  // Update serial number
  Future<void> updateSerialNumber(String category, String oldSerialNumber,
      String newSerialNumber, String currentTime) async {
    if (_serialNumbersMap.containsKey(category)) {
      final now = DateTime.now().toString(); // Get current time
      final index = _serialNumbersMap[category]
          ?.indexWhere((item) => item['serialNumber'] == oldSerialNumber);

      if (index != null && index != -1) {
        _serialNumbersMap[category]
            ?[index] = {'serialNumber': newSerialNumber, 'timestamp': now};
        _logger.d(
            'Updated $oldSerialNumber to $newSerialNumber with timestamp $now in $category'); // Log update
        await _saveSerialNumbers(); // Save to SharedPreferences
        notifyListeners(); // Notify listeners to update the UI
      } else {
        _logger.e('Could not find $oldSerialNumber in $category'); // Log error
      }
    } else {
      _logger.e('Category $category does not exist'); // Log error
    }
  }
}
