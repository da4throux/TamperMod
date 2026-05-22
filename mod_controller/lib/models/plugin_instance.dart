import 'parameter_metadata.dart';

class PluginInstance {
  final String instance;
  final String uri;
  String title;

  // Dynamic port symbol for controlling the gain/volume (discovered in real-time)
  String? gainPortSymbol;

  // Track parameters of this instance in real-time
  final Map<String, double> parameters = {};

  // Metadata cache for parameters discovered via WebView scraping
  final Map<String, ParameterMetadata> parameterMetadata = {};

  // Bypass state (true if bypassed/disabled, false if active/enabled)
  bool isBypassed = false;

  PluginInstance({
    required this.instance,
    required this.uri,
    required this.title,
    this.gainPortSymbol,
    this.isBypassed = false,
  });

  factory PluginInstance.fromRawFields({
    required String instance,
    required String uri,
    bool isBypassed = false,
  }) {
    // Format the title nicely from the instance name (e.g. /graph/Gain_1 -> Gain 1)
    String rawTitle = instance.split('/').last;
    rawTitle = rawTitle.replaceAll('_', ' ');
    if (rawTitle.isNotEmpty) {
      rawTitle = rawTitle[0].toUpperCase() + rawTitle.substring(1);
    }
    
    return PluginInstance(
      instance: instance,
      uri: uri,
      title: rawTitle.isEmpty ? instance : rawTitle,
      isBypassed: isBypassed,
    );
  }

  double get minGain {
    final uriLower = uri.toLowerCase();
    final titleLower = title.toLowerCase();
    
    if (uriLower.contains('volume') || titleLower.contains('volume')) {
      return -60.0;
    }
    if (uriLower.contains('amp') || titleLower.contains('amp')) {
      return -20.0;
    }
    if (uriLower.contains('gain') || titleLower.contains('gain')) {
      return -40.0;
    }
    return -60.0; // Safe default
  }

  double get maxGain {
    final uriLower = uri.toLowerCase();
    final titleLower = title.toLowerCase();
    
    if (uriLower.contains('volume') || titleLower.contains('volume')) {
      return 0.0;
    }
    if (uriLower.contains('amp') || titleLower.contains('amp')) {
      return 20.0;
    }
    if (uriLower.contains('gain') || titleLower.contains('gain')) {
      return 40.0;
    }
    return 20.0; // Safe default
  }

  @override
  String toString() {
    return 'PluginInstance(instance: $instance, uri: $uri, title: $title, gainPortSymbol: $gainPortSymbol, isBypassed: $isBypassed, parameters: $parameters)';
  }
}
