class PluginInstance {
  final String instance;
  final String uri;
  String title;

  // Dynamic port symbol for controlling the gain/volume (discovered in real-time)
  String? gainPortSymbol;

  // Track parameters of this instance in real-time
  final Map<String, double> parameters = {};

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

  @override
  String toString() {
    return 'PluginInstance(instance: $instance, uri: $uri, title: $title, gainPortSymbol: $gainPortSymbol, isBypassed: $isBypassed, parameters: $parameters)';
  }
}
