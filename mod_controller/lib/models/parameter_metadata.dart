// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

class ParameterMetadata {
  final String symbol;
  final String name;
  final double min;
  final double max;
  final double step;
  final bool isToggle;

  ParameterMetadata({
    required this.symbol,
    required this.name,
    required this.min,
    required this.max,
    required this.step,
    required this.isToggle,
  });

  factory ParameterMetadata.fromJson(Map<String, dynamic> json) {
    return ParameterMetadata(
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? json['symbol'] ?? '',
      min: (json['min'] as num?)?.toDouble() ?? 0.0,
      max: (json['max'] as num?)?.toDouble() ?? 1.0,
      step: (json['step'] as num?)?.toDouble() ?? 0.01,
      isToggle: json['is_toggle'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'min': min,
      'max': max,
      'step': step,
      'is_toggle': isToggle,
    };
  }
}
