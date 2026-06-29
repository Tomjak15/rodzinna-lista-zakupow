import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_scope.dart';
import '../models/entities.dart';
import '../services/nutrition_photo_picker.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  String? _selectedMemberId;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final currentMember = appState.data.currentMember;
    final visibleMembers = appState.isFamilyCreator
        ? appState.data.activeMembers
        : [if (currentMember != null) currentMember];
    final selectedMember = _selectedVisibleMember(
      visibleMembers,
      currentMember,
    );

    if (selectedMember == null) {
      return const Center(
        child: Text('Najpierw utwórz rodzinę albo dołącz do rodziny.'),
      );
    }

    final entries = appState
        .nutritionEntriesForDate(_selectedDate)
        .where((entry) => entry.memberId == selectedMember.id)
        .toList();
    final trainingEntries = appState
        .trainingEntriesForDate(_selectedDate)
        .where((entry) => entry.memberId == selectedMember.id)
        .toList();
    final goal = appState.nutritionGoalForMember(selectedMember.id);
    final calories = entries.fold<int>(0, (sum, entry) => sum + entry.calories);
    final protein = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.protein,
    );
    final fat = entries.fold<double>(0, (sum, entry) => sum + entry.fat);
    final carbs = entries.fold<double>(0, (sum, entry) => sum + entry.carbs);
    final trainingMinutes = trainingEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.durationMinutes,
    );
    final isOwnProfile = selectedMember.id == currentMember?.id;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _DateHeader(
          date: _selectedDate,
          onDateChanged: (date) => setState(() => _selectedDate = date),
        ),
        const SizedBox(height: 12),
        if (appState.isFamilyCreator && visibleMembers.length > 1) ...[
          _MemberSelector(
            members: visibleMembers,
            selectedMember: selectedMember,
            onChanged: (memberId) {
              setState(() => _selectedMemberId = memberId);
            },
          ),
          const SizedBox(height: 12),
        ],
        _GoalCard(
          member: selectedMember,
          calories: calories,
          protein: protein,
          fat: fat,
          carbs: carbs,
          goal: goal,
          canEditGoal: appState.isFamilyCreator,
          onEditGoal: () => _openGoalDialog(selectedMember, goal),
        ),
        const SizedBox(height: 12),
        _NutritionCard(
          entries: entries,
          canAdd: isOwnProfile,
          onAdd: () => _openNutritionDialog(),
          onDelete: isOwnProfile ? appState.deleteNutritionEntry : null,
        ),
        const SizedBox(height: 12),
        _TrainingCard(
          entries: trainingEntries,
          totalMinutes: trainingMinutes,
          canAdd: isOwnProfile || appState.isFamilyCreator,
          canDelete: isOwnProfile || appState.isFamilyCreator,
          onAdd: () => _openTrainingDialog(selectedMember),
          onDelete: appState.deleteTrainingEntry,
        ),
      ],
    );
  }

  Member? _selectedVisibleMember(List<Member> members, Member? currentMember) {
    if (members.isEmpty) {
      return null;
    }
    for (final member in members) {
      if (member.id == _selectedMemberId) {
        return member;
      }
    }
    if (currentMember != null) {
      for (final member in members) {
        if (member.id == currentMember.id) {
          return member;
        }
      }
    }
    return members.first;
  }

  Future<void> _openGoalDialog(Member member, NutritionGoal? goal) async {
    final draft = await showDialog<_NutritionGoalDraft>(
      context: context,
      builder: (_) => _NutritionGoalDialog(member: member, goal: goal),
    );
    if (draft == null || !mounted) {
      return;
    }
    try {
      await AppScope.of(context).saveNutritionGoal(
        memberId: member.id,
        dailyCalories: draft.dailyCalories,
        dailyProtein: draft.dailyProtein,
        dailyFat: draft.dailyFat,
        dailyCarbs: draft.dailyCarbs,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showError(error.toString());
    }
  }

  Future<void> _openNutritionDialog() async {
    final recipes =
        AppScope.of(context).data.activeRecipes
            .where(
              (recipe) =>
                  recipe.caloriesPerServing > 0 ||
                  recipe.proteinPerServing > 0 ||
                  recipe.fatPerServing > 0 ||
                  recipe.carbsPerServing > 0,
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final draft = await showDialog<_NutritionEntryDraft>(
      context: context,
      builder: (_) =>
          _NutritionEntryDialog(date: _selectedDate, recipes: recipes),
    );
    if (draft == null || !mounted) {
      return;
    }
    final appState = AppScope.of(context);
    if (draft.recipe != null && draft.servingPercent != null) {
      await appState.addNutritionEntryFromRecipe(
        date: _selectedDate,
        recipe: draft.recipe!,
        servingPercent: draft.servingPercent!,
        imageData: draft.imageData,
        imageMimeType: draft.imageMimeType,
      );
      return;
    }
    await appState.addNutritionEntry(
      date: _selectedDate,
      calories: draft.calories,
      protein: draft.protein,
      fat: draft.fat,
      carbs: draft.carbs,
      note: draft.note,
      imageData: draft.imageData,
      imageMimeType: draft.imageMimeType,
    );
  }

  Future<void> _openTrainingDialog(Member member) async {
    final draft = await showDialog<_TrainingEntryDraft>(
      context: context,
      builder: (_) => _TrainingEntryDialog(date: _selectedDate, member: member),
    );
    if (draft == null || !mounted) {
      return;
    }
    try {
      await AppScope.of(context).addTrainingEntry(
        memberId: member.id,
        date: _selectedDate,
        durationMinutes: draft.durationMinutes,
        activity: draft.activity,
        note: draft.note,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showError(error.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.onDateChanged});

  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = List.generate(
      15,
      (index) => today.add(Duration(days: index - 5)),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _fullDate(date),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Wybierz datę',
                  onPressed: () => _pickDate(context),
                  icon: const Icon(Icons.calendar_today),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final day = days[index];
                  final selected = DateUtils.isSameDay(day, date);
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) => onDateChanged(day),
                    label: SizedBox(
                      width: 54,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_shortDayName(day)),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('dd.MM').format(day),
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      onDateChanged(DateUtils.dateOnly(picked));
    }
  }
}

class _MemberSelector extends StatelessWidget {
  const _MemberSelector({
    required this.members,
    required this.selectedMember,
    required this.onChanged,
  });

  final List<Member> members;
  final Member selectedMember;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedMember.id,
      decoration: const InputDecoration(
        labelText: 'Osoba',
        prefixIcon: Icon(Icons.person_outline),
      ),
      items: members
          .map(
            (member) =>
                DropdownMenuItem(value: member.id, child: Text(member.name)),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.member,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.goal,
    required this.canEditGoal,
    required this.onEditGoal,
  });

  final Member member;
  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final NutritionGoal? goal;
  final bool canEditGoal;
  final VoidCallback onEditGoal;

  @override
  Widget build(BuildContext context) {
    final calorieGoal = goal?.dailyCalories ?? 0;
    final proteinGoal = goal?.dailyProtein ?? 0;
    final fatGoal = goal?.dailyFat ?? 0;
    final carbsGoal = goal?.dailyCarbs ?? 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zdrowie - ${member.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Prywatne dane zdrowia',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (canEditGoal)
                  IconButton.filledTonal(
                    tooltip: 'Ustaw cel',
                    onPressed: onEditGoal,
                    icon: const Icon(Icons.flag_outlined),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _MetricProgress(
              icon: Icons.local_fire_department_outlined,
              label: 'Kcal',
              value: calories.toDouble(),
              goal: calorieGoal.toDouble(),
              suffix: 'kcal',
            ),
            const SizedBox(height: 14),
            _MetricProgress(
              icon: Icons.fitness_center,
              label: 'Białko',
              value: protein,
              goal: proteinGoal,
              suffix: 'g',
            ),
            const SizedBox(height: 14),
            _MetricProgress(
              icon: Icons.water_drop_outlined,
              label: 'Tłuszcze',
              value: fat,
              goal: fatGoal,
              suffix: 'g',
            ),
            const SizedBox(height: 14),
            _MetricProgress(
              icon: Icons.grain_outlined,
              label: 'Węglowodany',
              value: carbs,
              goal: carbsGoal,
              suffix: 'g',
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({
    required this.entries,
    required this.canAdd,
    required this.onAdd,
    required this.onDelete,
  });

  final List<NutritionEntry> entries;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<NutritionEntry>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Jedzenie',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: canAdd ? onAdd : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const _EmptyInfo(
                icon: Icons.local_fire_department_outlined,
                text: 'Brak wpisów kcal w tym dniu.',
              )
            else
              ...entries.map(
                (entry) =>
                    _NutritionEntryTile(entry: entry, onDelete: onDelete),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({
    required this.entries,
    required this.totalMinutes,
    required this.canAdd,
    required this.canDelete,
    required this.onAdd,
    required this.onDelete,
  });

  final List<TrainingEntry> entries;
  final int totalMinutes;
  final bool canAdd;
  final bool canDelete;
  final VoidCallback onAdd;
  final ValueChanged<TrainingEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trening',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalMinutes == 0
                            ? 'Brak treningu'
                            : '$totalMinutes min w tym dniu',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: canAdd ? onAdd : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const _EmptyInfo(
                icon: Icons.monitor_heart_outlined,
                text: 'Nie zaznaczono treningu w tym dniu.',
              )
            else
              ...entries.map(
                (entry) => _TrainingEntryTile(
                  entry: entry,
                  onDelete: canDelete ? onDelete : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricProgress extends StatelessWidget {
  const _MetricProgress({
    required this.icon,
    required this.label,
    required this.value,
    required this.goal,
    required this.suffix,
  });

  final IconData icon;
  final String label;
  final double value;
  final double goal;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = goal <= 0 ? 0.0 : min(1.0, value / goal).toDouble();
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
          child: Icon(icon),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label)),
                  Text(
                    goal <= 0
                        ? '${_number(value)} $suffix'
                        : '${_number(value)} / ${_number(goal)} $suffix',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
            ],
          ),
        ),
      ],
    );
  }
}

class _NutritionEntryTile extends StatelessWidget {
  const _NutritionEntryTile({required this.entry, required this.onDelete});

  final NutritionEntry entry;
  final ValueChanged<NutritionEntry>? onDelete;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _decodeNutritionImage(entry.imageData) != null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: _NutritionPhotoThumb(
        imageData: entry.imageData,
        fallbackIcon: Icons.local_fire_department_outlined,
        onTap: hasPhoto ? () => _openNutritionPhoto(context, entry) : null,
      ),
      title: Text(
        '${entry.calories} kcal, ${_number(entry.protein)} g białka, '
        '${_number(entry.fat)} g tł., ${_number(entry.carbs)} g węgli',
      ),
      subtitle: entry.note.isEmpty ? null : Text(entry.note),
      trailing: IconButton(
        tooltip: 'Usuń',
        onPressed: onDelete == null ? null : () => onDelete!(entry),
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}

class _NutritionPhotoThumb extends StatelessWidget {
  const _NutritionPhotoThumb({
    required this.imageData,
    required this.fallbackIcon,
    this.onTap,
  });

  final String? imageData;
  final IconData fallbackIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeNutritionImage(imageData);
    if (bytes == null) {
      return Icon(fallbackIcon);
    }
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

void _openNutritionPhoto(BuildContext context, NutritionEntry entry) {
  final bytes = _decodeNutritionImage(entry.imageData);
  if (bytes == null) {
    return;
  }
  showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.note.isEmpty ? 'Zdjecie posilku' : entry.note,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Zamknij',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: InteractiveViewer(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TrainingEntryTile extends StatelessWidget {
  const _TrainingEntryTile({required this.entry, required this.onDelete});

  final TrainingEntry entry;
  final ValueChanged<TrainingEntry>? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.monitor_heart_outlined),
      title: Text('${entry.activity} - ${entry.durationMinutes} min'),
      subtitle: entry.note.isEmpty ? null : Text(entry.note),
      trailing: IconButton(
        tooltip: 'Usuń',
        onPressed: onDelete == null ? null : () => onDelete!(entry),
        icon: const Icon(Icons.delete_outline),
      ),
    );
  }
}

class _EmptyInfo extends StatelessWidget {
  const _EmptyInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _NutritionGoalDialog extends StatefulWidget {
  const _NutritionGoalDialog({required this.member, required this.goal});

  final Member member;
  final NutritionGoal? goal;

  @override
  State<_NutritionGoalDialog> createState() => _NutritionGoalDialogState();
}

class _NutritionGoalDialogState extends State<_NutritionGoalDialog> {
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _fatController;
  late final TextEditingController _carbsController;

  @override
  void initState() {
    super.initState();
    _caloriesController = TextEditingController(
      text: widget.goal?.dailyCalories.toString() ?? '2200',
    );
    _proteinController = TextEditingController(
      text: widget.goal == null ? '120' : _number(widget.goal!.dailyProtein),
    );
    _fatController = TextEditingController(
      text: widget.goal == null ? '70' : _number(widget.goal!.dailyFat),
    );
    _carbsController = TextEditingController(
      text: widget.goal == null ? '250' : _number(widget.goal!.dailyCarbs),
    );
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cel - ${widget.member.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cel kcal',
                  suffixText: 'kcal',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _proteinController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Cel białka',
                  suffixText: 'g',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fatController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Cel tłuszczu',
                  suffixText: 'g',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _carbsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Cel węglowodanów',
                  suffixText: 'g',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(onPressed: _save, child: const Text('Zapisz')),
      ],
    );
  }

  void _save() {
    final calories = _parseInt(_caloriesController.text);
    final protein = _parseDouble(_proteinController.text);
    final fat = _parseDouble(_fatController.text);
    final carbs = _parseDouble(_carbsController.text);
    Navigator.pop(
      context,
      _NutritionGoalDraft(
        dailyCalories: calories,
        dailyProtein: protein,
        dailyFat: fat,
        dailyCarbs: carbs,
      ),
    );
  }
}

class _NutritionEntryDialog extends StatefulWidget {
  const _NutritionEntryDialog({required this.date, required this.recipes});

  final DateTime date;
  final List<Recipe> recipes;

  @override
  State<_NutritionEntryDialog> createState() => _NutritionEntryDialogState();
}

class _NutritionEntryDialogState extends State<_NutritionEntryDialog> {
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _carbsController = TextEditingController();
  final _noteController = TextEditingController();
  final _percentController = TextEditingController(text: '100');
  int _mode = 0;
  String? _recipeId;
  String? _imageData;
  String? _imageMimeType;
  bool _pickingPhoto = false;

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _noteController.dispose();
    _percentController.dispose();
    super.dispose();
  }

  Recipe? get _selectedRecipe {
    if (widget.recipes.isEmpty) {
      return null;
    }
    final id = _recipeId ?? widget.recipes.first.id;
    return widget.recipes.firstWhere(
      (recipe) => recipe.id == id,
      orElse: () => widget.recipes.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Dodaj kcal - ${DateFormat('dd.MM').format(widget.date)}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.recipes.isNotEmpty) ...[
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.edit_outlined),
                      label: Text('Ręcznie'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.restaurant_menu),
                      label: Text('Z przepisu'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (value) =>
                      setState(() => _mode = value.first),
                ),
                const SizedBox(height: 12),
              ],
              if (_mode == 1 && widget.recipes.isNotEmpty)
                _RecipeNutritionPicker(
                  recipes: widget.recipes,
                  selectedRecipe: _selectedRecipe!,
                  percentController: _percentController,
                  onRecipeChanged: (id) => setState(() => _recipeId = id),
                  onPercentChanged: () => setState(() {}),
                )
              else ...[
                TextField(
                  controller: _caloriesController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kcal',
                    suffixText: 'kcal',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _proteinController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Białko',
                    suffixText: 'g',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fatController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Tłuszcze',
                    suffixText: 'g',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _carbsController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Węglowodany',
                    suffixText: 'g',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: 'Opis'),
                ),
              ],
              const SizedBox(height: 12),
              _photoSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(onPressed: _save, child: const Text('Dodaj')),
      ],
    );
  }

  void _save() {
    if (_mode == 1 && widget.recipes.isNotEmpty) {
      final recipe = _selectedRecipe!;
      final percent = max(0.0, _parseDouble(_percentController.text));
      Navigator.pop(
        context,
        _NutritionEntryDraft(
          calories: 0,
          protein: 0,
          fat: 0,
          carbs: 0,
          note: '',
          recipe: recipe,
          servingPercent: percent,
          imageData: _imageData,
          imageMimeType: _imageMimeType,
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _NutritionEntryDraft(
        calories: _parseInt(_caloriesController.text),
        protein: _parseDouble(_proteinController.text),
        fat: _parseDouble(_fatController.text),
        carbs: _parseDouble(_carbsController.text),
        note: _noteController.text.trim(),
        imageData: _imageData,
        imageMimeType: _imageMimeType,
      ),
    );
  }

  Widget _photoSection() {
    final bytes = _decodeNutritionImage(_imageData);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Zdjecie posilku',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (_pickingPhoto)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (bytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: nutritionCameraPhotoSupported && !_pickingPhoto
                  ? () => _pickPhoto(fromGallery: false)
                  : null,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(bytes == null ? 'Aparat' : 'Zmien'),
            ),
            OutlinedButton.icon(
              onPressed: nutritionGalleryPhotoSupported && !_pickingPhoto
                  ? () => _pickPhoto(fromGallery: true)
                  : null,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Galeria'),
            ),
            if (bytes != null)
              IconButton.outlined(
                tooltip: 'Usun zdjecie',
                onPressed: _pickingPhoto
                    ? null
                    : () => setState(() {
                        _imageData = null;
                        _imageMimeType = null;
                      }),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickPhoto({required bool fromGallery}) async {
    if (_pickingPhoto) {
      return;
    }
    setState(() => _pickingPhoto = true);
    try {
      final result = fromGallery
          ? await pickNutritionPhotoFromGallery()
          : await pickNutritionPhotoFromCamera();
      if (!mounted || result == null) {
        return;
      }
      setState(() {
        _imageData = result.imageData;
        _imageMimeType = result.imageMimeType;
      });
    } on NutritionPhotoException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _pickingPhoto = false);
      }
    }
  }
}

class _RecipeNutritionPicker extends StatelessWidget {
  const _RecipeNutritionPicker({
    required this.recipes,
    required this.selectedRecipe,
    required this.percentController,
    required this.onRecipeChanged,
    required this.onPercentChanged,
  });

  final List<Recipe> recipes;
  final Recipe selectedRecipe;
  final TextEditingController percentController;
  final ValueChanged<String> onRecipeChanged;
  final VoidCallback onPercentChanged;

  @override
  Widget build(BuildContext context) {
    final percent = max(0.0, _parseDouble(percentController.text));
    final multiplier = percent / 100;
    final calories = (selectedRecipe.caloriesPerServing * multiplier).round();
    final protein = selectedRecipe.proteinPerServing * multiplier;
    final fat = selectedRecipe.fatPerServing * multiplier;
    final carbs = selectedRecipe.carbsPerServing * multiplier;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          value: selectedRecipe.id,
          decoration: const InputDecoration(
            labelText: 'Co zjadłeś',
            prefixIcon: Icon(Icons.restaurant_menu),
          ),
          items: recipes
              .map(
                (recipe) => DropdownMenuItem(
                  value: recipe.id,
                  child: Text(recipe.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onRecipeChanged(value);
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: percentController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Ile z 1 porcji',
            suffixText: '%',
          ),
          onChanged: (_) => onPercentChanged(),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calculate_outlined),
          title: Text(
            '$calories kcal, ${_number(protein)} g białka, '
            '${_number(fat)} g tł., ${_number(carbs)} g węgli',
          ),
          subtitle: Text(
            '${selectedRecipe.caloriesPerServing} kcal, '
            '${_number(selectedRecipe.proteinPerServing)} g białka, '
            '${_number(selectedRecipe.fatPerServing)} g tł., '
            '${_number(selectedRecipe.carbsPerServing)} g węgli na 1 porcję',
          ),
        ),
      ],
    );
  }
}

class _TrainingEntryDialog extends StatefulWidget {
  const _TrainingEntryDialog({required this.date, required this.member});

  final DateTime date;
  final Member member;

  @override
  State<_TrainingEntryDialog> createState() => _TrainingEntryDialogState();
}

class _TrainingEntryDialogState extends State<_TrainingEntryDialog> {
  final _activityController = TextEditingController(text: 'Trening');
  final _durationController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _activityController.dispose();
    _durationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Trening - ${widget.member.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _activityController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Rodzaj treningu'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Czas',
              suffixText: 'min',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Notatka'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(onPressed: _save, child: const Text('Zapisz')),
      ],
    );
  }

  void _save() {
    Navigator.pop(
      context,
      _TrainingEntryDraft(
        activity: _activityController.text.trim(),
        durationMinutes: _parseInt(_durationController.text),
        note: _noteController.text.trim(),
      ),
    );
  }
}

class _NutritionGoalDraft {
  const _NutritionGoalDraft({
    required this.dailyCalories,
    required this.dailyProtein,
    required this.dailyFat,
    required this.dailyCarbs,
  });

  final int dailyCalories;
  final double dailyProtein;
  final double dailyFat;
  final double dailyCarbs;
}

class _NutritionEntryDraft {
  const _NutritionEntryDraft({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.note,
    this.recipe,
    this.servingPercent,
    this.imageData,
    this.imageMimeType,
  });

  final int calories;
  final double protein;
  final double fat;
  final double carbs;
  final String note;
  final Recipe? recipe;
  final double? servingPercent;
  final String? imageData;
  final String? imageMimeType;
}

class _TrainingEntryDraft {
  const _TrainingEntryDraft({
    required this.activity,
    required this.durationMinutes,
    required this.note,
  });

  final String activity;
  final int durationMinutes;
  final String note;
}

final _nutritionImageCache = <String, Uint8List?>{};
const _nutritionImageCacheLimit = 24;

Uint8List? _decodeNutritionImage(String? imageData) {
  var normalized = imageData?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  final dataUrlSeparator = normalized.indexOf(',');
  if (normalized.startsWith('data:image/') && dataUrlSeparator != -1) {
    normalized = normalized.substring(dataUrlSeparator + 1);
  }
  normalized = normalized.replaceAll(RegExp(r'\s+'), '');
  final cacheKey = '${normalized.length}:${normalized.hashCode}';
  if (_nutritionImageCache.containsKey(cacheKey)) {
    return _nutritionImageCache[cacheKey];
  }

  Uint8List? decoded;
  try {
    decoded = base64Decode(normalized);
  } on FormatException {
    try {
      decoded = base64Url.decode(base64Url.normalize(normalized));
    } on FormatException {
      decoded = null;
    }
  }
  _nutritionImageCache[cacheKey] = decoded;
  while (_nutritionImageCache.length > _nutritionImageCacheLimit) {
    _nutritionImageCache.remove(_nutritionImageCache.keys.first);
  }
  return decoded;
}

int _parseInt(String value) {
  return int.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
}

double _parseDouble(String value) {
  return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
}

String _number(num value) {
  if (value % 1 == 0) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

String _shortDayName(DateTime date) {
  const names = ['Pon', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob', 'Nd'];
  return names[date.weekday - 1];
}

String _fullDate(DateTime date) {
  return DateFormat('dd.MM.yyyy').format(date);
}
