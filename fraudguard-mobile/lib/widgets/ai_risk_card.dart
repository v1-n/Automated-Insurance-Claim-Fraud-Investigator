import 'package:flutter/material.dart';
import '../models/claim_model.dart';
import '../theme/app_theme.dart';

class AiRiskCard extends StatelessWidget {
  final ClaimModel claim;
  final VoidCallback? onRerun;
  final bool isRerunning;

  const AiRiskCard({
    super.key,
    required this.claim,
    this.onRerun,
    this.isRerunning = false,
  });

  Color _getSeverityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'HIGH':
        return AppTheme.dangerRed;
      case 'MEDIUM':
        return const Color(0xFFF59E0B);
      case 'LOW':
      default:
        return AppTheme.primaryBlue;
    }
  }

  Color _getRecommendationColor(String? recommendation) {
    switch (recommendation?.toUpperCase()) {
      case 'INVESTIGATE':
        return AppTheme.dangerRed;
      case 'REVIEW':
        return const Color(0xFFF59E0B);
      case 'FAST_TRACK':
        return AppTheme.successGreen;
      default:
        return const Color(0xFF64748B);
    }
  }

  String _cleanCode(String code) {
    return code.replaceAll('_', ' ').toLowerCase().split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey[200]!;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final labelColor = isDark ? Colors.grey[400]! : const Color(0xFF64748B);

    final aiStatus = claim.aiStatus?.toUpperCase() ??
        (claim.fraudScore > 0 || (claim.aiAnalysis?.riskScore != null) ? 'DONE' : 'PENDING');

    if (aiStatus == 'PENDING' || aiStatus == 'RUNNING') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primaryBlue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Analysis In Progress...',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Automated forensic verification running on submitted photos and claim data.',
                        style: TextStyle(color: labelColor, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (aiStatus == 'FAILED') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.dangerRed.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dangerRed.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Analysis Unavailable',
                        style: TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Automated analysis encountered an issue or timed out. Please conduct a standard manual review.',
                        style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (onRerun != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: isRerunning ? null : onRerun,
                  icon: isRerunning
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Re-run AI Analysis'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dangerRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // ── aiStatus == 'DONE' ──
    final score = claim.fraudScore;
    final riskColor = AppTheme.getRiskColor(score);
    final riskLevel = claim.aiRiskLevel ?? (score >= 60 ? 'HIGH' : score >= 25 ? 'MEDIUM' : 'LOW');
    final recommendation = claim.aiRecommendation ??
        (score >= 60 ? 'INVESTIGATE' : score >= 25 ? 'REVIEW' : 'FAST_TRACK');
    final recColor = _getRecommendationColor(recommendation);

    final summaryText = claim.aiSummary ??
        claim.aiAnalysis?.summary ??
        (score >= 70
            ? 'High probability of fraud matching standard patterns.'
            : score >= 40
                ? 'Moderate level of concerns. Manual inspection needed.'
                : 'Lower probability of fraud. Standard verification.');

    final flags = claim.aiAnalysis?.flags ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Gauge & Summary ──
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 90,
                    width: 90,
                    child: CircularProgressIndicator(
                      value: score / 100.0,
                      strokeWidth: 8,
                      backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey[200],
                      color: riskColor,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${score.toInt()}%',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      Text(
                        'RISK',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: labelColor),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AI Fraud Analysis',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const Spacer(),
                        if (onRerun != null)
                          IconButton(
                            icon: isRerunning
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.refresh_rounded, size: 18),
                            onPressed: isRerunning ? null : onRerun,
                            tooltip: 'Re-run analysis',
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: riskColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: riskColor.withAlpha(90)),
                          ),
                          child: Text(
                            '$riskLevel RISK',
                            style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: recColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: recColor.withAlpha(90)),
                          ),
                          child: Text(
                            recommendation.replaceAll('_', ' '),
                            style: TextStyle(color: recColor, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summaryText,
                      style: TextStyle(color: labelColor, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // ── Advisory Note ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: labelColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI is advisory. The decision is yours.',
                    style: TextStyle(color: labelColor, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),

          // ── Evidence Flags Section ──
          const SizedBox(height: 16),
          Text(
            flags.isEmpty ? 'Flagged Evidence: None' : 'Why was this flagged? (${flags.length})',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),

          if (flags.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.successGreen.withAlpha(50)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No anomalous risk flags raised during photo forensics and sanity checks.',
                      style: TextStyle(color: AppTheme.successGreen, fontSize: 11),
                    ),
                  ),
                ],
              ),
            )
          else
            ...flags.map((flag) {
              final sevColor = _getSeverityColor(flag.severity);
              final hasDetails = flag.benignExplanations.isNotEmpty || flag.nextSteps.isNotEmpty;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withAlpha(120) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sevColor.withAlpha(80)),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: sevColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        flag.severity,
                        style: TextStyle(color: sevColor, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    title: Text(
                      _cleanCode(flag.code),
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        flag.explanation,
                        style: TextStyle(color: labelColor, fontSize: 11, height: 1.3),
                      ),
                    ),
                    children: hasDetails
                        ? [
                            if (flag.benignExplanations.isNotEmpty) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Possible innocent explanations:',
                                  style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...flag.benignExplanations.map(
                                (exp) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2, left: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('• ', style: TextStyle(color: labelColor, fontSize: 11)),
                                      Expanded(
                                        child: Text(
                                          exp,
                                          style: TextStyle(color: labelColor, fontSize: 11, height: 1.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (flag.nextSteps.isNotEmpty) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Suggested next steps:',
                                  style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...flag.nextSteps.map(
                                (step) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2, left: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('→ ', style: TextStyle(color: AppTheme.primaryBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                                      Expanded(
                                        child: Text(
                                          step,
                                          style: TextStyle(color: labelColor, fontSize: 11, height: 1.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ]
                        : [],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
