import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sales_data.dart';
import 'bar_data.dart';

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
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                const style = TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                );
                String text;
                switch (value.toInt()) {
                  case 0:
                    text = 'Sun';
                    break;
                  case 1:
                    text = 'Mon';
                    break;
                  case 2:
                    text = 'Tue';
                    break;
                  case 3:
                    text = 'Wed';
                    break;
                  case 4:
                    text = 'Thu';
                    break;
                  case 5:
                    text = 'Fri';
                    break;
                  case 6:
                    text = 'Sat';
                    break;
                  default:
                    text = '';
                }
                return SideTitleWidget(
                  fitInside: SideTitleFitInsideData.fromTitleMeta(
                      meta), // ✅ Correct way
                  meta: meta,
                  child: Text(text, style: style),
                );
              },
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
