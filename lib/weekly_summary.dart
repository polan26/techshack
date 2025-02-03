import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For currency and date formatting
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

  WeeklySummaryPage(
      {super.key, required List<Map<String, dynamic>> weeklyData});

  @override
  Widget build(BuildContext context) {
    // Access SalesData from the provider
    final salesData = Provider.of<SalesData>(context);

    // Calculate total weekly sales
    double weeklyTotal = salesData.weeklySummary.fold(
      0.0, // Initial value is double
      (sum, dayTotal) => sum + dayTotal, // Ensuring the sum remains a double
    );

    // Get current date and generate a list of dates for the week
    DateTime today = DateTime.now();
    List<DateTime> weekDates = List.generate(
      7,
      (index) => today.subtract(Duration(days: today.weekday - index)),
    ); // Creates the list of dates for the current week (Sunday to Saturday)

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Summary'),
      ),
      backgroundColor: Colors.grey[300],
      body: salesData.isLoading
          ? const Center(
              child: CircularProgressIndicator()) // Show loading spinner
          : SingleChildScrollView(
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
                      salesData: const [],
                    ),
                  ),

                  // List of products for each day
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: List.generate(7, (index) {
                        return buildDailySummary(
                            index, salesData, weekDates[index]);
                      }),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Builds the list of products for a specific day
  Widget buildDailySummary(int dayIndex, SalesData salesData, DateTime date) {
    final List<Map<String, dynamic>> products =
        salesData.currentWeekData[dayIndex] ?? [];
    final double dayTotal = salesData.weeklySummary[dayIndex];

    // Format the date as "Monday, January 16"
    String formattedDate = DateFormat('EEEE, MMMM d').format(date);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      child: ExpansionTile(
        title: Text(
          '$formattedDate - Total: ${_currencyFormatter.format(dayTotal)}',
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
