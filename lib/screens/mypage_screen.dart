import 'package:flutter/material.dart';

// 1. 목업 데이터
final Map<String, dynamic> mockUserData = {
  "name": "김여행",
  "email": "travel@example.com",
  "avatar": "👤",
  "totalStamps": 89,
  "highestRank": 3,
};

final List<Map<String, dynamic>> mockVisitedRegions = [
  {"id": 1, "name": "종로구", "stamps": 23, "emoji": "🏛️", "color": const Color(0xFF9ED4D4)},
  {"id": 2, "name": "강남구", "stamps": 18, "emoji": "🏙️", "color": const Color(0xFFA8D5E2)},
  {"id": 3, "name": "마포구", "stamps": 15, "emoji": "🌉", "color": const Color(0xFFE8D5C4)},
  {"id": 4, "name": "용산구", "stamps": 12, "emoji": "🗼", "color": const Color(0xFFB8D4C8)},
  {"id": 5, "name": "성동구", "stamps": 9, "emoji": "🌳", "color": const Color(0xFF9FD5D1)},
];

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({Key? key}) : super(key: key);

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool showAllRegions = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE0F2F1), Color(0xFFE1F5FE)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildProfileCard(),
                      const SizedBox(height: 16),
                      _buildTravelHistory(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 헤더
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('마이페이지', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          IconButton(
            onPressed: () => print("로그아웃"),
            icon: const Icon(Icons.logout, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  // 프로필 카드
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 30, child: Text('👤', style: TextStyle(fontSize: 30))),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mockUserData['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(mockUserData['email'], style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('스탬프', '${mockUserData['totalStamps']}'),
              _buildStatItem('최고 순위', '${mockUserData['highestRank']}위'),
              _buildStatItem('방문 지역', '${mockVisitedRegions.length}곳'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // 여행 기록 리스트
  Widget _buildTravelHistory() {
    final regions = showAllRegions ? mockVisitedRegions : mockVisitedRegions.take(4).toList();
    
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: regions.length,
          itemBuilder: (context, index) {
            final region = regions[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Text(region['emoji'], style: const TextStyle(fontSize: 24)),
                title: Text(region['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text('${region['stamps']}개', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            );
          },
        ),
        TextButton(
          onPressed: () => setState(() => showAllRegions = !showAllRegions),
          child: Text(showAllRegions ? "접기" : "더보기"),
        ),
      ],
    );
  }
}