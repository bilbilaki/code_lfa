import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:global_repository/global_repository.dart';
import 'package:path/path.dart' as path;
import '../models/linux_app.dart';
import '../script.dart';

/// Manages Linux app installation, persistence, and lifecycle
class AppManager {
  static final AppManager _instance = AppManager._internal();
  factory AppManager() => _instance;
  AppManager._internal();

  /// Path to store app metadata
  String get appsMetadataPath => '${RuntimeEnvir.dataPath}/apps.json';

  /// Path to store installed apps
  String get appsInstallPath => '$ubuntuPath/opt/apps';

  /// Cache of loaded apps
  List<LinuxApp> _apps = [];

  /// Get all installed apps
  List<LinuxApp> get apps => List.unmodifiable(_apps);

  /// Load apps from persistent storage
  Future<void> loadApps() async {
    try {
      final file = File(appsMetadataPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _apps = jsonList.map((json) => LinuxApp.fromJson(json as Map<String, dynamic>)).toList();
        Log.i('Loaded ${_apps.length} apps from storage');
      } else {
        _apps = [];
        Log.i('No apps metadata file found, starting with empty list');
      }
    } catch (e) {
      Log.e('Failed to load apps: $e');
      _apps = [];
    }
  }

  /// Save apps to persistent storage
  Future<void> saveApps() async {
    try {
      final file = File(appsMetadataPath);
      await file.parent.create(recursive: true);
      final jsonList = _apps.map((app) => app.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      Log.i('Saved ${_apps.length} apps to storage');
    } catch (e) {
      Log.e('Failed to save apps: $e');
      rethrow;
    }
  }

  /// Add a new app
  Future<void> addApp(LinuxApp app) async {
    _apps.add(app);
    await saveApps();
    Log.i('Added app: ${app.name}');
  }

  /// Remove an app
  Future<void> removeApp(String appId) async {
    _apps.removeWhere((app) => app.id == appId);
    await saveApps();
    Log.i('Removed app: $appId');
  }

  /// Update an existing app
  Future<void> updateApp(LinuxApp app) async {
    final index = _apps.indexWhere((a) => a.id == app.id);
    if (index != -1) {
      _apps[index] = app;
      await saveApps();
      Log.i('Updated app: ${app.name}');
    }
  }

  /// Get app by ID
  LinuxApp? getAppById(String id) {
    try {
      return _apps.firstWhere((app) => app.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Install an app from an archive file
  Future<void> installApp(LinuxApp app, {Function(String)? onProgress}) async {
    try {
      if (app.archivePath == null || app.archivePath!.isEmpty) {
        throw Exception('Archive path is required for installation');
      }

      final archiveFile = File(app.archivePath!);
      if (!await archiveFile.exists()) {
        throw Exception('Archive file not found: ${app.archivePath}');
      }

      onProgress?.call('Reading archive file...');
      
      // Create installation directory
      final installDir = Directory('$appsInstallPath/${app.id}');
      await installDir.create(recursive: true);

      // Extract archive based on file extension
      final ext = path.extension(app.archivePath!).toLowerCase();
      
      if (ext == '.zip') {
        await _extractZip(archiveFile, installDir, onProgress);
      } else if (ext == '.gz' || ext == '.tgz') {
        await _extractTarGz(archiveFile, installDir, onProgress);
      } else if (ext == '.tar') {
        await _extractTar(archiveFile, installDir, onProgress);
      } else {
        throw Exception('Unsupported archive format: $ext');
      }

      onProgress?.call('Installation completed');
      
      // Update app as installed
      final updatedApp = app.copyWith(
        isInstalled: true,
        installPath: installDir.path,
      );
      await updateApp(updatedApp);
      
      Log.i('Successfully installed app: ${app.name}');
    } catch (e) {
      Log.e('Failed to install app: $e');
      rethrow;
    }
  }

  /// Extract a ZIP archive
  Future<void> _extractZip(File archiveFile, Directory destDir, Function(String)? onProgress) async {
    final bytes = await archiveFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    for (var i = 0; i < archive.files.length; i++) {
      final file = archive.files[i];
      final filename = file.name;
      
      if (i % 10 == 0) {
        onProgress?.call('Extracting: $filename (${i + 1}/${archive.files.length})');
      }
      
      if (file.isFile) {
        final outFile = File('${destDir.path}/$filename');
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory('${destDir.path}/$filename').create(recursive: true);
      }
    }
  }

  /// Extract a TAR.GZ archive
  Future<void> _extractTarGz(File archiveFile, Directory destDir, Function(String)? onProgress) async {
    final bytes = await archiveFile.readAsBytes();
    final gzipBytes = GZipDecoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(gzipBytes);
    
    await _extractArchive(archive, destDir, onProgress);
  }

  /// Extract a TAR archive
  Future<void> _extractTar(File archiveFile, Directory destDir, Function(String)? onProgress) async {
    final bytes = await archiveFile.readAsBytes();
    final archive = TarDecoder().decodeBytes(bytes);
    
    await _extractArchive(archive, destDir, onProgress);
  }

  /// Extract archive files
  Future<void> _extractArchive(Archive archive, Directory destDir, Function(String)? onProgress) async {
    for (var i = 0; i < archive.files.length; i++) {
      final file = archive.files[i];
      final filename = file.name;
      
      if (i % 10 == 0) {
        onProgress?.call('Extracting: $filename (${i + 1}/${archive.files.length})');
      }
      
      if (file.isFile) {
        final outFile = File('${destDir.path}/$filename');
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
        
        // Preserve file permissions if available
        if (file.mode != null) {
          // Set executable bit if needed
          if (file.mode! & 0x49 != 0) { // Check if any execute bit is set
            await Process.run('chmod', ['+x', outFile.path]);
          }
        }
      } else {
        await Directory('${destDir.path}/$filename').create(recursive: true);
      }
    }
  }

  /// Uninstall an app
  Future<void> uninstallApp(String appId) async {
    final app = getAppById(appId);
    if (app == null) {
      throw Exception('App not found: $appId');
    }

    try {
      // Delete installation directory
      final installDir = Directory(app.installPath);
      if (await installDir.exists()) {
        await installDir.delete(recursive: true);
        Log.i('Deleted installation directory: ${app.installPath}');
      }

      // Remove from apps list
      await removeApp(appId);
      
      Log.i('Successfully uninstalled app: ${app.name}');
    } catch (e) {
      Log.e('Failed to uninstall app: $e');
      rethrow;
    }
  }

  /// Generate shell script to launch an app
  String generateLaunchScript(LinuxApp app) {
    final buffer = StringBuffer();
    
    buffer.writeln('launch_app_${app.id}(){');
    buffer.writeln('  progress_echo "Launching ${app.name}..."');
    buffer.writeln('  cd ${app.installPath}');
    
    // Set environment variables
    app.envVars.forEach((key, value) {
      buffer.writeln('  export $key="$value"');
    });
    
    // Build command with arguments
    final args = app.args.join(' ');
    buffer.writeln('  ${app.entryPoint} $args &');
    buffer.writeln('  APP_PID=\$!');
    buffer.writeln('  progress_echo "${app.name} started with PID \$APP_PID"');
    buffer.writeln('}');
    
    return buffer.toString();
  }

  /// Launch an app using PTY
  Future<void> launchApp(Pty pty, String appId) async {
    final app = getAppById(appId);
    if (app == null) {
      throw Exception('App not found: $appId');
    }

    if (!app.isInstalled) {
      throw Exception('App is not installed: ${app.name}');
    }

    try {
      final launchScript = generateLaunchScript(app);
      await pty.defineFunction(launchScript);
      pty.writeString('launch_app_${app.id}\n');
      Log.i('Launched app: ${app.name}');
    } catch (e) {
      Log.e('Failed to launch app: $e');
      rethrow;
    }
  }

  /// Clear all apps (for testing/reset)
  Future<void> clearAllApps() async {
    _apps.clear();
    await saveApps();
    Log.i('Cleared all apps');
  }
}
