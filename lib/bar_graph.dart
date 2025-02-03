import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_scanner/bar_data.dart';
import 'sales_data.dart';

class MyBarGraph extends StatelessWidget {
  const MyBarGraph(
      {super.key,
      required List<double> weeklySummary,
      required List salesData});

  @override
  Widget build(BuildContext context) {
    // Watch for changes in SalesData
    final salesData = Provider.of<SalesData>(context);
    final weeklySummary = salesData.weeklySummary;

    // Check if weeklySummary is empty or invalid
    if (weeklySummary.isEmpty || weeklySummary.length < 7) {
      return const Center(
        child: Text('No data available for the week.'),
      );
    }

    // Find the maximum value in weeklySummary
    double maxValue = weeklySummary.reduce((a, b) => a > b ? a : b);

    // Initialize bar data
    BarData myBarData = BarData(
      sunAmount: weeklySummary[0],
      monAmount: weeklySummary[1],
      tueAmount: weeklySummary[2],
      wedAmount: weeklySummary[3],
      thurAmount: weeklySummary[4],
      friAmount: weeklySummary[5],
      satAmount: weeklySummary[6],
    );

    myBarData.initializeBarData();

    return BarChart(
      BarChartData(
        maxY: maxValue + 10, // Add padding above max value
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          show: true,
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: getBottomTiles,
            ),
          ),
        ),
        barGroups: myBarData.barData
            .map((data) => BarChartGroupData(
                  x: data.x,
                  barRods: [
                    BarChartRodData(
                      toY: data.y,
                      color: Colors.black,
                      width: 25,
                      borderRadius: BorderRadius.circular(4),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxValue + 10, // Match the maximum value
                        color: Colors.grey[200],
                      ),
                    ),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

Widget getBottomTiles(double value, TitleMeta meta) {
  const style = TextStyle(
    color: Colors.grey,
    fontWeight: FontWeight.bold,
    fontSize: 14,
  );
  Widget text;
  switch (value.toInt()) {
    case 0:
      text = const Text('S', style: style);
      break;
    case 1:
      text = const Text('M', style: style);
      break;
    case 2:
      text = const Text('T', style: style);
      break;
    case 3:
      text = const Text('W', style: style);
      break;
    case 4:
      text = const Text('T', style: style);
      break;
    case 5:
      text = const Text('F', style: style);
      break;
    case 6:
      text = const Text('S', style: style);
      break;
    default:
      text = const Text('', style: style);
  }
  return SideTitleWidget(axisSide: meta.axisSide, child: text);
}
