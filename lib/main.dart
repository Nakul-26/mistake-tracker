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
  static const _lastDailyReviewKey = 'last_daily_review_date';

  final _formKey = GlobalKey<FormState>();
  final _mistakeController = TextEditingController();
  final _lessonController = TextEditingController();
  final _mistakeFocusNode = FocusNode();
  final _lessonFocusNode = FocusNode();

  bool _isSaving = false;
  bool _isCheckingDailyReview = false;
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
    final entries = _decodeEntries(savedEntries);

    if (!mounted) {
      return;
    }

    setState(() {
      _entries = entries;
    });

    await _presentDailyReviewIfNeeded(entries);
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
      repeatCount: 0,
    );

    final updatedEntries = [newEntry, ..._entries];
    await _persistEntries(updatedEntries);

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

  List<MistakeEntry> _decodeEntries(List<String> savedEntries) {
    return savedEntries
        .map(
          (item) =>
              MistakeEntry.fromMap(jsonDecode(item) as Map<String, dynamic>),
        )
        .toList()
        .reversed
        .toList();
  }

  Future<void> _persistEntries(List<MistakeEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _storageKey,
      entries.reversed.map((entry) => jsonEncode(entry.toMap())).toList(),
    );
  }

  Future<void> _presentDailyReviewIfNeeded(List<MistakeEntry> entries) async {
    if (_isCheckingDailyReview || entries.isEmpty || !mounted) {
      return;
    }

    _isCheckingDailyReview = true;
    final preferences = await SharedPreferences.getInstance();
    final today = DateUtils.dateOnly(DateTime.now());
    final lastReviewDate = DateTime.tryParse(
      preferences.getString(_lastDailyReviewKey) ?? '',
    );

    if (lastReviewDate != null &&
        DateUtils.isSameDay(DateUtils.dateOnly(lastReviewDate), today)) {
      _isCheckingDailyReview = false;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _isCheckingDailyReview = false;
        return;
      }

      final reviewedEntries = await Navigator.of(context)
          .push<List<MistakeEntry>>(
            MaterialPageRoute(
              builder: (_) => DailyReviewPage(entries: entries),
              fullscreenDialog: true,
            ),
          );

      if (reviewedEntries != null) {
        await _persistEntries(reviewedEntries);
        await preferences.setString(
          _lastDailyReviewKey,
          today.toIso8601String(),
        );

        if (mounted) {
          setState(() {
            _entries = reviewedEntries;
          });
        }
      }

      _isCheckingDailyReview = false;
    });
  }

  Future<void> _markEntryRepeated(MistakeEntry entry) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final updatedEntries = _entries
        .map(
          (currentEntry) => currentEntry.createdAt == entry.createdAt
              ? currentEntry.copyWith(
                  repeatCount: currentEntry.repeatCount + 1,
                  lastRepeatedOn: today,
                )
              : currentEntry,
        )
        .toList(growable: false);

    await _persistEntries(updatedEntries);

    if (!mounted) {
      return;
    }

    setState(() {
      _entries = updatedEntries;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Mistake'),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ViewMistakesPage(
                    entries: _entries,
                    onMarkRepeated: _markEntryRepeated,
                  ),
                ),
              );
            },
            child: const Text('View Mistakes'),
          ),
        ],
      ),
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
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1EC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFCADFD5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start clean before the work starts.',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Run a quick reminder pass before you begin. Your saved lessons become rules to follow in this session.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StartSessionPage(entries: _entries),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Start Session'),
                        ),
                      ),
                    ),
                  ],
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
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ViewMistakesPage(
                          entries: _entries,
                          onMarkRepeated: _markEntryRepeated,
                        ),
                      ),
                    );
                  },
                  child: const Text('View All Mistakes'),
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

class ViewMistakesPage extends StatefulWidget {
  const ViewMistakesPage({
    super.key,
    required this.entries,
    required this.onMarkRepeated,
  });

  final List<MistakeEntry> entries;
  final Future<void> Function(MistakeEntry entry) onMarkRepeated;

  @override
  State<ViewMistakesPage> createState() => _ViewMistakesPageState();
}

class StartSessionPage extends StatelessWidget {
  const StartSessionPage({super.key, required this.entries});

  final List<MistakeEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Start Session'), centerTitle: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: entries.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFCF6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE7DCC7)),
                  ),
                  child: Text(
                    'No rules yet. Save a mistake first, then start a session to review what to avoid.',
                    style: theme.textTheme.bodyLarge,
                  ),
                )
              : Container(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Before you start:',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Read these once before you begin. This is the prevention step, not the post-mortem.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...entries.asMap().entries.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _SessionRuleItem(
                            index: item.key + 1,
                            entry: item.value,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class DailyReviewPage extends StatefulWidget {
  const DailyReviewPage({super.key, required this.entries});

  final List<MistakeEntry> entries;

  @override
  State<DailyReviewPage> createState() => _DailyReviewPageState();
}

class _DailyReviewPageState extends State<DailyReviewPage> {
  late List<MistakeEntry> _initialEntries;
  late List<MistakeEntry> _entries;
  late List<bool?> _answers;

  bool get _isComplete => _answers.every((answer) => answer != null);

  @override
  void initState() {
    super.initState();
    _initialEntries = List<MistakeEntry>.from(widget.entries);
    _entries = List<MistakeEntry>.from(widget.entries);
    _answers = List<bool?>.filled(widget.entries.length, null);
  }

  void _answerQuestion(int index, bool repeatedToday) {
    final today = DateUtils.dateOnly(DateTime.now());
    final entry = _initialEntries[index];

    setState(() {
      _answers[index] = repeatedToday;
      _entries = List<MistakeEntry>.from(_entries);
      _entries[index] = repeatedToday
          ? entry.copyWith(
              repeatCount: entry.repeatCount + 1,
              lastRepeatedOn: today,
            )
          : entry;
    });
  }

  void _finishReview() {
    if (!_isComplete) {
      return;
    }

    Navigator.of(context).pop(_entries);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Review'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Did you repeat any of these today?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Answer each one once. This keeps your mistakes active in memory instead of hidden in a list.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final answer = _answers[index];

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE7DCC7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${index + 1}. ${entry.mistake}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Did you repeat this today?',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: () => _answerQuestion(index, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: answer == true
                                        ? theme.colorScheme.primaryContainer
                                        : null,
                                  ),
                                  child: const Text('Yes'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _answerQuestion(index, false),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: answer == false
                                        ? const Color(0xFFFFFCF6)
                                        : null,
                                  ),
                                  child: const Text('No'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isComplete ? _finishReview : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Finish Review'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewMistakesPageState extends State<ViewMistakesPage> {
  late List<MistakeEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.entries;
  }

  Future<void> _handleMarkRepeated(MistakeEntry entry) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final updatedEntries = _entries
        .map(
          (currentEntry) => currentEntry.createdAt == entry.createdAt
              ? currentEntry.copyWith(
                  repeatCount: currentEntry.repeatCount + 1,
                  lastRepeatedOn: today,
                )
              : currentEntry,
        )
        .toList(growable: false);

    setState(() {
      _entries = updatedEntries;
    });

    await widget.onMarkRepeated(entry);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mistakes List'), centerTitle: false),
      body: SafeArea(
        child: _entries.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFCF6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE7DCC7)),
                  ),
                  child: Text(
                    'No mistakes saved yet. Add one first.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return _MistakeListItem(
                    index: index + 1,
                    entry: entry,
                    onMarkRepeated: () => _handleMarkRepeated(entry),
                  );
                },
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
            'Repeated: ${entry.repeatCount} times',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
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

class _MistakeListItem extends StatelessWidget {
  const _MistakeListItem({
    required this.index,
    required this.entry,
    required this.onMarkRepeated,
  });

  final int index;
  final MistakeEntry entry;
  final VoidCallback onMarkRepeated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7DCC7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index. Mistake: ${entry.mistake}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text('Lesson: ${entry.lesson}', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text(
            'Repeated: ${entry.repeatCount} times',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onMarkRepeated,
            child: const Text('Repeated Today'),
          ),
        ],
      ),
    );
  }
}

class _SessionRuleItem extends StatelessWidget {
  const _SessionRuleItem({required this.index, required this.entry});

  final int index;
  final MistakeEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F1EC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$index',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.lesson,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Watch for: ${entry.mistake}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MistakeEntry {
  const MistakeEntry({
    required this.mistake,
    required this.lesson,
    required this.createdAt,
    required this.repeatCount,
    this.lastRepeatedOn,
  });

  final String mistake;
  final String lesson;
  final DateTime createdAt;
  final int repeatCount;
  final DateTime? lastRepeatedOn;

  MistakeEntry copyWith({
    String? mistake,
    String? lesson,
    DateTime? createdAt,
    int? repeatCount,
    DateTime? lastRepeatedOn,
    bool clearLastRepeatedOn = false,
  }) {
    return MistakeEntry(
      mistake: mistake ?? this.mistake,
      lesson: lesson ?? this.lesson,
      createdAt: createdAt ?? this.createdAt,
      repeatCount: repeatCount ?? this.repeatCount,
      lastRepeatedOn: clearLastRepeatedOn
          ? null
          : lastRepeatedOn ?? this.lastRepeatedOn,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mistake': mistake,
      'lesson': lesson,
      'createdAt': createdAt.toIso8601String(),
      'repeatCount': repeatCount,
      'lastRepeatedOn': lastRepeatedOn?.toIso8601String(),
    };
  }

  factory MistakeEntry.fromMap(Map<String, dynamic> map) {
    return MistakeEntry(
      mistake: map['mistake'] as String? ?? '',
      lesson: map['lesson'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      repeatCount: map['repeatCount'] as int? ?? 0,
      lastRepeatedOn: DateTime.tryParse(map['lastRepeatedOn'] as String? ?? ''),
    );
  }
}
