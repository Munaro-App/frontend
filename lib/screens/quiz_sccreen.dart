import 'package:flutter/material.dart';
import 'dart:ui';

// 1. 목업 데이터
final List<Map<String, dynamic>> mockCompletedQuizzes = [
  {
    "id": 1,
    "location": "경복궁",
    "date": "2026.05.14",
    "isCorrect": true,
    "type": "quiz",
    "color": const Color(0xFF9ED4D4),
    "question": "경복궁은 조선시대 몇 번째 궁궐인가요?",
    "answer": "첫 번째",
    "userAnswer": "첫 번째"
  },
  {
    "id": 2,
    "location": "북촌 한옥마을",
    "date": "2026.05.13",
    "isCorrect": true,
    "type": "quiz",
    "color": const Color(0xFFA8D5E2),
    "question": "북촌 한옥마을은 어느 지역에 위치해 있나요?",
    "answer": "종로구",
    "userAnswer": "종로구"
  },
  {
    "id": 3,
    "location": "카페 서울",
    "date": "2026.05.12",
    "isCorrect": true,
    "type": "receipt",
    "color": const Color(0xFFE8D5C4),
    "receiptUrl": "receipt.jpg"
  },
  {
    "id": 4,
    "location": "인사동",
    "date": "2026.05.10",
    "isCorrect": false,
    "type": "quiz",
    "color": const Color(0xFFB8D4C8),
    "question": "인사동에서 유명한 전통 먹거리는?",
    "answer": "호떡",
    "userAnswer": "떡볶이"
  },
];

class QuizHistoryScreen extends StatefulWidget {
  const QuizHistoryScreen({Key? key}) : super(key: key);

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> {
  Map<String, dynamic>? selectedQuiz;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('퀴즈 기록', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mockCompletedQuizzes.length,
            itemBuilder: (context, index) {
              final quiz = mockCompletedQuizzes[index];
              return _buildQuizListItem(quiz);
            },
          ),
          if (selectedQuiz != null) _buildDetailModal(selectedQuiz!),
        ],
      ),
    );
  }

  Widget _buildQuizListItem(Map<String, dynamic> quiz) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ListTile(
        onTap: () => setState(() => selectedQuiz = quiz),
        title: Text(quiz['location'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(quiz['date']),
        trailing: Icon(
          quiz['isCorrect'] ? Icons.check_circle : Icons.cancel,
          color: quiz['isCorrect'] ? Colors.green : Colors.redAccent,
        ),
      ),
    );
  }

  Widget _buildDetailModal(Map<String, dynamic> quiz) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(quiz['location'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => setState(() => selectedQuiz = null), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              if (quiz['type'] == 'quiz') ...[
                Text(quiz['question'], style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Text('내 답변: ${quiz['userAnswer']}', style: TextStyle(color: quiz['isCorrect'] ? Colors.black : Colors.red)),
                Text('정답: ${quiz['answer']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ] else
                const Text('영수증 인증 완료'),
            ],
          ),
        ),
      ),
    );
  }
}