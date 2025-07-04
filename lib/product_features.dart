class ProductFeatures {
  final String productId;
  final String brand;
  final String category;
  final TechnicalSpecs specs;
  final MarketData marketData;
  final CustomerMetrics customerMetrics;

  ProductFeatures({
    required this.productId,
    required this.brand,
    required this.category,
    required this.specs,
    required this.marketData,
    required this.customerMetrics,
  });
}

class TechnicalSpecs {
  final double cpuClockSpeed; // GHz
  final int cpuCores;
  final int ramSize; // GB
  final int storageSize; // GB
  final String storageType; // SSD/HDD
  final String displayResolution;
  final int batteryCapacity; // mAh
  final double weight; // kg
  final DateTime releaseDate;

  TechnicalSpecs(
    this.ramSize,
    this.storageSize,
    this.storageType,
    this.displayResolution,
    this.batteryCapacity,
    this.weight,
    this.releaseDate, {
    required this.cpuClockSpeed,
    required this.cpuCores,
    // ... other specs
  });

  int get productAgeInMonths {
    return DateTime.now().difference(releaseDate).inDays ~/ 30;
  }
}

class MarketData {
  final double competitorPrice;
  final double currentDiscount;
  final int daysUntilHoliday;
  final double inflationRate;

  MarketData(
    this.currentDiscount,
    this.daysUntilHoliday,
    this.inflationRate, {
    required this.competitorPrice,
    // ... other market factors
  });
}

class CustomerMetrics {
  final double averageRating;
  final int reviewCount;
  final double searchTrendScore;
  final double socialMediaEngagement;

  CustomerMetrics(
    this.reviewCount,
    this.searchTrendScore,
    this.socialMediaEngagement, {
    required this.averageRating,
    // ... other metrics
  });
}
