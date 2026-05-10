import 'dart:convert';

class AppLimit {
  final String packageName;
  final String appName;
  final int limitMinutes;
  final bool enabled;

  AppLimit({
    required this.packageName,
    required this.appName,
    required this.limitMinutes,
    this.enabled = true,
  });

  AppLimit copyWith({
    String? packageName,
    String? appName,
    int? limitMinutes,
    bool? enabled,
  }) {
    return AppLimit(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      limitMinutes: limitMinutes ?? this.limitMinutes,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toMap() => {
        'packageName': packageName,
        'appName': appName,
        'limitMinutes': limitMinutes,
        'enabled': enabled,
      };

  factory AppLimit.fromMap(Map<String, dynamic> map) => AppLimit(
        packageName: map['packageName'] as String,
        appName: map['appName'] as String,
        limitMinutes: map['limitMinutes'] as int,
        enabled: map['enabled'] as bool? ?? true,
      );

  String toJson() => json.encode(toMap());

  factory AppLimit.fromJson(String source) =>
      AppLimit.fromMap(json.decode(source) as Map<String, dynamic>);
}
