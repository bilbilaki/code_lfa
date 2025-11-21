import 'dart:io';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:global_repository/global_repository.dart';
import '../models/linux_app.dart';
import '../utils.dart';

/// Manages Nginx configuration and service lifecycle
class NginxManager {
  static final NginxManager _instance = NginxManager._internal();
  factory NginxManager() => _instance;
  NginxManager._internal();

  /// Path to nginx configuration directory in Ubuntu
  String get nginxConfigPath => '/etc/nginx';
  String get nginxSitesAvailable => '$nginxConfigPath/sites-available';
  String get nginxSitesEnabled => '$nginxConfigPath/sites-enabled';

  /// Generate Nginx installation script
  String generateInstallScript() {
    return r'''
install_nginx(){
  progress_echo "Checking Nginx installation..."
  if ! command -v nginx &> /dev/null; then
    progress_echo "Nginx not installed, installing..."
    apt-get update -y
    apt-get install -y nginx
    progress_echo "Nginx installed successfully"
  else
    progress_echo "Nginx already installed"
  fi
}
''';
  }

  /// Generate Nginx server block configuration for an app
  String generateServerBlock(LinuxApp app) {
    if (app.nginxConfig == null || app.port == null) {
      return '';
    }

    final config = app.nginxConfig!;
    final buffer = StringBuffer();

    if (config.usePathRouting) {
      // Path-based routing configuration
      buffer.writeln('# Configuration for ${app.name}');
      buffer.writeln('location ${config.basePath} {');
      buffer.writeln('    proxy_pass http://127.0.0.1:${app.port};');
      buffer.writeln('    proxy_http_version 1.1;');
      buffer.writeln('    proxy_set_header Upgrade \$http_upgrade;');
      buffer.writeln('    proxy_set_header Connection "upgrade";');
      buffer.writeln('    proxy_set_header Host \$host;');
      buffer.writeln('    proxy_set_header X-Real-IP \$remote_addr;');
      buffer.writeln('    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;');
      buffer.writeln('    proxy_set_header X-Forwarded-Proto \$scheme;');
      
      // Add any additional configuration
      config.additionalConfig.forEach((key, value) {
        buffer.writeln('    $key $value;');
      });
      
      buffer.writeln('}');
    } else {
      // Port-based routing - separate server block
      buffer.writeln('# Configuration for ${app.name}');
      buffer.writeln('server {');
      buffer.writeln('    listen ${app.port};');
      buffer.writeln('    server_name localhost;');
      buffer.writeln('');
      buffer.writeln('    location / {');
      buffer.writeln('        proxy_pass http://127.0.0.1:${app.port};');
      buffer.writeln('        proxy_http_version 1.1;');
      buffer.writeln('        proxy_set_header Upgrade \$http_upgrade;');
      buffer.writeln('        proxy_set_header Connection "upgrade";');
      buffer.writeln('        proxy_set_header Host \$host;');
      buffer.writeln('        proxy_set_header X-Real-IP \$remote_addr;');
      buffer.writeln('        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;');
      buffer.writeln('        proxy_set_header X-Forwarded-Proto \$scheme;');
      
      // Add any additional configuration
      config.additionalConfig.forEach((key, value) {
        buffer.writeln('        $key $value;');
      });
      
      buffer.writeln('    }');
      buffer.writeln('}');
    }

    return buffer.toString();
  }

  /// Generate the main nginx.conf with app configurations
  String generateMainConfig(List<LinuxApp> apps) {
    final buffer = StringBuffer();
    
    buffer.writeln('server {');
    buffer.writeln('    listen 8080;');
    buffer.writeln('    server_name localhost;');
    buffer.writeln('');
    buffer.writeln('    # Main landing page');
    buffer.writeln('    location / {');
    buffer.writeln('        root /var/www/html;');
    buffer.writeln('        index index.html;');
    buffer.writeln('    }');
    buffer.writeln('');
    
    // Add path-based routing for each app
    for (final app in apps) {
      if (app.nginxConfig != null && app.nginxConfig!.usePathRouting && app.port != null) {
        buffer.writeln(generateServerBlock(app));
        buffer.writeln('');
      }
    }
    
    buffer.writeln('}');
    buffer.writeln('');
    
    // Add port-based server blocks
    for (final app in apps) {
      if (app.nginxConfig != null && !app.nginxConfig!.usePathRouting && app.port != null) {
        buffer.writeln(generateServerBlock(app));
        buffer.writeln('');
      }
    }
    
    return buffer.toString();
  }

  /// Create shell command to write nginx configuration
  String generateWriteConfigCommand(String configName, String content) {
    // Escape special characters for shell
    final escapedContent = content
        .replaceAll('\\', '\\\\')
        .replaceAll('\$', '\\\$')
        .replaceAll('"', '\\"')
        .replaceAll('`', '\\`');
    
    return '''
cat > /etc/nginx/sites-available/$configName << 'NGINX_EOF'
$content
NGINX_EOF
ln -sf /etc/nginx/sites-available/$configName /etc/nginx/sites-enabled/$configName
''';
  }

  /// Generate command to reload Nginx
  String generateReloadCommand() {
    return '''
nginx -t && nginx -s reload || echo "Nginx configuration test failed"
''';
  }

  /// Generate command to start Nginx
  String generateStartCommand() {
    return '''
if ! pgrep nginx > /dev/null; then
  nginx
  progress_echo "Nginx started"
else
  progress_echo "Nginx already running"
fi
''';
  }

  /// Generate command to stop Nginx
  String generateStopCommand() {
    return 'nginx -s stop';
  }

  /// Apply configuration for a list of apps using PTY
  Future<void> applyConfiguration(Pty pty, List<LinuxApp> apps) async {
    try {
      Log.i('Applying Nginx configuration for ${apps.length} apps');
      
      // Generate the main config
      final mainConfig = generateMainConfig(apps);
      
      // Write the configuration
      final writeCmd = generateWriteConfigCommand('apps.conf', mainConfig);
      await pty.defineFunction(writeCmd);
      
      // Reload nginx
      final reloadCmd = generateReloadCommand();
      await pty.defineFunction(reloadCmd);
      
      Log.i('Nginx configuration applied successfully');
    } catch (e) {
      Log.e('Failed to apply Nginx configuration: $e');
      rethrow;
    }
  }

  /// Start Nginx service using PTY
  Future<void> startNginx(Pty pty) async {
    try {
      final startCmd = generateStartCommand();
      await pty.defineFunction(startCmd);
      Log.i('Nginx start command executed');
    } catch (e) {
      Log.e('Failed to start Nginx: $e');
      rethrow;
    }
  }

  /// Stop Nginx service using PTY
  Future<void> stopNginx(Pty pty) async {
    try {
      final stopCmd = generateStopCommand();
      await pty.defineFunction(stopCmd);
      Log.i('Nginx stop command executed');
    } catch (e) {
      Log.e('Failed to stop Nginx: $e');
      rethrow;
    }
  }
}
