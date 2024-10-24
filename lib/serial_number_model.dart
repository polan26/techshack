import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore package
import 'package:logger/logger.dart';

class SerialNumberModel with ChangeNotifier {
  final Map<String, List<Map<String, String>>> _serialNumbersMap = {
    'Graphics Card': [],
    'Motherboard': [],
    'Processor': [],
  };

  final Logger _logger = Logger();
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Firestore instance

  SerialNumberModel() {
    _loadSerialNumbers().then((_) {
      _fetchSerialNumbersFromFirestore();
      // Set up listeners for real-time updates
      for (var category in _serialNumbersMap.keys) {
        listenToSerialNumbers(category);
      }
    });
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
      try {
        _serialNumbersMap[category] = List<Map<String, String>>.from(
          jsonDecode(serializedList).map((item) {
            return Map<String, String>.from(item);
          }),
        );
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
      await prefs.setString(category, serializedList);
    }
  }

  // Fetch serial numbers from Firestore
  Future<void> _fetchSerialNumbersFromFirestore() async {
    for (var category in _serialNumbersMap.keys) {
      try {
        QuerySnapshot snapshot = await _firestore.collection(category).get();
        List<Map<String, String>> fetchedSerialNumbers =
            snapshot.docs.map((doc) {
          return {
            'serialNumber': doc['serialNumber'] as String,
            'timestamp': doc['timestamp'] as String,
          };
        }).toList();

        // Update the local map and notify listeners
        _serialNumbersMap[category] = fetchedSerialNumbers;
        _logger.d(
            'Fetched ${fetchedSerialNumbers.length} serial numbers from Firestore for $category');
      } catch (e) {
        _logger.e('Error fetching serial numbers for $category: $e');
      }
    }
    notifyListeners(); // Notify listeners to update the UI
  }

  // Listen for real-time updates from Firestore
  void listenToSerialNumbers(String category) {
    _firestore.collection(category).snapshots().listen((snapshot) {
      List<Map<String, String>> updatedSerialNumbers = snapshot.docs.map((doc) {
        return {
          'serialNumber': doc['serialNumber'] as String,
          'timestamp': doc['timestamp'] as String,
        };
      }).toList();

      _serialNumbersMap[category] = updatedSerialNumbers;
      notifyListeners(); // Notify listeners to update the UI
      _logger.d(
          'Real-time update: Fetched ${updatedSerialNumbers.length} serial numbers for $category');
    });
  }

  // Save each serial number to Cloud Firestore
  Future<void> _saveToFirestore(
      String category, String serialNumber, String timestamp) async {
    try {
      // Define the document reference in Firestore
      DocumentReference ref = _firestore.collection(category).doc(serialNumber);

      // Create a data map with the serial number and timestamp
      Map<String, dynamic> data = {
        'serialNumber': serialNumber,
        'timestamp': timestamp,
      };

      // Upload the data to Firestore
      await ref.set(data);

      _logger.d('Saved $serialNumber to Firestore in $category category');
    } catch (e) {
      _logger.e('Error saving $serialNumber to Firestore: $e');
    }
  }

  // Add serial number with the current timestamp
  Future<void> addSerialNumber(String category, String serialNumber) async {
    if (_serialNumbersMap.containsKey(category)) {
      final now =
          DateTime.now().toIso8601String(); // Use ISO format for consistency
      final entry = {'serialNumber': serialNumber, 'timestamp': now};

      if (!_serialNumbersMap[category]!
          .any((item) => item['serialNumber'] == serialNumber)) {
        _serialNumbersMap[category]?.add(entry);

        // Save locally (SharedPreferences)
        await _saveSerialNumbers();

        // Save to Firestore
        await _saveToFirestore(category, serialNumber, now);

        _logger.d('Added $serialNumber to $category and saved to Firestore');
        notifyListeners(); // Notify listeners to update the UI
      } else {
        _logger.w('$serialNumber already exists in $category');
      }
    } else {
      _logger.e('Category $category does not exist');
    }
  }

  // Remove serial number from both local storage and Firestore
  Future<void> removeSerialNumber(String category, String serialNumber) async {
    if (_serialNumbersMap.containsKey(category)) {
      // Remove locally
      _serialNumbersMap[category]
          ?.removeWhere((item) => item['serialNumber'] == serialNumber);
      _logger.d('Removed $serialNumber from $category locally'); // Log removal

      await _saveSerialNumbers(); // Save changes to SharedPreferences

      // Notify listeners to update the UI
      notifyListeners();

      // Remove from Firestore
      try {
        await _firestore
            .collection(category)
            .doc(serialNumber)
            .delete(); // Delete the document in Firestore
        _logger.d(
            'Deleted $serialNumber from Firestore'); // Log success, String currentTime
      } catch (e) {
        _logger.e(
            'Error deleting $serialNumber from Firestore: $e'); // Log any error
      }
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

        await _saveSerialNumbers(); // Save locally
        await _firestore
            .collection(category)
            .doc(oldSerialNumber)
            .delete(); // Remove the old document
        await _saveToFirestore(
            category, newSerialNumber, now); // Save the new document

        _logger.d('Updated $oldSerialNumber to $newSerialNumber in $category');
        notifyListeners();
      } else {
        _logger.e('Could not find $oldSerialNumber in $category');
      }
    } else {
      _logger.e('Category $category does not exist');
    }
  }

  deleteSerialNumber(String category, String serialNumberToDelete) {}
}
