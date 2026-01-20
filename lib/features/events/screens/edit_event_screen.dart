// lib/features/events/screens/edit_event_screen.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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

  /// Existing images
  List<String> _existingImages = [];

  /// New images
  List<XFile> _newImages = [];
  List<Uint8List> _newWebImages = [];

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.event.title);
    _descriptionController =
        TextEditingController(text: widget.event.description);
    _venueController = TextEditingController(text: widget.event.venue);

    _selectedDate = widget.event.date;
    _selectedTime = TimeOfDay.fromDateTime(widget.event.date);
    _selectedCategory = widget.event.category;

    _existingImages = List<String>.from(widget.event.imageUrls);
  }

  // ================= PICK NEW IMAGES =================
  Future<void> _pickNewImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 75);
    if (images.isEmpty) return;

    _newImages = images;
    _newWebImages.clear();

    if (kIsWeb) {
      for (final img in images) {
        _newWebImages.add(await img.readAsBytes());
      }
    }

    setState(() {});
  }

  // ================= DELETE EXISTING IMAGE =================
  Future<void> _deleteExistingImage(int index) async {
    if (_existingImages.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one image is required')),
      );
      return;
    }

    final url = _existingImages[index];

    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
      setState(() => _existingImages.removeAt(index));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete image: $e')),
      );
    }
  }

  // ================= UPLOAD NEW IMAGES =================
  Future<List<String>> _uploadNewImages(String eventId) async {
    final storage = FirebaseStorage.instance;
    List<String> urls = [];

    for (int i = 0; i < _newImages.length; i++) {
      final ref = storage.ref(
        'event_images/$eventId/new_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
      );

      if (kIsWeb) {
        await ref.putData(
          _newWebImages[i],
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        await ref.putFile(File(_newImages[i].path));
      }

      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }

  // ================= UPDATE EVENT =================
  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final newImageUrls = await _uploadNewImages(widget.event.id);

      final updatedEvent = widget.event.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        venue: _venueController.text.trim(),
        date: updatedDateTime,
        category: _selectedCategory,
        imageUrls: [..._existingImages, ...newImageUrls],
      );

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .update(updatedEvent.toFirestore());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event updated successfully ✅'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _imageCarousel(),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add More Images'),
                    onPressed: _pickNewImages,
                  ),

                  const SizedBox(height: 20),

                  _field(_titleController, 'Title'),
                  _field(_descriptionController, 'Description', maxLines: 3),
                  _field(_venueController, 'Venue'),

                  const SizedBox(height: 16),
                  _dateTimeRow(),
                  const SizedBox(height: 16),
                  _categoryDropdown(),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('UPDATE EVENT'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= WIDGETS =================

  Widget _imageCarousel() {
    final totalImages = _existingImages.length + _newImages.length;

    if (totalImages == 0) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        color: Colors.grey.shade200,
        child: const Text('No images'),
      );
    }

    return SizedBox(
      height: 220,
      child: PageView.builder(
        itemCount: totalImages,
        itemBuilder: (_, index) {
          final isExisting = index < _existingImages.length;

          return Stack(
            children: [
              isExisting
                  ? Image.network(
                      _existingImages[index],
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : kIsWeb
                      ? Image.memory(
                          _newWebImages[index - _existingImages.length],
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : Image.file(
                          File(_newImages[index - _existingImages.length].path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
              if (isExisting)
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteExistingImage(index),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _dateTimeRow() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (d != null) setState(() => _selectedDate = d);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.access_time),
            label: Text(_selectedTime.format(context)),
            onPressed: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (t != null) setState(() => _selectedTime = t);
            },
          ),
        ),
      ],
    );
  }

  Widget _categoryDropdown() {
    return DropdownButtonFormField<EventCategory>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Event Type',
        border: OutlineInputBorder(),
      ),
      items: EventCategory.values
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e.name.toUpperCase()),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _selectedCategory = v!),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
