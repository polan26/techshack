import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart'; // Import logger package
import 'package:shared_preferences/shared_preferences.dart';

class SalesData extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger(); // Create logger instance
  DateTime? lastResetDate;
  Map<int, Map<int, List<Map<String, dynamic>>>> monthlyProducts = {};
  bool _isLoading = false; // Loading state

  final Map<int, List<Map<String, dynamic>>> dailyProducts = {
    for (int i = 0; i < 7; i++) i: [],
  };
  Map<int, List<Map<String, dynamic>>> currentWeekData = {
    for (int dayIndex = 0; dayIndex < 7; dayIndex++) dayIndex: [],
  };
  List<double> weeklySummary = List.generate(7, (_) => 0.0);

  SalesData() {
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadLastResetDate(); // Load last reset date
    await _loadData(); // Sync with Firestore
    _resetWeeklyDataIfNeeded();
    notifyListeners();
  }

// Load the last reset date from shared preferences
  Future<void> _loadLastResetDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReset = prefs.getString('lastResetDate');
    if (lastReset != null) {
      lastResetDate = DateTime.parse(lastReset);
    }
  }

// Save the last reset date to shared preferences
  Future<void> _saveLastResetDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastResetDate', lastResetDate!.toIso8601String());
  }

  // Expose loading state
  bool get isLoading => _isLoading;

  // Set loading state and notify listeners

  // Load data from Firestore with real-time updates using snapshots
  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load current week data
      final snapshot = await _firestore.collection('sales_data').get();
      monthlyProducts.clear();
      currentWeekData.forEach((_, products) => products.clear());
      weeklySummary = List.generate(7, (_) => 0.0);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final weekIndex = data['weekIndex'];
        final dayIndex = data['dayIndex'];
        final products = (data['products'] as List).map((p) {
          return {
            'name': p['name'],
            'price': p['price'],
            'date': (p['date'] as Timestamp).toDate(),
          };
        }).toList();

        monthlyProducts[weekIndex] ??= {for (int i = 0; i < 7; i++) i: []};
        monthlyProducts[weekIndex]![dayIndex] = products;
      }

      // Load archived data
      final archivedSnapshot =
          await _firestore.collection('archived_sales_data').get();
      for (var doc in archivedSnapshot.docs) {
        final data = doc.data();
        final weekIndex = data['weekIndex'];
        final dayIndex = data['dayIndex'];
        final products = (data['products'] as List).map((p) {
          return {
            'name': p['name'],
            'price': p['price'],
            'date': (p['date'] as Timestamp)
                .toDate(), // Convert Timestamp to DateTime
          };
        }).toList();

        monthlyProducts[weekIndex] ??= {for (int i = 0; i < 7; i++) i: []};
        monthlyProducts[weekIndex]![dayIndex] = products;
      }

      // Load current week from Firestore (if any)
      final currentWeek = getWeekOfMonth(DateTime.now());
      if (monthlyProducts.containsKey(currentWeek)) {
        for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
          currentWeekData[dayIndex] =
              List.from(monthlyProducts[currentWeek]?[dayIndex] ?? []);
          weeklySummary[dayIndex] = currentWeekData[dayIndex]!
              .fold(0.0, (total, p) => total + p['price']);
        }
      }
    } catch (e, stackTrace) {
      _logger.e("Error loading data", error: e, stackTrace: stackTrace);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _archiveWeekData(int weekIndex) async {
    try {
      final batch = _firestore.batch();

      for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
        final dayProducts = monthlyProducts[weekIndex]?[dayIndex];
        if (dayProducts == null || dayProducts.isEmpty) continue;

        final docRef = _firestore.collection('archived_sales_data').doc(
              'week_${weekIndex}_day_$dayIndex',
            );

        batch.set(docRef, {
          'weekIndex': weekIndex,
          'dayIndex': dayIndex,
          'products': dayProducts,
        });
      }

      await batch.commit();
      _logger.d("Week $weekIndex data archived to Firestore.");
    } catch (e, stackTrace) {
      _logger.e("Error archiving week data", error: e, stackTrace: stackTrace);
    }
  }

  // Save data to Firestore
  Future<void> _saveData() async {
    try {
      final batch = _firestore.batch();

      for (int weekIndex = 0; weekIndex < 4; weekIndex++) {
        final weekData = monthlyProducts[weekIndex];
        if (weekData == null) continue;

        for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
          final dayProducts = weekData[dayIndex];
          if (dayProducts == null || dayProducts.isEmpty) continue;

          final docRef = _firestore.collection('sales_data').doc(
                'week_${weekIndex}_day_$dayIndex',
              );

          batch.set(docRef, {
            'weekIndex': weekIndex,
            'dayIndex': dayIndex,
            'products': dayProducts,
          });
        }
      }

      await batch.commit();
      _logger.d("All sales data saved to Firestore.");
    } catch (e, stackTrace) {
      _logger.e("Error saving sales data to Firestore",
          error: e, stackTrace: stackTrace);
    }
  }

  // After loading data

  // Add a product to a specific day
  void addProduct(DateTime date, String name, double price) {
    final weekIndex = getWeekOfMonth(date);
    final dayIndex = getDayOfWeek(date);

    final newProduct = {
      'name': name,
      'price': price,
      'date': Timestamp.fromDate(date),
    };

    // Add to current week data
    currentWeekData[dayIndex]!.add(newProduct);

    // Add to monthly products
    monthlyProducts[weekIndex] ??= {for (int i = 0; i < 7; i++) i: []};
    monthlyProducts[weekIndex]![dayIndex] ??= [];
    monthlyProducts[weekIndex]![dayIndex]!.add(newProduct);

    // Update weekly summary
    weeklySummary[dayIndex] += price;
    notifyListeners();

    // Save to Firestore
    _saveDayData(weekIndex, dayIndex);
  }

  Future<void> _saveDayData(int weekIndex, int dayIndex) async {
    try {
      final docRef = _firestore
          .collection('sales_data')
          .doc('week_${weekIndex}_day_$dayIndex');

      // Save current week data
      await docRef.set({
        'weekIndex': weekIndex,
        'dayIndex': dayIndex,
        'products': currentWeekData[dayIndex]!,
      });
    } catch (e, stackTrace) {
      _logger.e("Error saving day data", error: e, stackTrace: stackTrace);
    }
  }

  // Remove a product from a specific day and update Firestore
  Future<void> removeProduct(DateTime date, int productIndex) async {
    int weekIndex = getWeekOfMonth(date);
    int dayIndex = getDayOfWeek(date);

    try {
      // Safely remove the product from local state
      if (currentWeekData[dayIndex] != null &&
          productIndex < currentWeekData[dayIndex]!.length) {
        // Remove the product from currentWeekData
        final removedProduct =
            currentWeekData[dayIndex]!.removeAt(productIndex);

        // Remove the product from monthlyProducts (if it exists there)
        if (monthlyProducts[weekIndex]?[dayIndex] != null) {
          monthlyProducts[weekIndex]![dayIndex]!.removeWhere((product) =>
              product['name'] == removedProduct['name'] &&
              product['price'] == removedProduct['price']);
        }

        // Update the weekly summary
        weeklySummary[dayIndex] -= removedProduct['price'];

        // If the day has no more products, delete it from Firestore
        if (currentWeekData[dayIndex]!.isEmpty) {
          await _firestore
              .collection('sales_data')
              .doc('week_${weekIndex}_day_$dayIndex')
              .delete();
          _logger.d(
              "Data for week $weekIndex, day $dayIndex deleted from Firestore");
        } else {
          // Update Firestore with the modified products list
          await _firestore
              .collection('sales_data')
              .doc('week_${weekIndex}_day_$dayIndex')
              .set({
            'weekIndex': weekIndex,
            'dayIndex': dayIndex,
            'products': currentWeekData[dayIndex]!.map((p) {
              return {
                'name': p['name'],
                'price': p['price'],
                'date': Timestamp.fromDate(
                    p['date']), // Convert DateTime to Timestamp
              };
            }).toList(),
          });
        }

        // Notify listeners to refresh the UI
        notifyListeners();
      }
    } catch (e, stackTrace) {
      _logger.e("Error removing product from Firestore",
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> deleteWeekData(int weekIndex) async {
    final batch = _firestore.batch(); // Use a batch operation
    try {
      for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
        final docRef = _firestore
            .collection('sales_data')
            .doc('week_${weekIndex + 1}_day_$dayIndex');
        batch.delete(docRef); // Queue deletion
      }
      await batch.commit(); // Commit all deletions
      _logger.d("Data for week $weekIndex deleted from Firestore");

      // Clear local data
      if (monthlyProducts[weekIndex] != null) {
        monthlyProducts[weekIndex]?.clear();
        notifyListeners();
      }
    } catch (e, stackTrace) {
      _logger.e("Error deleting week $weekIndex data from Firestore",
          error: e, stackTrace: stackTrace);
      // Optional: Notify UI about failure if needed
    }
  }

  Future<void> deleteDayData(DateTime date) async {
    int weekIndex = getWeekOfMonth(date);
    int dayIndex = getDayOfWeek(date);

    try {
      // Delete data from Firestore for the specific day
      await _firestore
          .collection('sales_data')
          .doc('week_${weekIndex + 1}_day_$dayIndex')
          .delete();
      _logger
          .d("Data for week $weekIndex, day $dayIndex deleted from Firestore");

      // Clear data from the local model
      monthlyProducts[weekIndex]?[dayIndex]?.clear();
      dailyProducts[dayIndex]?.clear();
      weeklySummary[dayIndex] = 0.0;
    } catch (e, stackTrace) {
      _logger.e("Error deleting day data from Firestore",
          error: e, stackTrace: stackTrace);
    } finally {
      _saveData(); // Save data after modification
      notifyListeners(); // Notify listeners to refresh the UI
    }
  }

  void clearAllData() {
    dailyProducts.clear();
    weeklySummary = List.generate(7, (_) => 0.0);
    monthlyProducts = {
      for (int weekIndex = 0; weekIndex < 4; weekIndex++)
        weekIndex: {
          for (int dayIndex = 0; dayIndex < 7; dayIndex++) dayIndex: []
        },
    };
    notifyListeners(); // Notify listeners to refresh the UI
  }

  // Edit an existing product
  void updateProduct(
      DateTime date, int productIndex, String name, double price) {
    int weekIndex = getWeekOfMonth(date);
    int dayIndex = getDayOfWeek(date);

    final products = monthlyProducts[weekIndex]?[dayIndex];
    if (products != null && productIndex < products.length) {
      products[productIndex] = {'name': name, 'price': price};
      dailyProducts[dayIndex]?[productIndex] = {
        'name': name,
        'price': price
      }; // Update dailyProducts
      _logger.d("Product updated for week $weekIndex, day $dayIndex");
      _saveData(); // Save data after modification
      notifyListeners();
    }
  }

  // Make sure to reset bar graph data
  void resetBarGraphData() {
    weeklySummary = List.generate(7, (_) => 0.0); // Reset weekly summary
    dailyProducts.clear(); // Clear daily products

    notifyListeners(); // Notify UI to refresh bar graph
  }

  Future<void> _resetWeeklyDataIfNeeded() async {
    final currentDate = DateTime.now();
    await _loadLastResetDate();

    if (lastResetDate == null) {
      lastResetDate = currentDate;
      await _saveLastResetDate();
      return;
    }

    final daysSinceReset = currentDate.difference(lastResetDate!).inDays;

    if (daysSinceReset >= 7) {
      // Archive current week data
      final weekIndex = getWeekOfMonth(lastResetDate!);
      await _archiveWeekData(weekIndex);

      // Reset current week data
      currentWeekData.forEach((_, products) => products.clear());
      weeklySummary = List.generate(7, (_) => 0.0);
      lastResetDate = currentDate;
      await _saveLastResetDate();
      notifyListeners();
    }
  }

  @override
  notifyListeners();

  @override
  void dispose() {
    _saveData(); // Save data before app closes
    super.dispose();
  }

  int getDayOfWeek(DateTime date) {
    return date.weekday % 7; // Map Sunday to 0
  }

  double getDailyTotal(int dayIndex) {
    return currentWeekData[dayIndex]!
        .fold(0.0, (total, p) => total + p['price']);
  }

  int getWeekOfMonth(DateTime date) {
    final dayOfMonth = date.day;
    return ((dayOfMonth - 1) / 7).floor(); // Map days to weeks
  }

  double getWeeklyTotal(int weekIndex) {
    return monthlyProducts[weekIndex]?.values.fold(0.0, (total, dayProducts) {
          return total! + dayProducts.fold(0.0, (s, p) => s + p['price']);
        }) ??
        0.0;
  }

  double getMonthlyTotal() {
    double total = 0.0;
    monthlyProducts.forEach((_, weekData) {
      weekData.forEach((_, dayProducts) {
        total += dayProducts.fold(0.0, (acc, p) => acc + p['price']);
      });
    });
    currentWeekData.forEach((_, dayProducts) {
      total += dayProducts.fold(0.0, (acc, p) => acc + p['price']);
    });
    return total;
  }
}
