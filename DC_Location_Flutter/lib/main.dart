import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const _syncTask = 'dc_location_sync_task';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _syncTask || task == Workmanager.iOSBackgroundTask) {
      await LocationSyncService.syncOnce(source: 'background');
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  runApp(const DCLocationApp());
}

class DCLocationApp extends StatelessWidget {
  const DCLocationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DC Location',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5865F2)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final endpoint = TextEditingController();
  final token = TextEditingController();
  final guildId = TextEditingController();
  final userId = TextEditingController();
  String status = '尚未啟動';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    endpoint.text = prefs.getString('endpoint') ?? '';
    token.text = prefs.getString('token') ?? '';
    guildId.text = prefs.getString('guild_id') ?? '';
    userId.text = prefs.getString('user_id') ?? '';
    setState(() => status = prefs.getBool('enabled') == true ? '背景同步已啟用' : '尚未啟動');
  }

  Future<void> _save({bool enabled = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('endpoint', endpoint.text.trim());
    await prefs.setString('token', token.text.trim());
    await prefs.setString('guild_id', guildId.text.trim());
    await prefs.setString('user_id', userId.text.trim());
    await prefs.setBool('enabled', enabled);
  }

  Future<void> _start() async {
    setState(() { busy = true; status = '正在確認定位權限'; });
    try {
      await _save(enabled: true);
      final ok = await LocationSyncService.ensurePermission();
      if (!ok) {
        setState(() => status = '定位權限不足，請到系統設定允許定位');
        return;
      }
      await Workmanager().cancelByUniqueName(_syncTask);
      await Workmanager().registerPeriodicTask(
        _syncTask,
        _syncTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      final result = await LocationSyncService.syncOnce(source: 'manual-start');
      setState(() => status = result);
    } catch (e) {
      setState(() => status = '啟動失敗：$e');
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() { busy = true; status = '正在同步目前位置'; });
    try {
      await _save(enabled: true);
      final result = await LocationSyncService.syncOnce(source: 'manual');
      setState(() => status = result);
    } catch (e) {
      setState(() => status = '同步失敗：$e');
    } finally {
      setState(() => busy = false);
    }
  }

  Future<void> _stop() async {
    await Workmanager().cancelByUniqueName(_syncTask);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enabled', false);
    setState(() => status = '已停止背景同步');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DC Location')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: endpoint, decoration: const InputDecoration(labelText: 'API Endpoint', hintText: 'https://your-domain/api/location/update')),
          TextField(controller: token, decoration: const InputDecoration(labelText: 'Token'), obscureText: true),
          TextField(controller: guildId, decoration: const InputDecoration(labelText: 'Discord Guild ID'), keyboardType: TextInputType.number),
          TextField(controller: userId, decoration: const InputDecoration(labelText: 'Discord User ID'), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          FilledButton(onPressed: busy ? null : _start, child: const Text('儲存並啟動背景同步')),
          OutlinedButton(onPressed: busy ? null : _syncNow, child: const Text('手動同步一次')),
          TextButton(onPressed: busy ? null : _stop, child: const Text('停止背景同步')),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(status),
            ),
          ),
          const SizedBox(height: 12),
          const Text('iOS 背景更新由系統決定，通常不是即時；Android 也可能受省電策略影響。', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class LocationSyncService {
  static Future<bool> ensurePermission() async {
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  static Future<String> syncOnce({String source = 'manual'}) async {
    final prefs = await SharedPreferences.getInstance();
    final endpoint = prefs.getString('endpoint') ?? '';
    final token = prefs.getString('token') ?? '';
    final guildId = prefs.getString('guild_id') ?? '';
    final userId = prefs.getString('user_id') ?? '';

    if (!endpoint.startsWith('https://')) return '請先填 HTTPS API Endpoint';
    if (token.isEmpty || guildId.isEmpty || userId.isEmpty) return '請先填 Token / Guild ID / User ID';

    final ok = await ensurePermission();
    if (!ok) return '定位權限不足';

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 25),
    );

    final payload = {
      'token': token,
      'guild_id': guildId,
      'user_id': userId,
      'lat': pos.latitude,
      'lon': pos.longitude,
      'accuracy': pos.accuracy,
      'platform': 'flutter-$source',
    };

    final res = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 25));

    final body = utf8.decode(res.bodyBytes);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return '同步失敗：HTTP ${res.statusCode} $body';
    }
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final region = data['region'] ?? '未知地區';
      final changed = data['changed'] == true ? '已更新暱稱' : '暱稱無變化';
      return '$changed：$region';
    } catch (_) {
      return '已同步';
    }
  }
}
