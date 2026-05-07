import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';

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
      _pickedName = file.name;
    });
  }

  void _next() {
    if (_step == 0 && !_formKey.currentState!.validate()) return;
    if (_step == 4) {
      _submit();
      return;
    }
    setState(() => _step += 1);
    _page.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
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
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
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
      if (_imageUrl.text.trim().isNotEmpty) images.add(_imageUrl.text.trim());
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
        const SnackBar(content: Text('Event saved and auto-approved.')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      _show(error.message);
    } catch (_) {
      _show('Could not create event.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      appBar: AppBar(
        title: const Text('Create Event'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _back,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: LinearProgressIndicator(
              value: (_step + 1) / 5,
              color: ZynkColors.primary,
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _BasicStep(title: _title, description: _description),
                  _DetailsStep(
                    venue: _venue,
                    date: _date,
                    time: _time,
                    onDate: _pickDate,
                    onTime: _pickTime,
                  ),
                  _CategoryStep(
                    value: _category,
                    onChanged: (value) => setState(() => _category = value),
                  ),
                  _MediaStep(
                    imageUrl: _imageUrl,
                    pickedBytes: _pickedBytes,
                    onPick: _pickImage,
                  ),
                  _PreviewStep(
                    title: _title,
                    venue: _venue,
                    date: _date,
                    time: _time,
                    category: _category,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ZynkButton(
              label: _step == 4 ? 'Submit' : 'Continue',
              icon: _step == 4
                  ? Icons.check_rounded
                  : Icons.arrow_forward_rounded,
              isLoading: _loading,
              onTap: _next,
            ),
          ),
        ],
      ),
    );
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
}

class _StepShell extends StatelessWidget {
  const _StepShell({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          title,
          style: const TextStyle(
            color: ZynkColors.darkText,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        child,
      ],
    );
  }
}

class _BasicStep extends StatelessWidget {
  const _BasicStep({required this.title, required this.description});
  final TextEditingController title;
  final TextEditingController description;

  @override
  Widget build(BuildContext context) => _StepShell(
    title: 'Basic Info',
    child: Column(
      children: [
        TextFormField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Title required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: description,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Description'),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Description required'
              : null,
        ),
      ],
    ),
  );
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.venue,
    required this.date,
    required this.time,
    required this.onDate,
    required this.onTime,
  });
  final TextEditingController venue;
  final DateTime date;
  final TimeOfDay time;
  final VoidCallback onDate;
  final VoidCallback onTime;

  @override
  Widget build(BuildContext context) => _StepShell(
    title: 'Details',
    child: Column(
      children: [
        TextFormField(
          controller: venue,
          decoration: const InputDecoration(labelText: 'Venue'),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Venue required' : null,
        ),
        const SizedBox(height: 14),
        ListTile(
          onTap: onDate,
          tileColor: ZynkColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Date'),
          subtitle: Text(DateFormat('EEE, MMM d, yyyy').format(date)),
        ),
        const SizedBox(height: 10),
        ListTile(
          onTap: onTime,
          tileColor: ZynkColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Time'),
          subtitle: Text(time.format(context)),
        ),
      ],
    ),
  );
}

class _CategoryStep extends StatelessWidget {
  const _CategoryStep({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const categories = ['tech', 'cultural', 'sports', 'workshop', 'seminar'];
    return _StepShell(
      title: 'Category',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: categories
            .map(
              (item) => ChoiceChip(
                selected: value == item,
                label: Text(item[0].toUpperCase() + item.substring(1)),
                onSelected: (_) => onChanged(item),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MediaStep extends StatelessWidget {
  const _MediaStep({
    required this.imageUrl,
    required this.pickedBytes,
    required this.onPick,
  });
  final TextEditingController imageUrl;
  final Uint8List? pickedBytes;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => _StepShell(
    title: 'Media',
    child: Column(
      children: [
        TextFormField(
          controller: imageUrl,
          decoration: const InputDecoration(
            labelText: 'Banner image URL (optional)',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.upload_rounded),
          label: Text(
            pickedBytes == null ? 'Upload banner' : 'Banner selected',
          ),
        ),
      ],
    ),
  );
}

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({
    required this.title,
    required this.venue,
    required this.date,
    required this.time,
    required this.category,
  });
  final TextEditingController title;
  final TextEditingController venue;
  final DateTime date;
  final TimeOfDay time;
  final String category;

  @override
  Widget build(BuildContext context) => _StepShell(
    title: 'Preview',
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ZynkColors.darkSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ZynkColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryBadge(category),
          const SizedBox(height: 12),
          Text(
            title.text.isEmpty ? 'Untitled event' : title.text,
            style: const TextStyle(
              color: ZynkColors.darkText,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            venue.text.isEmpty ? 'Venue not set' : venue.text,
            style: const TextStyle(color: ZynkColors.darkMuted),
          ),
          const SizedBox(height: 8),
          Text(
            '${DateFormat('MMM d').format(date)} at ${time.format(context)}',
            style: const TextStyle(
              color: ZynkColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Event -> Saved -> Auto Approved',
            style: TextStyle(color: ZynkColors.darkMuted),
          ),
        ],
      ),
    ),
  );
}
