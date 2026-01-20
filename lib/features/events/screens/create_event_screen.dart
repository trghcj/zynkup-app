// lib/features/events/screens/create_event_screen.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/event_model.dart';
import 'event_preview_screen.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  EventCategory _selectedCategory = EventCategory.tech;

  final ImagePicker _picker = ImagePicker();

  /// Images
  List<XFile> _pickedImages = [];
  List<Uint8List> _webImages = [];

  bool _isLoading = false;

  // ---------------- PICK IMAGES ----------------
  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 75);
    if (images.isEmpty) return;

    _pickedImages = images;
    _webImages.clear();

    if (kIsWeb) {
      for (final img in images) {
        _webImages.add(await img.readAsBytes());
      }
    }

    setState(() {});
  }

  // ---------------- UPLOAD IMAGES ----------------
  Future<List<String>> _uploadImages(String eventId) async {
    final storage = FirebaseStorage.instance;
    final List<String> urls = [];

    for (int i = 0; i < _pickedImages.length; i++) {
      final ref =
          storage.ref().child('event_images/$eventId/image_$i.jpg');

      if (kIsWeb) {
        await ref.putData(
          _webImages[i],
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        await ref.putFile(File(_pickedImages[i].path));
      }

      urls.add(await ref.getDownloadURL());
    }

    return urls;
  }

  // ---------------- PREVIEW ----------------
  void _previewEvent() {
    if (!_formKey.currentState!.validate()) return;

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final previewEvent = Event(
      id: 'preview',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      venue: _venueController.text.trim(),
      date: dateTime,
      category: _selectedCategory,
      organizerId: '',
      registeredUsers: const [],
      imageUrls: const [], // preview screen uses local images
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventPreviewScreen(
          event: previewEvent,
          pickedImages: _pickedImages.map((xfile) => File(xfile.path)).toList(),
          webImages: _webImages,
        ),
      ),
    );
  }

  // ---------------- CREATE EVENT ----------------
  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final docRef =
          FirebaseFirestore.instance.collection('events').doc();

      final imageUrls = await _uploadImages(docRef.id);

      final event = Event(
        id: docRef.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        venue: _venueController.text.trim(),
        date: dateTime,
        category: _selectedCategory,
        organizerId: user.uid,
        registeredUsers: const [],
        imageUrls: imageUrls,
      );

      await docRef.set(event.toFirestore());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event created successfully 🎉'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _imagePicker(),
                  const SizedBox(height: 20),

                  _field(_titleController, 'Title'),
                  _field(_descriptionController, 'Description', maxLines: 3),
                  _field(_venueController, 'Venue'),

                  const SizedBox(height: 16),
                  _dateTimeRow(),
                  const SizedBox(height: 16),
                  _categoryDropdown(),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previewEvent,
                          child: const Text('PREVIEW'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _submitButton()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- WIDGETS ----------------

  Widget _imagePicker() {
    return InkWell(
      onTap: _pickImages,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _pickedImages.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate, size: 42),
                    SizedBox(height: 6),
                    Text('Add Event Images'),
                  ],
                ),
              )
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pickedImages.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.memory(
                            _webImages[i],
                            width: 120,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_pickedImages[i].path),
                            width: 120,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
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

  Widget _submitButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createEvent,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('CREATE EVENT'),
      ),
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
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
