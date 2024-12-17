import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For currency formatting
import 'package:provider/provider.dart'; // Import Provider
import 'sales_data.dart'; // Ensure this exists and is correctly imported
import 'bar_graph.dart'; // Ensure this exists and works as expected

class WeeklySummaryPage extends StatelessWidget {
  // Currency formatter for Philippine Peso (₱)
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_PH', // Philippines locale
    symbol: '₱', // Peso symbol
    decimalDigits: 2,
  );

  WeeklySummaryPage({super.key, required List weeklyData});

  @override
  Widget build(BuildContext context) {
    // Access SalesData from the provider
    final salesData = Provider.of<SalesData>(context);

    // Calculate total weekly sales
    double weeklyTotal = salesData.weeklySummary.fold(
      0.0, // Initial value is double
      (sum, dayTotal) => sum + dayTotal, // Ensuring the sum remains a double
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Summary'),
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
                weeklySummary: salesData.weeklySummary,
              ),
            ),

            // List of products for each day
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: List.generate(7, (index) {
                  return buildDailySummary(index, salesData);
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the list of products for a specific day
  Widget buildDailySummary(int dayIndex, SalesData salesData) {
    final List<Map<String, dynamic>> products =
        salesData.dailyProducts[dayIndex] ?? [];
    final double dayTotal = salesData.weeklySummary[dayIndex];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      child: ExpansionTile(
        title: Text(
          'Day ${dayIndex + 1} - Total: ${_currencyFormatter.format(dayTotal)}',
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
