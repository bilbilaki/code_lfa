import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import '../models/linux_app.dart';
import '../managers/app_manager.dart';
import '../terminal_page.dart';
import 'app_setup_page.dart';

/// Launcher page displaying installed apps
class LauncherPage extends StatefulWidget {
  const LauncherPage({super.key});

  @override
  State<LauncherPage> createState() => _LauncherPageState();
}

class _LauncherPageState extends State<LauncherPage> {
  final AppManager _appManager = AppManager();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    await _appManager.loadApps();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linux App Launcher'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToAppSetup(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadApps(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildAppGrid(),
    );
  }

  Widget _buildAppGrid() {
    final apps = _appManager.apps;
    
    // Always include System Terminal as the first item
    final items = <Widget>[
      _buildSystemTerminalCard(),
      ...apps.map((app) => _buildAppCard(app)),
    ];

    if (items.length == 1) {
      // Only system terminal, show empty state
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.apps,
              size: 80.w,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
            SizedBox(height: 16.w),
            Text(
              'No apps installed',
              style: TextStyle(
                fontSize: 18.w,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            SizedBox(height: 8.w),
            Text(
              'Tap the + button to add an app',
              style: TextStyle(
                fontSize: 14.w,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 16.w,
        crossAxisSpacing: 16.w,
        children: items,
      ),
    );
  }

  Widget _buildSystemTerminalCard() {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _openTerminal(),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.terminal,
                size: 48.w,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 8.w),
              Text(
                'Terminal',
                style: TextStyle(
                  fontSize: 14.w,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppCard(LinuxApp app) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _launchApp(app),
        onLongPress: () => _showAppOptions(app),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon or default icon
              _buildAppIcon(app),
              SizedBox(height: 8.w),
              Text(
                app.name,
                style: TextStyle(
                  fontSize: 14.w,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!app.isInstalled)
                Container(
                  margin: EdgeInsets.only(top: 4.w),
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.w),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4.w),
                  ),
                  child: Text(
                    'Not installed',
                    style: TextStyle(
                      fontSize: 10.w,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppIcon(LinuxApp app) {
    if (app.iconPath != null && app.iconPath!.isNotEmpty) {
      // Try to load custom icon
      return Image.asset(
        app.iconPath!,
        width: 48.w,
        height: 48.w,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.app_settings_alt,
            size: 48.w,
            color: Theme.of(context).colorScheme.secondary,
          );
        },
      );
    } else {
      return Icon(
        Icons.app_settings_alt,
        size: 48.w,
        color: Theme.of(context).colorScheme.secondary,
      );
    }
  }

  void _openTerminal() {
    Get.to(() => const TerminalPage());
  }

  void _launchApp(LinuxApp app) {
    if (!app.isInstalled) {
      Get.snackbar(
        'App Not Installed',
        'Please install ${app.name} before launching',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // App launch logic requires PTY integration with terminal controller
    // This will be fully implemented when the environment is initialized
    Get.snackbar(
      'Not Implemented',
      'App launching requires environment initialization. Use the Terminal to manually launch apps for now.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
    // Future implementation will:
    // 1. Check if PTY/environment is initialized
    // 2. Call AppManager().launchApp(pty, app.id)
    // 3. Open WebView if nginx config exists
  }

  void _showAppOptions(LinuxApp app) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('App Info'),
              onTap: () {
                Navigator.pop(context);
                _showAppInfo(app);
              },
            ),
            if (!app.isInstalled)
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Install'),
                onTap: () {
                  Navigator.pop(context);
                  _installApp(app);
                },
              ),
            if (app.isInstalled)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Uninstall'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmUninstall(app);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Remove'),
              onTap: () {
                Navigator.pop(context);
                _confirmRemove(app);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAppInfo(LinuxApp app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(app.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoRow('ID', app.id),
              _infoRow('Entry Point', app.entryPoint),
              if (app.port != null) _infoRow('Port', app.port.toString()),
              _infoRow('Install Path', app.installPath),
              _infoRow('Installed', app.isInstalled ? 'Yes' : 'No'),
              if (app.args.isNotEmpty) _infoRow('Arguments', app.args.join(' ')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.w,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          SizedBox(height: 2.w),
          Text(
            value,
            style: TextStyle(fontSize: 14.w),
          ),
        ],
      ),
    );
  }

  void _installApp(LinuxApp app) async {
    if (app.archivePath == null || app.archivePath!.isEmpty) {
      Get.snackbar(
        'Error',
        'No archive file specified for installation',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Show progress dialog
    Get.dialog(
      AlertDialog(
        title: const Text('Installing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: 16.w),
            Text('Installing ${app.name}...'),
          ],
        ),
      ),
      barrierDismissible: false,
    );

    try {
      await _appManager.installApp(app, onProgress: (msg) {
        Log.i('Install progress: $msg');
      });
      Get.back(); // Close progress dialog
      Get.snackbar(
        'Success',
        '${app.name} installed successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _loadApps();
    } catch (e) {
      Get.back(); // Close progress dialog
      Get.snackbar(
        'Error',
        'Failed to install ${app.name}: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _confirmUninstall(LinuxApp app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Uninstall'),
        content: Text('Are you sure you want to uninstall ${app.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _uninstallApp(app);
            },
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
  }

  void _uninstallApp(LinuxApp app) async {
    try {
      await _appManager.uninstallApp(app.id);
      Get.snackbar(
        'Success',
        '${app.name} uninstalled successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _loadApps();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to uninstall ${app.name}: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _confirmRemove(LinuxApp app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Remove'),
        content: Text(
          'Are you sure you want to remove ${app.name} from the launcher? '
          '${app.isInstalled ? "This will also uninstall the app." : ""}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeApp(app);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _removeApp(LinuxApp app) async {
    try {
      if (app.isInstalled) {
        await _appManager.uninstallApp(app.id);
      } else {
        await _appManager.removeApp(app.id);
      }
      Get.snackbar(
        'Success',
        '${app.name} removed successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _loadApps();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to remove ${app.name}: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _navigateToAppSetup() async {
    final result = await Get.to(() => const AppSetupPage());
    if (result == true) {
      await _loadApps();
    }
  }
}
