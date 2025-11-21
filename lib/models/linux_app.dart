import 'dart:convert';

/// Model representing a Linux ARM64 application that can be installed and managed
class LinuxApp {
  /// Unique identifier for the app
  final String id;

  /// Display name of the application
  final String name;

  /// Path to the app icon (optional)
  final String? iconPath;

  /// Entry point script or binary path within Ubuntu filesystem
  final String entryPoint;

  /// Port number the app will run on (if applicable)
  final int? port;

  /// Additional command line arguments
  final List<String> args;

  /// Environment variables to set when launching the app
  final Map<String, String> envVars;

  /// Nginx configuration for reverse proxy (if applicable)
  final NginxConfig? nginxConfig;

  /// Installation directory path
  final String installPath;

  /// Whether the app is currently installed
  final bool isInstalled;

  /// Archive file path (for installation)
  final String? archivePath;

  LinuxApp({
    required this.id,
    required this.name,
    this.iconPath,
    required this.entryPoint,
    this.port,
    this.args = const [],
    this.envVars = const {},
    this.nginxConfig,
    required this.installPath,
    this.isInstalled = false,
    this.archivePath,
  });

  /// Create a copy of this app with updated fields
  LinuxApp copyWith({
    String? id,
    String? name,
    String? iconPath,
    String? entryPoint,
    int? port,
    List<String>? args,
    Map<String, String>? envVars,
    NginxConfig? nginxConfig,
    String? installPath,
    bool? isInstalled,
    String? archivePath,
  }) {
    return LinuxApp(
      id: id ?? this.id,
      name: name ?? this.name,
      iconPath: iconPath ?? this.iconPath,
      entryPoint: entryPoint ?? this.entryPoint,
      port: port ?? this.port,
      args: args ?? this.args,
      envVars: envVars ?? this.envVars,
      nginxConfig: nginxConfig ?? this.nginxConfig,
      installPath: installPath ?? this.installPath,
      isInstalled: isInstalled ?? this.isInstalled,
      archivePath: archivePath ?? this.archivePath,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconPath': iconPath,
      'entryPoint': entryPoint,
      'port': port,
      'args': args,
      'envVars': envVars,
      'nginxConfig': nginxConfig?.toJson(),
      'installPath': installPath,
      'isInstalled': isInstalled,
      'archivePath': archivePath,
    };
  }

  /// Create from JSON
  factory LinuxApp.fromJson(Map<String, dynamic> json) {
    return LinuxApp(
      id: json['id'] as String,
      name: json['name'] as String,
      iconPath: json['iconPath'] as String?,
      entryPoint: json['entryPoint'] as String,
      port: json['port'] as int?,
      args: (json['args'] as List<dynamic>?)?.cast<String>() ?? [],
      envVars: (json['envVars'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
      nginxConfig: json['nginxConfig'] != null
          ? NginxConfig.fromJson(json['nginxConfig'] as Map<String, dynamic>)
          : null,
      installPath: json['installPath'] as String,
      isInstalled: json['isInstalled'] as bool? ?? false,
      archivePath: json['archivePath'] as String?,
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory LinuxApp.fromJsonString(String jsonString) {
    return LinuxApp.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }
}

/// Nginx configuration for reverse proxy
class NginxConfig {
  /// Base path for the app (e.g., '/app1')
  final String basePath;

  /// Whether to use path-based routing (true) or port-based (false)
  final bool usePathRouting;

  /// Additional nginx server block configuration
  final Map<String, String> additionalConfig;

  NginxConfig({
    required this.basePath,
    this.usePathRouting = true,
    this.additionalConfig = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'basePath': basePath,
      'usePathRouting': usePathRouting,
      'additionalConfig': additionalConfig,
    };
  }

  factory NginxConfig.fromJson(Map<String, dynamic> json) {
    return NginxConfig(
      basePath: json['basePath'] as String,
      usePathRouting: json['usePathRouting'] as bool? ?? true,
      additionalConfig: (json['additionalConfig'] as Map<String, dynamic>?)?.cast<String, String>() ?? {},
    );
  }
}
