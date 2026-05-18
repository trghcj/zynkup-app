import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/event_card_widget.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
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
  final _imageUrl = TextEditingController();
  final _page = PageController();
  final _picker = ImagePicker();

  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = TimeOfDay.now();
  String _category = 'tech';
  int _step = 0;
  bool _loading = false;
  Uint8List? _pickedBytes;
  String? _pickedName;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _venue.dispose();
    _imageUrl.dispose();
    _page.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedBytes = bytes;
      _pickedName = file.name.split('/').last.split('\\').last;
    });
  }

  void _next() {
    if (_step == 0 && !_formKey.currentState!.validate()) return;
    if (_step == 1 && (_venue.text.trim().isEmpty)) {
      _show('Please set the venue first.');
      return;
    }
    if (_step == 4) {
      _submit();
      return;
    }
    setState(() => _step += 1);
    _page.animateToPage(
      _step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
    );
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step -= 1);
    _page.animateToPage(
      _step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
    );
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final dateTime = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );

      final images = <String>[];

      if (_imageUrl.text.trim().isNotEmpty) {
        images.add(_imageUrl.text.trim());
      }

      if (_pickedBytes != null && _pickedName != null) {
        final uploaded = await ApiService.uploadImageBytes(
          _pickedBytes!,
          _pickedName!,
        );
        if (uploaded != null) images.add(uploaded);
      }

      await ApiService.createEvent(
        title: _title.text.trim(),
        description: _description.text.trim(),
        venue: _venue.text.trim(),
        date: dateTime.toIso8601String(),
        category: _category,
        imageUrls: images,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created successfully!')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      _show(error.message);
    } catch (e) {
      _show('Could not create event. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(context: context, initialTime: _time);
    if (value != null) setState(() => _time = value);
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: ZynkColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZynkColors.darkBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Host an Event'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _back,
              )
            : const SizedBox.shrink(),
      ),
      body: ZynkBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildStepper(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: PageView(
                    controller: _page,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStepShell(
                        'What are we calling it?',
                        'Make it catchy and descriptive.',
                        _buildBasics(),
                      ),
                      _buildStepShell(
                        'When & Where?',
                        'Set the time and location.',
                        _buildDetails(),
                      ),
                      _buildStepShell(
                        'What kind of event?',
                        'Categorize to help students find it.',
                        _buildCategory(),
                      ),
                      _buildStepShell(
                        'Make it pop',
                        'Upload a banner or poster for the event.',
                        _buildMedia(),
                      ),
                      _buildStepShell(
                        'Review & Launch',
                        'Here is how your event will look.',
                        _buildPreview(),
                      ),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Row(
        children: List.generate(5, (index) {
          final active = _step >= index;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.only(right: index == 4 ? 0 : 8),
              height: 4,
              decoration: BoxDecoration(
                color: active
                    ? ZynkColors.gold
                    : ZynkColors.darkSurface2,
                borderRadius: BorderRadius.circular(2),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: ZynkColors.gold.withValues(alpha: 0.5),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepShell(String title, String subtitle, Widget child) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        Text(
          title,
          style: const TextStyle(
            color: ZynkColors.offWhite,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: ZynkColors.darkMuted.withValues(alpha: 0.8),
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 32),
        child,
      ],
    );
  }

  Widget _buildBasics() {
    return Column(
      children: [
        TextFormField(
          controller: _title,
          style: const TextStyle(color: ZynkColors.offWhite, fontSize: 18, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            labelText: 'Event Title',
            hintText: 'e.g. Syntx Launch 2025',
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Give your event a name' : null,
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _description,
          maxLines: 6,
          style: const TextStyle(color: ZynkColors.offWhite, fontSize: 15),
          decoration: const InputDecoration(
            labelText: 'Event Description',
            hintText: 'What is this event about? Who should attend?',
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
        ),
      ],
    );
  }

  Widget _buildDetails() {
    return Column(
      children: [
        TextFormField(
          controller: _venue,
          style: const TextStyle(color: ZynkColors.offWhite, fontSize: 16),
          decoration: const InputDecoration(
            labelText: 'Venue / Location',
            prefixIcon: Icon(Icons.location_on_rounded, color: ZynkColors.darkMuted),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ZynkColors.darkSurface,
                    borderRadius: BorderRadius.circular(ZynkRadius.lg),
                    border: Border.all(color: ZynkColors.darkBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date', style: TextStyle(color: ZynkColors.darkMuted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(_date),
                        style: const TextStyle(color: ZynkColors.offWhite, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: _pickTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ZynkColors.darkSurface,
                    borderRadius: BorderRadius.circular(ZynkRadius.lg),
                    border: Border.all(color: ZynkColors.darkBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Time', style: TextStyle(color: ZynkColors.darkMuted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        _time.format(context),
                        style: const TextStyle(color: ZynkColors.offWhite, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategory() {
    const categories = [
      ('tech', Icons.computer_rounded),
      ('cultural', Icons.theater_comedy_rounded),
      ('sports', Icons.sports_basketball_rounded),
      ('workshop', Icons.build_rounded),
      ('seminar', Icons.record_voice_over_rounded),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: categories.map((item) {
        final cat = item.$1;
        final icon = item.$2;
        final selected = _category == cat;
        return GestureDetector(
          onTap: () => setState(() => _category = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: selected ? ZynkGradients.forCategory(cat) : null,
              color: selected ? null : ZynkColors.darkSurface,
              borderRadius: BorderRadius.circular(ZynkRadius.pill),
              border: Border.all(
                color: selected ? Colors.transparent : ZynkColors.darkBorder,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: ZynkColors.forCategory(cat).withValues(alpha: 0.3), blurRadius: 12)]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: selected ? Colors.white : ZynkColors.darkMuted, size: 20),
                const SizedBox(width: 8),
                Text(
                  cat[0].toUpperCase() + cat.substring(1),
                  style: TextStyle(
                    color: selected ? Colors.white : ZynkColors.darkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMedia() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: ZynkColors.darkSurface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(ZynkRadius.xl),
              border: Border.all(color: ZynkColors.gold.withValues(alpha: 0.3), style: BorderStyle.solid, width: 2),
            ),
            child: _pickedBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(ZynkRadius.xl - 2),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(_pickedBytes!, fit: BoxFit.cover),
                        Container(color: Colors.black45),
                        const Center(
                          child: Icon(Icons.edit_rounded, color: Colors.white, size: 32),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ZynkColors.gold.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.cloud_upload_rounded, color: ZynkColors.gold, size: 32),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tap to upload poster',
                        style: TextStyle(color: ZynkColors.offWhite, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'PNG, JPG up to 5MB',
                        style: TextStyle(color: ZynkColors.darkMuted, fontSize: 12),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),
        const Center(child: Text('— OR —', style: TextStyle(color: ZynkColors.darkMuted, fontWeight: FontWeight.w800))),
        const SizedBox(height: 24),
        TextFormField(
          controller: _imageUrl,
          decoration: const InputDecoration(
            labelText: 'Paste image URL instead',
            prefixIcon: Icon(Icons.link_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    // Generate a mock event to render via the real EventCardWidget
    final mockEvent = Event(
      id: 'mock',
      title: _title.text.isEmpty ? 'Untitled Event' : _title.text,
      description: _description.text,
      venue: _venue.text.isEmpty ? 'TBA' : _venue.text,
      date: DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute,
      ),
      category: EventCategory.values.firstWhere(
        (e) => e.name == _category,
        orElse: () => EventCategory.tech,
      ),
      organizerId: 'mock',
      attendeeCount: 0,
      imageUrls: _imageUrl.text.isNotEmpty ? [_imageUrl.text] : [],
      registeredUsers: [],
      isRegistered: false,
    );

    return Column(
      children: [
        const Text(
          'This is how your event will appear on the feed.',
          style: TextStyle(color: ZynkColors.darkMuted),
        ),
        const SizedBox(height: 24),
        PointerInterceptor( // Prevents clicks on the mock card
          child: EventCardWidget(
            event: mockEvent,
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: ZynkColors.darkBg.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: ZynkColors.darkBorder.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            Expanded(
              child: ZynkButton(
                label: 'Back',
                outlined: true,
                onTap: _back,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: 2,
            child: ZynkButton(
              label: _step == 4 ? 'Launch Event' : 'Continue',
              icon: _step == 4 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
              isLoading: _loading,
              onTap: _next,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to prevent tap events from hitting the mock preview card
class PointerInterceptor extends StatelessWidget {
  final Widget child;
  const PointerInterceptor({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: child);
  }
}