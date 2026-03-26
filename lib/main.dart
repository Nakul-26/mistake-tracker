import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MistakeTrackingApp());
}

class MistakeTrackingApp extends StatelessWidget {
  const MistakeTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mistake Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F6F5C),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F1E8),
        useMaterial3: true,
      ),
      home: const AddMistakePage(),
    );
  }
}

class AddMistakePage extends StatefulWidget {
  const AddMistakePage({super.key});

  @override
  State<AddMistakePage> createState() => _AddMistakePageState();
}

class _AddMistakePageState extends State<AddMistakePage> {
  static const _storageKey = 'saved_mistakes';

  final _formKey = GlobalKey<FormState>();
  final _mistakeController = TextEditingController();
  final _lessonController = TextEditingController();
  final _mistakeFocusNode = FocusNode();
  final _lessonFocusNode = FocusNode();

  bool _isSaving = false;
  List<MistakeEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _mistakeController.dispose();
    _lessonController.dispose();
    _mistakeFocusNode.dispose();
    _lessonFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final preferences = await SharedPreferences.getInstance();
    final savedEntries = preferences.getStringList(_storageKey) ?? const [];
    final entries = savedEntries
        .map(
          (item) =>
              MistakeEntry.fromMap(jsonDecode(item) as Map<String, dynamic>),
        )
        .toList()
        .reversed
        .toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _entries = entries;
    });
  }

  Future<void> _saveEntry() async {
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate() || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final newEntry = MistakeEntry(
      mistake: _mistakeController.text.trim(),
      lesson: _lessonController.text.trim(),
      createdAt: DateTime.now(),
    );

    final updatedEntries = [newEntry, ..._entries];
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _storageKey,
      updatedEntries.reversed
          .map((entry) => jsonEncode(entry.toMap()))
          .toList(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _entries = updatedEntries;
      _isSaving = false;
    });

    _mistakeController.clear();
    _lessonController.clear();
    _formKey.currentState?.reset();
    FocusScope.of(context).requestFocus(_mistakeFocusNode);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mistake saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Mistake'), centerTitle: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Capture it while it is still fresh.',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Write what happened and the lesson to keep the next decision cleaner.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _mistakeController,
                        focusNode: _mistakeFocusNode,
                        autofocus: true,
                        textInputAction: TextInputAction.next,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Mistake',
                          hintText: 'What happened?',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_lessonFocusNode);
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter the mistake.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _lessonController,
                        focusNode: _lessonFocusNode,
                        textInputAction: TextInputAction.done,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Lesson',
                          hintText: 'What will you do instead?',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (_) => _saveEntry(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter the lesson.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isSaving ? null : _saveEntry,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              _isSaving ? 'Saving...' : 'Save Mistake',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Recent saves',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (_entries.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFCF6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE7DCC7)),
                  ),
                  child: Text(
                    'No mistakes saved yet. Add the first one above.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else
                ..._entries
                    .take(5)
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SavedMistakeCard(entry: entry),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedMistakeCard extends StatelessWidget {
  const _SavedMistakeCard({required this.entry});

  final MistakeEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7DCC7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.mistake,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(entry.lesson, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 10),
          Text(
            _formatTimestamp(entry.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at $hour:$minute $period';
  }
}

class MistakeEntry {
  const MistakeEntry({
    required this.mistake,
    required this.lesson,
    required this.createdAt,
  });

  final String mistake;
  final String lesson;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'mistake': mistake,
      'lesson': lesson,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MistakeEntry.fromMap(Map<String, dynamic> map) {
    return MistakeEntry(
      mistake: map['mistake'] as String? ?? '',
      lesson: map['lesson'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
