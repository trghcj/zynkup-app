import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/core/theme/theme_provider.dart';
import 'package:zynkup/core/widgets/zynk_toast.dart';

class EditClubSheet extends StatefulWidget {
  final Map<String, dynamic> club;
  const EditClubSheet({super.key, required this.club});

  @override
  State<EditClubSheet> createState() => _EditClubSheetState();
}

class _EditClubSheetState extends State<EditClubSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _category;
  String? _existingLogoUrl;
  String? _existingBannerUrl;

  final _picker = ImagePicker();
  bool _loading = false;

  Uint8List? _logoBytes;
  String? _logoName;

  Uint8List? _bannerBytes;
  String? _bannerName;

  static const _categories = [
    ('tech', Icons.computer_rounded, 'Tech'),
    ('cultural', Icons.theater_comedy_rounded, 'Cultural'),
    ('sports', Icons.sports_basketball_rounded, 'Sports'),
    ('workshop', Icons.build_rounded, 'Workshop'),
    ('seminar', Icons.record_voice_over_rounded, 'Seminar'),
    ('general', Icons.groups_rounded, 'General'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.club['name'] ?? '');
    _descriptionController = TextEditingController(text: widget.club['description'] ?? '');
    _category = (widget.club['category'] ?? 'general').toString().toLowerCase();
    _existingLogoUrl = widget.club['logo_url'];
    _existingBannerUrl = widget.club['banner_url'];
  }

  @override
  void dispose() {
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
      String? logoUrl = _existingLogoUrl;
      String? bannerUrl = _existingBannerUrl;

      if (_logoBytes != null && _logoName != null) {
        logoUrl = await ApiService.uploadImageBytes(_logoBytes!, _logoName!);
      }
      if (_bannerBytes != null && _bannerName != null) {
        bannerUrl = await ApiService.uploadImageBytes(_bannerBytes!, _bannerName!);
      }

      final clubId = widget.club['id'] is int ? widget.club['id'] as int : int.parse(widget.club['id'].toString());
      final updatedClub = await ApiService.updateClub(
        clubId: clubId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        logoUrl: logoUrl,
        bannerUrl: bannerUrl,
      );

      if (!mounted) return;
      ZToast.showSuccess(context, 'Club Updated', subtitle: 'Changes saved successfully.');
      Navigator.pop(context, updatedClub);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: ZynkColors.error),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update club. Please try again.'), backgroundColor: ZynkColors.error),
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
                  'Edit Club',
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
                      'Club Banner',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickBanner,
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? ZynkColors.darkSurface2 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? ZynkColors.darkBorder : const Color(0xFFE2E8F0),
                          ),
                          image: _bannerBytes != null
                              ? DecorationImage(
                                  image: MemoryImage(_bannerBytes!),
                                  fit: BoxFit.cover,
                                )
                              : (_existingBannerUrl != null && _existingBannerUrl!.isNotEmpty)
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(_existingBannerUrl!),
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
                                  (_bannerBytes != null || (_existingBannerUrl != null && _existingBannerUrl!.isNotEmpty))
                                      ? 'Change Banner'
                                      : 'Add Banner Image',
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

                    // Logo Image
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _pickLogo,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: isDark ? ZynkColors.darkSurface2 : const Color(0xFFE2E8F0),
                                backgroundImage: _logoBytes != null
                                    ? MemoryImage(_logoBytes!)
                                    : (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty)
                                        ? CachedNetworkImageProvider(_existingLogoUrl!) as ImageProvider
                                        : null,
                                child: (_logoBytes == null && (_existingLogoUrl == null || _existingLogoUrl!.isEmpty))
                                    ? const Icon(Icons.groups_rounded, size: 36, color: ZynkColors.primary)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: ZynkColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Club Logo / Icon',
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0E1117),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to choose a picture representing this community',
                                style: TextStyle(
                                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Club Name
                    Text(
                      'Club Name',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0E1117)),
                      decoration: InputDecoration(
                        hintText: 'e.g. Google Developer Student Club',
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
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a club name' : null,
                    ),

                    const SizedBox(height: 20),

                    // Category
                    Text(
                      'Category / Type',
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
                        hintText: 'What is this club about? What activities do you organize?',
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
