import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';

/// A small badge indicating the confidence level of a match or suggestion.
///
/// Displays a colored dot and text label (e.g. "High", "Medium", "?").
class ConfidenceBadge extends StatelessWidget {
  /// Confidence value from 0.0 to 1.0. Used if [level] is not provided.
  final double? confidence;

  /// Explicit level string ('high', 'medium', 'low', 'unidentified').
  final String? level;

  const ConfidenceBadge({
    super.key,
    this.confidence,
    this.level,
  });

  String get _computedLevel {
    if (level != null && level!.isNotEmpty) return level!.toLowerCase();
    if (confidence != null) {
      if (confidence! >= 0.8) return 'high';
      if (confidence! >= 0.5) return 'medium';
      return 'low';
    }
    return 'unidentified';
  }

  Color get _color {
    switch (_computedLevel) {
      case 'high':
        return AppColors.confidenceHigh;
      case 'medium':
        return AppColors.confidenceMedium;
      case 'low':
        return AppColors.confidenceLow;
      case 'unidentified':
      default:
        return AppColors.textHint;
    }
  }

  String get _label {
    switch (_computedLevel) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      case 'unidentified':
      default:
        return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_computedLevel == 'unprocessed') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withAlpha(100), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
