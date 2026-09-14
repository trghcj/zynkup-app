import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/widgets/zynk_toast.dart';
import 'package:zynkup/core/widgets/zynk_background.dart';
import 'package:zynkup/core/widgets/college_picker_sheet.dart';

class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  String _category = 'tech';
  String? _college;
  bool _loading = false;

  Uint8List? _logoBytes;
  String? _logoName;

  Uint8List? _bannerBytes;
  String? _bannerName;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    setState(() {}); // Trigger rebuild for live preview & validation marks
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _descriptionController.removeListener(_onFormChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _logoBytes = bytes;
      _logoName = file.name.split('/').last.split('\\').last;
    });
  }

  Future<void> _pickBanner() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _bannerBytes = bytes;
      _bannerName = file.name.split('/').last.split('\\').last;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      String? logoUrl;
      String? bannerUrl;

      // Upload files
      if (_logoBytes != null && _logoName != null) {
        logoUrl = await ApiService.uploadImageBytes(_logoBytes!, _logoName!);
      }
      if (_bannerBytes != null && _bannerName != null) {
        bannerUrl = await ApiService.uploadImageBytes(_bannerBytes!, _bannerName!);
      }

      await ApiService.createClub(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        college: _college,
        logoUrl: logoUrl,
        bannerUrl: bannerUrl,
      );

      if (!mounted) return;
      ZToast.showSuccess(context, 'Club created', subtitle: 'Your campus community is live.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not create club. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: ZynkColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 700;
    final isWide = width > 1050;

    final isNameValid = _nameController.text.trim().isNotEmpty;
    final isDescValid = _descriptionController.text.trim().isNotEmpty;

    const categories = [
      ('tech', Icons.computer_rounded),
      ('cultural', Icons.theater_comedy_rounded),
      ('sports', Icons.sports_basketball_rounded),
      ('workshop', Icons.build_rounded),
      ('seminar', Icons.record_voice_over_rounded),
      ('general', Icons.public_rounded),
    ];

    final formElements = <Widget>[
       Text(
        'Start a New Club',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 36,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      const SizedBox(height: 12),
       Text(
        'Unite the campus around shared passions. Create custom logos and banner posters.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 15),
      ),
      const SizedBox(height: 32),

      // SECTION 01
      _buildSectionHeader('01', 'Club Information', isComplete: isNameValid && isDescValid),
      const SizedBox(height: 12),

      _buildLabel('Club Name'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _nameController,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Enter your club name',
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: isNameValid 
              ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20) 
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ZynkColors.primary, width: 1.5),
          ),
        ),
        validator: (v) => v == null || v.trim().isEmpty ? 'Give your club a name' : null,
      ),
      const SizedBox(height: 20),

      _buildLabel('Club Description', isValid: isDescValid),
      const SizedBox(height: 8),
      TextFormField(
        controller: _descriptionController,
        maxLines: 5,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, height: 1.4),
        decoration: InputDecoration(
          hintText: 'Tell students what your club is about...',
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ZynkColors.primary, width: 1.5),
          ),
        ),
        validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
      ),
      const SizedBox(height: 20),

      _buildLabel('College / University (Optional)'),
      const SizedBox(height: 8),
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
            });
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
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
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _college ?? 'Select Delhi college (optional)',
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
      const SizedBox(height: 32),

      // SECTION 02
      _buildSectionHeader('02', 'Category', subtitle: 'Choose the category that best describes your club.', isComplete: true),
      const SizedBox(height: 24),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: categories.map((item) {
          final cat = item.$1;
          final icon = item.$2;
          final selected = _category == cat;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: chipBorder,
                  width: selected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: chipContentColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    cat[0].toUpperCase() + cat.substring(1),
                    style: TextStyle(
                      color: chipContentColor,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 32),

      // SECTION 03
      _buildSectionHeader('03', 'Club Graphics', subtitle: 'Give your club a recognizable identity.', isComplete: _logoBytes != null || _bannerBytes != null),
      const SizedBox(height: 12),

      if (isDesktop)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: _buildMediaPicker(
                title: 'Club Logo',
                icon: Icons.add_photo_alternate_rounded,
                bytes: _logoBytes,
                height: 160,
                onTap: _pickLogo,
                onClear: () => setState(() {
                  _logoBytes = null;
                  _logoName = null;
                }),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: _buildMediaPicker(
                title: 'Club Banner',
                icon: Icons.view_headline_rounded,
                bytes: _bannerBytes,
                height: 160,
                onTap: _pickBanner,
                onClear: () => setState(() {
                  _bannerBytes = null;
                  _bannerName = null;
                }),
              ),
            ),
          ],
        )
      else ...[
        _buildMediaPicker(
          title: 'Club Logo',
          icon: Icons.add_photo_alternate_rounded,
          bytes: _logoBytes,
          height: 160,
          onTap: _pickLogo,
          onClear: () => setState(() {
            _logoBytes = null;
            _logoName = null;
          }),
        ),
        const SizedBox(height: 24),
        _buildMediaPicker(
          title: 'Club Banner',
          icon: Icons.view_headline_rounded,
          bytes: _bannerBytes,
          height: 160,
          onTap: _pickBanner,
          onClear: () => setState(() {
            _bannerBytes = null;
            _bannerName = null;
          }),
        ),
      ],

      const SizedBox(height: 32),

      // Primary Action
      Align(
        alignment: isDesktop ? Alignment.centerRight : Alignment.center,
        child: SizedBox(
          width: isDesktop ? 280 : double.infinity,
          child: ZynkButton(
            label: 'Found Club \u2192',
            icon: null,
            isLoading: _loading,
            onTap: _submit,
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title:  Text(
          'Found a Club',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon:  Icon(Icons.close_rounded, color: Theme.of(context).colorScheme.onSurface, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ZynkBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 1200 : 960),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 40 : 24,
                    vertical: 32,
                  ),
                  children: [
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: formElements,
                            ),
                          ),
                          const SizedBox(width: 64),
                          Expanded(
                            flex: 10,
                            child: Container(
                              margin: const EdgeInsets.only(top: 8),
                              child: _buildLivePreview(),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      ...formElements,
                      if (isDesktop) ...[
                        const SizedBox(height: 48),
                        _buildLivePreview(),
                      ]
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreview() {
    final name = _nameController.text.trim();
    final desc = _descriptionController.text.trim();
    final catName = _category.isEmpty ? 'Category' : _category[0].toUpperCase() + _category.substring(1);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.remove_red_eye_rounded, size: 16, color: ZynkColors.darkMuted),
              const SizedBox(width: 8),
               Text(
                'Live Preview',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Banner
          if (_bannerBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_bannerBytes!, height: 120, width: double.infinity, fit: BoxFit.cover),
            )
          else
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, style: BorderStyle.solid),
              ),
              child: const Center(child: Icon(Icons.view_headline_rounded, color: ZynkColors.darkMuted)),
            ),
          const SizedBox(height: 20),
          // Logo and Name
          Row(
            children: [
              if (_logoBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_logoBytes!, height: 64, width: 64, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: const Center(child: Icon(Icons.group, color: ZynkColors.darkMuted)),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Club Name' : name,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$catName • Campus Club',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Description
          Text(
            desc.isEmpty ? 'Your club description will appear here...' : desc,
            style: TextStyle(
              color: desc.isEmpty
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)
                  : Theme.of(context).colorScheme.onSurface, 
              fontSize: 14, 
              height: 1.4
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String number, String title, {String? subtitle, bool isComplete = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              number,
              style: TextStyle(
                color: isComplete
                    ? (Theme.of(context).brightness == Brightness.light
                        ? const Color(0xFF65A30D)
                        : ZynkColors.primary)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isComplete) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).brightness == Brightness.light
                    ? const Color(0xFF65A30D)
                    : ZynkColors.primary,
                size: 14,
              ),
            ]
          ],
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), fontSize: 14)),
        ],
      ],
    );
  }

  Widget _buildLabel(String text, {bool isValid = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        if (isValid) ...[
          const SizedBox(width: 8),
          const Icon(Icons.check, color: Colors.green, size: 16),
        ]
      ],
    );
  }

  Widget _buildMediaPicker({
    required String title,
    required IconData icon,
    required Uint8List? bytes,
    required double height,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: bytes != null
                    ? ZynkColors.primary.withValues(alpha: 0.5)
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: bytes != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.memory(bytes, fit: BoxFit.cover),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'PREVIEW',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap to replace',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onClear,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55), size: 28),
                      const SizedBox(height: 8),
                       Text(
                        'Upload Image',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
