import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for currency formatting
import 'package:provider/provider.dart';
import 'sales_data.dart';

class MonthlySummaryPage extends StatelessWidget {
  MonthlySummaryPage(
      {super.key, required List monthlyData, required List weeklySales});

  // Create a currency formatter for Philippine Peso (₱)
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_PH', // Locale for the Philippines
    symbol: '₱', // Peso symbol
    decimalDigits: 2, // Show 2 decimal places
  );
  final List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  // Format to display the current month
  final String _currentMonth =
      DateFormat('MMMM yyyy').format(DateTime.now()); // Example: "June 2024"

  @override
  Widget build(BuildContext context) {
    final salesData = Provider.of<SalesData>(context);

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Summary ($_currentMonth):',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: salesData.monthlyProducts.length, // Number of weeks
                itemBuilder: (context, weekIndex) {
                  // Fetch week data dynamically
                  final weeklyData = salesData.monthlyProducts[weekIndex];
                  final weeklyTotal = salesData.getWeeklyTotal(weekIndex);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ExpansionTile(
                      title: Text('Week ${weekIndex + 1}'),
                      children: [
                        ...List.generate(7, (dayIndex) {
                          final daySales = weeklyData?[dayIndex] ?? [];
                          final dayTotal = daySales.fold<double>(
                            0.0,
                            (sum, product) => sum + product['price'],
                          );

                          return ListTile(
                            title: Text(_dayNames[
                                dayIndex]), // Replace 'Day ${dayIndex + 1}' with day names
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: daySales.isNotEmpty
                                  ? daySales.map((product) {
                                      return Text(
                                        '${product['name']}: ${_currencyFormatter.format(product['price'])}',
                                      );
                                    }).toList()
                                  : [const Text('No sales for this day.')],
                            ),
                            trailing: Text(
                              'Total: ${_currencyFormatter.format(dayTotal)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          );
                        }),
                        ListTile(
                          title: const Text('Weekly Total'),
                          trailing: Text(
                            _currencyFormatter.format(weeklyTotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Text(
              'Monthly Total: ${_currencyFormatter.format(salesData.getMonthlyTotal())}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
