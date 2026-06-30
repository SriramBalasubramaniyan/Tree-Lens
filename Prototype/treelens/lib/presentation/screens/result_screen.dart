// lib/presentation/screens/result_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:treelens/core/constants/app_constants.dart';
import 'package:treelens/core/theme/app_theme.dart';
import 'package:treelens/data/models/scan_result_model.dart';
import 'package:treelens/presentation/providers/app_provider.dart';
import 'package:treelens/presentation/widgets/common_widgets.dart';

class ResultScreen extends StatefulWidget {
  final ScanResult result;
  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late ScanResult _result;
  bool _editingNote = false;
  late TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
    _noteCtrl = TextEditingController(text: _result.note ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    await context.read<AppProvider>().saveNote(_result.id, note);
    setState(() {
      _result = _result.copyWith(note: note);
      _editingNote = false;
    });
  }

  Future<void> _share() async {
    final sp = _result.species;
    final text = '''
🌳 TreeLens Identification

Species: ${sp.common} (${sp.scientific})
Family: ${sp.family}
CO₂ Sequestration: ${sp.co2KgYr.toStringAsFixed(0)} kg/yr
CO₂ Class: ${sp.co2Class}
Height: ${sp.heightM.toStringAsFixed(0)} m | DBH: ${sp.dbhCm.toStringAsFixed(0)} cm
Biome: ${sp.biome}
Confidence: ${(_result.confidence * 100).toStringAsFixed(1)}%
Scanned: ${DateFormat('dd MMM yyyy, h:mm a').format(_result.scannedAt)}

Identified with TreeLens — 100% offline AI
''';
    await Share.share(text, subject: 'Tree: ${sp.common}');
  }

  @override
  Widget build(BuildContext context) {
    final sp = _result.species;
    final cs = Theme.of(context).colorScheme;
    final confident = _result.confidence >= AppConstants.highConfidence;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // --- Hero image ---
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                ),
                onPressed: _share,
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(_result.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: AppColors.primary),
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                  // Species badge at bottom
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                sp.emoji,
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sp.common,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  fontFamily: 'SpaceGrotesk',
                                ),
                              ),
                              Text(
                                sp.scientific,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.75),
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ConfidenceBadge(confidence: _result.confidence),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Body content ---
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Low confidence warning
                if (!confident)
                  _buildLowConfidenceWarning(cs)
                    .animate().fadeIn().slideY(begin: 0.03, end: 0),

                // CO₂ & class
                _buildCarbonCard(sp, cs)
                  .animate().fadeIn(delay: 100.ms).slideY(begin: 0.03, end: 0),
                const SizedBox(height: 16),

                // Key stats grid
                _buildStatsGrid(sp, cs)
                  .animate().fadeIn(delay: 150.ms).slideY(begin: 0.03, end: 0),
                const SizedBox(height: 16),

                // Description
                _buildDescriptionCard(sp, cs)
                  .animate().fadeIn(delay: 200.ms).slideY(begin: 0.03, end: 0),
                const SizedBox(height: 16),

                // Carbon note
                _buildCarbonNote(sp, cs)
                  .animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 16),

                // All predictions
                if (_result.topScores.isNotEmpty)
                  _buildPredictionsCard(cs)
                    .animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 16),

                // Note
                _buildNoteCard(cs)
                  .animate().fadeIn(delay: 350.ms),
                const SizedBox(height: 16),

                // Metadata
                _buildMetaCard(cs)
                  .animate().fadeIn(delay: 400.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowConfidenceWarning(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Low confidence — try a clearer photo of leaves, bark, or the full tree.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF92400E),
                fontFamily: 'SpaceGrotesk',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarbonCard(species, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.co2_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Carbon Sequestration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SpaceGrotesk',
                ),
              ),
              const Spacer(),
              Co2ClassChip(co2Class: species.co2Class),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                species.co2KgYr.toStringAsFixed(0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                  fontFamily: 'SpaceGrotesk',
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'kg CO₂/year',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Range: ${species.co2Min.toStringAsFixed(0)}–${species.co2Max.toStringAsFixed(0)} kg/yr',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          // Simple bar visualisation relative to max (67 = mangrove)
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: species.co2KgYr / 70,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(species, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: StatTile(label: 'Height', value: species.heightM.toStringAsFixed(0), unit: 'm', icon: Icons.height_rounded)),
              Container(width: 1, height: 56, color: Theme.of(context).dividerColor),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: StatTile(label: 'Trunk dia.', value: species.dbhCm.toStringAsFixed(0), unit: 'cm', icon: Icons.circle_outlined),
              )),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Theme.of(context).dividerColor),
          ),
          Row(
            children: [
              Expanded(child: StatTile(label: 'Biome', value: species.biome, icon: Icons.terrain_rounded)),
              Container(width: 1, height: 56, color: Theme.of(context).dividerColor),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: StatTile(label: 'Growth', value: species.growthRate, icon: Icons.trending_up_rounded),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(species, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'About ${species.common}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            species.description,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withOpacity(0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Chip(
            label: Text('Family: ${species.family}'),
            avatar: const Icon(Icons.account_tree_rounded, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildCarbonNote(species, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌿', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Carbon insight',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  species.carbonNote,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryLight,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionsCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Model predictions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ..._result.topScores.asMap().entries.map((e) {
            final score = e.value;
            final isTop = e.key == 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        score.speciesCode,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                          color: isTop ? cs.onSurface : AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(score.score * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isTop ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ConfidenceBar(
                    value: score.score,
                    color: isTop ? AppColors.primary : AppColors.textMuted,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNoteCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Field note',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  if (_editingNote) {
                    _saveNote();
                  } else {
                    setState(() => _editingNote = true);
                  }
                },
                icon: Icon(_editingNote ? Icons.check_rounded : Icons.edit_rounded, size: 14),
                label: Text(_editingNote ? 'Save' : 'Edit'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_editingNote)
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Add your field observation here…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.all(12),
                isDense: true,
              ),
            )
          else if (_result.note != null && _result.note!.isNotEmpty)
            Text(
              _result.note!,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withOpacity(0.8),
                height: 1.5,
              ),
            )
          else
            GestureDetector(
              onTap: () => setState(() => _editingNote = true),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.note_add_outlined, size: 16, color: AppColors.textMuted),
                    SizedBox(width: 8),
                    Text(
                      'Tap to add a field observation',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetaCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scan info',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _MetaRow(
            icon: Icons.access_time_rounded,
            label: 'Scanned',
            value: DateFormat('dd MMM yyyy, h:mm a').format(_result.scannedAt),
          ),
          const SizedBox(height: 8),
          const _MetaRow(
            icon: Icons.memory_rounded,
            label: 'Model',
            value: 'EfficientNetB0 INT8 · On-device',
          ),
          const SizedBox(height: 8),
          const _MetaRow(
            icon: Icons.wifi_off_rounded,
            label: 'Network',
            value: 'No internet used',
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
