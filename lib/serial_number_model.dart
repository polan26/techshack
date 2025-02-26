import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart'; // Import the logger package

class SerialNumberModel with ChangeNotifier {
  final Logger _logger = Logger(); // Initialize logger

  // A map to store serial numbers categorized by component type.
  final Map<String, List<Map<String, String>>> serialNumbersMap = {
    'Graphics Card': [],
    'Motherboard': [],
    'Processor': [],
  };

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Constructor that initializes the model and loads existing data.
  SerialNumberModel() {
    initializeSerialNumbers();
  }

  // Fetch serial numbers for a specified category.
  List<Map<String, String>> getSerialNumbers(String category) {
    return serialNumbersMap[category] ?? [];
  }

  // Find a serial number across all categories.
  Map<String, dynamic>? findSerialNumber(String serialNumber) {
    for (var category in serialNumbersMap.keys) {
      final entry = serialNumbersMap[category]!.firstWhere(
          (item) => item['serialNumber'] == serialNumber,
          orElse: () => {});

      if (entry.isNotEmpty) {
        return {
          'category': category,
          'serialNumber': entry['serialNumber'],
          'timestamp': entry['timestamp'],
        };
      }
    }
    return null;
  }

  // Load serial numbers from local storage and Firestore.
  Future<void> initializeSerialNumbers() async {
    await loadLocalSerialNumbers();
    await syncSerialNumbersWithFirestore();
    setupRealtimeFirestoreListeners();
  }

  // Load serial numbers from local storage.
  Future<void> loadLocalSerialNumbers() async {
    final prefs = await SharedPreferences.getInstance();

    for (var category in serialNumbersMap.keys) {
      final data = prefs.getString(category) ?? '[]';
      serialNumbersMap[category] = List<Map<String, String>>.from(
        jsonDecode(data).map((item) => Map<String, String>.from(item)),
      );
    }

    notifyListeners();
  }

  // Save the current state of serial numbers to local storage.
  Future<void> saveLocalSerialNumbers() async {
    final prefs = await SharedPreferences.getInstance();

    for (var category in serialNumbersMap.keys) {
      await prefs.setString(category, jsonEncode(serialNumbersMap[category]!));
    }
  }

  // Sync serial numbers with Firestore to ensure we have the latest data.
  Future<void> syncSerialNumbersWithFirestore() async {
    for (var category in serialNumbersMap.keys) {
      final snapshot = await firestore.collection(category).get();
      serialNumbersMap[category] = snapshot.docs.map((doc) {
        return {
          'serialNumber': doc['serialNumber'] as String,
          'timestamp': doc['timestamp'] as String,
        };
      }).toList();
    }

    notifyListeners();
  }

  // Set up real-time listeners to react to changes in Firestore.
  void setupRealtimeFirestoreListeners() {
    for (var category in serialNumbersMap.keys) {
      firestore.collection(category).snapshots().listen((snapshot) {
        serialNumbersMap[category] = snapshot.docs.map((doc) {
          return {
            'serialNumber': doc['serialNumber'] as String,
            'timestamp': doc['timestamp'] as String,
          };
        }).toList();

        notifyListeners();
      });
    }
  }

  // Add a new serial number to a specific category.
  Future<void> addSerialNumber(String category, String serialNumber) async {
    if (!serialNumbersMap.containsKey(category)) return;

    if (serialNumbersMap[category]!
        .any((entry) => entry['serialNumber'] == serialNumber)) {
      return; // Prevent adding duplicates.
    }

    final newEntry = {
      'serialNumber': serialNumber,
      'timestamp': DateTime.now().toIso8601String(),
    };

    serialNumbersMap[category]!.add(newEntry);

    await saveLocalSerialNumbers();
    await addSerialNumberToFirestore(category, newEntry);

    notifyListeners();
  }

  // Helper method to add a serial number to Firestore.
  Future<void> addSerialNumberToFirestore(
      String category, Map<String, String> entry) async {
    try {
      await firestore
          .collection(category)
          .doc(entry['serialNumber'])
          .set(entry);
    } catch (e) {
      _logger.e('Error adding serial number to Firestore: $e'); // Use logger
    }
  }

  // Remove a serial number from a specific category.
  Future<void> removeSerialNumber(String category, String serialNumber) async {
    if (!serialNumbersMap.containsKey(category)) return;

    serialNumbersMap[category]!
        .removeWhere((item) => item['serialNumber'] == serialNumber);

    await saveLocalSerialNumbers();
    await removeSerialNumberFromFirestore(category, serialNumber);

    notifyListeners();
  }

  // Helper method to remove a serial number from Firestore.
  Future<void> removeSerialNumberFromFirestore(
      String category, String serialNumber) async {
    try {
      await firestore.collection(category).doc(serialNumber).delete();
    } catch (e) {
      _logger
          .e('Error removing serial number from Firestore: $e'); // Use logger
    }
  }

  // Update an existing serial number with a new one.
  Future<void> updateSerialNumber(String category, String oldSerialNumber,
      String newSerialNumber, String currentTime) async {
    if (!serialNumbersMap.containsKey(category)) return;

    final index = serialNumbersMap[category]!
        .indexWhere((item) => item['serialNumber'] == oldSerialNumber);

    if (index == -1) return;

    final updatedEntry = {
      'serialNumber': newSerialNumber,
      'timestamp': DateTime.now().toIso8601String(),
    };

    serialNumbersMap[category]![index] = updatedEntry;

    await saveLocalSerialNumbers();
    await removeSerialNumberFromFirestore(category, oldSerialNumber);
    await addSerialNumberToFirestore(category, updatedEntry);

    notifyListeners();
  }

  // Delete a serial number from a specific category.
  Future<void> deleteSerialNumber(String category, String serialNumber) async {
    await removeSerialNumber(category, serialNumber);
  }
}
