import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'sales_data.dart';
import 'weekly_summary.dart';
import 'bar_graph.dart';
import 'daily_report_screen.dart';

enum ProductBrand {
  nvidia('NVIDIA'),
  amd('AMD'),
  intel('Intel'),
  asus('ASUS'),
  msi('MSI'),
  gigabyte('Gigabyte'),
  evga('EVGA'),
  other('Other');

  final String displayName;
  const ProductBrand(this.displayName);
}

enum VramOption {
  none('No VRAM', null),
  gb2('2GB', 2),
  gb4('4GB', 4),
  gb6('6GB', 6),
  gb8('8GB', 8),
  gb12('12GB', 12),
  gb16('16GB', 16),
  gb24('24GB', 24);

  final String displayName;
  final double? value;

  const VramOption(this.displayName, this.value);
}

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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          day,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _currencyFormatter.format(salesData.weeklySummary[index]),
          style: const TextStyle(fontSize: 14),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.analytics),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DailyReportScreen(
                      date: getDateForDayIndex(index),
                      salesData: salesData,
                      showAllDays: true, // Add this parameter
                    ),
                  ),
                );
              },
              tooltip: 'View Weekly Products',
            ),
            ElevatedButton(
              onPressed: () {
                showManageProductsDialog(context, day, index, salesData);
              },
              child: const Text('Manage'),
            ),
          ],
        ),
      ),
    );
  }

  void showManageProductsDialog(
      BuildContext context, String day, int index, SalesData salesData) {
    String newProductName = '';
    double? newProductPrice;
    VramOption selectedVram = VramOption.none;
    ProductBrand selectedBrand = ProductBrand.other; // Default brand

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
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('₱${product['price'].toStringAsFixed(2)}'),
                          if (product['vram'] != null)
                            Text('VRAM: ${product['vram']}GB',
                                style: TextStyle(color: Colors.grey)),
                          if (product['brand'] != null)
                            Text('Brand: ${product['brand']}',
                                style: TextStyle(color: Colors.grey)),
                        ],
                      ),
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
                const SizedBox(height: 16),
                // Brand Dropdown
                DropdownButtonFormField<ProductBrand>(
                  value: selectedBrand,
                  decoration: const InputDecoration(
                    labelText: 'Brand',
                    border: OutlineInputBorder(),
                  ),
                  items: ProductBrand.values.map((brand) {
                    return DropdownMenuItem<ProductBrand>(
                      value: brand,
                      child: Text(brand.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      selectedBrand = value;
                    }
                  },
                ),
                const SizedBox(height: 16),
                // VRAM Dropdown
                DropdownButtonFormField<VramOption>(
                  value: selectedVram,
                  decoration: const InputDecoration(
                    labelText: 'VRAM (for GPUs)',
                    border: OutlineInputBorder(),
                  ),
                  items: VramOption.values.map((vram) {
                    return DropdownMenuItem<VramOption>(
                      value: vram,
                      child: Text(vram.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      selectedVram = value;
                    }
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (newProductName.isNotEmpty && newProductPrice != null) {
                      DateTime targetDate = getDateForDayIndex(index);
                      salesData.addProduct(
                        targetDate,
                        newProductName,
                        newProductPrice!,
                        vram: selectedVram.value,
                        brand: selectedBrand.displayName, // Add brand
                        model: null,
                      );
                      Navigator.pop(context);
                      setState(() {});
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
    VramOption selectedVram = VramOption.values.firstWhere(
      (v) => v.value == (product?['vram']?.toDouble()),
      orElse: () => VramOption.none,
    );
    ProductBrand selectedBrand = ProductBrand.values.firstWhere(
      (b) => b.displayName == product?['brand'],
      orElse: () => ProductBrand.other,
    );

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
              const SizedBox(height: 16),
              // Brand Dropdown
              DropdownButtonFormField<ProductBrand>(
                value: selectedBrand,
                decoration: const InputDecoration(
                  labelText: 'Brand',
                  border: OutlineInputBorder(),
                ),
                items: ProductBrand.values.map((brand) {
                  return DropdownMenuItem<ProductBrand>(
                    value: brand,
                    child: Text(brand.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedBrand = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              // VRAM Dropdown
              DropdownButtonFormField<VramOption>(
                value: selectedVram,
                decoration: const InputDecoration(
                  labelText: 'VRAM (for GPUs)',
                  border: OutlineInputBorder(),
                ),
                items: VramOption.values.map((vram) {
                  return DropdownMenuItem<VramOption>(
                    value: vram,
                    child: Text(vram.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedVram = value;
                  }
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
                    targetDate,
                    productIndex,
                    updatedName,
                    updatedPrice!,
                    vram: selectedVram.value,
                    brand: selectedBrand.displayName, // Add brand parameter
                  );
                  Navigator.pop(context);
                  setState(() {});
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
