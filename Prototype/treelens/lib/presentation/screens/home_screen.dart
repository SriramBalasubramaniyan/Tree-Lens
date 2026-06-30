// lib/presentation/screens/home_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:treelens/core/theme/app_theme.dart';
import 'package:treelens/presentation/providers/app_provider.dart';
import 'package:treelens/presentation/screens/result_screen.dart';
import 'package:treelens/presentation/screens/history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _picker = ImagePicker();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required')),
          );
        }
        return;
      }
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null || !mounted) return;

      final provider = context.read<AppProvider>();
      final result = await provider.classify(File(picked.path));

      if (!mounted) return;

      if (result != null) {
        // Success — navigate to result screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
        );
      } else if (provider.classifyState == ClassifyState.rejected) {
        // Rejected by image validator or inference guard — show bottom sheet
        _showRejectionSheet(provider.rejectionMessage ?? 'Could not classify image.');
        provider.resetClassify();
      } else if (provider.errorMessage != null) {
        // Unexpected error — snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
        provider.resetClassify();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open image: $e')),
        );
      }
    }
  }

  void _showRejectionSheet(String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      // Allow the sheet to use up to 85% of screen height before scrolling
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (_) => _RejectionSheet(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;
    final isLoading = provider.classifyState == ClassifyState.loading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // --- App bar ---
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            snap: true,
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.forest_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('TreeLens'),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                onPressed: () => context.read<AppProvider>().toggleTheme(),
                tooltip: 'Toggle theme',
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
                tooltip: 'Scan history',
              ),
              const SizedBox(width: 4),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // --- Hero scan zone ---
                _buildScanHero(context, isLoading, cs),
                const SizedBox(height: 24),

                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: isLoading
                      ? const SizedBox.shrink()
                      : _ActionButtons(
                    key: const ValueKey('action-buttons'),
                    onCamera: () => _pickImage(ImageSource.camera),
                    onGallery: () => _pickImage(ImageSource.gallery),
                  ),
                ),

                // --- Recent scans ---
                if (provider.history.isNotEmpty) ...[
                  _buildRecentSection(context, provider),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanHero(BuildContext context, bool isLoading, ColorScheme cs) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _ForestPatternPainter()),
          ),

          if (isLoading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Container(
                      width: 80 + (_pulseController.value * 10),
                      height: 80 + (_pulseController.value * 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3 + _pulseController.value * 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Identifying species…',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'SpaceGrotesk',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Analysing image quality then running model',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 32),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(begin: const Offset(1, 1), end: const Offset(1.04, 1.04), duration: 2000.ms),
                  const SizedBox(height: 16),
                  const Text(
                    'Identify a tree',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      fontFamily: 'SpaceGrotesk',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Take a photo or choose from gallery',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _buildRecentSection(BuildContext context, AppProvider provider) {
    final recent = provider.history.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent scans',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.2,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...recent.map((scan) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RecentScanCard(scan: scan),
        )),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Rejection bottom sheet ────────────────────────────────────────────────────

class _RejectionSheet extends StatelessWidget {
  final String message;
  const _RejectionSheet({required this.message});

  // Pick icon based on message content
  IconData get _icon {
    if (message.contains('dark')) return Icons.brightness_low_rounded;
    if (message.contains('overexposed') || message.contains('bright')) {
      return Icons.brightness_high_rounded;
    }
    if (message.contains('blurry') || message.contains('blurred')) {
      return Icons.blur_on_rounded;
    }
    if (message.contains('doesn\'t look like') || message.contains('not one of')) {
      return Icons.search_off_rounded;
    }
    return Icons.warning_amber_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      // SingleChildScrollView prevents overflow on small screens.
      // isScrollControlled + maxHeightFraction cap it at 85% screen height
      // (set in _showRejectionSheet).
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 32, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            const Text(
              'Image not accepted',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'SpaceGrotesk',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withOpacity(0.65),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Tips
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tips for a better photo',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.primary,
                      fontFamily: 'SpaceGrotesk',
                    ),
                  ),
                  SizedBox(height: 8),
                  _Tip(icon: Icons.close_fullscreen_rounded, text: 'Get closer — focus on leaves, bark, or the trunk'),
                  _Tip(icon: Icons.wb_sunny_outlined, text: 'Shoot in natural daylight, avoid harsh shadows'),
                  _Tip(icon: Icons.center_focus_strong_outlined, text: 'Tap the screen to focus before capturing'),
                  _Tip(icon: Icons.nature_rounded, text: 'One tree per photo works best'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action buttons ────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _ActionButtons({
    super.key,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onCamera,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Camera'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              style: OutlinedButton.styleFrom(
                textStyle: const TextStyle(
                  inherit: false,
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                  color: AppColors.primary,
                  decoration: TextDecoration.none,
                ),
              ),
              label: const Text('Gallery'),
            ),
          ),
        ],
      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.03, end: 0),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _RecentScanCard extends StatelessWidget {
  final dynamic scan;
  const _RecentScanCard({required this.scan});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(result: scan)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(scan.imagePath),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.image_outlined, size: 24, color: AppColors.textMuted),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${scan.species.emoji} ${scan.species.common}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    scan.species.scientific,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(scan.confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ForestPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    final positions = [
      Offset(size.width * 0.1, size.height * 0.2),
      Offset(size.width * 0.85, size.height * 0.15),
      Offset(size.width * 0.6, size.height * 0.8),
      Offset(size.width * 0.25, size.height * 0.75),
      Offset(size.width * 0.75, size.height * 0.5),
      Offset(size.width * 0.4, size.height * 0.35),
    ];
    final radii = [45.0, 60.0, 50.0, 35.0, 70.0, 40.0];

    for (int i = 0; i < positions.length; i++) {
      canvas.drawCircle(positions[i], radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}