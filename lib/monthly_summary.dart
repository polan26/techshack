import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For currency formatting

class MonthlySummaryPage extends StatelessWidget {
  final List<Map<String, dynamic>> monthlyData; // Contains data for each week

  // Currency formatter for Philippine Peso (₱)
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_PH', // Philippines locale
    symbol: '₱', // Peso symbol
    decimalDigits: 2,
  );

  MonthlySummaryPage({super.key, required this.monthlyData});

  @override
  Widget build(BuildContext context) {
    // Calculate total monthly sales
    double monthlyTotal = monthlyData.fold(
      0.0, // Initial value is double
      (sum, weekData) => sum + (weekData['total'] as double),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Summary'),
      ),
      backgroundColor: Colors.grey[300],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Monthly Total
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Monthly Total: ${_currencyFormatter.format(monthlyTotal)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),

            // List of weekly summaries
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: monthlyData.map((weekData) {
                  return buildWeeklySummary(weekData);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the list of products for a specific week
  // Builds the list of products for a specific week
  Widget buildWeeklySummary(Map<String, dynamic> weekData) {
    final String week = weekData['day']; // Example: "Week 1"
    final List<Map<String, dynamic>> products = weekData['products'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      child: ExpansionTile(
        title: Text(
          '$week - Total: ${_currencyFormatter.format(weekData['total'])}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: products.isNotEmpty
            ? products.map((product) {
                return ListTile(
                  title: Text(product['name']),
                  trailing: Text(
                    _currencyFormatter.format(product['price']),
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList()
            : [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('No products added for this week.',
                      style: TextStyle(color: Colors.grey)),
                )
              ],
      ),
    );
  }
}
