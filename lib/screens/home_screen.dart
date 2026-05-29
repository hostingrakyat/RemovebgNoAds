import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/strings.dart';
import '../services/recents_store.dart';
import '../widgets/credits_bar.dart';
import 'editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  List<String> _recents = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final list = await RecentsStore.list();
    if (mounted) setState(() => _recents = list);
  }

  Future<void> _pick(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _permissionDenied();
        return;
      }
    }
    try {
      // No maxWidth/maxHeight: keep full original resolution for HD output.
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );
      if (file == null) return;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EditorScreen(imagePath: file.path),
        ),
      );
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('save_failed'))),
        );
      }
    }
  }

  void _permissionDenied() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('permission_needed')),
        action: SnackBarAction(
          label: tr('open_settings'),
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  Future<void> _openRecent(String path) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(imagePath: path),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('app_name')),
        actions: [
          IconButton(
            tooltip: tr('choose_language'),
            icon: const Icon(Icons.translate),
            onPressed: () => setLang(
                appLang.value == AppLang.en ? AppLang.id : AppLang.en),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _BigButton(
                        icon: Icons.photo_library_outlined,
                        label: tr('pick_image'),
                        color: cs.primaryContainer,
                        onColor: cs.onPrimaryContainer,
                        onTap: () => _pick(ImageSource.gallery),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BigButton(
                        icon: Icons.photo_camera_outlined,
                        label: tr('take_photo'),
                        color: cs.tertiaryContainer,
                        onColor: cs.onTertiaryContainer,
                        onTap: () => _pick(ImageSource.camera),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(tr('recent_results'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (_recents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        tr('no_recents'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.outline),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _recents.length,
                    itemBuilder: (context, i) {
                      final path = _recents[i];
                      return GestureDetector(
                        onTap: () => _openRecent(path),
                        onLongPress: () async {
                          await RecentsStore.delete(path);
                          await _refresh();
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            color: cs.surfaceContainerHighest,
                            child: Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const CreditsBar(),
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Icon(icon, size: 44, color: onColor),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: onColor, fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
