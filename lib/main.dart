import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

void main() {
  runApp(const TelzEgyptApp());
}

class TelzEgyptApp extends StatelessWidget {
  const TelzEgyptApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'أداة إرسال المكالمات',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
      ),
      home: const HomePage(),
    );
  }
}

// نموذج بيانات السجل
class CallLogItem {
  final String phone;
  final String status;
  final String time;
  final bool isSuccess;

  CallLogItem({
    required this.phone,
    required this.status,
    required this.time,
    required this.isSuccess,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _countController = TextEditingController();
  
  bool _isLoading = false;
  final List<CallLogItem> _logs = [];

  // دالة إرسال المكالمة المصرية
  Future<void> _sendCalls() async {
    String rawPhone = _phoneController.text.trim();
    String countStr = _countController.text.trim();

    if (rawPhone.isEmpty || countStr.isEmpty) {
      _showSnackBar('❌ يرجى إدخال الرقم وعدد المرات بنجاح', Colors.red);
      return;
    }

    // تنسيق الرقم المصري من 010 إلى +2010
    String phone = "";
    if (rawPhone.startsWith("0") && rawPhone.length == 11) {
      phone = "+20" + rawPhone.substring(1);
    } else if (rawPhone.startsWith("+20") && rawPhone.length == 13) {
      phone = rawPhone;
    } else {
      _showSnackBar('❌ صيغة رقم غير صحيحة (يجب أن يبدأ بـ 010, 011, 012, 015)', Colors.red);
      return;
    }

    int count = int.tryParse(countStr) ?? 1;
    setState(() {
      _isLoading = true;
    });

    for (int i = 1; i <= count; i++) {
      bool success = await _executeTelzCall(phone);
      String timeNow = TimeOfDay.now().format(context);
      
      setState(() {
        _logs.insert(
          0,
          CallLogItem(
            phone: rawPhone,
            status: success ? '✅ نجاح الإرسال' : '❌ فشل (قيد الكولدوان)',
            time: timeNow,
            isSuccess: success,
          ),
        );
      });

      if (i < count) {
        await Future.delayed(const Duration(seconds: 3));
      }
    }

    setState(() {
      _isLoading = false;
    });
    _showSnackBar('🎉 تم الانتهاء من إرسال الدفعة بنجاح!', Colors.green);
  }

  Future<bool> _executeTelzCall(String phone) async {
    try {
      var rng = Random();
      String androidId = List.generate(16, (_) => rng.nextInt(16).toRadixString(16)).join();
      String uid = "${rng.nextInt(999999)}-${rng.nextInt(999999)}";
      int ts = DateTime.now().millisecondsSinceEpoch;

      Map<String, String> headers = {
        "User-Agent": "Telz-Android/17.5.48",
        "Content-Type": "application/json; charset=UTF-8"
      };

      // 1. المصادقة الأولى
      await http.post(
        Uri.parse("https://api.telz.com/app/auth_list"),
        headers: headers,
        body: jsonEncode({"android_id": androidId, "app_version": "17.5.48", "event": "auth_list", "os": "android", "os_version": "15", "ts": ts, "uuid": uid}),
      );

      // 2. التشغيل
      await http.post(
        Uri.parse("https://api.telz.com/app/run"),
        headers: headers,
        body: jsonEncode({"android_id": androidId, "app_version": "17.5.48", "device_name": "", "event": "run", "ipv4_address": "", "lang": "ar", "network_country": "eg", "network_type": "WIFI", "os": "android", "os_version": "15", "push_token": "", "roaming": "no", "root": "no", "run_id": ts.toString(), "sim_country": "eg", "ts": ts, "uuid": uid}),
      );

      // 3. التحقق من الرقم
      await http.post(
        Uri.parse("https://api.telz.com/app/validate_phonenumber"),
        headers: headers,
        body: jsonEncode({"android_id": androidId, "app_version": "17.5.48", "event": "validate_phonenumber", "os": "android", "os_version": "15", "phone": phone, "region": "EG", "ts": ts, "uuid": uid}),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      // 4. تنفيذ المكالمة
      var response = await http.post(
        Uri.parse("https://api.telz.com/app/auth_call"),
        headers: headers,
        body: jsonEncode({"android_id": androidId, "app_version": "17.5.48", "attempt": "0", "event": "auth_call", "lang": "ar", "os": "android", "os_version": "15", "phone": phone, "ts": ts, "uuid": uid, "run_id": ts.toString()}),
      );

      var data = jsonDecode(response.body);
      if (data['status'] == 'ok') {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      // الصفحة الرئيسية: إرسال المكالمات
      SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            // أيقونة التطبيق وشعاره
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_in_talk, size: 60, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "أداة إرسال المكالمات",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Text(
                    "المطور: محمود",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),
            // حقل إدخال الرقم
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'الرقم المصري (يبدأ بـ 010, 011...)',
                prefixIcon: const Icon(Icons.phone_android, color: Colors.blueAccent),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),
            // حقل إدخال العدد
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'عدد المرات (كم مرة يرن)',
                prefixIcon: const Icon(Icons.repeat, color: Colors.blueAccent),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 30),
            // زر التنفيذ
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendCalls,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'بدء الإرسال (غير محدود ♾️)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),

      // صفحة السجل (Logs)
      Padding(
        padding: const EdgeInsets.all(12.0),
        child: _logs.isEmpty
            ? const Center(
                child: Text(
                  "لا يوجد سجل مكالمات حتى الآن",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            : ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: Icon(
                        log.isSuccess ? Icons.check_circle : Icons.error,
                        color: log.isSuccess ? Colors.green : Colors.red,
                      ),
                      title: Text("الرقم: ${log.phone}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(log.status),
                      trailing: Text(log.time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  );
                },
              ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? "الرئيسية" : "سجل العمليات"),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'السجل',
          ),
        ],
      ),
    );
  }
}
