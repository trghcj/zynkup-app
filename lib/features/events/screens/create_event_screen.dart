import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _venue = TextEditingController();
  final _registrationUrlController = TextEditingController();
  final _imageUrlController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _category = "tech";
  bool _loading = false;

  // ── Registration URL ─────────────────────────────
  RegistrationUrlType _urlType = RegistrationUrlType.googleForm;
  bool _addRegistrationUrl = false;

  // ── Images ───────────────────────────────────────
  // Store as maps {bytes, name} — validated before storing
  final List<Map<String, dynamic>> _pickedImages = [];
  final List<String> _imageUrls = [];
  final ImagePicker _picker = ImagePicker();
  int _imageInputMode = 0; // 0 = file, 1 = url

  final List<Map<String, dynamic>> _categories = [
    {'value': 'tech', 'label': 'Tech', 'icon': Icons.computer_rounded},
    {'value': 'cultural', 'label': 'Cultural', 'icon': Icons.palette_rounded},
    {'value': 'sports', 'label': 'Sports', 'icon': Icons.sports_rounded},
    {'value': 'workshop', 'label': 'Workshop', 'icon': Icons.build_rounded},
    {'value': 'seminar', 'label': 'Seminar', 'icon': Icons.school_rounded},
  ];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _venue.dispose();
    _registrationUrlController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  // ── Pick images — validate magic bytes before storing ─
  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage(imageQuality: 85);
      if (images.isEmpty) return;

      for (final img in images) {
        final bytes = await img.readAsBytes();
        if (!_isValidImageBytes(bytes)) {
          _showError('${img.name}: unsupported format. Use PNG, JPG, or WEBP.');
          continue;
        }
        setState(() => _pickedImages.add({'bytes': bytes, 'name': img.name}));
      }
    } catch (e) {
      _showError('Failed to pick images: $e');
    }
  }

  /// Validate by checking magic bytes — avoids ImageCodecException on web
  bool _isValidImageBytes(Uint8List b) {
    if (b.length < 12) return false;
    // JPEG: FF D8 FF
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;
    // PNG: 89 50 4E 47
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return true;
    // WEBP: RIFF....WEBP
    if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) return true;
    return false;
  }

  void _removePickedImage(int i) => setState(() => _pickedImages.removeAt(i));

  void _addImageUrl() {
    final url = _imageUrlController.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http')) {
      _showError('Enter a valid URL starting with http');
      return;
    }
    setState(() {
      _imageUrls.add(url);
      _imageUrlController.clear();
    });
  }

  void _removeImageUrl(int i) => setState(() => _imageUrls.removeAt(i));

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final dateTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      );

      List<String> uploadedUrls = [];
      for (final img in _pickedImages) {
        final url = await ApiService.uploadImageBytes(
            img['bytes'] as Uint8List, img['name'] as String);
        if (url != null) uploadedUrls.add(url);
      }

      final success = await ApiService.createEvent(
        title: _title.text.trim(),
        description: _description.text.trim(),
        venue: _venue.text.trim(),
        date: dateTime.toIso8601String(),
        category: _category,
        imageUrls: [...uploadedUrls, ..._imageUrls],
        registrationUrl: _addRegistrationUrl
            ? _registrationUrlController.text.trim()
            : null,
        registrationUrlType: _addRegistrationUrl ? _urlType.name : null,
      );

      if (!success) { _showError("Failed to create event"); return; }
      _showSuccess("Event created! Pending approval 🎉");
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showError("Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: ZynkColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(msg),
        ]),
        backgroundColor: ZynkColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ══ 1. EVENT DETAILS ══════════════════
              _sectionLabel('Event Details'),
              const SizedBox(height: 12),
              _field(_title, 'Event Title', Icons.title_rounded),
              const SizedBox(height: 12),
              _field(_description, 'Description', Icons.description_rounded, maxLines: 4),
              const SizedBox(height: 12),
              _field(_venue, 'Venue', Icons.location_on_rounded),
              const SizedBox(height: 24),

              // ══ 2. DATE & TIME ════════════════════
              _sectionLabel('Date & Time'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _datePicker(dark)),
                const SizedBox(width: 12),
                Expanded(child: _timePicker(dark)),
              ]),
              const SizedBox(height: 24),

              // ══ 3. CATEGORY ═══════════════════════
              _sectionLabel('Category'),
              const SizedBox(height: 12),
              _categorySelector(dark),
              const SizedBox(height: 24),

              // ══ 4. IMAGES / POSTERS ═══════════════
              _sectionLabel('Event Images / Posters'),
              const SizedBox(height: 4),
              Text('Upload posters or banners visible to students',
                  style: TextStyle(fontSize: 12,
                      color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),
              const SizedBox(height: 12),

              _toggleTabs(
                selectedIndex: _imageInputMode,
                onChanged: (i) => setState(() => _imageInputMode = i),
                tabs: [(Icons.upload_rounded, 'Upload File'), (Icons.link_rounded, 'Paste URL')],
                dark: dark,
              ),
              const SizedBox(height: 12),

              // File picker
              if (_imageInputMode == 0) ...[
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    height: 100, width: double.infinity,
                    decoration: BoxDecoration(
                      color: dark ? ZynkColors.darkSurface2 : ZynkColors.lightSurf2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ZynkColors.primary.withOpacity(0.45)),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_rounded, color: ZynkColors.primary, size: 28),
                      const SizedBox(height: 6),
                      Text('Tap to pick images',
                          style: TextStyle(color: ZynkColors.primary,
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('PNG, JPG, WEBP',
                          style: TextStyle(fontSize: 11,
                              color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),
                    ]),
                  ),
                ),
                if (_pickedImages.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pickedImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _pickedImages[i]['bytes'] as Uint8List,
                            width: 100, height: 100, fit: BoxFit.cover,
                            // Graceful fallback — bytes already validated, but just in case
                            errorBuilder: (_, __, ___) => Container(
                              width: 100, height: 100,
                              decoration: BoxDecoration(
                                color: ZynkColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.image_rounded,
                                  color: ZynkColors.primary, size: 32),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () => _removePickedImage(i),
                            child: Container(
                              width: 22, height: 22,
                              decoration: const BoxDecoration(
                                  color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ],

              // URL input
              if (_imageInputMode == 1) ...[
                TextFormField(
                  controller: _imageUrlController,
                  decoration: InputDecoration(
                    hintText: 'https://example.com/poster.jpg',
                    prefixIcon: const Icon(Icons.image_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle_rounded, color: ZynkColors.primary),
                      onPressed: _addImageUrl,
                    ),
                  ),
                ),
                if (_imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ..._imageUrls.asMap().entries.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: dark ? ZynkColors.darkSurface : ZynkColors.lightSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
                    ),
                    child: Row(children: [
                      const Icon(Icons.link_rounded, size: 15, color: ZynkColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.value,
                          style: TextStyle(fontSize: 12,
                              color: dark ? ZynkColors.darkText : ZynkColors.lightText),
                          overflow: TextOverflow.ellipsis)),
                      GestureDetector(
                        onTap: () => _removeImageUrl(e.key),
                        child: const Icon(Icons.close_rounded, size: 16, color: ZynkColors.error),
                      ),
                    ]),
                  )),
                ],
              ],

              const SizedBox(height: 24),

              // ══ 5. REGISTRATION QR ════════════════
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _sectionLabel('Registration QR'),
                  const SizedBox(height: 2),
                  Text('Attach a form or link — users scan to register',
                      style: TextStyle(fontSize: 12,
                          color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),
                ])),
                Switch(
                  value: _addRegistrationUrl,
                  onChanged: (v) => setState(() => _addRegistrationUrl = v),
                  activeColor: ZynkColors.primary,
                ),
              ]),

              if (_addRegistrationUrl) ...[
                const SizedBox(height: 14),
                _toggleTabs(
                  selectedIndex: _urlType == RegistrationUrlType.googleForm ? 0 : 1,
                  onChanged: (i) => setState(() => _urlType =
                      i == 0 ? RegistrationUrlType.googleForm : RegistrationUrlType.customUrl),
                  tabs: [(Icons.assignment_rounded, 'Google Form'), (Icons.language_rounded, 'Custom URL')],
                  dark: dark,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _registrationUrlController,
                  keyboardType: TextInputType.url,
                  validator: (v) {
                    if (!_addRegistrationUrl) return null;
                    if (v == null || v.trim().isEmpty) return 'URL required';
                    if (!v.trim().startsWith('http')) return 'Must start with http';
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: _urlType == RegistrationUrlType.googleForm
                        ? 'Google Form URL' : 'Registration Site URL',
                    hintText: _urlType == RegistrationUrlType.googleForm
                        ? 'https://forms.gle/...' : 'https://your-site.com/register',
                    prefixIcon: Icon(_urlType == RegistrationUrlType.googleForm
                        ? Icons.assignment_rounded : Icons.language_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ZynkColors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZynkColors.accent.withOpacity(0.25)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.qr_code_rounded, color: ZynkColors.accent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'A QR code will be generated and shown to students on the event page.',
                      style: TextStyle(fontSize: 12, height: 1.5,
                          color: dark ? ZynkColors.darkText.withOpacity(0.7)
                              : ZynkColors.lightText.withOpacity(0.7)),
                    )),
                  ]),
                ),
              ],

              const SizedBox(height: 32),
              ZynkButton(label: 'Create Event', icon: Icons.add_circle_rounded,
                  isLoading: _loading, onTap: _createEvent),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleTabs({
    required int selectedIndex,
    required ValueChanged<int> onChanged,
    required List<(IconData, String)> tabs,
    required bool dark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? ZynkColors.darkSurface2 : ZynkColors.lightSurf2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
      ),
      child: Row(children: tabs.asMap().entries.map((e) {
        final selected = selectedIndex == e.key;
        return Expanded(child: GestureDetector(
          onTap: () => onChanged(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? ZynkColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(e.value.$1, size: 16,
                  color: selected ? Colors.white
                      : (dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),
              const SizedBox(width: 6),
              Text(e.value.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white
                      : (dark ? ZynkColors.darkMuted : ZynkColors.lightMuted))),
            ]),
          ),
        ));
      }).toList()),
    );
  }

  Widget _sectionLabel(String label) => Text(label.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
          letterSpacing: 1.5, color: ZynkColors.primary));

  Widget _field(TextEditingController c, String label, IconData icon, {int maxLines = 1}) =>
      TextFormField(controller: c, maxLines: maxLines,
          validator: (v) => v!.trim().isEmpty ? 'Required' : null,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)));

  Widget _datePicker(bool dark) => GestureDetector(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: _selectedDate,
            firstDate: DateTime.now(), lastDate: DateTime(2030),
            builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme:
            Theme.of(ctx).colorScheme.copyWith(primary: ZynkColors.primary)), child: child!));
        if (d != null) setState(() => _selectedDate = d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: dark ? ZynkColors.darkSurface2 : ZynkColors.lightSurf2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_rounded, color: ZynkColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(DateFormat('MMM dd').format(_selectedDate),
              style: TextStyle(fontWeight: FontWeight.w600,
                  color: dark ? ZynkColors.darkText : ZynkColors.lightText)),
        ]),
      ));

  Widget _timePicker(bool dark) => GestureDetector(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: _selectedTime,
            builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme:
            Theme.of(ctx).colorScheme.copyWith(primary: ZynkColors.primary)), child: child!));
        if (t != null) setState(() => _selectedTime = t);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: dark ? ZynkColors.darkSurface2 : ZynkColors.lightSurf2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
        ),
        child: Row(children: [
          const Icon(Icons.schedule_rounded, color: ZynkColors.primary, size: 18),
          const SizedBox(width: 8),
          Text(_selectedTime.format(context),
              style: TextStyle(fontWeight: FontWeight.w600,
                  color: dark ? ZynkColors.darkText : ZynkColors.lightText)),
        ]),
      ));

  Widget _categorySelector(bool dark) => Wrap(
      spacing: 8, runSpacing: 8,
      children: _categories.map((cat) {
        final isSelected = _category == cat['value'];
        final color = ZynkColors.forCategory(cat['value'] as String);
        return GestureDetector(
          onTap: () => setState(() => _category = cat['value'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.15)
                  : (dark ? ZynkColors.darkSurface : ZynkColors.lightSurface),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : (dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(cat['icon'] as IconData, size: 16,
                  color: isSelected ? color : (dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),
              const SizedBox(width: 6),
              Text(cat['label'] as String, style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : (dark ? ZynkColors.darkMuted : ZynkColors.lightMuted))),
            ]),
          ),
        );
      }).toList());
}