// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../../models/plugin_instance.dart';
import '../../utils/color_utils.dart';

/// Settings drawer widget (puzzle organizer)
class SettingsDrawer extends StatefulWidget {
  final bool isDarkMode;
  final ValueNotifier<List<PluginInstance>> allPluginsNotifier;
  final List<String> enabledPluginInstances;
  final List<String> orderedPluginInstances;
  final Map<String, String> pedalSizes;
  final Map<String, String> pedalGlowColors;
  final Map<String, String> customTitles;
  final VoidCallback onLayoutSettingsChanged;
  final Function(PluginInstance) onHighlightPedal;
  final Function(PluginInstance) onShowColorPicker;
  final Function(String) onCyclePedalSize;
  final Function(String) onScrollToCard;

  const SettingsDrawer({
    super.key,
    required this.isDarkMode,
    required this.allPluginsNotifier,
    required this.enabledPluginInstances,
    required this.orderedPluginInstances,
    required this.pedalSizes,
    required this.pedalGlowColors,
    required this.customTitles,
    required this.onLayoutSettingsChanged,
    required this.onHighlightPedal,
    required this.onShowColorPicker,
    required this.onCyclePedalSize,
    required this.onScrollToCard,
  });

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {

  Widget _buildMiniPuzzleTile({
    required PluginInstance pedal,
    required bool isActive,
    required double cWidth,
    required double rWidth,
    required double eWidth,
  }) {
    final String instanceId = pedal.instance;
    final size = widget.pedalSizes[instanceId] ?? 'regular';

    final uriLower = pedal.uri.toLowerCase();
    final titleLower = pedal.title.toLowerCase();
    final isLooper =
        uriLower.contains('alo') ||
        titleLower.contains('alo') ||
        instanceId.toLowerCase().contains('alo');
    final isSwitch =
        uriLower.contains('switch') || titleLower.contains('switch');

    double width = rWidth;
    double height = 46.0;
    if (isActive) {
      if (isLooper) {
        width = eWidth;
        height = 56.0;
      } else if (size == 'compact') {
        width = cWidth;
        height = 40.0;
      } else if (size == 'regular') {
        width = rWidth;
        height = 48.0;
      } else {
        width = eWidth;
        height = 56.0;
      }
    } else {
      // Inactive tiles always show regular sizing for grid visual consistency in pool
      width = rWidth;
      height = 46.0;
    }

    final String colorHex =
        widget.pedalGlowColors[instanceId] ?? getLeastUsedColor(widget.pedalGlowColors);
    final Color glowColor = hexToColor(colorHex);

    IconData typeIcon = Icons.help_outline;
    if (isLooper) {
      typeIcon = Icons.fiber_manual_record; // red looper dot
    } else if (isSwitch) {
      typeIcon = Icons.swap_horiz;
    } else {
      typeIcon = Icons.adjust; // rotary volume knob
    }

    final tileContent = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? glowColor.withOpacity(widget.isDarkMode ? 0.12 : 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: glowColor.withOpacity(isActive ? 0.9 : 0.4),
          width: isActive ? 1.5 : 1.0,
          style: BorderStyle.solid,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: glowColor.withOpacity(0.3),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Device Type Icon
          Icon(
            typeIcon,
            size: size == 'compact' && isActive ? 11 : 13,
            color: isLooper && isActive ? const Color(0xFFFF0055) : glowColor,
          ),
          const SizedBox(width: 4),

          // Title
          Expanded(
            child: Text(
              (widget.customTitles[instanceId] ?? pedal.title).toUpperCase(),
              style: TextStyle(
                color: isActive
                    ? (widget.isDarkMode ? Colors.white : Colors.black)
                    : (widget.isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                fontWeight: FontWeight.bold,
                fontSize: size == 'compact' && isActive ? 8 : 9.5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Right panel options
          if (isActive) ...[
            // Size Toggle C/R/E (non-loopers only)
            if (!isLooper)
              GestureDetector(
                onTap: () => widget.onCyclePedalSize(instanceId),
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? Colors.grey[900] : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    size[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: widget.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );

    // Draggable wrapping
    return DragTarget<String>(
      onWillAccept: (data) => data != instanceId,
      onAccept: (draggedId) {
        setState(() {
          // Reorder list order
          final idxA = widget.orderedPluginInstances.indexOf(draggedId);
          final idxB = widget.orderedPluginInstances.indexOf(instanceId);
          if (idxA != -1 && idxB != -1) {
            final item = widget.orderedPluginInstances.removeAt(idxA);
            widget.orderedPluginInstances.insert(idxB, item);
          }

          // If dragged item was inactive, activate it at target index
          if (!widget.enabledPluginInstances.contains(draggedId)) {
            widget.enabledPluginInstances.add(draggedId);
          }

          // Also sync reorder inside active visibility list
          final activeA = widget.enabledPluginInstances.indexOf(draggedId);
          final activeB = widget.enabledPluginInstances.indexOf(instanceId);
          if (activeA != -1 && activeB != -1 && activeA != activeB) {
            final item = widget.enabledPluginInstances.removeAt(activeA);
            widget.enabledPluginInstances.insert(activeB, item);
          }
        });
        widget.onLayoutSettingsChanged();
      },
      builder: (context, _, __) {
        return LongPressDraggable<String>(
          data: instanceId,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.7,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: glowColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: glowColor, width: 2.0),
                ),
                child: Center(
                  child: Text(
                    (widget.customTitles[instanceId] ?? pedal.title).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: GestureDetector(
            onTap: () {
              widget.onHighlightPedal(pedal);
              if (isActive) {
                widget.onScrollToCard(instanceId);
              }
            },
            onDoubleTap: () => widget.onShowColorPicker(pedal),
            child: tileContent,
          ),
        );
      },
    );
  }

  Widget _buildDrawerContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double drawerWidth = constraints.maxWidth;
        final double horizontalPadding = 12.0;
        final double spacing = 6.0;
        // Account for container margin (10px each side) + container padding (6px each side)
        // so that two regularWidth tiles actually fit in a Wrap row.
        final double tileAreaWidth =
            drawerWidth - horizontalPadding * 2 - 10 * 2 - 6 * 2;
        final double gridWidth = tileAreaWidth;

        // 4 Columns available width calculation
        final double totalColumnWidth = gridWidth - (spacing * 3);
        final double colWidth = totalColumnWidth / 4;

        final double compactWidth = colWidth;
        final double regularWidth = (colWidth * 2) + spacing;
        final double expandedWidth = gridWidth;

        return ValueListenableBuilder<List<PluginInstance>>(
          valueListenable: widget.allPluginsNotifier,
          builder: (context, allPlugins, _) {
            // Hydrate active list based on saved order & visibility
            final List<PluginInstance> activePedals = [];
            for (final id in widget.orderedPluginInstances) {
              if (widget.enabledPluginInstances.contains(id)) {
                final pedal = allPlugins.firstWhere(
                  (p) => p.instance == id,
                  orElse: () =>
                      PluginInstance(instance: '', title: '', uri: ''),
                );
                if (pedal.instance.isNotEmpty) {
                  activePedals.add(pedal);
                }
              }
            }

            // Hydrate inactive list
            final List<PluginInstance> inactivePedals = [];
            for (final id in widget.orderedPluginInstances) {
              if (!widget.enabledPluginInstances.contains(id)) {
                final pedal = allPlugins.firstWhere(
                  (p) => p.instance == id,
                  orElse: () =>
                      PluginInstance(instance: '', title: '', uri: ''),
                );
                if (pedal.instance.isNotEmpty) {
                  inactivePedals.add(pedal);
                }
              }
            }

            return Column(
              children: [
                // ACTIVE PUZZLE CANVAS
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.extension,
                        size: 15,
                        color: widget.isDarkMode
                            ? const Color(0xFF00FFCC)
                            : const Color(0xFF00B3FF),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'PUZZLE CANVAS (ACTIVE)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                          color: widget.isDarkMode ? Colors.grey : Colors.grey[700],
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  flex: 3,
                  child: DragTarget<String>(
                    onAccept: (draggedId) {
                      // Drag from Inactive or general drop to activate/reorder to the end
                      setState(() {
                        if (!widget.enabledPluginInstances.contains(draggedId)) {
                          widget.enabledPluginInstances.add(draggedId);
                        }

                        // Move to end of active list in widget.orderedPluginInstances
                        final List<String> actives = widget.orderedPluginInstances
                            .where(
                              (id) =>
                                  widget.enabledPluginInstances.contains(id) &&
                                  id != draggedId,
                            )
                            .toList();

                        widget.orderedPluginInstances.remove(draggedId);
                        if (actives.isNotEmpty) {
                          final lastActiveId = actives.last;
                          final targetIdx = widget.orderedPluginInstances.indexOf(
                            lastActiveId,
                          );
                          if (targetIdx != -1) {
                            widget.orderedPluginInstances.insert(
                              targetIdx + 1,
                              draggedId,
                            );
                          } else {
                            widget.orderedPluginInstances.add(draggedId);
                          }
                        } else {
                          widget.orderedPluginInstances.insert(0, draggedId);
                        }

                        // Also sync widget.enabledPluginInstances order
                        widget.enabledPluginInstances.remove(draggedId);
                        widget.enabledPluginInstances.add(draggedId);
                      });
                      widget.onLayoutSettingsChanged();
                    },
                    builder: (context, _, __) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode
                              ? const Color(0xFF0F141C).withOpacity(0.5)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (widget.isDarkMode
                                ? Colors.grey[850]
                                : Colors.grey[300])!,
                            width: 1.5,
                          ),
                        ),
                        child: activePedals.isEmpty
                            ? Center(
                                child: Text(
                                  'Drag cards here or toggle below to activate.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: widget.isDarkMode
                                        ? Colors.grey[600]
                                        : Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  alignment: WrapAlignment.start,
                                  runAlignment: WrapAlignment.start,
                                  crossAxisAlignment: WrapCrossAlignment.start,
                                  children: activePedals.map((pedal) {
                                    return _buildMiniPuzzleTile(
                                      pedal: pedal,
                                      isActive: true,
                                      cWidth: compactWidth,
                                      rWidth: regularWidth,
                                      eWidth: expandedWidth,
                                    );
                                  }).toList(),
                                ),
                              ),
                      );
                    },
                  ),
                ),

                // INACTIVE / AVAILABLE POOL
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 15,
                        color: inactivePedals.isEmpty
                            ? Colors.grey
                            : (widget.isDarkMode
                                  ? const Color(0xFFFF007F)
                                  : const Color(0xFFFF0055)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AVAILABLE POOL (INACTIVE)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                          color: widget.isDarkMode ? Colors.grey : Colors.grey[700],
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  flex: 2,
                  child: DragTarget<String>(
                    onAccept: (draggedId) {
                      // Drag from Active to Inactive
                      if (widget.enabledPluginInstances.contains(draggedId)) {
                        setState(() {
                          widget.enabledPluginInstances.remove(draggedId);
                        });
                        widget.onLayoutSettingsChanged();
                      }
                    },
                    builder: (context, _, __) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: widget.isDarkMode
                              ? const Color(0xFF0F141C).withOpacity(0.3)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (widget.isDarkMode
                                ? Colors.grey[900]
                                : Colors.grey[200])!,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: inactivePedals.isEmpty
                            ? Center(
                                child: Text(
                                  'All components are active.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: widget.isDarkMode
                                        ? Colors.grey[600]
                                        : Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Wrap(
                                  spacing: spacing,
                                  runSpacing: spacing,
                                  children: inactivePedals.map((pedal) {
                                    return _buildMiniPuzzleTile(
                                      pedal: pedal,
                                      isActive: false,
                                      cWidth: compactWidth,
                                      rWidth: regularWidth,
                                      eWidth: expandedWidth,
                                    );
                                  }).toList(),
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF0F141C) : Colors.white,
        border: Border(
          left: BorderSide(
            color: widget.isDarkMode
                ? const Color(0xFF00FFCC)
                : const Color(0xFF00B3FF),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Drawer header with the puzzle toggle button matching AppBar height
          Container(
            height: kToolbarHeight + statusBarHeight,
            padding: EdgeInsets.only(top: statusBarHeight),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: (widget.isDarkMode
                          ? const Color(0xFF00FFCC)
                          : const Color(0xFF00B3FF))
                      .withOpacity(0.3),
                  width: 1.5,
                ),
              ),
            ),
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.extension,
                    color: Color(0xFFFF007F),
                    size: 22,
                  ),
                  tooltip: 'Puzzle Organizer',
                  onPressed: () {
                    Scaffold.of(context).closeEndDrawer();
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          
          // Drawer content
          Expanded(
            child: _buildDrawerContent(),
          ),
        ],
      ),
    );
  }
}
