import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For currency formatting
import 'package:qr_scanner/bar_graph.dart';
import 'weekly_summary.dart'; // Import the new file

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Data structure to hold daily products
  final Map<int, List<Map<String, dynamic>>> dailyProducts = {
    for (int i = 0; i < 7; i++) i: [],
  };

  // Weekly summary to track total per day
  List<double> weeklySummary = List.generate(7, (_) => 0.0);

  // Currency formatter for Philippine Peso (₱)
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'en_PH', // Philippines locale
    symbol: '₱', // Peso symbol
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        title: const Text(''),
        actions: [
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed: () {
              // Navigate to the WeeklySummaryPage
              List<Map<String, dynamic>> weeklyData = generateWeeklyData();
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
                'Weekly Sales: ${_currencyFormatter.format(weeklySummary.fold(0.0, (sum, value) => sum + value))}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),

            // Add a placeholder for your bar graph widget
            SizedBox(
              height: 300,
              child: MyBarGraph(weeklySummary: weeklySummary),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  buildSpendingRow('Sunday', 0),
                  buildSpendingRow('Monday', 1),
                  buildSpendingRow('Tuesday', 2),
                  buildSpendingRow('Wednesday', 3),
                  buildSpendingRow('Thursday', 4),
                  buildSpendingRow('Friday', 5),
                  buildSpendingRow('Saturday', 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSpendingRow(String day, int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        ElevatedButton(
          onPressed: () {
            showManageProductsDialog(context, day, index);
          },
          child: const Text('Manage Products'),
        ),
      ],
    );
  }

  void showManageProductsDialog(BuildContext context, String day, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              title: Text('Manage Products for $day'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dailyProducts[index]!.isNotEmpty)
                    Column(
                      children:
                          dailyProducts[index]!.asMap().entries.map((entry) {
                        final productIndex = entry.key;
                        final product = entry.value;

                        return ListTile(
                          title: Text(product['name']),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_currencyFormatter.format(product['price'])),
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  showEditProductDialog(
                                    context,
                                    day,
                                    index,
                                    productIndex,
                                    setStateInDialog,
                                  );
                                },
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    weeklySummary[index] -= product['price'];
                                    dailyProducts[index]
                                        ?.removeAt(productIndex);
                                  });
                                  setStateInDialog(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  else
                    const Text(
                      'No products added yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  const Divider(),
                  ElevatedButton(
                    onPressed: () {
                      showAddProductDialog(
                          context, day, index, setStateInDialog);
                    },
                    child: const Text('Add Product'),
                  ),
                ],
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
      },
    );
  }

  void showAddProductDialog(
    BuildContext context,
    String day,
    int index,
    Function setStateInDialog,
  ) {
    final TextEditingController productNameController = TextEditingController();
    final TextEditingController productPriceController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Product for $day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: productNameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              TextField(
                controller: productPriceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Product Price (₱)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final String productName = productNameController.text;
                final double productPrice =
                    double.tryParse(productPriceController.text) ?? 0.0;

                if (productName.isNotEmpty && productPrice > 0) {
                  setState(() {
                    dailyProducts[index]
                        ?.add({'name': productName, 'price': productPrice});
                    weeklySummary[index] += productPrice;
                  });
                  setStateInDialog(() {});
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void showEditProductDialog(
    BuildContext context,
    String day,
    int dayIndex,
    int productIndex,
    Function setStateInDialog,
  ) {
    final product = dailyProducts[dayIndex]![productIndex];
    final TextEditingController productNameController =
        TextEditingController(text: product['name']);
    final TextEditingController productPriceController =
        TextEditingController(text: product['price'].toString());

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Product for $day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: productNameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              TextField(
                controller: productPriceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Product Price (₱)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final String newName = productNameController.text;
                final double newPrice =
                    double.tryParse(productPriceController.text) ?? 0.0;

                if (newName.isNotEmpty && newPrice > 0) {
                  setState(() {
                    weeklySummary[dayIndex] -= product['price'];
                    weeklySummary[dayIndex] += newPrice;
                    dailyProducts[dayIndex]![productIndex] = {
                      'name': newName,
                      'price': newPrice,
                    };
                  });
                  setStateInDialog(() {});
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> generateWeeklyData() {
    final List<Map<String, dynamic>> data = [];
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];

    for (int i = 0; i < 7; i++) {
      data.add({
        'day': days[i],
        'total': weeklySummary[i],
        'products': dailyProducts[i]!,
      });
    }

    return data;
  }
}
