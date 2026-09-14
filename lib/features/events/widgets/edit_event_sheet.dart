import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/theme/theme_provider.dart';
import 'package:zynkup/core/widgets/zynk_toast.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class EditEventSheet extends StatefulWidget {
  final Event event;
  const EditEventSheet({super.key, required this.event});

  @override
  State<EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends State<EditEventSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _venueController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _category;
  String? _existingImageUrl;

  final _picker = ImagePicker();
  bool _loading = false;

  Uint8List? _imageBytes;
  String? _imageName;

  static const _categories = [
    ('tech', Icons.computer_rounded, 'Tech'),
    ('cultural', Icons.theater_comedy_rounded, 'Cultural'),
    ('sports', Icons.sports_basketball_rounded, 'Sports'),
    ('workshop', Icons.build_rounded, 'Workshop'),
    ('seminar', Icons.record_voice_over_rounded, 'Seminar'),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController = TextEditingController(text: widget.event.description);
    _venueController = TextEditingController(text: widget.event.venue);
    _selectedDate = widget.event.date;
    _selectedTime = TimeOfDay.fromDateTime(widget.event.date);
    _category = widget.event.category.name.toLowerCase();
    _existingImageUrl = widget.event.imageUrls.isNotEmpty ? widget.event.imageUrls.first : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageName = file.name.split('/').last.split('\\').last;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      String? imageUrl = _existingImageUrl;
      if (_imageBytes != null && _imageName != null) {
        imageUrl = await ApiService.uploadImageBytes(_imageBytes!, _imageName!);
      }

      final combined = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final eventId = int.parse(widget.event.id);
      final updatedData = await ApiService.updateEvent(
        eventId: eventId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        venue: _venueController.text.trim(),
        date: combined.toIso8601String(),
        category: _category,
        imageUrls: imageUrl != null ? [imageUrl] : null,
      );

      if (!mounted) return;
      ZToast.showSuccess(context, 'Event Updated', subtitle: 'Changes saved successfully.');
      Navigator.pop(context, updatedData);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: ZynkColors.error),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update event. Please try again.'), backgroundColor: ZynkColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeProvider.isDark;
    final maxH = MediaQuery.of(context).size.height * 0.9;
    final dateFormat = DateFormat('EEE, MMM d, yyyy');

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: isDark ? ZynkColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle & Header
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Edit Event',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0E1117),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.white60 : Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Image
                    Text(
                      'Event Banner / Poster',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                          ),
                          image: _imageBytes != null
                              ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                              : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(_existingImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  (_imageBytes != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty))
                                      ? 'Change Poster'
                                      : 'Add Event Poster',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Event Title
                    Text(
                      'Event Title',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0E1117)),
                      decoration: InputDecoration(
                        hintText: 'e.g. Hackathon 2026',
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: ZynkColors.primary, width: 1.5),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter an event title' : null,
                    ),

                    const SizedBox(height: 20),

                    // Venue
                    Text(
                      'Venue / Location',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _venueController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0E1117)),
                      decoration: InputDecoration(
                        hintText: 'e.g. Main Auditorium or Online (Zoom)',
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: ZynkColors.primary, width: 1.5),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a venue' : null,
                    ),

                    const SizedBox(height: 20),

                    // Date & Time Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month_rounded, size: 18, color: ZynkColors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          dateFormat.format(_selectedDate),
                                          style: TextStyle(
                                            color: isDark ? Colors.white : const Color(0xFF0E1117),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Time',
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _pickTime,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.schedule_rounded, size: 18, color: ZynkColors.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _selectedTime.format(context),
                                          style: TextStyle(
                                            color: isDark ? Colors.white : const Color(0xFF0E1117),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Category
                    Text(
                      'Category',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _category == cat.$1;
                        final color = ZynkColors.forCategory(cat.$1);
                        return ChoiceChip(
                          avatar: Icon(
                            cat.$2,
                            size: 16,
                            color: isSelected ? Colors.black : (isDark ? Colors.white70 : const Color(0xFF475569)),
                          ),
                          label: Text(
                            cat.$3,
                            style: TextStyle(
                              color: isSelected ? Colors.black : (isDark ? Colors.white : const Color(0xFF0E1117)),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: color,
                          backgroundColor: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? color
                                  : (isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          onSelected: (_) => setState(() => _category = cat.$1),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Description
                    Text(
                      'Description',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0E1117)),
                      decoration: InputDecoration(
                        hintText: 'Provide details about the schedule, requirements, speakers, etc.',
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: ZynkColors.primary, width: 1.5),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a description' : null,
                    ),

                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ZynkButton(
                        label: _loading ? 'Saving...' : 'Save Changes',
                        icon: Icons.check_rounded,
                        onTap: _loading ? null : _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
