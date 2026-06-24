import 'package:flutter/material.dart';

import '../models/activity_history.dart';
import '../models/ranking.dart';

class ActivityDetailScreen extends StatelessWidget {
  final ActivityHistoryDetail detail;

  const ActivityDetailScreen({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: const Color(0xFF1A1D23),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '활동 상세',
          style: TextStyle(
            color: Color(0xFF1A1D23),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  historyIconFor(detail.spotName),
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.spotName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1D23),
                      ),
                    ),
                    if (detail.category != null)
                      Text(
                        detail.category!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '+${formatRankingScore(detail.points)}pt',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF10B981),
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (detail.quizCompleted)
                _MissionChip(
                  label: '퀴즈 ✓',
                  color: const Color(0xFF4F8EFF),
                  background: const Color(0xFFEEF2FF),
                ),
              if (detail.photoCompleted)
                _MissionChip(
                  label: '사진 ✓',
                  color: const Color(0xFFFF6B35),
                  background: const Color(0xFFFFF7ED),
                ),
            ],
          ),
          if (detail.correctCount != null && detail.totalCount != null) ...[
            const SizedBox(height: 16),
            Text(
              '정답 ${detail.correctCount}/${detail.totalCount}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ],
          if (detail.completedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              '완료일 ${detail.shortDate}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
          if (detail.address != null) ...[
            const SizedBox(height: 16),
            _InfoBox(title: '주소', value: detail.address!),
          ],
          if (detail.description != null) ...[
            const SizedBox(height: 12),
            _InfoBox(title: '설명', value: detail.description!),
          ],
        ],
      ),
    );
  }
}

class _MissionChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _MissionChip({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String value;

  const _InfoBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1D23),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
