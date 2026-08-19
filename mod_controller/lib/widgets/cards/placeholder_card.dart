// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../../models/plugin_instance.dart';
import '../../models/parameter_metadata.dart';
import '../common/size_toggle_button.dart';
import 'base_card.dart';

/// Generic card for unsupported controller types that dynamically builds controls.
class PlaceholderCard extends StatelessWidget {
  final PluginInstance pedal;
  final String size;
  final bool isDarkMode;
  final Color glowColor;
  final String displayName;
  final List<String> visibleParams;
  final List<String> visibleCompactParams;
  final ValueChanged<bool> onBypassToggle;
  final VoidCallback onRenamePressed;
  final VoidCallback onHighlightPressed;
  final VoidCallback onColorPickerPressed;
  final VoidCallback onSizeToggled;
  final void Function(String port, double value) onParamChanged;
  final void Function(String symbol, bool visible) onParamVisibilityToggled;
  final void Function(String symbol, bool visible) onParamVisibilityCompactToggled;
  final ValueChanged<String> onOpenUri;

  const PlaceholderCard({
    super.key,
    required this.pedal,
    required this.size,
    required this.isDarkMode,
    required this.glowColor,
    required this.displayName,
    required this.visibleParams,
    required this.visibleCompactParams,
    required this.onBypassToggle,
    required this.onRenamePressed,
    required this.onHighlightPressed,
    required this.onColorPickerPressed,
    required this.onSizeToggled,
    required this.onParamChanged,
    required this.onParamVisibilityToggled,
    required this.onParamVisibilityCompactToggled,
    required this.onOpenUri,
  });

  // Resolve metadata, falling back to safe defaults if not found
  List<ParameterMetadata> _getResolvedMetadata() {
    final List<ParameterMetadata> list = [];
    final Set<String> allSymbols = {
      ...pedal.parameters.keys,
      ...pedal.parameterMetadata.keys,
    };
    final keys = allSymbols.toList()..sort();
    for (final sym in keys) {
      if (pedal.parameterMetadata.containsKey(sym)) {
        list.add(pedal.parameterMetadata[sym]!);
      } else {
        // Safe defaults
        list.add(ParameterMetadata(
          symbol: sym,
          name: sym,
          min: 0.0,
          max: 1.0,
          step: 0.01,
          isToggle: false,
        ));
      }
    }
    return list;
  }

  void _showInfoDialog(BuildContext context) {
    final metadataList = _getResolvedMetadata();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF0F141C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: glowColor.withOpacity(0.5), width: 1.5),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${displayName.toUpperCase()} INFO',
                  style: TextStyle(
                    color: glowColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                  4: FlexColumnWidth(1.2),
                },
                border: TableBorder.all(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.5,
                ),
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                    ),
                    children: const [
                      TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('SYMBOL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('MIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('MAX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                      TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('VALUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                    ],
                  ),
                  ...metadataList.map((meta) {
                    final currentVal = pedal.parameters[meta.symbol] ?? 0.0;
                    return TableRow(
                      children: [
                        TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(meta.name, style: const TextStyle(fontSize: 11)))),
                        TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(meta.symbol, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')))),
                        TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(meta.min.toStringAsFixed(2), style: const TextStyle(fontSize: 10)))),
                        TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(meta.max.toStringAsFixed(2), style: const TextStyle(fontSize: 10)))),
                        TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text(currentVal.toStringAsFixed(2), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: glowColor)))),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildParamControl(ParameterMetadata meta, Color accentColor, BuildContext context) {
    final double currentVal = pedal.parameters[meta.symbol] ?? meta.min;
    
    if (meta.isToggle) {
      final bool isSwitchedOn = currentVal >= 0.5;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDarkMode ? Colors.grey[850]! : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    meta.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    meta.symbol,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontFamily: 'monospace',
                      color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Switch(
              value: isSwitchedOn,
              activeColor: accentColor,
              activeTrackColor: accentColor.withOpacity(0.4),
              onChanged: pedal.isBypassed
                  ? null
                  : (val) {
                      onParamChanged(meta.symbol, val ? 1.0 : 0.0);
                    },
            ),
          ],
        ),
      );
    } else {
      // Slider control
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDarkMode ? Colors.grey[850]! : Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        meta.symbol,
                        style: TextStyle(
                          fontSize: 8.5,
                          fontFamily: 'monospace',
                          color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black : Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    currentVal.toStringAsFixed(2),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: accentColor,
                inactiveTrackColor: isDarkMode ? Colors.grey[900] : Colors.grey[300],
                trackHeight: 4.0,
                thumbColor: isDarkMode ? Colors.white : Colors.grey[800],
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayColor: accentColor.withOpacity(0.2),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
              ),
              child: Slider(
                value: currentVal.clamp(meta.min, meta.max),
                min: meta.min,
                max: meta.max,
                onChanged: pedal.isBypassed
                    ? null
                    : (val) {
                        onParamChanged(meta.symbol, val);
                      },
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildCompactParamControl(ParameterMetadata meta, Color accentColor, BuildContext context) {
    final double currentVal = pedal.parameters[meta.symbol] ?? meta.min;
    
    if (meta.isToggle) {
      final bool isSwitchedOn = currentVal >= 0.5;
      return Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black.withOpacity(0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDarkMode ? Colors.grey[900]! : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                meta.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              height: 18,
              width: 32,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Switch(
                  value: isSwitchedOn,
                  activeColor: accentColor,
                  onChanged: pedal.isBypassed
                      ? null
                      : (val) {
                          onParamChanged(meta.symbol, val ? 1.0 : 0.0);
                        },
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black.withOpacity(0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isDarkMode ? Colors.grey[900]! : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 50,
              child: Text(
                meta.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.0,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accentColor,
                  inactiveTrackColor: isDarkMode ? Colors.grey[900] : Colors.grey[300],
                  trackHeight: 2.0,
                  thumbColor: isDarkMode ? Colors.white : Colors.grey[800],
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0),
                ),
                child: Slider(
                  value: currentVal.clamp(meta.min, meta.max),
                  min: meta.min,
                  max: meta.max,
                  onChanged: pedal.isBypassed
                      ? null
                      : (val) {
                          onParamChanged(meta.symbol, val);
                        },
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 24,
              child: Text(
                currentVal.toStringAsFixed(1),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBypassed = pedal.isBypassed;
    final Color accentColor = isBypassed ? Colors.grey[600]! : glowColor;
    final Color powerIconColor = isBypassed ? const Color(0xFFFF007F) : glowColor;

    final allMetadata = _getResolvedMetadata();

    Widget buildSizeToggle() {
      return SizeToggleButton(
        instanceId: pedal.instance,
        currentSize: size,
        accentColor: accentColor,
        isDarkMode: isDarkMode,
        onTap: onSizeToggled,
        onLongPress: onRenamePressed,
      );
    }

    Widget buildStandardHeaderRow(BuildContext context) {
      return Row(
        children: [
          // 1. Size Toggle
          buildSizeToggle(),
          const SizedBox(width: 6),

          // 2. Card Name (Expanded)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onHighlightPressed,
              onLongPress: onRenamePressed,
              child: Text(
                displayName.toUpperCase(),
                style: TextStyle(
                  fontSize: size == 'compact' ? 13.0 : (size == 'regular' ? 15.0 : 17.0),
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                  letterSpacing: 0.8,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 3. Info Button
          GestureDetector(
            onTap: () => _showInfoDialog(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1C2433) : Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.info_outline,
                size: 13,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 4. Edit Button
          GestureDetector(
            onTap: onRenamePressed,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1C2433) : Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.edit,
                size: 13,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 5. Focus Button
          GestureDetector(
            onTap: onHighlightPressed,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1C2433) : Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.radar,
                size: 13,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 6. Power Button
          GestureDetector(
            onTap: () => onBypassToggle(!isBypassed),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: !isBypassed
                    ? glowColor.withOpacity(isDarkMode ? 0.25 : 0.18)
                    : (isDarkMode ? const Color(0xFF1C2433) : Colors.grey[200]),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: !isBypassed ? glowColor : Colors.grey[700]!,
                  width: !isBypassed ? 1.2 : 0.8,
                ),
              ),
              child: Icon(
                Icons.power_settings_new,
                size: 14,
                color: !isBypassed ? glowColor : Colors.grey[500],
              ),
            ),
          ),
        ],
      );
    }

    if (size == 'compact') {
      final displayCompactList = allMetadata.where((meta) {
        return visibleCompactParams.contains(meta.symbol);
      }).toList();

      return BaseCard(
        glowColor: glowColor,
        isBypassed: isBypassed,
        isDarkMode: isDarkMode,
        onLongPress: onColorPickerPressed,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildStandardHeaderRow(context),
              if (displayCompactList.isNotEmpty) ...[
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: displayCompactList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      return _buildCompactParamControl(displayCompactList[index], accentColor, context);
                    },
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Generic device with ${allMetadata.length} parameters',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.info_outline,
                        color: accentColor.withOpacity(0.8),
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showInfoDialog(context),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (size == 'regular') {
      // Show only visible/checked parameters
      final displayList = allMetadata.where((meta) {
        return visibleParams.isEmpty || visibleParams.contains(meta.symbol);
      }).toList();

      return BaseCard(
        glowColor: glowColor,
        isBypassed: isBypassed,
        isDarkMode: isDarkMode,
        onLongPress: onColorPickerPressed,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              buildStandardHeaderRow(context),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => onOpenUri(pedal.uri),
                child: Text(
                  pedal.uri,
                  style: TextStyle(
                    fontSize: 8.5,
                    color: isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
                    decoration: TextDecoration.underline,
                    fontFamily: 'monospace',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Controls Grid (2 columns)
              Expanded(
                child: displayList.isEmpty
                    ? Center(
                        child: Text(
                          'No parameters visible.\nGo to Expanded (E) mode to configure.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                        ),
                      )
                    : GridView.builder(
                        padding: EdgeInsets.zero,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.8,
                        ),
                        itemCount: displayList.length,
                        itemBuilder: (context, index) {
                          return _buildParamControl(displayList[index], accentColor, context);
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    }

    // Expanded View (Full size / Checklist layout)
    return BaseCard(
      glowColor: glowColor,
      isBypassed: isBypassed,
      isDarkMode: isDarkMode,
      onLongPress: onColorPickerPressed,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            buildStandardHeaderRow(context),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => onOpenUri(pedal.uri),
              child: Text(
                pedal.uri,
                style: TextStyle(
                  fontSize: 8.5,
                  color: isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
                  decoration: TextDecoration.underline,
                  fontFamily: 'monospace',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Section 1: Checklist of visible parameters in regular card
            Text(
              'REGULAR CARD PARAMETERS CONFIGURATION',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: accentColor.withOpacity(0.8),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDarkMode ? Colors.grey[850]! : Colors.grey[300]!),
              ),
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allMetadata.map((meta) {
                  final isChecked = visibleParams.contains(meta.symbol);
                  return GestureDetector(
                    onTap: () {
                      onParamVisibilityToggled(meta.symbol, !isChecked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isChecked ? glowColor.withOpacity(0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isChecked ? glowColor : (isDarkMode ? Colors.grey[800]! : Colors.grey[400]!),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                            color: isChecked ? glowColor : Colors.grey[600],
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            meta.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isChecked ? glowColor : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            // Section 1.5: Checklist of visible parameters in compact card
            Text(
              'COMPACT CARD PARAMETERS CONFIGURATION',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: accentColor.withOpacity(0.8),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDarkMode ? Colors.grey[850]! : Colors.grey[300]!),
              ),
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allMetadata.map((meta) {
                  final isChecked = visibleCompactParams.contains(meta.symbol);
                  return GestureDetector(
                    onTap: () {
                      onParamVisibilityCompactToggled(meta.symbol, !isChecked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isChecked ? glowColor.withOpacity(0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isChecked ? glowColor : (isDarkMode ? Colors.grey[800]! : Colors.grey[400]!),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                            color: isChecked ? glowColor : Colors.grey[600],
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            meta.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isChecked ? glowColor : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            // Section 2: All parameters control grid
            Text(
              'ALL CONTROLLER PARAMETERS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: accentColor.withOpacity(0.8),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            // Scrollable Wrap or Grid of all sliders (auto-expanding so we don't nest GridViews inside SingleChildScrollView layout constraint conflicts)
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: allMetadata.map((meta) {
                // Size controls to match 2-column layout width on expanded card
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final double colWidth = (constraints.maxWidth - 12) / 2;
                    return SizedBox(
                      width: colWidth > 0 ? colWidth : 200,
                      child: _buildParamControl(meta, accentColor, context),
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
