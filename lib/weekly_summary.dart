import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For currency formatting
import 'package:qr_scanner/bar_graph.dart'; // Ensure this exists and works as expected

class WeeklySummaryPage extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData; // Contains data for each day

  // Currency formatter for Philippine Peso (₱)
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_PH', // Philippines locale
    symbol: '₱', // Peso symbol
    decimalDigits: 2,
  );

  WeeklySummaryPage({super.key, required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    // Calculate total weekly sales
    double weeklyTotal = weeklyData.fold(
      0.0, // Initial value is double
      (sum, dayData) =>
          sum +
          (dayData['total'] as double), // Ensuring the sum remains a double
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
      ),
      backgroundColor: Colors.grey[300],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Weekly Total
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Weekly Summary: ${_currencyFormatter.format(weeklyTotal)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),

            // Bar Graph
            SizedBox(
              height: 300,
              child: MyBarGraph(
                weeklySummary:
                    weeklyData.map((day) => day['total'] as double).toList(),
              ),
            ),

            // List of products for each day
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: weeklyData.map((dayData) {
                  return buildDailySummary(dayData);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the list of products for a specific day
  Widget buildDailySummary(Map<String, dynamic> dayData) {
    final String day = dayData['day'];
    final List<Map<String, dynamic>> products = dayData['products'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      child: ExpansionTile(
        title: Text(
          '$day - Total: ${_currencyFormatter.format(dayData['total'])}',
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
                  child: Text('No products added for this day.',
                      style: TextStyle(color: Colors.grey)),
                )
              ],
      ),
    );
  }
}
