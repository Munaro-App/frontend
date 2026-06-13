import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Mock 데이터
  final List<Map<String, dynamic>> mockLocations = [
    {
      "id": 1, "name": "경복궁", "type": "landmark", "color": const Color(0xFF9ED4D4),
      "quiz": {"question": "경복궁은 조선시대 몇 번째 궁궐인가요?", "options": ["첫 번째", "두 번째", "세 번째", "네 번째"], "answer": 0}
    },
    { "id": 2, "name": "북촌 한옥마을", "type": "travel", "color": const Color(0xFFA8D5E2),
      "quiz": {"question": "북촌 한옥마을은 어느 지역에 위치해 있나요?", "options": ["강남구", "종로구", "중구", "마포구"], "answer": 1}
    },
    { "id": 3, "name": "카페 서울", "type": "cafe", "color": const Color(0xFFE8D5C4), "needsReceipt": true },
  ];

  Map<String, dynamic>? selectedLocation;
  int? selectedAnswer;
  bool showResult = false;
  bool isCorrect = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map Background (그라데이션 + 그리드)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFFE0F2F1), Color(0xFFE1F5FE)],
              ),
            ),
          ),
          
          // Markers
          ...mockLocations.asMap().entries.map((entry) {
            int index = entry.key;
            var location = entry.value;
            return Positioned(
              top: 200.0 + (index * 100),
              left: 50.0 + (index * 80),
              child: GestureDetector(
                onTap: () => setState(() => selectedLocation = location),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: location['color'], shape: BoxShape.circle, boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black12)]),
                      child: Icon(location['type'] == 'landmark' ? Icons.location_city : Icons.place, color: Colors.white),
                    ),
                    Text(location['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }).toList(),

          // Modal
          if (selectedLocation != null) _buildModal(),
        ],
      ),
    );
  }

  Widget _buildModal() {
    return Container(
      color: Colors.black45,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(selectedLocation!['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              if (selectedLocation!['needsReceipt'] == true)
                ElevatedButton(onPressed: () => setState(() => showResult = true), child: const Text("영수증 인증"))
              else
                ...List.generate(selectedLocation!['quiz']['options'].length, (i) => 
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedAnswer = i;
                        isCorrect = (i == selectedLocation!['quiz']['answer']);
                        showResult = true;
                      });
                    },
                    child: Text(selectedLocation!['quiz']['options'][i]),
                  )
                ),
              if (showResult) Text(isCorrect ? "성공! 🎉" : "실패 ❌"),
              IconButton(onPressed: () => setState(() => selectedLocation = null), icon: const Icon(Icons.close)),
            ],
          ),
        ),
      ),
    );
  }
}