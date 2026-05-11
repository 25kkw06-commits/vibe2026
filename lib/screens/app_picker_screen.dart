import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({super.key});

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  List<AppInfo> _apps = [];
  List<AppInfo> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  Future<void> _load() async {
    final apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      excludeNonLaunchableApps: true,
      withIcon: true,
    );
    apps.sort((a, b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _apps = apps;
      _filtered = apps;
      _loading = false;
    });
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _apps
          : _apps.where((a) {
              return a.name.toLowerCase().contains(q) ||
                  a.packageName.toLowerCase().contains(q);
            }).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('추적할 앱 선택')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '앱 이름 검색',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final a = _filtered[i];
                      final icon = a.icon;
                      return ListTile(
                        leading: icon != null
                            ? Image.memory(Uint8List.fromList(icon),
                                width: 40, height: 40)
                            : const Icon(Icons.android, size: 40),
                        title: Text(a.name),
                        subtitle: Text(a.packageName),
                        onTap: () => Navigator.pop(context, a),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
