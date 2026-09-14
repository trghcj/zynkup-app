import 'package:flutter/material.dart';
import 'package:zynkup/core/constants/delhi_colleges.dart';
import 'package:zynkup/core/theme/app_theme.dart';

class CollegePickerSheet extends StatefulWidget {
  final String? initialValue;
  final bool allowNone;

  const CollegePickerSheet({
    super.key,
    this.initialValue,
    this.allowNone = true,
  });

  static Future<String?> show(BuildContext context, {String? initialValue, bool allowNone = true}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CollegePickerSheet(
        initialValue: initialValue,
        allowNone: allowNone,
      ),
    );
  }

  @override
  State<CollegePickerSheet> createState() => _CollegePickerSheetState();
}

class _CollegePickerSheetState extends State<CollegePickerSheet> {
  final _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredList = DelhiColleges.list.where((college) {
      if (_filter.isEmpty) return true;
      return college.toLowerCase().contains(_filter.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select College / University',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose from Delhi universities & colleges',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              style: TextStyle(color: theme.colorScheme.onSurface),
              onChanged: (val) => setState(() => _filter = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search (e.g. MAIT, DTU, NSUT, DU)...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ZynkColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // Optional: "None / Not Specified"
          if (widget.allowNone && _filter.isEmpty)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.block_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              title: Text(
                'None / Not College Specific',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              onTap: () => Navigator.pop(context, ''),
            ),

          const Divider(height: 1),

          // List of colleges
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 44,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No colleges matched "$_filter"',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => Navigator.pop(context, _filter),
                            child: Text(
                              'Use "$_filter" as college name',
                              style: const TextStyle(color: ZynkColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      final isSelected = widget.initialValue == item;

                      return InkWell(
                        onTap: () => Navigator.pop(context, item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? ZynkColors.primary.withValues(alpha: 0.15)
                                    : const Color(0xFFF7FEE7))
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_balance_rounded,
                                size: 20,
                                color: isSelected
                                    ? ZynkColors.primary
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    color: isSelected
                                        ? (isDark ? ZynkColors.primary : const Color(0xFF3F6212))
                                        : theme.colorScheme.onSurface,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: ZynkColors.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
