import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class SerialNumberModel with ChangeNotifier {
  final Map<String, List<Map<String, String>>> _serialNumbersMap = {
    'Graphics Card': [],
    'Motherboard': [],
    'Processor': [],
  };

  final Logger _logger = Logger();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SerialNumberModel() {
    _initializeSerialNumbers();
  }

  List<Map<String, String>> getSerialNumbers(String category) {
    return _serialNumbersMap[category] ?? [];
  }

  Future<void> _initializeSerialNumbers() async {
    await _loadLocalSerialNumbers();
    await _syncSerialNumbersWithFirestore();
    _setupRealtimeFirestoreListeners();
  }

  Future<void> _loadLocalSerialNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    for (var category in _serialNumbersMap.keys) {
      try {
        final data = prefs.getString(category) ?? '[]';
        _serialNumbersMap[category] = List<Map<String, String>>.from(
          jsonDecode(data).map((item) => Map<String, String>.from(item)),
        );
      } catch (e) {
        _logger.e('Failed to load $category data from local storage: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _saveLocalSerialNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    for (var category in _serialNumbersMap.keys) {
      await prefs.setString(category, jsonEncode(_serialNumbersMap[category]!));
    }
  }

  Future<void> _syncSerialNumbersWithFirestore() async {
    for (var category in _serialNumbersMap.keys) {
      try {
        final snapshot = await _firestore.collection(category).get();
        _serialNumbersMap[category] = snapshot.docs.map((doc) {
          return {
            'serialNumber': doc['serialNumber'] as String,
            'timestamp': doc['timestamp'] as String,
          };
        }).toList();
      } catch (e) {
        _logger.w('Error syncing $category with Firestore: $e');
      }
    }
    notifyListeners();
  }

  void _setupRealtimeFirestoreListeners() {
    for (var category in _serialNumbersMap.keys) {
      _firestore.collection(category).snapshots().listen((snapshot) {
        _serialNumbersMap[category] = snapshot.docs.map((doc) {
          return {
            'serialNumber': doc['serialNumber'] as String,
            'timestamp': doc['timestamp'] as String,
          };
        }).toList();
        notifyListeners();
      });
    }
  }

  Future<void> addSerialNumber(String category, String serialNumber) async {
    if (!_serialNumbersMap.containsKey(category)) {
      _logger.e('Invalid category: $category');
      return;
    }
    if (_serialNumbersMap[category]!
        .any((entry) => entry['serialNumber'] == serialNumber)) {
      _logger.w('Duplicate serial number in $category');
      return;
    }

    final newEntry = {
      'serialNumber': serialNumber,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _serialNumbersMap[category]!.add(newEntry);
    await _saveLocalSerialNumbers();
    await _addSerialNumberToFirestore(category, newEntry);
    notifyListeners();
  }

  Future<void> _addSerialNumberToFirestore(
      String category, Map<String, String> entry) async {
    try {
      await _firestore
          .collection(category)
          .doc(entry['serialNumber'])
          .set(entry);
    } catch (e) {
      _logger.e('Error adding ${entry['serialNumber']} to Firestore: $e');
    }
  }

  Future<void> removeSerialNumber(String category, String serialNumber) async {
    if (!_serialNumbersMap.containsKey(category)) {
      _logger.e('Invalid category: $category');
      return;
    }

    _serialNumbersMap[category]!
        .removeWhere((item) => item['serialNumber'] == serialNumber);

    await _saveLocalSerialNumbers();
    await _removeSerialNumberFromFirestore(category, serialNumber);
    notifyListeners();
  }

  Future<void> _removeSerialNumberFromFirestore(
      String category, String serialNumber) async {
    try {
      await _firestore.collection(category).doc(serialNumber).delete();
    } catch (e) {
      _logger.e('Error deleting $serialNumber from Firestore: $e');
    }
  }

  Future<void> updateSerialNumber(String category, String oldSerialNumber,
      String newSerialNumber, String currentTime) async {
    if (!_serialNumbersMap.containsKey(category)) {
      _logger.e('Invalid category: $category');
      return;
    }

    final index = _serialNumbersMap[category]!
        .indexWhere((item) => item['serialNumber'] == oldSerialNumber);

    if (index == -1) {
      _logger.e('Serial number not found: $oldSerialNumber');
      return;
    }

    final updatedEntry = {
      'serialNumber': newSerialNumber,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _serialNumbersMap[category]![index] = updatedEntry;

    await _saveLocalSerialNumbers();
    await _removeSerialNumberFromFirestore(category, oldSerialNumber);
    await _addSerialNumberToFirestore(category, updatedEntry);
    notifyListeners();
  }
}
