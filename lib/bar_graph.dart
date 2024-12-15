import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:qr_scanner/bar_data.dart';

class MyBarGraph extends StatelessWidget {
  final List weeklySummary;
  const MyBarGraph({super.key, required this.weeklySummary});

  @override
  Widget build(BuildContext context) {
    // Ensure the elements of weeklySummary are doubles
    List weeklySummaryDoubles = weeklySummary.map((e) => e.toDouble()).toList();

    // Find the maximum value in the weeklySummary list
    double maxValue = weeklySummaryDoubles.reduce((a, b) => a > b ? a : b);

    // Initialize bar data
    BarData myBarData = BarData(
      sunAmount: weeklySummary[0].toDouble(),
      monAmount: weeklySummary[1].toDouble(),
      tueAmount: weeklySummary[2].toDouble(),
      wedAmount: weeklySummary[3].toDouble(),
      thurAmount: weeklySummary[4].toDouble(),
      friAmount: weeklySummary[5].toDouble(),
      satAmount: weeklySummary[6].toDouble(),
    );

    myBarData.initializeBarData();

    return BarChart(
      BarChartData(
        maxY: maxValue +
            10, // Add some padding above the max value for better visualization
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
                        toY: maxValue +
                            10, // Match the maximum value here as well
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
      text = const Text('TH', style: style);
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
