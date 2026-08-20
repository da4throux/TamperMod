// Copyright (c) 2026 TamperMod Contributors
// Licensed under the MIT License

import 'package:flutter/material.dart';
import '../../models/plugin_instance.dart';
import '../../utils/color_utils.dart';
import '../../utils/plugin_category.dart';

enum InactivePoolExpansion {
  minimal,
  partial,
  full,
}

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
  final String currentConfig;
  final List<String> configsList;
  final Function(String) onConfigChanged;
  final VoidCallback onConfigDuplicate;
  final VoidCallback onConfigRename;
  final VoidCallback onConfigDelete;
  final VoidCallback onBackupRestore;
  final VoidCallback onAddSpacer;
  final Function(String) onDeleteSpacer;
  final VoidCallback onAddLineBreak;
  final Function(String) onDeleteLineBreak;
  final String? highlightedInstanceId;

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
    required this.currentConfig,
    required this.configsList,
    required this.onConfigChanged,
    required this.onConfigDuplicate,
    required this.onConfigRename,
    required this.onConfigDelete,
    required this.onBackupRestore,
    required this.onAddSpacer,
    required this.onDeleteSpacer,
    required this.onAddLineBreak,
    required this.onDeleteLineBreak,
    this.highlightedInstanceId,
  });

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  InactivePoolExpansion _inactivePoolExpansion = InactivePoolExpansion.partial;
  final Map<String, GlobalKey> _activeTileKeys = {};
  final Set<PluginCategoryType> _selectedCategoryFilters = {};

  GlobalKey _getTileKey(String instanceId) {
    return _activeTileKeys.putIfAbsent(instanceId, () => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant SettingsDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightedInstanceId != null &&
        widget.highlightedInstanceId != oldWidget.highlightedInstanceId) {
      _scrollToHighlightedTile(widget.highlightedInstanceId!);
    }
  }

  void _scrollToHighlightedTile(String instanceId) {
    final key = _activeTileKeys[instanceId];
    final targetContext = key?.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        alignment: 0.1,
      );
    }
  }

  void _showCategoryHelpDialog({PluginCategoryType? initialCategory}) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: widget.isDarkMode ? const Color(0xFF131822) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: widget.isDarkMode
                  ? const Color(0xFF00FFCC).withValues(alpha: 0.3)
                  : const Color(0xFF00B3FF).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          title: Row(
            children: [
              Icon(
                Icons.category_rounded,
                color: widget.isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Effect Categories Guide',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: PluginCategoryHelper.categories.values
                    .where((cat) => cat.type != PluginCategoryType.lineBreak && cat.type != PluginCategoryType.spacer)
                    .map((cat) {
                  final bool isHighlighted = initialCategory == cat.type;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? cat.defaultColor.withValues(alpha: 0.2)
                          : (widget.isDarkMode ? Colors.grey[900]!.withValues(alpha: 0.4) : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isHighlighted
                            ? cat.defaultColor
                            : (widget.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!),
                        width: isHighlighted ? 1.5 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: cat.defaultColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(cat.icon, size: 15, color: cat.defaultColor),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: cat.defaultColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: cat.defaultColor.withValues(alpha: 0.5), width: 0.8),
                          ),
                          child: Text(
                            cat.shortCode,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: cat.defaultColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.label,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                cat.description,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('GOT IT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryFilterBar(List<PluginInstance> allPedals) {
    final Set<PluginCategoryType> presentCategories = {};
    for (final p in allPedals) {
      final cat = PluginCategoryHelper.getCategoryForPlugin(p);
      if (cat.type != PluginCategoryType.lineBreak && cat.type != PluginCategoryType.spacer) {
        presentCategories.add(cat.type);
      }
    }

    if (presentCategories.isEmpty) return const SizedBox.shrink();

    final isAllSelected = _selectedCategoryFilters.isEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      height: 26,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // ALL chip
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryFilters.clear();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isAllSelected
                    ? (widget.isDarkMode
                        ? const Color(0xFF00FFCC).withValues(alpha: 0.2)
                        : const Color(0xFF00B3FF).withValues(alpha: 0.2))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isAllSelected
                      ? (widget.isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF))
                      : (widget.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!),
                  width: isAllSelected ? 1.2 : 0.8,
                ),
              ),
              child: Center(
                child: Text(
                  'ALL',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: isAllSelected
                        ? (widget.isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF))
                        : (widget.isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                  ),
                ),
              ),
            ),
          ),

          // Individual category chips
          ...presentCategories.map((catType) {
            final catInfo = PluginCategoryHelper.categories[catType]!;
            final isSelected = _selectedCategoryFilters.contains(catType);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedCategoryFilters.remove(catType);
                  } else {
                    _selectedCategoryFilters.add(catType);
                  }
                });
              },
              onLongPress: () {
                setState(() {
                  _selectedCategoryFilters.clear();
                  _selectedCategoryFilters.add(catType);
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? catInfo.defaultColor.withValues(alpha: 0.25)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isSelected
                        ? catInfo.defaultColor
                        : (widget.isDarkMode ? Colors.grey[800]! : Colors.grey[400]!),
                    width: isSelected ? 1.2 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      catInfo.icon,
                      size: 11,
                      color: isSelected
                          ? catInfo.defaultColor
                          : (widget.isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      catInfo.shortCode,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? (widget.isDarkMode ? Colors.white : Colors.black87)
                            : (widget.isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Help / Legend Button
          GestureDetector(
            onTap: () => _showCategoryHelpDialog(),
            child: Container(
              margin: const EdgeInsets.only(left: 2, right: 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isDarkMode ? Colors.grey[900] : Colors.grey[200],
                border: Border.all(
                  color: widget.isDarkMode ? Colors.grey[700]! : Colors.grey[400]!,
                  width: 0.8,
                ),
              ),
              child: Icon(
                Icons.help_outline_rounded,
                size: 11,
                color: widget.isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInactivePoolHeader(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 15,
            color: count == 0
                ? Colors.grey
                : (widget.isDarkMode ? const Color(0xFFFF007F) : const Color(0xFFFF0055)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'AVAILABLE POOL (INACTIVE)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                      color: widget.isDarkMode ? Colors.grey : Colors.grey[700],
                      letterSpacing: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: (widget.isDarkMode ? const Color(0xFFFF007F) : const Color(0xFFFF0055))
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: widget.isDarkMode ? const Color(0xFFFF007F) : const Color(0xFFFF0055),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 3-way Segmented Expansion Pills: MIN / MID / MAX
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? Colors.grey[900] : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildExpansionPill('MIN', InactivePoolExpansion.minimal),
                _buildExpansionPill('MID', InactivePoolExpansion.partial),
                _buildExpansionPill('MAX', InactivePoolExpansion.full),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpansionPill(String label, InactivePoolExpansion mode) {
    final bool isSelected = _inactivePoolExpansion == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _inactivePoolExpansion = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (widget.isDarkMode ? const Color(0xFFFF007F).withValues(alpha: 0.25) : const Color(0xFFFF0055).withValues(alpha: 0.25))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (widget.isDarkMode ? const Color(0xFFFF007F) : const Color(0xFFFF0055))
                : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
            color: isSelected
                ? (widget.isDarkMode ? const Color(0xFFFF007F) : const Color(0xFFFF0055))
                : (widget.isDarkMode ? Colors.grey[500] : Colors.grey[600]),
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniPuzzleTile({
    required PluginInstance pedal,
    required bool isActive,
    required double cWidth,
    required double rWidth,
    required double eWidth,
  }) {
    final String instanceId = pedal.instance;
    final bool isSpacer = instanceId.startsWith('__spacer_');
    final bool isLineBreak = instanceId.startsWith('__linebreak_');

    final category = PluginCategoryHelper.getCategoryForPlugin(pedal);
    final size = widget.pedalSizes[instanceId] ?? (category.type == PluginCategoryType.looper ? 'expanded' : 'regular');

    // Handle Slim "Chain Divider" Line Breaks
    if (isLineBreak) {
      final lineBreakWidget = Container(
        width: eWidth,
        height: 18.0,
        alignment: Alignment.center,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFF00FFCC).withValues(alpha: widget.isDarkMode ? 0.6 : 0.8),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF00FFCC).withValues(alpha: widget.isDarkMode ? 0.12 : 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF00FFCC).withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wrap_text, size: 9, color: Color(0xFF00FFCC)),
                  const SizedBox(width: 3),
                  const Text(
                    'ROW BREAK',
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF00FFCC),
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => widget.onDeleteLineBreak(instanceId),
                      child: const Icon(
                        Icons.close,
                        size: 9,
                        color: Color(0xFFFF0055),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Container(
                height: 1.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00FFCC).withValues(alpha: widget.isDarkMode ? 0.6 : 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      return KeyedSubtree(
        key: _getTileKey(instanceId),
        child: DragTarget<String>(
          onWillAccept: (data) => data != instanceId,
          onMove: (details) {
            final draggedId = details.data;
            if (draggedId == instanceId) return;

            final idxA = widget.orderedPluginInstances.indexOf(draggedId);
            final idxB = widget.orderedPluginInstances.indexOf(instanceId);
            if (idxA != -1 && idxB != -1 && idxA != idxB) {
              setState(() {
                final item = widget.orderedPluginInstances.removeAt(idxA);
                widget.orderedPluginInstances.insert(idxB, item);
                if (isActive) {
                  if (!widget.enabledPluginInstances.contains(draggedId)) {
                    widget.enabledPluginInstances.add(draggedId);
                  }
                  final activeA = widget.enabledPluginInstances.indexOf(draggedId);
                  final activeB = widget.enabledPluginInstances.indexOf(instanceId);
                  if (activeA != -1 && activeB != -1 && activeA != activeB) {
                    final aItem = widget.enabledPluginInstances.removeAt(activeA);
                    widget.enabledPluginInstances.insert(activeB, aItem);
                  }
                }
              });
              widget.onLayoutSettingsChanged();
            }
          },
          onAccept: (draggedId) {
            widget.onLayoutSettingsChanged();
          },
          builder: (context, _, __) {
            return Draggable<String>(
              data: instanceId,
              feedback: Material(
                color: Colors.transparent,
                child: Opacity(
                  opacity: 0.9,
                  child: lineBreakWidget,
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: lineBreakWidget,
              ),
              child: lineBreakWidget,
            );
          },
        ),
      );
    }

    final String colorHex = isSpacer
        ? ''
        : (widget.pedalGlowColors[instanceId] ??
            getLeastUsedColor(widget.pedalGlowColors));
    final Color glowColor = isSpacer
        ? (widget.isDarkMode ? Colors.grey[700]! : Colors.grey[400]!)
        : hexToColor(colorHex);

    final IconData typeIcon = category.icon;

    // INACTIVE POOL: Full-width row tile for maximum legibility and ease of browsing
    if (!isActive) {
      final inactiveContent = Container(
        width: eWidth,
        height: 38.0,
        margin: const EdgeInsets.symmetric(vertical: 2.5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.isDarkMode
              ? glowColor.withValues(alpha: 0.08)
              : glowColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: glowColor.withValues(alpha: widget.isDarkMode ? 0.45 : 0.6),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            // Category Icon with glow circle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: glowColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(typeIcon, size: 13, color: glowColor),
            ),
            const SizedBox(width: 8),

            // Title (Full, untruncated)
            Expanded(
              child: Text(
                (widget.customTitles[instanceId] ?? pedal.title).toUpperCase(),
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 10.0,
                  letterSpacing: 0.5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Category Badge
            GestureDetector(
              onTap: () => _showCategoryHelpDialog(initialCategory: category.type),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 2),
                decoration: BoxDecoration(
                  color: category.defaultColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: category.defaultColor.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  category.shortCode,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: category.defaultColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Quick Add button
            GestureDetector(
              onTap: () {
                setState(() {
                  widget.enabledPluginInstances.add(instanceId);
                  widget.orderedPluginInstances.remove(instanceId);
                  widget.orderedPluginInstances.add(instanceId);
                });
                widget.onLayoutSettingsChanged();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF00FFCC).withValues(alpha: 0.6),
                    width: 1.0,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 10, color: Color(0xFF00FFCC)),
                    SizedBox(width: 2),
                    Text(
                      'ADD',
                      style: TextStyle(
                        fontSize: 8.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00FFCC),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      return KeyedSubtree(
        key: _getTileKey(instanceId),
        child: Draggable<String>(
          data: instanceId,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.9,
              child: SizedBox(
                width: eWidth,
                child: inactiveContent,
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: inactiveContent,
          ),
          child: inactiveContent,
        ),
      );
    }

    // ACTIVE TILE
    double width = rWidth;
    double height = 46.0;
    if (isSpacer) {
      if (size == 'compact') {
        width = cWidth;
        height = 40.0;
      } else if (size == 'regular') {
        width = rWidth;
        height = 48.0;
      } else {
        width = eWidth;
        height = 56.0;
      }
    } else if (category.type == PluginCategoryType.looper) {
      if (size == 'regular') {
        width = rWidth;
        height = 48.0;
      } else {
        width = eWidth;
        height = 56.0;
      }
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

    final tileContent = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isSpacer
            ? Colors.transparent
            : glowColor.withOpacity(widget.isDarkMode ? 0.12 : 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (widget.highlightedInstanceId == instanceId)
              ? Colors.white
              : (isSpacer
                  ? (widget.isDarkMode ? Colors.grey[600]! : Colors.grey[400]!)
                  : glowColor.withOpacity(0.9)),
          width: (widget.highlightedInstanceId == instanceId) ? 2.5 : 1.5,
          style: BorderStyle.solid,
        ),
        boxShadow: (widget.highlightedInstanceId == instanceId)
            ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.9),
                  blurRadius: 16,
                  spreadRadius: 3,
                ),
              ]
            : (!isSpacer
                ? [
                    BoxShadow(
                      color: glowColor.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null),
      ),
      child: Row(
        children: [
          // Size Toggle C/R/E (Top Left, before title)
          if (!isSpacer) ...[
            GestureDetector(
              onTap: () => widget.onCyclePedalSize(instanceId),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? Colors.grey[900]
                      : Colors.grey[300],
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

          // Device Type Icon (tap to see category guide)
          GestureDetector(
            onTap: isSpacer ? null : () => _showCategoryHelpDialog(initialCategory: category.type),
            child: Icon(
              typeIcon,
              size: (size == 'compact' ? 11 : 13),
              color: isSpacer
                  ? (widget.isDarkMode ? Colors.grey[500] : Colors.grey[600])
                  : (category.type == PluginCategoryType.looper ? const Color(0xFFFF0055) : glowColor),
            ),
          ),
          const SizedBox(width: 4),

          // Title
          Expanded(
            child: Text(
              isSpacer
                  ? 'SPACER'
                  : (widget.customTitles[instanceId] ?? pedal.title).toUpperCase(),
              style: TextStyle(
                color: isSpacer
                    ? (widget.isDarkMode ? Colors.grey[400] : Colors.grey[600])
                    : (widget.isDarkMode ? Colors.white : Colors.black),
                fontWeight: FontWeight.bold,
                fontSize: (size == 'compact' ? 8 : 9.5),
                letterSpacing: 0.5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Category Micro-Badge Pill (tap to view effect guide)
          if (!isSpacer && size != 'compact') ...[
            GestureDetector(
              onTap: () => _showCategoryHelpDialog(initialCategory: category.type),
              child: Container(
                margin: const EdgeInsets.only(left: 3, right: 2),
                padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: category.defaultColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: category.defaultColor.withValues(alpha: 0.5),
                    width: 0.6,
                  ),
                ),
                child: Text(
                  category.shortCode,
                  style: TextStyle(
                    fontSize: 7.0,
                    fontWeight: FontWeight.w900,
                    color: category.defaultColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],

          // Right panel options (Delete for Spacer)
          if (isSpacer) ...[
            GestureDetector(
              onTap: () => widget.onDeleteSpacer(instanceId),
              child: Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF0055),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 8,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    // Draggable wrapping with live interactive reordering while moving
    return KeyedSubtree(
      key: _getTileKey(instanceId),
      child: DragTarget<String>(
      onWillAccept: (data) => data != instanceId,
      onMove: (details) {
        final draggedId = details.data;
        if (draggedId == instanceId) return;

        final idxA = widget.orderedPluginInstances.indexOf(draggedId);
        final idxB = widget.orderedPluginInstances.indexOf(instanceId);
        if (idxA != -1 && idxB != -1 && idxA != idxB) {
          setState(() {
            final item = widget.orderedPluginInstances.removeAt(idxA);
            widget.orderedPluginInstances.insert(idxB, item);

            if (isActive) {
              // Hovering over active grid: activate immediately so space opens up and preview is live
              if (!widget.enabledPluginInstances.contains(draggedId)) {
                widget.enabledPluginInstances.add(draggedId);
              }
              final activeA = widget.enabledPluginInstances.indexOf(draggedId);
              final activeB = widget.enabledPluginInstances.indexOf(instanceId);
              if (activeA != -1 && activeB != -1 && activeA != activeB) {
                final aItem = widget.enabledPluginInstances.removeAt(activeA);
                widget.enabledPluginInstances.insert(activeB, aItem);
              }
            } else {
              // Hovering over inactive pool: deactivate so it returns to pool
              if (widget.enabledPluginInstances.contains(draggedId)) {
                widget.enabledPluginInstances.remove(draggedId);
              }
            }
          });
        }
      },
      onAccept: (draggedId) {
        setState(() {
          // Reorder list order
          final idxA = widget.orderedPluginInstances.indexOf(draggedId);
          final idxB = widget.orderedPluginInstances.indexOf(instanceId);
          if (idxA != -1 && idxB != -1 && idxA != idxB) {
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
          delay: const Duration(milliseconds: 150),
          onDragEnd: (_) => widget.onLayoutSettingsChanged(),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.75,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: isLineBreak
                      ? const Color(0xFF00FFCC).withValues(alpha: 0.25)
                      : glowColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLineBreak ? const Color(0xFF00FFCC) : glowColor,
                    width: 2.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    isLineBreak
                        ? 'LINE BREAK'
                        : isSpacer
                            ? 'SPACER'
                            : (widget.customTitles[instanceId] ?? pedal.title)
                                .toUpperCase(),
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
              if (!isSpacer && !isLineBreak) {
                widget.onHighlightPedal(pedal);
              }
              if (isActive) {
                widget.onScrollToCard(instanceId);
              }
            },
            onDoubleTap: () {
              if (isActive) {
                if (!isLineBreak) {
                  widget.onCyclePedalSize(instanceId);
                }
              } else {
                if (!isSpacer && !isLineBreak) {
                  widget.onShowColorPicker(pedal);
                }
              }
            },
            child: tileContent,
          ),
        );
      },
    ),
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
                if (id.startsWith('__spacer_')) {
                  activePedals.add(PluginInstance(
                    instance: id,
                    title: 'SPACER',
                    uri: 'spacer',
                  ));
                  continue;
                }
                if (id.startsWith('__linebreak_')) {
                  activePedals.add(PluginInstance(
                    instance: id,
                    title: 'LINE BREAK',
                    uri: 'linebreak',
                  ));
                  continue;
                }
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
                if (id.startsWith('__spacer_')) {
                  inactivePedals.add(PluginInstance(
                    instance: id,
                    title: 'SPACER',
                    uri: 'spacer',
                  ));
                  continue;
                }
                if (id.startsWith('__linebreak_')) {
                  inactivePedals.add(PluginInstance(
                    instance: id,
                    title: 'LINE BREAK',
                    uri: 'linebreak',
                  ));
                  continue;
                }
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

            final int activeFlex = _inactivePoolExpansion == InactivePoolExpansion.minimal
                ? 1
                : (_inactivePoolExpansion == InactivePoolExpansion.partial ? 5 : 2);
            final int inactiveFlex = _inactivePoolExpansion == InactivePoolExpansion.minimal
                ? 0
                : (_inactivePoolExpansion == InactivePoolExpansion.partial ? 4 : 7);

            return Column(
              children: [
                // CONFIGURATIONS SECTION
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_suggest,
                        size: 15,
                        color: widget.isDarkMode
                            ? const Color(0xFF00FFCC)
                            : const Color(0xFF00B3FF),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'LAYOUT CONFIGURATION',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                            color: widget.isDarkMode
                                ? Colors.grey
                                : Colors.grey[700],
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  child: Row(
                    children: [
                      // Active Config Name Dropdown/Popup Button
                      Expanded(
                        child: PopupMenuButton<String>(
                          initialValue: widget.currentConfig,
                          tooltip: 'Switch configuration',
                          onSelected: widget.onConfigChanged,
                          itemBuilder: (BuildContext context) {
                            return widget.configsList.map((String config) {
                              final bool isCurrent = config == widget.currentConfig;
                              return PopupMenuItem<String>(
                                value: config,
                                child: Row(
                                  children: [
                                    Icon(
                                      isCurrent ? Icons.radio_button_checked : Icons.radio_button_off,
                                      size: 14,
                                      color: isCurrent
                                          ? (widget.isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF))
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      config.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                        color: widget.isDarkMode ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.layers_outlined,
                                  size: 16,
                                  color: widget.isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.currentConfig.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: widget.isDarkMode ? Colors.white : Colors.black,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: widget.isDarkMode ? Colors.grey : Colors.grey[700],
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Duplicate
                      IconButton(
                        icon: const Icon(Icons.copy_all_rounded, size: 18),
                        color: widget.isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF),
                        tooltip: 'Duplicate current configuration',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.onConfigDuplicate,
                      ),
                      const SizedBox(width: 8),

                      // Rename
                      IconButton(
                        icon: const Icon(Icons.drive_file_rename_outline_rounded, size: 18),
                        color: widget.currentConfig == 'default'
                            ? Colors.grey
                            : (widget.isDarkMode ? const Color(0xFF00FFCC) : const Color(0xFF00B3FF)),
                        tooltip: widget.currentConfig == 'default'
                            ? 'Cannot rename default'
                            : 'Rename current configuration',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.currentConfig == 'default' ? null : widget.onConfigRename,
                      ),
                      const SizedBox(width: 8),

                      // Delete
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                        color: widget.currentConfig == 'default'
                            ? Colors.grey
                            : const Color(0xFFFF007F),
                        tooltip: widget.currentConfig == 'default'
                            ? 'Cannot delete default'
                            : 'Delete current configuration',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.currentConfig == 'default' ? null : widget.onConfigDelete,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Backup & Restore Action Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onBackupRestore,
                          icon: const Icon(Icons.settings_backup_restore_rounded, size: 14),
                          label: const Text(
                            'BACKUP & RESTORE CONFIGURATIONS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: widget.isDarkMode
                                ? const Color(0xFF00FFCC)
                                : const Color(0xFF00B3FF),
                            side: BorderSide(
                              color: (widget.isDarkMode
                                      ? const Color(0xFF00FFCC)
                                      : const Color(0xFF00B3FF))
                                  .withOpacity(0.5),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

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
                      Expanded(
                        child: Text(
                          'PUZZLE CANVAS (ACTIVE)',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                            color: widget.isDarkMode
                                ? Colors.grey
                                : Colors.grey[700],
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: widget.onAddSpacer,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (widget.isDarkMode
                                    ? const Color(0xFF00FFCC)
                                    : const Color(0xFF00B3FF))
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: widget.isDarkMode
                                  ? const Color(0xFF00FFCC)
                                  : const Color(0xFF00B3FF),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                size: 10,
                                color: widget.isDarkMode
                                    ? const Color(0xFF00FFCC)
                                    : const Color(0xFF00B3FF),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'SPACER',
                                style: TextStyle(
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isDarkMode
                                      ? const Color(0xFF00FFCC)
                                      : const Color(0xFF00B3FF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: widget.onAddLineBreak,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (widget.isDarkMode
                                    ? const Color(0xFF00FFCC)
                                    : const Color(0xFF00B3FF))
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: widget.isDarkMode
                                  ? const Color(0xFF00FFCC)
                                  : const Color(0xFF00B3FF),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                size: 10,
                                color: widget.isDarkMode
                                    ? const Color(0xFF00FFCC)
                                    : const Color(0xFF00B3FF),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'LINE BREAK',
                                style: TextStyle(
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.bold,
                                  color: widget.isDarkMode
                                      ? const Color(0xFF00FFCC)
                                      : const Color(0xFF00B3FF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Category Filter Bar (Icons & Category Chips)
                _buildCategoryFilterBar(allPlugins),

                Expanded(
                  flex: activeFlex,
                  child: DragTarget<String>(
                    onMove: (details) {
                      final draggedId = details.data;
                      if (!widget.enabledPluginInstances.contains(draggedId)) {
                        setState(() {
                          widget.enabledPluginInstances.add(draggedId);
                          widget.orderedPluginInstances.remove(draggedId);
                          widget.orderedPluginInstances.add(draggedId);
                        });
                      }
                    },
                    onAccept: (draggedId) {
                      final bool wasAlreadyActive =
                          widget.enabledPluginInstances.contains(draggedId);
                      if (wasAlreadyActive) {
                        // Already active and released in place: preserve exact current position
                        widget.onLayoutSettingsChanged();
                        return;
                      }

                      // Dragged from Inactive pool: activate and append to end of active list
                      setState(() {
                        widget.enabledPluginInstances.add(draggedId);

                        // Move to end of active list in widget.orderedPluginInstances
                        final List<String> actives = widget
                            .orderedPluginInstances
                            .where(
                              (id) =>
                                  widget.enabledPluginInstances.contains(id) &&
                                  id != draggedId,
                            )
                            .toList();

                        widget.orderedPluginInstances.remove(draggedId);
                        if (actives.isNotEmpty) {
                          final lastActiveId = actives.last;
                          final targetIdx = widget.orderedPluginInstances
                              .indexOf(lastActiveId);
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
                      final List<PluginInstance> displayedActivePedals = _selectedCategoryFilters.isEmpty
                          ? activePedals
                          : activePedals.where((pedal) {
                              final cat = PluginCategoryHelper.getCategoryForPlugin(pedal);
                              if (cat.type == PluginCategoryType.lineBreak || cat.type == PluginCategoryType.spacer) {
                                return true;
                              }
                              return _selectedCategoryFilters.contains(cat.type);
                            }).toList();

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
                        child: displayedActivePedals.isEmpty
                            ? Center(
                                child: Text(
                                  activePedals.isEmpty
                                      ? 'Drag cards here or toggle below to activate.'
                                      : 'No pedals match selected category filter.',
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
                                  children: displayedActivePedals.map((pedal) {
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

                // INACTIVE / AVAILABLE POOL (Header with MIN / MID / MAX Toggle)
                _buildInactivePoolHeader(inactivePedals.length),

                if (_inactivePoolExpansion != InactivePoolExpansion.minimal)
                  Expanded(
                    flex: inactiveFlex,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode
                            ? const Color(0xFF0B0E14).withOpacity(0.6)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (widget.isDarkMode
                              ? Colors.grey[900]
                              : Colors.grey[300])!,
                          width: 1.5,
                        ),
                      ),
                      child: inactivePedals.isEmpty
                          ? Center(
                              child: Text(
                                'All pedals are currently active on dashboard',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.isDarkMode
                                      ? Colors.grey[600]
                                      : Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: (_selectedCategoryFilters.isEmpty
                                      ? inactivePedals
                                      : inactivePedals.where((pedal) {
                                          final cat = PluginCategoryHelper.getCategoryForPlugin(pedal);
                                          if (cat.type == PluginCategoryType.lineBreak || cat.type == PluginCategoryType.spacer) {
                                            return true;
                                          }
                                          return _selectedCategoryFilters.contains(cat.type);
                                        }).toList())
                                  .map((pedal) {
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
                  color:
                      (widget.isDarkMode
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
          Expanded(child: _buildDrawerContent()),
        ],
      ),
    );
  }
}
