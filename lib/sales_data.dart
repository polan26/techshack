import 'package:flutter/material.dart';

class SalesData extends ChangeNotifier {
  // Data structure to hold daily products
  final Map<int, List<Map<String, dynamic>>> dailyProducts = {
    for (int i = 0; i < 7; i++) i: [],
  };

  // Weekly summary to track total per day
  List<double> weeklySummary = List.generate(7, (_) => 0.0);

  // Group daily data into 4 weeks for the month
  final Map<int, Map<int, List<Map<String, dynamic>>>> monthlyProducts = {
    for (int weekIndex = 0; weekIndex < 4; weekIndex++)
      weekIndex: {
        for (int dayIndex = 0; dayIndex < 7; dayIndex++) dayIndex: []
      },
  };

  // Add a product to a specific day
  void addProduct(DateTime date, String name, double price) {
    int weekIndex = getWeekOfMonth(date); // Calculate the week
    int dayIndex = getDayOfWeek(date); // Calculate the day

    // Add product to the monthly data
    monthlyProducts[weekIndex]?[dayIndex]?.add({'name': name, 'price': price});

    // Update dailyProducts as well
    dailyProducts[dayIndex]?.add({'name': name, 'price': price});

    // Update the weekly summary for that day
    weeklySummary[dayIndex] += price;

    notifyListeners(); // Notify listeners to refresh the UI
  }

  // Remove a product from a specific day
  void removeProduct(DateTime date, int productIndex) {
    int weekIndex = getWeekOfMonth(date);
    int dayIndex = getDayOfWeek(date);

    // Safely remove product from monthlyProducts
    if (monthlyProducts[weekIndex]?[dayIndex] != null &&
        productIndex < monthlyProducts[weekIndex]![dayIndex]!.length) {
      final removedProduct =
          monthlyProducts[weekIndex]![dayIndex]!.removeAt(productIndex);

      // Remove product from dailyProducts
      if (dailyProducts[dayIndex] != null) {
        dailyProducts[dayIndex]!.removeWhere((product) =>
            product['name'] == removedProduct['name'] &&
            product['price'] == removedProduct['price']);
      }

      // Update the weekly summary
      weeklySummary[dayIndex] -= removedProduct['price'];

      // Notify listeners
      notifyListeners();
    }
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
      notifyListeners();
    }
  }

  // Calculate the weekly total for a specific week
  double getWeeklyTotal(int weekIndex) {
    if (monthlyProducts.containsKey(weekIndex)) {
      // Sum the total sales for all days of the week
      double total = 0.0;
      monthlyProducts[weekIndex]?.forEach((dayIndex, sales) {
        total += sales.fold(0.0, (sum, product) => sum + product['price']);
      });
      return total;
    }
    return 0.0;
  }

  // Calculate the total for the entire month
  double getMonthlyTotal() {
    return monthlyProducts.values
        .expand((week) => week.values)
        .expand((daySales) => daySales)
        .fold(0.0, (sum, product) => sum + product['price']);
  }

  int getDayOfWeek(DateTime date) {
    // Adjust Sunday (7) to 6, and keep Monday-Saturday unchanged
    return date.weekday % 7;
  }

  int getWeekOfMonth(DateTime date) {
    // Calculate the week index (0-3 for a 4-week month)
    return (date.day - 1) ~/ 7;
  }
}
