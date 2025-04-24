# FoldSync

FoldSync is a Flutter-based desktop application designed to synchronize files and folders between a source and destination directory. It provides an intuitive interface for previewing changes, skipping hidden folders, and pausing/resuming sync operations, making it ideal for backups, file migrations, or keeping directories in sync.

## Features

- **Folder Synchronization**: Copy, update, or delete files to match the source folder with the destination.
- **Preview Changes**: View planned changes (Copy, Update, Delete, Skip) in a tabbed dialog before syncing.
- **Pause/Resume**: Pause and resume sync operations for large folders without losing progress.
- **Skip Hidden Folders**: Option to exclude hidden folders (e.g., `.git`, `.DS_Store`) during sync.
- **User-Friendly Interface**:
    - Clear instructions for selecting source and destination folders.
    - Green-styled labels for key fields (Instructions, Source, Destination, Status, Current).
    - Fixed button positions to prevent UI jumping during sync.
    - Compact 750x600 non-resizable window with a white background.
- **Cross-Platform**: Built with Flutter for compatibility on macOS, Windows, and Linux.
- **Progress Tracking**: Displays real-time sync progress and current file being processed.

## Screenshots

*(Add screenshots of the FoldSync UI here, e.g., main window, preview dialog. Create an `assets/` folder in the repository and reference images like `![Main Window](assets/main-window.png)`.)*

## Installation

### Prerequisites
- **Flutter SDK**: Version 3.0.0 or higher. Follow the [Flutter installation guide](https://flutter.dev/docs/get-started/install).
- **Dart**: Included with Flutter.
- **Git**: To clone the repository.
- A desktop environment (macOS, Windows, or Linux).

### Steps
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-username/foldsync.git
   cd foldsync
   ```

2. **Install Dependencies**:
   Ensure the `pubspec.yaml` includes:
   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     file_picker: ^6.1.1
     window_manager: ^0.3.7
     url_launcher: ^6.3.0
   ```
   Run:
   ```bash
   flutter pub get
   ```

3. **macOS Configuration**:
    - Open `macos/Runner/Info.plist` and ensure:
      ```xml
      <key>CFBundleName</key>
      <string>FoldSync</string>
      ```
    - Open `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`, and add:
      ```xml
      <key>com.apple.security.files.user-selected.read-write</key>
      <true/>
      ```
    - Grant Full Disk Access to your IDE or Flutter for accessing all folders (System Settings > Privacy & Security > Full Disk Access).

4. **Build and Run**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```
   For a release build:
   ```bash
   flutter build macos
   ```

5. **Windows/Linux**:
    - No additional configuration is needed beyond installing Flutter and dependencies.
    - Run `flutter run` or `flutter build windows`/`flutter build linux` for release builds.

## Usage

1. **Launch FoldSync**:
   Run the app using `flutter run` or open the built executable.

2. **Select Folders**:
    - Click **Source Folder** to choose the source directory.
    - Click **Destination Folder** to choose the destination directory.

3. **Preview Changes**:
    - Click **Preview** to view planned changes in a tabbed dialog (Copy, Update, Delete, Skip).
    - Review changes and close the dialog.

4. **Synchronize**:
    - Click **Synchronize** to start syncing.
    - Monitor progress via the status bar and current file display.
    - Use **Pause** to pause syncing and **Resume** to continue.
    - Check "Skip hidden folders" to exclude hidden files (e.g., `.git`) if needed.

5. **Close**:
    - Click **Close** to exit the application.

**Tips**:
- For large folders, use the Pause/Resume feature to manage sync operations.
- If permission errors occur, grant Full Disk Access (macOS) or check folder permissions (Windows/Linux).
- Long file paths are supported, and the UI ensures buttons remain fixed during sync.

## Contributing

Contributions are welcome! To contribute:
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit changes (`git commit -m "Add your feature"`).
4. Push to the branch (`git push origin feature/your-feature`).
5. Open a Pull Request.

Please ensure code follows Flutter best practices and includes tests where applicable.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

Developed by Nguyễn Đăng Minh Phúc.
- GitHub: [ndmphuc](https://github.com/ndmphuc)
- Website: [https://www.gjw.cx/TrEduWict](https://www.gjw.cx/TrEduWict)

For issues or feature requests, open an issue on the [GitHub repository](https://github.com/ndmphuc/foldsync/issues).

---
*FoldSync © 2025. All rights reserved.*