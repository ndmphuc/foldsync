import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setTitle('FoldSync');
    await windowManager.setSize(const Size(750, 600));
    await windowManager.setMinimumSize(const Size(750, 600));
    await windowManager.setMaximumSize(const Size(750, 600));
    await windowManager.setResizable(false);
    await windowManager.show();
  });
  runApp(const FoldSyncApp());
}

class FoldSyncApp extends StatelessWidget {
  const FoldSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoldSync',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const FoldSyncHomePage(),
    );
  }
}

class FoldSyncHomePage extends StatefulWidget {
  const FoldSyncHomePage({super.key});

  @override
  FoldSyncHomePageState createState() => FoldSyncHomePageState();
}

class FoldSyncHomePageState extends State<FoldSyncHomePage> {
  String? sourceFolder;
  String? destFolder;
  String status = 'Ready';
  String currentSyncItem = '';
  double progress = 0.0;
  bool isSyncing = false;
  bool isPaused = false;
  bool skipHiddenFolders = false;
  List<String> previewChanges = [];
  List<String> skippedItems = [];
  List<MapEntry<String, Future<void> Function()>> syncQueue = [];
  int currentQueueIndex = 0;

  Future<void> chooseSourceFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        sourceFolder = selectedDirectory;
        status = 'Source folder selected: $sourceFolder';
      });
    }
  }

  Future<void> chooseDestinationFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        destFolder = selectedDirectory;
        status = 'Destination folder selected: $destFolder';
      });
    }
  }

  Future<List<String>> generateSyncChanges() async {
    if (sourceFolder == null || destFolder == null) {
      return ['Error: Please select both source and destination folders'];
    }

    List<String> changes = [];
    skippedItems.clear();
    Directory sourceDir = Directory(sourceFolder!);
    Directory destDir = Directory(destFolder!);

    if (!await sourceDir.exists()) {
      return ['Error: Source folder does not exist'];
    }
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
      changes.add('Copy: $destFolder');
    }

    Map<String, FileSystemEntity> sourceEntities = {};
    Map<String, FileSystemEntity> destEntities = {};

    try {
      await for (var entity in sourceDir.list(recursive: true, followLinks: false)) {
        String relativePath = entity.path.substring(sourceDir.path.length + 1);
        if (skipHiddenFolders && relativePath.split(Platform.pathSeparator).any((part) => part.startsWith('.'))) {
          skippedItems.add('Skipped hidden: $relativePath');
          continue;
        }
        if (await _isAccessible(entity)) {
          sourceEntities[relativePath] = entity;
        } else {
          skippedItems.add('Skipped inaccessible: $relativePath');
        }
      }
    } catch (e) {
      skippedItems.add('Error listing source directory: $e');
    }

    try {
      await for (var entity in destDir.list(recursive: true, followLinks: false)) {
        String relativePath = entity.path.substring(destDir.path.length + 1);
        if (skipHiddenFolders && relativePath.split(Platform.pathSeparator).any((part) => part.startsWith('.'))) {
          skippedItems.add('Skipped hidden: $relativePath');
          continue;
        }
        if (await _isAccessible(entity)) {
          destEntities[relativePath] = entity;
        } else {
          skippedItems.add('Skipped inaccessible: $relativePath');
        }
      }
    } catch (e) {
      skippedItems.add('Error listing destination directory: $e');
    }

    for (var entry in sourceEntities.entries) {
      String relativePath = entry.key;
      FileSystemEntity sourceEntity = entry.value;
      String destPath = '${destDir.path}/$relativePath';

      if (!destEntities.containsKey(relativePath)) {
        changes.add('Copy: $relativePath');
      } else {
        FileSystemEntity destEntity = destEntities[relativePath]!;
        if (sourceEntity is File && destEntity is File) {
          try {
            DateTime sourceModTime = await sourceEntity.stat().then((s) => s.modified);
            DateTime destModTime = await destEntity.stat().then((s) => s.modified);
            if (sourceModTime.isAfter(destModTime)) {
              changes.add('Update: $relativePath');
            }
          } catch (e) {
            skippedItems.add('Skipped due to stat error: $relativePath ($e)');
          }
        }
      }
    }

    for (var entry in destEntities.entries) {
      String relativePath = entry.key;
      if (!sourceEntities.containsKey(relativePath)) {
        changes.add('Delete: $relativePath');
      }
    }

    if (skippedItems.isNotEmpty) {
      changes.addAll(skippedItems);
    }

    return changes.isEmpty ? ['No changes needed'] : changes;
  }

  Future<bool> _isAccessible(FileSystemEntity entity) async {
    try {
      if (entity is Directory) {
        await entity.list().first;
      } else if (entity is File) {
        await entity.exists();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  void previewSyncChanges() async {
    if (sourceFolder == null || destFolder == null) {
      setState(() {
        status = 'Please select both source and destination folders';
      });
      return;
    }

    setState(() {
      status = 'Generating preview...';
    });

    previewChanges = await generateSyncChanges();

    setState(() {
      status = 'Preview changes generated';
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview Sync Changes'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Copy'),
                    Tab(text: 'Update'),
                    Tab(text: 'Delete'),
                    Tab(text: 'Skip'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: previewChanges.where((c) => c.startsWith('Copy: ')).length,
                        itemBuilder: (context, index) {
                          var items = previewChanges.where((c) => c.startsWith('Copy: ')).toList();
                          return ListTile(title: Text(items[index]));
                        },
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: previewChanges.where((c) => c.startsWith('Update: ')).length,
                        itemBuilder: (context, index) {
                          var items = previewChanges.where((c) => c.startsWith('Update: ')).toList();
                          return ListTile(title: Text(items[index]));
                        },
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: previewChanges.where((c) => c.startsWith('Delete: ')).length,
                        itemBuilder: (context, index) {
                          var items = previewChanges.where((c) => c.startsWith('Delete: ')).toList();
                          return ListTile(title: Text(items[index]));
                        },
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: previewChanges.where((c) => c.startsWith('Skipped')).length,
                        itemBuilder: (context, index) {
                          var items = previewChanges.where((c) => c.startsWith('Skipped')).toList();
                          return ListTile(title: Text(items[index]));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

  Future<void> performSync() async {
    Directory sourceDir = Directory(sourceFolder!);
    Directory destDir = Directory(destFolder!);

    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    if (currentQueueIndex == 0) {
      List<String> changes = await generateSyncChanges();
      syncQueue.clear();
      skippedItems.clear();

      for (String change in changes) {
        if (change.startsWith('Skipped')) {
          skippedItems.add(change);
          continue;
        }

        if (change.startsWith('Copy: ')) {
          String relativePath = change.substring(6);
          String sourcePath = '${sourceDir.path}/$relativePath';
          String destPath = '${destDir.path}/$relativePath';
          FileSystemEntity entity = FileSystemEntity.typeSync(sourcePath) == FileSystemEntityType.file
              ? File(sourcePath)
              : Directory(sourcePath);

          if (entity is File) {
            syncQueue.add(MapEntry(
              relativePath,
                  () async {
                setState(() {
                  currentSyncItem = 'Copying: $relativePath';
                });
                await Directory(destPath).parent.create(recursive: true);
                await entity.copy(destPath);
              },
            ));
          } else if (entity is Directory) {
            syncQueue.add(MapEntry(
              relativePath,
                  () async {
                setState(() {
                  currentSyncItem = 'Copying directory: $relativePath';
                });
                await Directory(destPath).create(recursive: true);
                await for (var subEntity in entity.list(recursive: true, followLinks: false)) {
                  String subRelativePath = subEntity.path.substring(sourceDir.path.length + 1);
                  if (skipHiddenFolders && subRelativePath.split(Platform.pathSeparator).any((part) => part.startsWith('.'))) {
                    skippedItems.add('Skipped hidden: $subRelativePath');
                    continue;
                  }
                  if (!await _isAccessible(subEntity)) {
                    skippedItems.add('Skipped inaccessible: $subRelativePath');
                    continue;
                  }
                  String subDestPath = '${destDir.path}/$subRelativePath';
                  setState(() {
                    currentSyncItem = 'Copying: $subRelativePath';
                  });
                  if (subEntity is File) {
                    await Directory(subDestPath).parent.create(recursive: true);
                    await subEntity.copy(subDestPath);
                  } else if (subEntity is Directory) {
                    await Directory(subDestPath).create(recursive: true);
                  }
                }
              },
            ));
          }
        } else if (change.startsWith('Update: ')) {
          String relativePath = change.substring(8);
          String sourcePath = '${sourceDir.path}/$relativePath';
          String destPath = '${destDir.path}/$relativePath';
          syncQueue.add(MapEntry(
            relativePath,
                () async {
              setState(() {
                currentSyncItem = 'Updating: $relativePath';
              });
              await File(sourcePath).copy(destPath);
            },
          ));
        } else if (change.startsWith('Delete: ')) {
          String relativePath = change.substring(8);
          String destPath = '${destDir.path}/$relativePath';
          syncQueue.add(MapEntry(
            relativePath,
                () async {
              setState(() {
                currentSyncItem = 'Deleting: $relativePath';
              });
              FileSystemEntity entity = FileSystemEntity.typeSync(destPath) == FileSystemEntityType.file
                  ? File(destPath)
                  : Directory(destPath);
              await entity.delete(recursive: true);
            },
          ));
        }
      }
    }

    int totalTasks = syncQueue.length;
    for (; currentQueueIndex < syncQueue.length; currentQueueIndex++) {
      if (!isSyncing || isPaused) {
        break;
      }
      try {
        await syncQueue[currentQueueIndex].value();
        setState(() {
          progress = totalTasks > 0 ? (currentQueueIndex + 1) / totalTasks : 1.0;
          status = 'Synchronizing... ${(progress * 100).toStringAsFixed(0)}%';
        });
      } catch (e) {
        skippedItems.add('Error processing ${syncQueue[currentQueueIndex].key}: $e');
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (currentQueueIndex >= syncQueue.length && isSyncing && !isPaused) {
      setState(() {
        isSyncing = false;
        isPaused = false;
        status = 'Synchronization complete${skippedItems.isNotEmpty ? " (some items skipped)" : ""}';
        progress = 1.0;
        currentSyncItem = '';
        currentQueueIndex = 0;
      });
    }
  }

  void startSync() async {
    if (sourceFolder == null || destFolder == null) {
      setState(() {
        status = 'Please select both source and destination folders';
      });
      return;
    }

    setState(() {
      isSyncing = true;
      isPaused = false;
      status = 'Synchronizing... ${(progress * 100).toStringAsFixed(0)}%';
      if (currentQueueIndex == 0) {
        currentSyncItem = '';
      }
    });

    try {
      await performSync();
    } catch (e) {
      setState(() {
        isSyncing = false;
        isPaused = false;
        status = 'Error during synchronization: $e';
        currentSyncItem = '';
        currentQueueIndex = 0;
      });
    }
  }

  void togglePauseResume() {
    setState(() {
      if (isPaused) {
        isPaused = false;
        status = 'Synchronizing... ${(progress * 100).toStringAsFixed(0)}%';
        startSync();
      } else {
        isPaused = true;
        status = 'Paused at ${(progress * 100).toStringAsFixed(0)}%';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        width: 750,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                  children: [
                    const TextSpan(
                      text: 'Instructions:\n',
                      style: TextStyle(fontSize: 16, color: Colors.green), // New: Green, larger
                    ),
                    const TextSpan(
                      text:
                      '1. Click "Source Folder" to select the source folder.\n2. Click "Destination Folder" to select the destination folder.\n3. Click "Preview" to see changes before syncing.\n4. Click "Synchronize" to sync folders. Use "Pause" or "Resume" as needed.',
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: chooseSourceFolder,
                    child: const Text('Source Folder'), // New: Simplified
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: chooseDestinationFolder,
                    child: const Text('Destination Folder'), // New: Simplified
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: previewSyncChanges,
                    child: const Text('Preview'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                  children: [
                    const TextSpan(
                      text: 'Source: ',
                      style: TextStyle(fontSize: 16, color: Colors.green),
                    ),
                    TextSpan(text: sourceFolder ?? 'Not selected'),
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                  children: [
                    const TextSpan(
                      text: 'Destination: ',
                      style: TextStyle(fontSize: 16, color: Colors.green),
                    ),
                    TextSpan(text: destFolder ?? 'Not selected'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: skipHiddenFolders,
                    onChanged: (value) {
                      setState(() {
                        skipHiddenFolders = value ?? false;
                      });
                    },
                  ),
                  const Text('Skip hidden folders (e.g., .symlinks)'),
                ],
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                  children: [
                    const TextSpan(
                      text: 'Status: ',
                      style: TextStyle(fontSize: 16, color: Colors.green),
                    ),
                    TextSpan(text: status),
                  ],
                ),
              ),
              if (currentSyncItem.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 40, // New: Reserve space for two lines
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                      children: [
                        const TextSpan(
                          text: 'Current: ',
                          style: TextStyle(fontSize: 16, color: Colors.green),
                        ),
                        TextSpan(text: currentSyncItem),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: isSyncing && isPaused ? null : startSync,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text(
                      'Synchronize',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: isSyncing ? togglePauseResume : null,
                    child: Text(isPaused ? 'Resume' : 'Pause'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => exit(0),
                    child: const Text('Close'),
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    children: [
                      const TextSpan(text: '@ 2025 FoldSync 1.0. All rights reserved. Developed by '),
                      TextSpan(
                        text: 'Nguyễn Đăng Minh Phúc',
                        style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () async {
                            final url = Uri.parse('https://www.gjw.cx/TrEduWict');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}