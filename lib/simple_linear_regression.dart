class SimpleLinearRegression {
  double? _slope;
  double? _intercept;

  void train(List<double> x, List<double> y) {
    if (x.length != y.length) {
      throw ArgumentError('Input arrays must have the same length');
    }

    final n = x.length;
    final xSum = x.reduce((a, b) => a + b);
    final ySum = y.reduce((a, b) => a + b);
    final xySum = _dotProduct(x, y);
    final xSquaredSum = _dotProduct(x, x);

    _slope = (n * xySum - xSum * ySum) / (n * xSquaredSum - xSum * xSum);
    _intercept = (ySum - _slope! * xSum) / n;
  }

  double predict(double x) {
    if (_slope == null || _intercept == null) {
      throw StateError('Model must be trained before making predictions');
    }
    return _slope! * x + _intercept!;
  }

  double _dotProduct(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }
}
