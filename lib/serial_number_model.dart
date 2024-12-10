import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class SerialNumberModel with ChangeNotifier {
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
      // Retrieve stored data or default to an empty list if none exists.
      final data = prefs.getString(category) ?? '[]';
      serialNumbersMap[category] = List<Map<String, String>>.from(
        jsonDecode(data).map((item) => Map<String, String>.from(item)),
      );
    }

    notifyListeners(); // Inform listeners about the updated data.
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
      // Update our local map with the latest data from Firestore.
      serialNumbersMap[category] = snapshot.docs.map((doc) {
        return {
          'serialNumber': doc['serialNumber'] as String,
          'timestamp': doc['timestamp'] as String,
        };
      }).toList();
    }

    notifyListeners(); // Notify listeners about the updated data.
  }

  // Set up real-time listeners to react to changes in Firestore.
  void setupRealtimeFirestoreListeners() {
    for (var category in serialNumbersMap.keys) {
      firestore.collection(category).snapshots().listen((snapshot) {
        // Update our local map whenever there's a change in Firestore.
        serialNumbersMap[category] = snapshot.docs.map((doc) {
          return {
            'serialNumber': doc['serialNumber'] as String,
            'timestamp': doc['timestamp'] as String,
          };
        }).toList();

        notifyListeners(); // Inform listeners about the change.
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

    // Add the new entry locally.
    serialNumbersMap[category]!.add(newEntry);

    await saveLocalSerialNumbers(); // Save changes locally.
    await addSerialNumberToFirestore(category, newEntry); // Save to Firestore.

    notifyListeners(); // Notify listeners about the new entry.
  }

  // Helper method to add a serial number to Firestore.
  Future<void> addSerialNumberToFirestore(
      String category, Map<String, String> entry) async {
    await firestore.collection(category).doc(entry['serialNumber']).set(entry);
  }

  // Remove a serial number from a specific category.
  Future<void> removeSerialNumber(String category, String serialNumber) async {
    if (!serialNumbersMap.containsKey(category)) return;

    // Remove the entry from our local map.
    serialNumbersMap[category]!
        .removeWhere((item) => item['serialNumber'] == serialNumber);

    await saveLocalSerialNumbers(); // Save updated list locally.
    await removeSerialNumberFromFirestore(
        category, serialNumber); // Remove from Firestore.

    notifyListeners(); // Notify listeners about the removal.
  }

  // Helper method to remove a serial number from Firestore.
  Future<void> removeSerialNumberFromFirestore(
      String category, String serialNumber) async {
    await firestore.collection(category).doc(serialNumber).delete();
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

    // Update the entry in our local map.
    serialNumbersMap[category]![index] = updatedEntry;

    await saveLocalSerialNumbers(); // Save updated list locally.

    await removeSerialNumberFromFirestore(
        category, oldSerialNumber); // Remove old entry from Firestore
    await addSerialNumberToFirestore(
        category, updatedEntry); // Add new entry to Firestore.

    notifyListeners(); // Notify listeners about the update.
  }
}
