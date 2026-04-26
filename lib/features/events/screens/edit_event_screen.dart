import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import '../models/event_model.dart';

class EditEventScreen extends StatefulWidget {
  final Event event;
  const EditEventScreen({super.key, required this.event});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _venueController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late EventCategory _selectedCategory;

  List<XFile> _newImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  final String baseUrl = "http://127.0.0.1:8000";

  final List<Map<String, dynamic>> _categories = [
    {'value': EventCategory.tech, 'label': 'Tech', 'icon': Icons.computer_rounded},
    {'value': EventCategory.cultural, 'label': 'Cultural', 'icon': Icons.palette_rounded},
    {'value': EventCategory.sports, 'label': 'Sports', 'icon': Icons.sports_rounded},
    {'value': EventCategory.workshop, 'label': 'Workshop', 'icon': Icons.build_rounded},
    {'value': EventCategory.seminar, 'label': 'Seminar', 'icon': Icons.school_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController = TextEditingController(text: widget.event.description);
    _venueController = TextEditingController(text: widget.event.venue);
    _selectedDate = widget.event.date;
    _selectedTime = TimeOfDay.fromDateTime(widget.event.date);
    _selectedCategory = widget.event.category;
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage();
    if (images.isNotEmpty) setState(() => _newImages = images);
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final updatedDateTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      );

      List<String> imageUrls = [];
      for (var img in _newImages) {
        var request = http.MultipartRequest('POST', Uri.parse("$baseUrl/upload"));
        request.files.add(await http.MultipartFile.fromPath('file', img.path));
        var res = await request.send();
        if (res.statusCode == 200) {
          final responseBody = await res.stream.bytesToString();
          final data = jsonDecode(responseBody);
          imageUrls.add(data["url"]);
        }
      }

      final response = await http.put(
        Uri.parse("$baseUrl/events/${widget.event.id}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "title": _titleController.text.trim(),
          "description": _descriptionController.text.trim(),
          "venue": _venueController.text.trim(),
          "date": updatedDateTime.toIso8601String(),
          "category": _selectedCategory.name,
          "image_urls": imageUrls,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Event updated successfully'),
            ]),
            backgroundColor: ZynkColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception("Update failed");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: ZynkColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image Picker ───────────────────────────────
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: dark ? ZynkColors.darkSurface2 : ZynkColors.lightSurf2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _newImages.isNotEmpty
                          ? ZynkColors.primary
                          : (dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
                      width: _newImages.isNotEmpty ? 1.5 : 1,
                    ),
                  ),
                  child: _newImages.isNotEmpty
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image_rounded,
                                color: ZynkColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              '${_newImages.length} image(s) selected',
                              style: const TextStyle(
                                color: ZynkColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 32,
                              color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to update images',
                              style: TextStyle(
                                color: dark ? ZynkColors.darkMuted : ZynkColors.lightMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),
              _sectionLabel('Event Details'),
              const SizedBox(height: 12),

              _field(_titleController, 'Event Title', Icons.title_rounded),
              const SizedBox(height: 12),
              _field(_descriptionController, 'Description',
                  Icons.description_rounded, maxLines: 4),
              const SizedBox(height: 12),
              _field(_venueController, 'Venue', Icons.location_on_rounded),

              const SizedBox(height: 24),
              _sectionLabel('Date & Time'),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: _datePicker(dark)),
                  const SizedBox(width: 12),
                  Expanded(child: _timePicker(dark)),
                ],
              ),

              const SizedBox(height: 24),
              _sectionLabel('Category'),
              const SizedBox(height: 12),
              _categorySelector(dark),

              const SizedBox(height: 32),

              ZynkButton(
                label: 'Update Event',
                icon: Icons.save_rounded,
                isLoading: _isLoading,
                onTap: _updateEvent,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          color: ZynkColors.primary,
        ),
      );

  Widget _field(TextEditingController c, String label, IconData icon,
      {int maxLines = 1}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }

  Widget _datePicker(bool dark) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: ZynkColors.primary),
            ),
            child: child!,
          ),
        );
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
          Text(
            DateFormat('MMM dd, yyyy').format(_selectedDate),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: dark ? ZynkColors.darkText : ZynkColors.lightText,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _timePicker(bool dark) {
    return GestureDetector(
      onTap: () async {
        final t = await showTimePicker(
          context: context,
          initialTime: _selectedTime,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: ZynkColors.primary),
            ),
            child: child!,
          ),
        );
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
          Text(
            _selectedTime.format(context),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: dark ? ZynkColors.darkText : ZynkColors.lightText,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _categorySelector(bool dark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final isSelected = _selectedCategory == cat['value'];
        final color = ZynkColors.forCategory((cat['value'] as EventCategory).name);
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat['value'] as EventCategory),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(0.15)
                  : (dark ? ZynkColors.darkSurface : ZynkColors.lightSurface),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : (dark ? ZynkColors.darkBorder : ZynkColors.lightBorder),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(cat['icon'] as IconData, size: 16,
                    color: isSelected ? color : (dark ? ZynkColors.darkMuted : ZynkColors.lightMuted)),
                const SizedBox(width: 6),
                Text(
                  cat['label'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : (dark ? ZynkColors.darkMuted : ZynkColors.lightMuted),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}