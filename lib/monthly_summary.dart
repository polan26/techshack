// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'sales_data.dart'; // Import your SalesData class
// import 'package:provider/provider.dart';

// class MonthlySummaryPage extends StatelessWidget {
//   const MonthlySummaryPage(
//       {super.key, required List monthlyData, required List weeklySales});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Monthly Sales Summary'),
//         centerTitle: true,
//       ),
//       body: Consumer<SalesData>(
//         builder: (context, salesData, child) {
//           final monthlyTotal = salesData.getMonthlyTotal();
//           final weeklyTotals = List.generate(4, (weekIndex) {
//             return salesData.getWeeklyTotal(weekIndex);
//           });

//           return SingleChildScrollView(
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Monthly Total
//                   _buildSummaryCard(
//                     title: 'Monthly Total',
//                     value:
//                         '₱${monthlyTotal.toStringAsFixed(2)}', // Changed to pesos
//                     color: Colors.blueAccent,
//                   ),
//                   const SizedBox(height: 20),

//                   // Weekly Totals
//                   const Text(
//                     'Weekly Totals',
//                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 10),
//                   ...weeklyTotals.asMap().entries.map((entry) {
//                     final weekIndex = entry.key;
//                     final weekTotal = entry.value;
//                     return _buildExpandableWeekCard(
//                       weekIndex: weekIndex,
//                       weekTotal: weekTotal,
//                       salesData: salesData,
//                     );
//                   }),
//                 ],
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }

//   // Helper method to build a summary card
//   Widget _buildSummaryCard({
//     required String title,
//     required String value,
//     required Color color,
//   }) {
//     return Card(
//       elevation: 4,
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               title,
//               style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             Text(
//               value,
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: color,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Helper method to build an expandable week card
//   Widget _buildExpandableWeekCard({
//     required int weekIndex,
//     required double weekTotal,
//     required SalesData salesData,
//   }) {
//     final weekData = salesData.monthlyProducts[weekIndex];
//     if (weekData == null) {
//       return ListTile(
//         title: Text('Week ${weekIndex + 1}'),
//         subtitle: const Text('No data available'),
//       );
//     }

//     return ExpansionTile(
//       title: Text(
//         'Week ${weekIndex + 1}',
//         style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//       ),
//       subtitle: Text(
//         'Total: ₱${weekTotal.toStringAsFixed(2)}', // Changed to pesos
//         style: const TextStyle(fontSize: 14),
//       ),
//       children: List.generate(7, (dayIndex) {
//         final dailyData = weekData[dayIndex] ?? [];
//         final dailyTotal = dailyData.fold(
//             0.0, (total, product) => total + (product['price'] as double));
//         return _buildExpandableDayCard(
//           dayIndex: dayIndex,
//           dailyTotal: dailyTotal,
//           dailyData: dailyData,
//         );
//       }),
//     );
//   }

//   // Helper method to build an expandable day card
//   Widget _buildExpandableDayCard({
//     required int dayIndex,
//     required double dailyTotal,
//     required List<Map<String, dynamic>> dailyData,
//   }) {
//     return ExpansionTile(
//       title: Text(
//         _getDayName(dayIndex),
//         style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//       ),
//       subtitle: Text(
//         'Total: ₱${dailyTotal.toStringAsFixed(2)}', // Changed to pesos
//         style: const TextStyle(fontSize: 14),
//       ),
//       children: dailyData.map((product) {
//         return ListTile(
//           title: Text(product['name']),
//           subtitle: Text(
//               '₱${product['price'].toStringAsFixed(2)}'), // Changed to pesos
//           trailing: Text(
//             'Date: ${_formatDate(product['date'])}',
//             style: const TextStyle(fontSize: 12),
//           ),
//         );
//       }).toList(),
//     );
//   }

//   // Helper method to get the day name from the day index
//   String _getDayName(int dayIndex) {
//     final days = [
//       'Sunday',
//       'Monday',
//       'Tuesday',
//       'Wednesday',
//       'Thursday',
//       'Friday',
//       'Saturday',
//     ];
//     return days[dayIndex];
//   }

//   // Helper method to format the date
//   String _formatDate(dynamic date) {
//     DateTime dateTime;
//     if (date is Timestamp) {
//       dateTime = date.toDate(); // Convert Timestamp to DateTime
//     } else if (date is DateTime) {
//       dateTime = date; // Use as-is if already a DateTime
//     } else {
//       throw ArgumentError(
//           'Expected Timestamp or DateTime, got ${date.runtimeType}');
//     }
//     return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
//   }
// }
