import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_toast.dart';
import 'package:zynkup/core/widgets/event_card_widget.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/core/widgets/college_picker_sheet.dart';
import 'package:zynkup/features/events/models/event_model.dart';

class CreateEventScreen extends StatefulWidget {
  final int? clubId;
  const CreateEventScreen({super.key, this.clubId});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _venue = TextEditingController();
  final _imageUrl = TextEditingController();
  final _registrationUrl = TextEditingController();
  final _coHostEmail = TextEditingController();
  final _page = PageController();
  final _picker = ImagePicker();

  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = TimeOfDay.now();
  String _category = 'tech';
  String? _college;
  bool _isInterCollege = false;
  String? _opponentCollege;
  String _matchupType = 'vs';
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
    _registrationUrl.dispose();
    _coHostEmail.dispose();
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
    if (_step == 5) {
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

      final formLink = _registrationUrl.text.trim();

      String? finalCollege = _college;
      if (_isInterCollege && _opponentCollege != null && _opponentCollege!.trim().isNotEmpty) {
        final host = (_college != null && _college!.trim().isNotEmpty) ? _college!.trim() : 'Host Campus';
        final opp = _opponentCollege!.trim();
        finalCollege = _matchupType == 'vs' ? '$host vs $opp' : '$host × $opp';
      }

      await ApiService.createEvent(
        title: _title.text.trim(),
        description: _description.text.trim(),
        venue: _venue.text.trim(),
        college: finalCollege,
        coHostEmail: _coHostEmail.text.trim().isNotEmpty ? _coHostEmail.text.trim().toLowerCase() : null,
        date: dateTime.toUtc().toIso8601String(),
        category: _category,
        imageUrls: images,
        registrationUrl: formLink.isEmpty ? null : formLink,
        registrationUrlType: formLink.isEmpty ? null : 'customUrl',
        clubId: widget.clubId,
      );

      if (!mounted) return;
      ZToast.showSuccess(context, 'Event created', subtitle: 'Your event is ready to be discovered.');
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
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
                            'External Form (Optional)',
                            'Attach a Google Form, Typeform, or custom survey for attendees.',
                            _buildFormLink(),
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
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        children: [
          Text(
            'Step ${_step + 1} of 6',
            style: const TextStyle(
              color: ZynkColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (_step + 1) / 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: ZynkColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepShell(String title, String subtitle, Widget child) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
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
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.60),
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
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: 'Event Title',
            hintText: 'e.g. Syntx Launch 2025',
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Give your event a name' : null,
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _description,
          maxLines: 6,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final selected = await CollegePickerSheet.show(
              context,
              initialValue: _college,
              allowNone: true,
            );
            if (selected != null) {
              setState(() {
                _college = selected.isEmpty ? null : selected;
                if (_college != null && _venue.text.trim().isEmpty) {
                  _venue.text = _college!;
                }
              });
            }
          },
          borderRadius: BorderRadius.circular(ZynkRadius.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(ZynkRadius.lg),
              border: Border.all(
                color: _college != null 
                    ? ZynkColors.primary.withValues(alpha: 0.5) 
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_rounded,
                  color: _college != null 
                      ? ZynkColors.primary 
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'College / University',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _college ?? 'Select Delhi College (optional)',
                        style: TextStyle(
                          color: _college != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                          fontSize: 15,
                          fontWeight: _college != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_college != null)
                  GestureDetector(
                    onTap: () => setState(() => _college = null),
                    child: Icon(
                      Icons.close_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      size: 18,
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Inter-College Competition / Matchup Toggle Card
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(ZynkRadius.lg),
            border: Border.all(
              color: _isInterCollege
                  ? ZynkColors.primary.withValues(alpha: 0.6)
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                value: _isInterCollege,
                onChanged: (val) {
                  setState(() {
                    _isInterCollege = val;
                  });
                },
                activeThumbColor: ZynkColors.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                title: Row(
                  children: [
                    Text(
                      _matchupType == 'vs' ? '⚔️' : '🤝',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Inter-College Event',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'Host a competition (vs) or collaboration (×) with another college',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ),
              if (_isInterCollege) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Matchup Type Selector (vs / ×)
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _matchupType = 'vs'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _matchupType == 'vs'
                                      ? ZynkColors.primary.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _matchupType == 'vs'
                                        ? ZynkColors.primary
                                        : Theme.of(context).colorScheme.outlineVariant,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('⚔️', style: TextStyle(fontSize: 13)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Matchup (vs)',
                                      style: TextStyle(
                                        color: _matchupType == 'vs'
                                            ? ZynkColors.primary
                                            : Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _matchupType = '×'),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _matchupType == '×'
                                      ? ZynkColors.primary.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _matchupType == '×'
                                        ? ZynkColors.primary
                                        : Theme.of(context).colorScheme.outlineVariant,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('🤝', style: TextStyle(fontSize: 13)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Joint / Collab (×)',
                                      style: TextStyle(
                                        color: _matchupType == '×'
                                            ? ZynkColors.primary
                                            : Theme.of(context).colorScheme.onSurface,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Opponent / Partner College Picker
                      InkWell(
                        onTap: () async {
                          final selected = await CollegePickerSheet.show(
                            context,
                            initialValue: _opponentCollege,
                            allowNone: true,
                          );
                          if (selected != null) {
                            setState(() {
                              _opponentCollege = selected.isEmpty ? null : selected;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? ZynkColors.darkSurface2
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _opponentCollege != null
                                  ? ZynkColors.primary.withValues(alpha: 0.5)
                                  : Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.sports_kabaddi_rounded,
                                color: _opponentCollege != null
                                    ? ZynkColors.primary
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _matchupType == 'vs'
                                          ? 'Opponent College'
                                          : 'Partner / Co-Host College',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _opponentCollege ?? 'Select Rival / Partner College',
                                      style: TextStyle(
                                        color: _opponentCollege != null
                                            ? Theme.of(context).colorScheme.onSurface
                                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                                        fontSize: 14,
                                        fontWeight: _opponentCollege != null ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (_opponentCollege != null)
                                GestureDetector(
                                  onTap: () => setState(() => _opponentCollege = null),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    size: 16,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_college != null && _opponentCollege != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: ZynkColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.flash_on_rounded, size: 14, color: ZynkColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Preview: ${Event.extractShortCollegeName(_college!)} ${_matchupType == 'vs' ? 'vs' : '×'} ${Event.extractShortCollegeName(_opponentCollege!)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: ZynkColors.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _coHostEmail,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Partner Co-Host Gmail / Email (Optional)',
                          hintText: 'e.g. partner.lead@gmail.com',
                          helperText: 'Grants ticket scanning & co-management to this Gmail account',
                          helperMaxLines: 2,
                          helperStyle: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                              ? ZynkColors.darkSurface2
                              : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: ZynkColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _venue,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
          decoration: InputDecoration(
            labelText: 'Venue / Hall / Room',
            hintText: 'e.g. Audi 1, Block 5 or Campus Grounds',
            prefixIcon: Icon(
              Icons.location_on_rounded,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
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
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(ZynkRadius.lg),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text('Date', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(_date),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700),
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
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(ZynkRadius.lg),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text('Time', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        _time.format(context),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: categories.map((item) {
        final cat = item.$1;
        final icon = item.$2;
        final selected = _category == cat;

        final chipBg = selected
            ? (isDark
                ? ZynkColors.primary.withValues(alpha: 0.15)
                : const Color(0xFFF7FEE7))
            : Theme.of(context).colorScheme.surface;
        final chipBorder = selected
            ? (isDark ? ZynkColors.primary : const Color(0xFF65A30D))
            : Theme.of(context).colorScheme.outlineVariant;
        final chipContentColor = selected
            ? (isDark ? ZynkColors.primary : const Color(0xFF3F6212))
            : Theme.of(context).colorScheme.onSurface;

        return GestureDetector(
          onTap: () => setState(() => _category = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(ZynkRadius.pill),
              border: Border.all(
                color: chipBorder,
                width: selected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: chipContentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  cat[0].toUpperCase() + cat.substring(1),
                  style: TextStyle(
                    color: chipContentColor,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w600,
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
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(ZynkRadius.lg),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: _pickedBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(ZynkRadius.lg - 1),
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
                          color: ZynkColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cloud_upload_rounded, color: ZynkColors.primary, size: 32),
                      ),
                      const SizedBox(height: 16),
                       Text(
                        'Tap to upload poster',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                       Text(
                        'PNG, JPG up to 5MB',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 12),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 24),
         Center(child: Text('— OR —', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontWeight: FontWeight.w800))),
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

  Widget _buildFormLink() {
    final formUrl = _registrationUrl.text.trim();
    final isValidUrl = formUrl.startsWith('http://') || formUrl.startsWith('https://');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZynkColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: ZynkColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Optional External Form',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Attach a Google Form, Typeform, or custom survey. A dedicated QR code popup will be generated for attendees.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _registrationUrl,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Form / Survey Link (Optional)',
            hintText: 'https://forms.gle/... or https://...',
            prefixIcon: Icon(
              Icons.link_rounded,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (formUrl.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    tooltip: 'Clear',
                    onPressed: () => setState(() => _registrationUrl.clear()),
                  ),
                IconButton(
                  icon: const Icon(Icons.paste_rounded, size: 20),
                  tooltip: 'Paste link',
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      setState(() => _registrationUrl.text = data!.text!.trim());
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (isValidUrl) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ZynkColors.primary.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, color: ZynkColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Live Form QR Preview',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: formUrl,
                    size: 160,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Attendees will be able to scan this QR code or tap to open this form directly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(formUrl), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Test Form Link in Browser'),
                ),
              ],
            ),
          ),
        ] else if (formUrl.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Please enter a valid link starting with http:// or https://',
              style: const TextStyle(
                color: ZynkColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreview() {
    final formLink = _registrationUrl.text.trim();
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
      registrationUrl: formLink.isEmpty ? null : formLink,
      registrationUrlType: formLink.isEmpty ? null : RegistrationUrlType.customUrl,
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
        if (formLink.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ZynkColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZynkColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_2_rounded, color: ZynkColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Form attached: Attendees can view the QR code and tap to fill it out.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: isDark
            ? ZynkColors.darkBg.withValues(alpha: 0.95)
            : Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
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
              label: _step == 5 ? 'Launch Event' : 'Continue',
              icon: _step == 5 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
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