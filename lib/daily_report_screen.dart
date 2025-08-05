import 'dart:math' show max, min, pow;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'sales_data.dart';

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

class ProductTrend {
  final String name;
  final ProductBrand brand;
  final double currentPrice;
  final double? vram;
  final double trend;
  final List<double> priceHistory;
  final List<DateTime> dateHistory;
  final PolynomialRegression regressionModel;
  final double lastDayIndex; // Days since first date

  ProductTrend({
    required this.name,
    required String brand,
    required this.currentPrice,
    this.vram,
    required this.trend,
    required this.priceHistory,
    required this.dateHistory,
    required this.regressionModel,
    required this.lastDayIndex,
  }) : brand = _normalizeBrand(brand);

  // Add this static method to normalize brand names
  static ProductBrand _normalizeBrand(String inputBrand) {
    if (inputBrand.isEmpty || inputBrand.toLowerCase() == 'unknown') {
      debugPrint('NormalizeBrand: Empty/Unknown brand, returning Other');
      return ProductBrand.other;
    }

    final lowerBrand = inputBrand.toLowerCase().trim();
    debugPrint(
        'NormalizeBrand: Input brand: $inputBrand, Lowercase: $lowerBrand');

    // Try direct match first
    for (final brand in ProductBrand.values) {
      if (lowerBrand == brand.displayName.toLowerCase()) {
        debugPrint('NormalizeBrand: Exact match with ${brand.displayName}');
        return brand;
      }
    }

    // Try partial match if exact fails
    for (final brand in ProductBrand.values) {
      if (lowerBrand.contains(brand.displayName.toLowerCase())) {
        debugPrint('NormalizeBrand: Partial match with ${brand.displayName}');
        return brand;
      }
    }

    debugPrint('NormalizeBrand: No match found, returning Other');
    return ProductBrand.other;
  }

  double get projectedNextPrice => regressionModel.predict(lastDayIndex + 1);

  double get projectedPriceInOneWeek =>
      regressionModel.predict(lastDayIndex + 7);

  double get pricePerGB => vram != null && vram! > 0 ? currentPrice / vram! : 0;
}

class PolynomialRegression {
  final List<double> coefficients;
  final int degree;

  PolynomialRegression({required this.coefficients, required this.degree});

  double predict(double x) {
    double result = 0;
    for (int i = 0; i < coefficients.length; i++) {
      result += coefficients[i] * pow(x, i).toDouble();
    }
    return result;
  }
}

List<Map<String, double>> _generatePredictionData(List<ProductTrend> products) {
  if (products.isEmpty) return [];

  // Get min and max VRAM values
  final minVram = products.map((p) => p.vram!).reduce(min);
  final maxVram = products.map((p) => p.vram!).reduce(max);

  // Create a linear regression model
  final regression = _calculateLinearRegression(products);

  // Generate points for the trend line
  return [
    {'x': minVram, 'y': regression.predict(minVram)},
    {'x': maxVram, 'y': regression.predict(maxVram)},
  ];
}

LinearRegression _calculateLinearRegression(List<ProductTrend> products) {
  final points = products.map((p) => Point(p.vram!, p.currentPrice)).toList();
  return linearRegression(points);
}

class LinearRegression {
  final double slope;
  final double intercept;

  LinearRegression(this.slope, this.intercept);

  double predict(double x) => slope * x + intercept;
}

LinearRegression linearRegression(List<Point> points) {
  final n = points.length;
  double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;

  for (final point in points) {
    sumX += point.x;
    sumY += point.y;
    sumXY += point.x * point.y;
    sumXX += point.x * point.x;
  }

  final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
  final intercept = (sumY - slope * sumX) / n;

  return LinearRegression(slope, intercept);
}

class Point {
  final double x;
  final double y;

  Point(this.x, this.y);
}

class TrendAnalysisService {
  static final TrendAnalysisService _instance =
      TrendAnalysisService._internal();
  factory TrendAnalysisService() => _instance;
  TrendAnalysisService._internal();
  final Map<String, ProductTrend> _productTrends = {};
  DateTime? _lastAnalysisDate;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> loadHistoricalTrends() async {
    try {
      final snapshot = await _firestore.collection('product_trends').get();
      _productTrends.clear();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = doc.id;
        final brand = data['brand']?.toString() ?? 'Unknown';
        debugPrint('Loading product: $name, Brand: $brand');

        final priceHistory = (data['priceHistory'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [];
        final dateHistory = (data['dateHistory'] as List?)?.map((item) {
              if (item is Timestamp) return item.toDate();
              if (item is DateTime) return item;
              return DateTime.now();
            }).toList() ??
            [];
        final vram =
            data['vram'] != null ? (data['vram'] as num).toDouble() : null;

        if (priceHistory.isNotEmpty && dateHistory.isNotEmpty) {
          final firstDate = dateHistory.reduce((a, b) => a.isBefore(b) ? a : b);
          final lastDate = dateHistory.last;
          final lastDayIndex = lastDate.difference(firstDate).inDays.toDouble();

          final regression = _calculateTimeBasedPolynomialRegression(
              priceHistory, dateHistory, 2);

          _productTrends[name] = ProductTrend(
            name: name,
            brand: brand,
            currentPrice: priceHistory.last,
            vram: vram,
            trend: _calculateTimeTrend(regression, lastDayIndex),
            priceHistory: priceHistory,
            dateHistory: dateHistory,
            regressionModel: regression,
            lastDayIndex: lastDayIndex,
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading historical trends: $e');
    }
  }

  PolynomialRegression _calculateTimeBasedPolynomialRegression(
      List<double> prices, List<DateTime> dates, int degree) {
    if (prices.isEmpty || dates.isEmpty || prices.length != dates.length) {
      debugPrint('Insufficient data for polynomial regression');
      return PolynomialRegression(coefficients: [0], degree: 0);
    }

    // Find the earliest date
    final firstDate = dates.reduce((a, b) => a.isBefore(b) ? a : b);

    // Convert dates to days since first date
    final dayIndices =
        dates.map((d) => d.difference(firstDate).inDays.toDouble()).toList();

    // If all dates are the same, return constant value
    if (dayIndices.toSet().length == 1) {
      debugPrint('All dates identical, returning constant regression');
      return PolynomialRegression(
        coefficients: [prices.first],
        degree: 0,
      );
    }

    // Use day indices for regression instead of VRAM
    return _calculatePolynomialRegression(prices, dayIndices, degree);
  }

  PolynomialRegression _calculatePolynomialRegression(
      List<double> yValues, List<double> xValues, int degree) {
    if (xValues.length != yValues.length || xValues.length < degree + 1) {
      debugPrint('Insufficient data for polynomial regression');
      return PolynomialRegression(coefficients: [0], degree: 0);
    }

    final n = xValues.length;
    final List<List<double>> equations = List.generate(
        degree + 1, (i) => List.filled(degree + 2, 0.0)); // Augmented matrix

    // Build the system of equations
    for (int k = 0; k <= degree; k++) {
      for (int j = 0; j <= degree; j++) {
        double sum = 0;
        for (int i = 0; i < n; i++) {
          sum += pow(xValues[i], j + k).toDouble();
        }
        equations[k][j] = sum;
      }

      double sumY = 0;
      for (int i = 0; i < n; i++) {
        sumY += yValues[i] * pow(xValues[i], k).toDouble();
      }
      equations[k][degree + 1] = sumY;
    }

    // Solve the system using Gaussian elimination
    for (int i = 0; i <= degree; i++) {
      // Pivot
      for (int k = i + 1; k <= degree; k++) {
        if (equations[i][i].abs() < equations[k][i].abs()) {
          equations.swap(i, k);
        }
      }

      // Make diagonal 1
      for (int k = i + 1; k <= degree; k++) {
        final factor = equations[k][i] / equations[i][i];
        for (int j = i; j <= degree + 1; j++) {
          equations[k][j] -= factor * equations[i][j];
        }
      }
    }

    // Back substitution
    final coefficients = List<double>.filled(degree + 1, 0.0);
    for (int i = degree; i >= 0; i--) {
      coefficients[i] = equations[i][degree + 1];
      for (int j = i + 1; j <= degree; j++) {
        coefficients[i] -= equations[i][j] * coefficients[j];
      }
      coefficients[i] /= equations[i][i];
    }

    return PolynomialRegression(coefficients: coefficients, degree: degree);
  }

  Future<void> analyzeSalesData(SalesData salesData) async {
    await loadHistoricalTrends();

    final productSalesMap = <String, List<Map<String, dynamic>>>{};

    for (var weekData in salesData.monthlyProducts.values) {
      for (var dayProducts in weekData.values) {
        for (var product in dayProducts) {
          final name = product['name'] ?? 'Unknown';
          productSalesMap.putIfAbsent(name, () => []).add(product);
        }
      }
    }

    for (var dayProducts in salesData.currentWeekData.values) {
      for (var product in dayProducts) {
        final name = product['name'] ?? 'Unknown';
        productSalesMap.putIfAbsent(name, () => []).add(product);
      }
    }

    for (var entry in productSalesMap.entries) {
      final existingTrend = _productTrends[entry.key];
      final newTrend = _analyzeProductTrend(entry.key, entry.value);

      if (existingTrend != null) {
        final mergedPrices = [
          ...existingTrend.priceHistory,
          ...newTrend.priceHistory
        ];
        final mergedDates = [
          ...existingTrend.dateHistory,
          ...newTrend.dateHistory
        ];

        final mergedRegression = _calculateTimeBasedPolynomialRegression(
            mergedPrices, mergedDates, 2);

        final firstDate = mergedDates.reduce((a, b) => a.isBefore(b) ? a : b);
        final lastDate = mergedDates.last;
        final lastDayIndex = lastDate.difference(firstDate).inDays.toDouble();

        _productTrends[entry.key] = ProductTrend(
          name: entry.key,
          brand: existingTrend.brand.displayName,
          currentPrice: newTrend.currentPrice,
          vram: existingTrend.vram ?? newTrend.vram,
          trend: _calculateTimeTrend(mergedRegression, lastDayIndex),
          priceHistory: mergedPrices,
          dateHistory: mergedDates,
          regressionModel: mergedRegression,
          lastDayIndex: lastDayIndex,
        );
      } else {
        _productTrends[entry.key] = newTrend;
      }
    }

    await saveCurrentTrends();
    _lastAnalysisDate = DateTime.now();
  }

  ProductTrend _analyzeProductTrend(
      String name, List<Map<String, dynamic>> sales) {
    if (sales.isEmpty) {
      return ProductTrend(
        name: name,
        brand: 'Unknown',
        currentPrice: 0.0,
        vram: null,
        trend: 0,
        priceHistory: [],
        dateHistory: [],
        regressionModel: PolynomialRegression(coefficients: [0], degree: 0),
        lastDayIndex: 0,
      );
    }

    final brand = (sales.first['brand']?.toString() ?? 'Unknown').trim();
    final vram = sales.first['vram'] != null
        ? (sales.first['vram'] as num).toDouble()
        : null;

    final uniqueSales = sales
        .fold<Map<DateTime, Map<String, dynamic>>>(
          {},
          (map, sale) {
            final date = _parseDate(sale['date']);
            final price = sale['price'];
            if (price != null &&
                (!map.containsKey(date) || map[date]!['price'] != price)) {
              map[date] = sale;
            }
            return map;
          },
        )
        .values
        .toList();

    uniqueSales
        .sort((a, b) => _parseDate(a['date']).compareTo(_parseDate(b['date'])));

    final prices = uniqueSales.map((s) {
      final price = s['price'];
      return price != null ? (price as num).toDouble() : 0.0;
    }).toList();

    final dates = uniqueSales.map((s) => _parseDate(s['date'])).toList();

    if (prices.length < 2) {
      debugPrint('Insufficient data points for trend calculation');
      return ProductTrend(
        name: name,
        brand: brand,
        currentPrice: prices.isNotEmpty ? prices.last : 0.0,
        vram: vram,
        trend: 0,
        priceHistory: prices,
        dateHistory: dates,
        regressionModel:
            PolynomialRegression(coefficients: [prices.last], degree: 0),
        lastDayIndex: 0,
      );
    }

    final regression =
        _calculateTimeBasedPolynomialRegression(prices, dates, 2);

    final firstDate = dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final lastDate = dates.last;
    final lastDayIndex = lastDate.difference(firstDate).inDays.toDouble();
    final trend = _calculateTimeTrend(regression, lastDayIndex);

    debugPrint('Trend calculation for $name: '
        'coefficients: ${regression.coefficients}, '
        'lastDayIndex: $lastDayIndex, '
        'result: $trend');

    return ProductTrend(
      name: name,
      brand: brand,
      currentPrice: prices.isNotEmpty ? prices.last : 0.0,
      vram: vram,
      trend: trend,
      priceHistory: prices,
      dateHistory: dates,
      regressionModel: regression,
      lastDayIndex: lastDayIndex,
    );
  }

  double _calculateTimeTrend(
      PolynomialRegression regression, double lastDayIndex) {
    if (regression.coefficients.isEmpty) return 0;

    // For constant model (degree 0)
    if (regression.degree == 0) {
      return 0;
    }

    // For linear model (degree 1): slope = coefficients[1]
    if (regression.degree == 1) {
      return regression.coefficients.length > 1
          ? regression.coefficients[1]
          : 0;
    }

    // For quadratic model (degree 2): derivative = b + 2*c*x
    if (regression.degree >= 2 && regression.coefficients.length >= 3) {
      final b = regression.coefficients[1];
      final c = regression.coefficients[2];
      return b + 2 * c * lastDayIndex;
    }

    return 0;
  }

  Future<void> saveCurrentTrends() async {
    try {
      final batch = _firestore.batch();

      for (var entry in _productTrends.entries) {
        final docRef = _firestore.collection('product_trends').doc(entry.key);
        final doc = await docRef.get();
        final existingData = doc.data() ?? {};

        final existingPrices =
            List<double>.from(existingData['priceHistory'] ?? []);
        final existingDates = (existingData['dateHistory'] as List?)
                ?.map((d) => (d as Timestamp).toDate())
                .toList() ??
            [];

        final mergedData = _mergeTrendData(
          existingPrices,
          existingDates,
          entry.value.priceHistory,
          entry.value.dateHistory,
        );

        batch.set(
            docRef,
            {
              'priceHistory': mergedData.prices,
              'dateHistory':
                  mergedData.dates.map((d) => Timestamp.fromDate(d)).toList(),
              'vram': entry.value.vram,
              'brand': entry.value.brand.displayName,
              'lastUpdated': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error saving trends: $e');
      rethrow;
    }
  }

  ({List<double> prices, List<DateTime> dates}) _mergeTrendData(
    List<double> existingPrices,
    List<DateTime> existingDates,
    List<double> newPrices,
    List<DateTime> newDates,
  ) {
    final combined = <DateTime, double>{};
    for (int i = 0; i < existingDates.length; i++) {
      combined[existingDates[i]] = existingPrices[i];
    }
    for (int i = 0; i < newDates.length; i++) {
      combined[newDates[i]] = newPrices[i];
    }

    final sortedDates = combined.keys.toList()..sort();
    final sortedPrices = sortedDates.map((d) => combined[d]!).toList();

    return (prices: sortedPrices, dates: sortedDates);
  }

  DateTime _normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  DateTime _parseDate(dynamic date) {
    final dt = date is Timestamp
        ? date.toDate()
        : date is DateTime
            ? date
            : date is String
                ? DateTime.parse(date)
                : DateTime.now();
    return _normalizeDate(dt);
  }

  List<ProductTrend> getProductTrends() => _productTrends.values.toList();
  List<ProductTrend> getTopPerformingProducts() =>
      _productTrends.values.where((trend) => trend.trend > 0).toList()
        ..sort((a, b) => b.trend.compareTo(a.trend));
  List<ProductTrend> getBottomPerformingProducts() =>
      _productTrends.values.where((trend) => trend.trend < 0).toList()
        ..sort((a, b) => a.trend.compareTo(b.trend));
  DateTime? get lastAnalysisDate => _lastAnalysisDate;
}

// Extension for list swapping
extension SwappableList<E> on List<E> {
  void swap(int index1, int index2) {
    final temp = this[index1];
    this[index1] = this[index2];
    this[index2] = temp;
  }
}

class DailyReportScreen extends StatefulWidget {
  final DateTime date;
  final SalesData salesData;
  final bool showAllDays;

  const DailyReportScreen({
    super.key,
    required this.date,
    required this.salesData,
    this.showAllDays = false,
  });

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  final TrendAnalysisService _trendAnalysis = TrendAnalysisService();
  bool _isAnalyzing = false;
  bool _showForecast = false;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    setState(() => _isAnalyzing = true);
    try {
      await _trendAnalysis.loadHistoricalTrends();
      await _trendAnalysis.analyzeSalesData(widget.salesData);
    } catch (e) {
      debugPrint('Error loading analysis: $e');
    }
    setState(() => _isAnalyzing = false);
  }

  Future<void> _refreshAnalysis() async {
    setState(() => _isAnalyzing = true);
    await _trendAnalysis.analyzeSalesData(widget.salesData);
    setState(() => _isAnalyzing = false);
  }

  String _getBrandAbbreviation(String brand) {
    if (brand.isEmpty || brand.toLowerCase() == 'unknown') {
      debugPrint('GetBrandAbbreviation: Empty/Unknown brand, returning UN');
      return 'UN';
    }

    debugPrint('GetBrandAbbreviation: Input brand: $brand');

    // First try to match with any ProductBrand
    try {
      final brandEnum = ProductBrand.values.firstWhere(
        (b) => brand.toLowerCase().contains(b.displayName.toLowerCase()),
        orElse: () => ProductBrand.other,
      );

      final abbreviation = _getAbbreviationFromEnum(brandEnum);
      debugPrint(
          'GetBrandAbbreviation: Matched $brand to ${brandEnum.displayName}, returning $abbreviation');
      return abbreviation;
    } catch (e) {
      debugPrint('GetBrandAbbreviation: Error matching enum: $e');
    }

    // Fallback to first two uppercase letters
    final fallback = brand.length >= 2
        ? brand.substring(0, 2).toUpperCase()
        : brand.toUpperCase();
    debugPrint('GetBrandAbbreviation: Using fallback abbreviation: $fallback');
    return fallback;
  }

  String _getAbbreviationFromEnum(ProductBrand brand) {
    switch (brand) {
      case ProductBrand.nvidia:
        return 'NV';
      case ProductBrand.amd:
        return 'AMD';
      case ProductBrand.intel:
        return 'INT';
      case ProductBrand.asus:
        return 'AS';
      case ProductBrand.msi:
        return 'MSI';
      case ProductBrand.gigabyte:
        return 'GB';
      case ProductBrand.evga:
        return 'EVGA';
      case ProductBrand.other:
        return 'OT';
    }
  }

  Map<String, Color> _generateBrandColors(List<String> brands) {
    final brandColors = {
      'NVIDIA': Colors.green,
      'AMD': Colors.red,
      'Intel': Colors.blue,
      'ASUS': Colors.purple,
      'MSI': Colors.amber,
      'Gigabyte': Colors.cyan,
      'EVGA': Colors.deepOrange,
      'Other': Colors.grey,
    };

    final result = <String, Color>{};
    final remainingColors = [
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
      Colors.lime,
    ];

    int colorIndex = 0;

    for (final brand in brands) {
      final matchedBrand = brandColors.keys.firstWhere(
        (known) => brand.toLowerCase().contains(known.toLowerCase()),
        orElse: () => '',
      );

      if (matchedBrand.isNotEmpty) {
        result[brand] = brandColors[matchedBrand]!;
      } else {
        result[brand] = remainingColors[colorIndex % remainingColors.length];
        colorIndex++;
      }
    }

    return result;
  }

  Widget _buildVRAMPriceChart() {
    final products = _trendAnalysis.getProductTrends()
      ..sort((a, b) => (a.vram ?? 0).compareTo(b.vram ?? 0));

    final validProducts =
        products.where((p) => p.vram != null && p.vram! > 0).toList();

    if (validProducts.isEmpty) {
      return const Center(child: Text('No products with VRAM data found'));
    }

    // Generate prediction data points
    final predictionData = _generatePredictionData(validProducts);

    final brandColors = _generateBrandColors(
        validProducts.map((p) => p.brand.displayName).toSet().toList());

    return SizedBox(
      height: 400,
      child: SfCartesianChart(
        primaryXAxis: NumericAxis(
          title: AxisTitle(text: 'VRAM (GB)'),
          minimum: 0, // Start from 0
          maximum: 24, // Go up to 24GB
          interval: 4, // Show labels every 4GB
          labelFormat: '{value}GB', // Add 'GB' suffix
        ),
        series: [
          // Scatter series for actual data points
          ScatterSeries<ProductTrend, double>(
            dataSource: validProducts,
            xValueMapper: (trend, _) => trend.vram!,
            yValueMapper: (trend, _) => trend.currentPrice,
            pointColorMapper: (trend, _) =>
                brandColors[trend.brand.displayName]!,
            markerSettings: const MarkerSettings(
              isVisible: true,
              shape: DataMarkerType.circle,
              width: 14,
              height: 14,
              borderWidth: 2,
              borderColor: Colors.black,
            ),
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              labelAlignment: ChartDataLabelAlignment.auto,
              builder: (data, _, __, ___, ____) {
                final brandAbbr = _getBrandAbbreviation(data.brand.displayName);
                return Text(
                  brandAbbr,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                );
              },
            ),
            name: 'Actual Prices',
          ),
          // Line series for prediction/trend line
          LineSeries<Map<String, double>, double>(
            dataSource: predictionData,
            xValueMapper: (data, _) => data['x']!,
            yValueMapper: (data, _) => data['y']!,
            color: Colors.blue,
            width: 2,
            dashArray: [5, 5],
            markerSettings: const MarkerSettings(isVisible: false),
            name: 'Price Trend',
          ),
        ],
        legend: Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          overflowMode: LegendItemOverflowMode.wrap,
        ),
        tooltipBehavior: TooltipBehavior(
          enable: true,
          builder: (data, point, series, pointIndex, seriesIndex) {
            if (seriesIndex == 0) {
              // Actual data points
              final product = validProducts[pointIndex];
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Brand: ${product.brand.displayName}'),
                    Text('VRAM: ${product.vram} GB'),
                    Text(
                        'Price: ${_currencyFormat.format(product.currentPrice)}'),
                    Text(
                        'Price/GB: ${_currencyFormat.format(product.pricePerGB)}'),
                  ],
                ),
              );
            } else {
              // Trend line
              final point = predictionData[pointIndex];
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Price Trend',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('VRAM: ${point['x']!.toStringAsFixed(1)} GB'),
                    Text(
                        'Estimated Price: ${_currencyFormat.format(point['y'])}'),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildVRAMPriceTable() {
    final products = _trendAnalysis.getProductTrends()
      ..sort((a, b) => (b.vram ?? 0).compareTo(a.vram ?? 0));

    final validProducts =
        products.where((p) => p.vram != null && p.vram! > 0).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Product')),
          DataColumn(label: Text('Brand')),
          DataColumn(label: Text('VRAM (GB)'), numeric: true),
          DataColumn(label: Text('Price'), numeric: true),
          DataColumn(label: Text('Price/GB'), numeric: true),
          DataColumn(label: Text('Trend'), numeric: true),
        ],
        rows: validProducts.map((product) {
          return DataRow(cells: [
            DataCell(SizedBox(
              width: 150,
              child: Text(
                product.name,
                overflow: TextOverflow.ellipsis,
              ),
            )),
            DataCell(Text(product.brand.displayName)),
            DataCell(Text(product.vram!.toStringAsFixed(1))),
            DataCell(Text(_currencyFormat.format(product.currentPrice))),
            DataCell(Text(_currencyFormat.format(product.pricePerGB))),
            DataCell(Text(
              product.trend > 0
                  ? '↑ ${product.trend.toStringAsFixed(2)}'
                  : '↓ ${product.trend.abs().toStringAsFixed(2)}',
              style: TextStyle(
                color: product.trend > 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            )),
          ]);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final salesData = Provider.of<SalesData>(context);
    List<Map<String, dynamic>> productsToShow = [];
    double totalAmount = 0;

    if (widget.showAllDays) {
      for (var dayProducts in salesData.currentWeekData.values) {
        productsToShow.addAll(dayProducts);
      }
      totalAmount = productsToShow.fold(0.0, (runningTotal, product) {
        return runningTotal + (product['price'] as num).toDouble();
      });
    } else {
      final dayIndex = widget.date.weekday % 7;
      productsToShow = salesData.currentWeekData[dayIndex] ?? [];
      totalAmount = salesData.getDailyTotal(dayIndex);
    }

    if (salesData.isLoading || _isAnalyzing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showAllDays
            ? 'Weekly Products Report'
            : 'Daily Report - ${DateFormat('EEE, MMM d, y').format(widget.date)}'),
        actions: [
          IconButton(
            icon: Icon(_showForecast ? Icons.pie_chart : Icons.scatter_plot),
            onPressed: () => setState(() => _showForecast = !_showForecast),
            tooltip:
                _showForecast ? 'Show Sales Breakdown' : 'Show VRAM Analysis',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAnalysis,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      widget.showAllDays ? 'Weekly Summary' : 'Daily Summary',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Sales:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          _currencyFormat.format(totalAmount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Products Sold:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${productsToShow.length}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_showForecast) ...[
              _buildVRAMPriceChart(),
              const SizedBox(height: 16),
              _buildVRAMPriceTable(),
            ] else ...[
              ProductListWidget(
                products: productsToShow,
                groupByDay: widget.showAllDays,
                dateFormat: DateFormat('EEEE, MMM d'),
                timeFormat: DateFormat('h:mm a'),
                currencyFormat: _currencyFormat,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProductListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final bool groupByDay;
  final DateFormat dateFormat;
  final DateFormat timeFormat;
  final NumberFormat currencyFormat;

  const ProductListWidget({
    super.key,
    required this.products,
    this.groupByDay = false,
    required this.dateFormat,
    required this.timeFormat,
    required this.currencyFormat,
  });

  DateTime _parseFirestoreDate(dynamic date) {
    try {
      if (date == null) return DateTime.now();
      if (date is Timestamp) return date.toDate();
      if (date is DateTime) return date;
      if (date is String) return DateTime.parse(date);
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupProductsByDay() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var product in products) {
      if (product['date'] != null) {
        final date = _parseFirestoreDate(product['date']);
        final day = dateFormat.format(date);

        grouped.putIfAbsent(day, () => []).add(product);
      }
    }

    return grouped;
  }

  Widget _buildProductItem(Map<String, dynamic> product) {
    final productDate = _parseFirestoreDate(product['date']);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(product['name']?.toString() ?? 'Unknown'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(timeFormat.format(productDate)),
            if (product['brand'] != null)
              Text('Brand: ${product['brand']}',
                  style: TextStyle(color: Colors.grey.shade600)),
            if (product['vram'] != null)
              Text('VRAM: ${product['vram']}GB',
                  style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
        trailing: Text(
          currencyFormat.format(product['price']),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildDayGroup(String day, List<Map<String, dynamic>> dayProducts) {
    final dayTotal = dayProducts.fold(
      0.0,
      (runningTotal, p) => runningTotal + (p['price'] as num).toDouble(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                currencyFormat.format(dayTotal),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        ...dayProducts.map(_buildProductItem),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(child: Text('No products sold'));
    }

    return groupByDay
        ? Column(
            children: _groupProductsByDay()
                .entries
                .map((entry) => _buildDayGroup(entry.key, entry.value))
                .toList(),
          )
        : Column(
            children: products.map(_buildProductItem).toList(),
          );
  }
}
