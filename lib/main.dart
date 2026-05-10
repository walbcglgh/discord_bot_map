import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const _syncTask = 'dc_location_sync_task';
const _apiEndpoint = 'https://taiwandisasternews.dpdns.org/api/location/update';

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

String generateLocationCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  String part(int length) => List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  return 'DCL-${part(4)}-${part(4)}-${part(4)}-${part(4)}';
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
  final code = TextEditingController();
  String status = '尚未啟動';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    code.text = prefs.getString('code') ?? generateLocationCode();
    await prefs.setString('code', code.text.trim());
    setState(() => status = prefs.getBool('enabled') == true ? '背景同步已啟用' : '尚未啟動');
  }

  Future<void> _save({bool enabled = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('code', code.text.trim().toUpperCase());
    await prefs.setBool('enabled', enabled);
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: code.text.trim()));
    setState(() => status = '通知碼已複製，請到 Discord 使用 /location_code 綁定。');
  }

  Future<void> _regenerateCode() async {
    await Workmanager().cancelByUniqueName(_syncTask);
    final prefs = await SharedPreferences.getInstance();
    final next = generateLocationCode();
    await prefs.setString('code', next);
    await prefs.setBool('enabled', false);
    setState(() {
      code.text = next;
      status = '已重新產生通知碼，請重新到 Discord 綁定。';
    });
  }

  Future<void> _start() async {
    setState(() { busy = true; status = '正在要求定位權限'; });
    try {
      await _save(enabled: true);
      final ok = await LocationSyncService.ensurePermission(requireBackground: true);
      if (!ok) {
        setState(() => status = '背景定位權限不足，請到系統設定允許「一律允許」');
        return;
      }
      await Workmanager().cancelByUniqueName(_syncTask);
      await Workmanager().registerPeriodicTask(
        _syncTask,
        _syncTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
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
    setState(() { busy = true; status = '正在要求定位權限並同步位置'; });
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
          TextField(controller: code, readOnly: true, decoration: const InputDecoration(labelText: '通知碼')),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: busy ? null : _copyCode, child: const Text('複製通知碼'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: busy ? null : _regenerateCode, child: const Text('重新產生'))),
            ],
          ),
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
          const Text('先複製通知碼，到 Discord 伺服器使用 /location_code 綁定，再回來同步。', style: TextStyle(color: Colors.grey)),
          const Text('iOS 背景更新由系統決定，通常不是即時；Android 也可能受省電策略影響。', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class LocationSyncService {
  static Future<bool> ensurePermission({bool requireBackground = false}) async {
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return false;
    }
    if (!requireBackground) {
      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    }
    if (permission == LocationPermission.always) return true;

    final always = await ph.Permission.locationAlways.request();
    if (always.isGranted) return true;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always) return true;

    if (always.isPermanentlyDenied || permission == LocationPermission.deniedForever) {
      await ph.openAppSettings();
    }
    return false;
  }

  static Future<String> syncOnce({String source = 'manual'}) async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('code') ?? '';

    if (!_apiEndpoint.startsWith('https://')) return 'App API Endpoint not configured';
    if (code.isEmpty) return '請先產生並綁定通知碼';

    final ok = await ensurePermission();
    if (!ok) return '定位權限不足';

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 25),
    );

    final payload = {
      'code': code,
      'lat': pos.latitude,
      'lon': pos.longitude,
      'accuracy': pos.accuracy,
      'platform': 'flutter-$source',
    };

    final res = await http.post(
      Uri.parse(_apiEndpoint),
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
