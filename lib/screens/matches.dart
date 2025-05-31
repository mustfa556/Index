import 'package:flutter/material.dart';

class MatchesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> channels = [
    {
      'name': 'beIN Sports 1',
      'logo': 'assets/bein_sports1.png',
    },
    {
      'name': 'beIN Sports 2',
      'logo': 'assets/bein_sports2.png',
    },
    {
      'name': 'SSC Sports',
      'logo': 'assets/ssc_sports.png',
    },
    {
      'name': 'AD Sports',
      'logo': 'assets/ad_sports.png',
    },
    // أضف المزيد من القنوات حسب الحاجة
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Matches'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: GridView.builder(
          itemCount: channels.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final channel = channels[index];
            return Card(
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  // هنا يمكن إضافة التنقل أو تشغيل القناة
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      channel['logo'],
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: 12),
                    Text(
                      channel['name'],
                      style: Theme.of(context).textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
