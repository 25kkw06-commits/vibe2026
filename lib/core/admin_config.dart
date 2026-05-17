/// ADMIN_MODE=true 빌드에서만 true. 일반 APK는 관리 UI 없음.
/// 룰은 같고 저장소·앱 ID만 admin/prod 갈림.
class AdminConfig {
  AdminConfig._();

  static const bool enabled = bool.fromEnvironment(
    'ADMIN_MODE',
    defaultValue: false,
  );
}
