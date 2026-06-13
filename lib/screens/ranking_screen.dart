import 'dart:ui';
import 'package:flutter/material.dart';

// 목업 데이터
final List<Map<String, dynamic>> mockRankings = [
  {"rank": 1, "name": "김여행", "stamps": 245, "region": "종로구", "color": const Color(0xFFFFD700)}, // 금색
  {"rank": 2, "name": "이탐험", "stamps": 198, "region": "강남구", "color": const Color(0xFFC0C0C0)}, // 은색
  {"rank": 3, "name": "박투어", "stamps": 156, "region": "마포구", "color": const Color(0xFFCD7F32)}, // 동색
  {"rank": 4, "name": "최여행", "stamps": 134, "region": "용산구", "color": const Color(0xFFB8D4C8)},
  {"rank": 5, "name": "정탐험", "stamps": 128, "region": "성동구", "color": const Color(0xFF9FD5D1)},
];

class RankingScreen extends StatelessWidget {
  const RankingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // 전체 배경색을 깔끔한 연회색으로
      appBar: AppBar(
        title: const Text('🏆 랭킹', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildTopThreePodium(),
            const SizedBox(height: 30),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
                  itemCount: mockRankings.length - 3,
                  itemBuilder: (context, index) {
                    final user = mockRankings[index + 3];
                    return _buildRankingListItem(user);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopThreePodium() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPodiumItem(mockRankings[1], '🥈', 110), // 2등
          _buildPodiumItem(mockRankings[0], '🥇', 140), // 1등
          _buildPodiumItem(mockRankings[2], '🥉', 90),  // 3등
        ],
      ),
    );
  }

  Widget _buildPodiumItem(Map<String, dynamic> user, String icon, double height) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        CircleAvatar(
          radius: 30,
          backgroundColor: user['color'],
          child: Text('${user['rank']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(height: 8),
        Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: user['color'].withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          child: Text('${user['stamps']}\npts', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildRankingListItem(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Text('${user['rank']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(width: 20),
          CircleAvatar(backgroundColor: Colors.grey[200], child: Text(user['name'][0])),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(user['region'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text('${user['stamps']} pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00796B))),
        ],
      ),
    );
  }
}