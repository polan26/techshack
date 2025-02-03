import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'sales_data.dart';
import 'weekly_summary.dart';
import 'bar_graph.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Currency formatter for Philippine Peso (₱)
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    // Access SalesData using Provider
    final salesData = Provider.of<SalesData>(context);

    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        title: const Text(''),
        actions: [
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed: () {
              // Navigate to the WeeklySummaryPage
              List<Map<String, dynamic>> weeklyData =
                  generateWeeklyData(salesData);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WeeklySummaryPage(weeklyData: weeklyData),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Daily Sales: ${_currencyFormatter.format(salesData.weeklySummary.fold(0.0, (sum, value) => sum + value))}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            SizedBox(
              height: 300,
              child: MyBarGraph(
                weeklySummary: salesData.weeklySummary,
                salesData: const [],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  buildSpendingRow('Sunday', 0, salesData),
                  buildSpendingRow('Monday', 1, salesData),
                  buildSpendingRow('Tuesday', 2, salesData),
                  buildSpendingRow('Wednesday', 3, salesData),
                  buildSpendingRow('Thursday', 4, salesData),
                  buildSpendingRow('Friday', 5, salesData),
                  buildSpendingRow('Saturday', 6, salesData),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSpendingRow(String day, int index, SalesData salesData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        ElevatedButton(
          onPressed: () {
            showManageProductsDialog(
                context, day, index, salesData); // `index` is passed correctly
          },
          child: const Text('Manage Products'),
        ),
      ],
    );
  }

  void showManageProductsDialog(
      BuildContext context, String day, int index, SalesData salesData) {
    String newProductName = '';
    double? newProductPrice;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Manage Products for $day'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (salesData.currentWeekData[index] != null)
                  ...salesData.currentWeekData[index]!
                      .asMap()
                      .entries
                      .map((entry) {
                    final product = entry.value;
                    final productIndex = entry.key;
                    return ListTile(
                      title: Text(product['name']),
                      subtitle: Text('₱${product['price'].toStringAsFixed(2)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              showEditProductDialog(
                                  context, index, productIndex, salesData);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              DateTime targetDate = getDateForDayIndex(index);
                              salesData.removeProduct(targetDate, productIndex);
                              Navigator.pop(context);
                              showManageProductsDialog(
                                  context, day, index, salesData);
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 20),
                TextField(
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  onChanged: (value) {
                    newProductName = value;
                  },
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Product Price',
                    hintText: 'Enter price (e.g., 100.0)',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    newProductPrice = double.tryParse(value);
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (newProductName.isNotEmpty && newProductPrice != null) {
                      DateTime targetDate = getDateForDayIndex(index);
                      salesData.addProduct(
                          targetDate, newProductName, newProductPrice!);
                      Navigator.pop(context);

                      // Rebuild the UI by calling setState
                      setState(() {});
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please enter valid data')),
                      );
                    }
                  },
                  child: const Text('Add Product'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void showEditProductDialog(BuildContext context, int dayIndex,
      int productIndex, SalesData salesData) {
    final product = salesData.currentWeekData[dayIndex]?[productIndex];
    String updatedName = product?['name'] ?? '';
    double? updatedPrice = product?['price'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Product Name'),
                controller: TextEditingController(text: updatedName),
                onChanged: (value) {
                  updatedName = value;
                },
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Product Price'),
                controller:
                    TextEditingController(text: updatedPrice.toString()),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  updatedPrice = double.tryParse(value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (updatedName.isNotEmpty && updatedPrice != null) {
                  DateTime targetDate = getDateForDayIndex(dayIndex);
                  salesData.updateProduct(
                      targetDate, productIndex, updatedName, updatedPrice!);
                  Navigator.pop(context);
                  setState(() {}); // Rebuild the UI
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  DateTime getDateForDayIndex(int index) {
    DateTime currentDateTime = DateTime.now();
    return currentDateTime
        .subtract(Duration(days: currentDateTime.weekday - index));
  }

  List<Map<String, dynamic>> generateWeeklyData(SalesData salesData) {
    final List<Map<String, dynamic>> data = [];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    for (int i = 0; i < 7; i++) {
      data.add({
        'day': days[i],
        'total': salesData.weeklySummary[i],
        'products':
            salesData.dailyProducts[i] ?? [], // Use a fallback empty list
      });
    }

    return data;
  }
}
