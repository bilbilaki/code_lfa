import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:path/path.dart' as path;
import '../models/linux_app.dart';
import '../managers/app_manager.dart';

/// App setup wizard page for configuring new apps
class AppSetupPage extends StatefulWidget {
  const AppSetupPage({super.key});

  @override
  State<AppSetupPage> createState() => _AppSetupPageState();
}

class _AppSetupPageState extends State<AppSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _appManager = AppManager();
  
  // Form fields
  final _nameController = TextEditingController();
  final _entryPointController = TextEditingController();
  final _portController = TextEditingController();
  final _argsController = TextEditingController();
  final _basePathController = TextEditingController();
  
  String? _selectedArchivePath;
  bool _enableNginx = false;
  bool _usePathRouting = true;
  
  int _currentStep = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _entryPointController.dispose();
    _portController.dispose();
    _argsController.dispose();
    _basePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New App'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        steps: [
          Step(
            title: const Text('Select Archive'),
            content: _buildArchiveSelectionStep(),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: const Text('Configure App'),
            content: _buildConfigurationStep(),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: const Text('Review & Save'),
            content: _buildReviewStep(),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveSelectionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select an archive file containing your Linux ARM64 application',
          style: TextStyle(fontSize: 14.w),
        ),
        SizedBox(height: 16.w),
        if (_selectedArchivePath != null)
          Card(
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected File:',
                    style: TextStyle(
                      fontSize: 12.w,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.w),
                  Text(
                    path.basename(_selectedArchivePath!),
                    style: TextStyle(fontSize: 14.w),
                  ),
                  SizedBox(height: 4.w),
                  Text(
                    _selectedArchivePath!,
                    style: TextStyle(
                      fontSize: 12.w,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Text(
                'No file selected',
                style: TextStyle(
                  fontSize: 14.w,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        SizedBox(height: 16.w),
        ElevatedButton.icon(
          onPressed: _selectArchiveFile,
          icon: const Icon(Icons.folder_open),
          label: const Text('Browse Files'),
        ),
        SizedBox(height: 8.w),
        Text(
          'Supported formats: .zip, .tar.gz, .tgz, .tar',
          style: TextStyle(
            fontSize: 12.w,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildConfigurationStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'App Name *',
              hintText: 'Enter application name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an app name';
              }
              return null;
            },
          ),
          SizedBox(height: 16.w),
          TextFormField(
            controller: _entryPointController,
            decoration: const InputDecoration(
              labelText: 'Entry Point *',
              hintText: 'e.g., /opt/myapp/bin/start.sh',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an entry point';
              }
              return null;
            },
          ),
          SizedBox(height: 16.w),
          TextFormField(
            controller: _argsController,
            decoration: const InputDecoration(
              labelText: 'Command Arguments',
              hintText: 'e.g., --port 8080 --host 0.0.0.0',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 16.w),
          SwitchListTile(
            title: const Text('Enable Nginx Proxy'),
            subtitle: const Text('Route app through Nginx reverse proxy'),
            value: _enableNginx,
            onChanged: (value) {
              setState(() {
                _enableNginx = value;
              });
            },
          ),
          if (_enableNginx) ...[
            SizedBox(height: 16.w),
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port *',
                hintText: 'e.g., 8080',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (_enableNginx && (value == null || value.isEmpty)) {
                  return 'Please enter a port number';
                }
                if (value != null && value.isNotEmpty) {
                  final port = int.tryParse(value);
                  if (port == null || port < 1 || port > 65535) {
                    return 'Please enter a valid port (1-65535)';
                  }
                }
                return null;
              },
            ),
            SizedBox(height: 16.w),
            SwitchListTile(
              title: const Text('Path-based Routing'),
              subtitle: const Text('Use /app-name instead of port-based routing'),
              value: _usePathRouting,
              onChanged: (value) {
                setState(() {
                  _usePathRouting = value;
                });
              },
            ),
            if (_usePathRouting) ...[
              SizedBox(height: 16.w),
              TextFormField(
                controller: _basePathController,
                decoration: const InputDecoration(
                  labelText: 'Base Path',
                  hintText: 'e.g., /myapp',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_enableNginx && _usePathRouting && (value == null || value.isEmpty)) {
                    return 'Please enter a base path';
                  }
                  if (value != null && value.isNotEmpty && !value.startsWith('/')) {
                    return 'Base path must start with /';
                  }
                  return null;
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review your configuration',
          style: TextStyle(
            fontSize: 16.w,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16.w),
        _reviewItem('App Name', _nameController.text),
        _reviewItem('Entry Point', _entryPointController.text),
        if (_argsController.text.isNotEmpty)
          _reviewItem('Arguments', _argsController.text),
        if (_selectedArchivePath != null)
          _reviewItem('Archive', path.basename(_selectedArchivePath!)),
        if (_enableNginx) ...[
          _reviewItem('Port', _portController.text),
          _reviewItem('Nginx Enabled', 'Yes'),
          _reviewItem('Routing Type', _usePathRouting ? 'Path-based' : 'Port-based'),
          if (_usePathRouting && _basePathController.text.isNotEmpty)
            _reviewItem('Base Path', _basePathController.text),
        ],
        SizedBox(height: 24.w),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveApp,
            icon: const Icon(Icons.save),
            label: const Text('Save App'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16.w),
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14.w,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14.w),
            ),
          ),
        ],
      ),
    );
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      // Validate archive selection
      if (_selectedArchivePath == null) {
        Get.snackbar(
          'Error',
          'Please select an archive file',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      // Validate configuration form
      if (_formKey.currentState?.validate() ?? false) {
        setState(() => _currentStep++);
      }
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Get.back();
    }
  }

  void _selectArchiveFile() {
    // For now, show a dialog with manual path entry
    // In a real implementation, you might use file_picker package
    final pathController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Archive File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the full path to your archive file:'),
            SizedBox(height: 16.w),
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                hintText: '/sdcard/myapp.tar.gz',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 8.w),
            const Text(
              'The file should be accessible on your device (e.g., in /sdcard/)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final filePath = pathController.text.trim();
              if (filePath.isNotEmpty) {
                final file = File(filePath);
                if (file.existsSync()) {
                  setState(() {
                    _selectedArchivePath = filePath;
                  });
                  Navigator.pop(context);
                } else {
                  Get.snackbar(
                    'Error',
                    'File does not exist: $filePath',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                }
              }
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  void _saveApp() async {
    try {
      // Generate unique ID
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Parse arguments
      final args = _argsController.text.trim().isEmpty
          ? <String>[]
          : _argsController.text.trim().split(RegExp(r'\s+'));
      
      // Create nginx config if enabled
      NginxConfig? nginxConfig;
      if (_enableNginx) {
        nginxConfig = NginxConfig(
          basePath: _usePathRouting ? _basePathController.text : '/',
          usePathRouting: _usePathRouting,
        );
      }
      
      // Create app instance
      final app = LinuxApp(
        id: id,
        name: _nameController.text,
        entryPoint: _entryPointController.text,
        port: _enableNginx ? int.tryParse(_portController.text) : null,
        args: args,
        nginxConfig: nginxConfig,
        installPath: '${_appManager.appsInstallPath}/$id',
        archivePath: _selectedArchivePath,
        isInstalled: false,
      );
      
      // Save app
      await _appManager.addApp(app);
      
      Get.snackbar(
        'Success',
        'App added successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
      
      // Return to launcher with success result
      Get.back(result: true);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save app: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
