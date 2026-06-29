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
  _HistoryRange _historyRange = _HistoryRange.week;

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

    final memberNutritionEntries = appState.data.activeNutritionEntries
        .where((entry) => entry.memberId == selectedMember.id)
        .toList();
    final memberTrainingEntries = appState.data.activeTrainingEntries
        .where((entry) => entry.memberId == selectedMember.id)
        .toList();
    final entries = appState
        .nutritionEntriesForDate(_selectedDate)
        .where((entry) => entry.memberId == selectedMember.id)
        .toList();
    final trainingEntries = appState
        .trainingEntriesForDate(_selectedDate)
        .where((entry) => entry.memberId == selectedMember.id)
        .toList();
    final goal = appState.nutritionGoalForMember(selectedMember.id);
    final daySummary = _daySummary(
      date: _selectedDate,
      entries: memberNutritionEntries,
      trainingEntries: memberTrainingEntries,
      goal: goal,
    );
    final weekSummary = _weekSummary(
      date: _selectedDate,
      entries: memberNutritionEntries,
      trainingEntries: memberTrainingEntries,
      goal: goal,
    );
    final streak = _streakSummary(
      entries: memberNutritionEntries,
      trainingEntries: memberTrainingEntries,
      goal: goal,
    );
    final achievements = _achievements(
      streak: streak,
      trainingEntries: memberTrainingEntries,
    );
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
        _StreakCard(streak: streak, daySummary: daySummary),
        const SizedBox(height: 12),
        _GoalCard(
          member: selectedMember,
          calories: daySummary.goalCalories,
          protein: daySummary.goalProtein,
          fat: daySummary.goalFat,
          carbs: daySummary.goalCarbs,
          goal: goal,
          canEditGoal: appState.isFamilyCreator,
          onEditGoal: () => _openGoalDialog(selectedMember, goal),
        ),
        const SizedBox(height: 12),
        _GoalDetailsCard(summary: daySummary),
        const SizedBox(height: 12),
        _WeeklyProgressCard(summary: weekSummary),
        const SizedBox(height: 12),
        _WeeklyChartCard(summary: weekSummary),
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
        const SizedBox(height: 12),
        _AchievementCard(achievements: achievements),
        const SizedBox(height: 12),
        _HistoryCard(
          range: _historyRange,
          entries: _historyNutritionEntries(memberNutritionEntries),
          trainingEntries: _historyTrainingEntries(memberTrainingEntries),
          onRangeChanged: (range) => setState(() => _historyRange = range),
        ),
      ],
    );
  }

  List<NutritionEntry> _historyNutritionEntries(List<NutritionEntry> entries) {
    final start = _rangeStart(_historyRange, _selectedDate);
    final end = _rangeEnd(_historyRange, _selectedDate);
    return entries
        .where(
          (entry) =>
              (start == null || !entry.date.isBefore(start)) &&
              (end == null ||
                  entry.date.isBefore(end.add(const Duration(days: 1)))),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<TrainingEntry> _historyTrainingEntries(List<TrainingEntry> entries) {
    final start = _rangeStart(_historyRange, _selectedDate);
    final end = _rangeEnd(_historyRange, _selectedDate);
    return entries
        .where(
          (entry) =>
              (start == null || !entry.date.isBefore(start)) &&
              (end == null ||
                  entry.date.isBefore(end.add(const Duration(days: 1)))),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
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
        dailySteps: draft.dailySteps,
        dailyTrainingMinutes: draft.dailyTrainingMinutes,
        weeklyTrainingMinutes: draft.weeklyTrainingMinutes,
        weeklyTrainingCount: draft.weeklyTrainingCount,
        weeklySteps: draft.weeklySteps,
        weeklyDistanceKm: draft.weeklyDistanceKm,
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
        mealType: draft.mealType,
        isCheatMeal: draft.isCheatMeal,
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
      mealType: draft.mealType,
      isCheatMeal: draft.isCheatMeal,
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
        steps: draft.steps,
        distanceKm: draft.distanceKm,
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

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.daySummary});

  final _StreakSummary streak;
  final _HealthDaySummary daySummary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: daySummary.isComplete
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: const Icon(Icons.local_fire_department),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${streak.current} dni passy',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    daySummary.isComplete
                        ? 'Dzien zaliczony. Rekord: ${streak.best}'
                        : 'Dzisiaj wykonano ${daySummary.completedGoals}/${daySummary.totalGoals} celow',
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 58,
              height: 58,
              child: CircularProgressIndicator(
                value: daySummary.completion.clamp(0.0, 1.0),
                strokeWidth: 7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalDetailsCard extends StatelessWidget {
  const _GoalDetailsCard({required this.summary});

  final _HealthDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final checks = summary.checks.where((check) => check.enabled).toList();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cele na dzis',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (checks.isEmpty)
              const _EmptyInfo(
                icon: Icons.flag_outlined,
                text: 'Brak ustawionych celow.',
              )
            else
              ...checks.map((check) => _GoalCheckRow(check: check)),
          ],
        ),
      ),
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  const _WeeklyProgressCard({required this.summary});

  final _HealthWeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final checks = summary.checks.where((check) => check.enabled).toList();
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
                    'Postep tygodniowy',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${DateFormat('dd.MM').format(summary.weekStart)}-${DateFormat('dd.MM').format(summary.weekEnd)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Raport: ${_number(summary.averageCalories)} kcal srednio, '
              '${summary.trainingCount} treningow, '
              '${summary.trainingMinutes} min, ${summary.steps} krokow, '
              '${summary.goalDays}/7 dni z celem.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (checks.isEmpty)
              const _EmptyInfo(
                icon: Icons.calendar_view_week_outlined,
                text: 'Ustaw cele tygodniowe.',
              )
            else
              ...checks.map((check) => _GoalCheckRow(check: check)),
          ],
        ),
      ),
    );
  }
}

class _WeeklyChartCard extends StatelessWidget {
  const _WeeklyChartCard({required this.summary});

  final _HealthWeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final maxCalories = max(
      1,
      summary.days.fold<int>(
        0,
        (maxValue, day) => max(maxValue, day.totalCalories),
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wykres tygodnia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in summary.days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: day.totalCalories / maxCalories,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: day.isComplete
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.tertiaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(_shortDayName(day.date)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievements});

  final List<_Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Osiagniecia', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...achievements.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(item.icon),
                title: Text(
                  item.done ? '${item.title} - zaliczone' : item.title,
                ),
                subtitle: LinearProgressIndicator(value: item.progress),
                trailing: Text(
                  '${_number(min(item.current, item.target))}/${_number(item.target)} ${item.unit}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.range,
    required this.entries,
    required this.trainingEntries,
    required this.onRangeChanged,
  });

  final _HistoryRange range;
  final List<NutritionEntry> entries;
  final List<TrainingEntry> trainingEntries;
  final ValueChanged<_HistoryRange> onRangeChanged;

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
                    'Historia zdrowia',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                DropdownButton<_HistoryRange>(
                  value: range,
                  items: _HistoryRange.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onRangeChanged(value);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${entries.length} posilkow, ${trainingEntries.length} aktywnosci. Historia nie jest automatycznie usuwana.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...entries
                .take(5)
                .map(
                  (entry) => _NutritionEntryTile(entry: entry, onDelete: null),
                ),
            ...trainingEntries
                .take(5)
                .map(
                  (entry) => _TrainingEntryTile(entry: entry, onDelete: null),
                ),
          ],
        ),
      ),
    );
  }
}

class _GoalCheckRow extends StatelessWidget {
  const _GoalCheckRow({required this.check});

  final _GoalCheck check;

  @override
  Widget build(BuildContext context) {
    final status = check.isDone
        ? 'w marginesie'
        : 'zostalo ${_number(check.remaining)} ${check.suffix}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(_goalIcon(check.label)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(check.label)),
                    Text('${(check.progress * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: check.progress.clamp(0.0, 1.0)),
                const SizedBox(height: 4),
                Text(
                  '${_number(check.value)} / ${_number(check.goal)} ${check.suffix} - $status (${check.rangeText})',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
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
    final details = <String>[
      entry.mealType,
      if (entry.isCheatMeal) 'wyjatkowy posilek',
      if (entry.note.isNotEmpty) entry.note,
    ];
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
      subtitle: details.isEmpty ? null : Text(details.join(' - ')),
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
    final details = <String>[
      if (entry.durationMinutes > 0) '${entry.durationMinutes} min',
      if (entry.steps > 0) '${entry.steps} krokow',
      if (entry.distanceKm > 0) '${_number(entry.distanceKm)} km',
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.monitor_heart_outlined),
      title: Text(
        details.isEmpty
            ? entry.activity
            : '${entry.activity} - ${details.join(', ')}',
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
  late final TextEditingController _stepsController;
  late final TextEditingController _dailyTrainingController;
  late final TextEditingController _weeklyTrainingMinutesController;
  late final TextEditingController _weeklyTrainingCountController;
  late final TextEditingController _weeklyStepsController;
  late final TextEditingController _weeklyDistanceController;

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
    _stepsController = TextEditingController(
      text: widget.goal == null ? '8000' : widget.goal!.dailySteps.toString(),
    );
    _dailyTrainingController = TextEditingController(
      text: widget.goal == null
          ? '30'
          : widget.goal!.dailyTrainingMinutes.toString(),
    );
    _weeklyTrainingMinutesController = TextEditingController(
      text: widget.goal == null
          ? '300'
          : widget.goal!.weeklyTrainingMinutes.toString(),
    );
    _weeklyTrainingCountController = TextEditingController(
      text: widget.goal == null
          ? '5'
          : widget.goal!.weeklyTrainingCount.toString(),
    );
    _weeklyStepsController = TextEditingController(
      text: widget.goal == null ? '60000' : widget.goal!.weeklySteps.toString(),
    );
    _weeklyDistanceController = TextEditingController(
      text: widget.goal == null ? '0' : _number(widget.goal!.weeklyDistanceKm),
    );
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _stepsController.dispose();
    _dailyTrainingController.dispose();
    _weeklyTrainingMinutesController.dispose();
    _weeklyTrainingCountController.dispose();
    _weeklyStepsController.dispose();
    _weeklyDistanceController.dispose();
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
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Cele ruchu',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _stepsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kroki dziennie',
                  suffixText: 'krokow',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dailyTrainingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minuty treningu dziennie',
                  suffixText: 'min',
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Cele tygodniowe',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _weeklyTrainingMinutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minuty treningu tygodniowo',
                  suffixText: 'min',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _weeklyTrainingCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Treningi tygodniowo',
                  suffixText: 'x',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _weeklyStepsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kroki tygodniowo',
                  suffixText: 'krokow',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _weeklyDistanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Dystans tygodniowo',
                  suffixText: 'km',
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
    final steps = _parseInt(_stepsController.text);
    final dailyTraining = _parseInt(_dailyTrainingController.text);
    final weeklyTrainingMinutes = _parseInt(
      _weeklyTrainingMinutesController.text,
    );
    final weeklyTrainingCount = _parseInt(_weeklyTrainingCountController.text);
    final weeklySteps = _parseInt(_weeklyStepsController.text);
    final weeklyDistance = _parseDouble(_weeklyDistanceController.text);
    Navigator.pop(
      context,
      _NutritionGoalDraft(
        dailyCalories: calories,
        dailyProtein: protein,
        dailyFat: fat,
        dailyCarbs: carbs,
        dailySteps: steps,
        dailyTrainingMinutes: dailyTraining,
        weeklyTrainingMinutes: weeklyTrainingMinutes,
        weeklyTrainingCount: weeklyTrainingCount,
        weeklySteps: weeklySteps,
        weeklyDistanceKm: weeklyDistance,
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
  String _mealType = 'Posilek';
  String? _recipeId;
  String? _imageData;
  String? _imageMimeType;
  bool _isCheatMeal = false;
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
              DropdownButtonFormField<String>(
                value: _mealType,
                decoration: const InputDecoration(
                  labelText: 'Typ posilku',
                  prefixIcon: Icon(Icons.restaurant_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Sniadanie',
                    child: Text('Sniadanie'),
                  ),
                  DropdownMenuItem(value: 'Obiad', child: Text('Obiad')),
                  DropdownMenuItem(value: 'Kolacja', child: Text('Kolacja')),
                  DropdownMenuItem(
                    value: 'Przekaska',
                    child: Text('Przekaska'),
                  ),
                  DropdownMenuItem(
                    value: 'Po treningu',
                    child: Text('Po treningu'),
                  ),
                  DropdownMenuItem(
                    value: 'Posilek',
                    child: Text('Inny posilek'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _mealType = value);
                  }
                },
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isCheatMeal,
                onChanged: (value) =>
                    setState(() => _isCheatMeal = value ?? false),
                title: const Text('Nie licz do celu'),
                subtitle: const Text(
                  'Wyjatkowy posilek zostaje w historii, ale nie przerywa passy.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
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
          mealType: _mealType,
          isCheatMeal: _isCheatMeal,
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
        mealType: _mealType,
        isCheatMeal: _isCheatMeal,
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
  final _stepsController = TextEditingController();
  final _distanceController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _activityController.dispose();
    _durationController.dispose();
    _stepsController.dispose();
    _distanceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Trening - ${widget.member.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: SingleChildScrollView(
          child: Column(
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
                controller: _stepsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kroki',
                  suffixText: 'krokow',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _distanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Dystans',
                  suffixText: 'km',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Notatka'),
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
    Navigator.pop(
      context,
      _TrainingEntryDraft(
        activity: _activityController.text.trim(),
        durationMinutes: _parseInt(_durationController.text),
        steps: _parseInt(_stepsController.text),
        distanceKm: _parseDouble(_distanceController.text),
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
    required this.dailySteps,
    required this.dailyTrainingMinutes,
    required this.weeklyTrainingMinutes,
    required this.weeklyTrainingCount,
    required this.weeklySteps,
    required this.weeklyDistanceKm,
  });

  final int dailyCalories;
  final double dailyProtein;
  final double dailyFat;
  final double dailyCarbs;
  final int dailySteps;
  final int dailyTrainingMinutes;
  final int weeklyTrainingMinutes;
  final int weeklyTrainingCount;
  final int weeklySteps;
  final double weeklyDistanceKm;
}

class _NutritionEntryDraft {
  const _NutritionEntryDraft({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.note,
    this.mealType = 'Posilek',
    this.isCheatMeal = false,
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
  final String mealType;
  final bool isCheatMeal;
  final Recipe? recipe;
  final double? servingPercent;
  final String? imageData;
  final String? imageMimeType;
}

class _TrainingEntryDraft {
  const _TrainingEntryDraft({
    required this.activity,
    required this.durationMinutes,
    required this.steps,
    required this.distanceKm,
    required this.note,
  });

  final String activity;
  final int durationMinutes;
  final int steps;
  final double distanceKm;
  final String note;
}

final _nutritionImageCache = <String, Uint8List?>{};
const _nutritionImageCacheLimit = 24;

class _GoalCheck {
  const _GoalCheck({
    required this.label,
    required this.value,
    required this.goal,
    required this.suffix,
    required this.allowOverTarget,
  });

  final String label;
  final double value;
  final double goal;
  final String suffix;
  final bool allowOverTarget;

  bool get enabled => goal > 0;
  double get lowerLimit => goal * 0.8;
  double get upperLimit => goal * 1.2;
  bool get isDone =>
      !enabled ||
      (value >= lowerLimit && (allowOverTarget || value <= upperLimit));
  double get progress => !enabled ? 0 : (value / goal).clamp(0.0, 1.4);
  double get remaining => max(0, lowerLimit - value).toDouble();
  String get rangeText => allowOverTarget
      ? 'min. ${_number(lowerLimit)} $suffix'
      : '${_number(lowerLimit)}-${_number(upperLimit)} $suffix';
}

class _HealthDaySummary {
  const _HealthDaySummary({
    required this.date,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarbs,
    required this.goalCalories,
    required this.goalProtein,
    required this.goalFat,
    required this.goalCarbs,
    required this.steps,
    required this.trainingMinutes,
    required this.trainingCount,
    required this.cheatMeals,
    required this.checks,
  });

  final DateTime date;
  final int totalCalories;
  final double totalProtein;
  final double totalFat;
  final double totalCarbs;
  final int goalCalories;
  final double goalProtein;
  final double goalFat;
  final double goalCarbs;
  final int steps;
  final int trainingMinutes;
  final int trainingCount;
  final int cheatMeals;
  final List<_GoalCheck> checks;

  Iterable<_GoalCheck> get enabledChecks =>
      checks.where((item) => item.enabled);
  int get completedGoals => enabledChecks.where((item) => item.isDone).length;
  int get totalGoals => enabledChecks.length;
  bool get isComplete => totalGoals > 0 && completedGoals == totalGoals;
  double get completion => totalGoals == 0 ? 0 : completedGoals / totalGoals;
}

class _HealthWeekSummary {
  const _HealthWeekSummary({
    required this.weekStart,
    required this.weekEnd,
    required this.trainingMinutes,
    required this.trainingCount,
    required this.steps,
    required this.distanceKm,
    required this.goalDays,
    required this.averageCalories,
    required this.averageProtein,
    required this.checks,
    required this.days,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final int trainingMinutes;
  final int trainingCount;
  final int steps;
  final double distanceKm;
  final int goalDays;
  final double averageCalories;
  final double averageProtein;
  final List<_GoalCheck> checks;
  final List<_HealthDaySummary> days;

  Iterable<_GoalCheck> get enabledChecks =>
      checks.where((item) => item.enabled);
  int get completedGoals => enabledChecks.where((item) => item.isDone).length;
  int get totalGoals => enabledChecks.length;
  double get completion => totalGoals == 0 ? 0 : completedGoals / totalGoals;
}

class _StreakSummary {
  const _StreakSummary({
    required this.current,
    required this.best,
    required this.completedDays,
  });

  final int current;
  final int best;
  final Set<String> completedDays;
}

class _Achievement {
  const _Achievement({
    required this.title,
    required this.icon,
    required this.current,
    required this.target,
    required this.unit,
  });

  final String title;
  final IconData icon;
  final double current;
  final double target;
  final String unit;

  bool get done => current >= target;
  double get progress => target <= 0 ? 0 : (current / target).clamp(0.0, 1.0);
}

_HealthDaySummary _daySummary({
  required DateTime date,
  required List<NutritionEntry> entries,
  required List<TrainingEntry> trainingEntries,
  required NutritionGoal? goal,
}) {
  final day = DateUtils.dateOnly(date);
  final dayEntries = entries
      .where((entry) => DateUtils.isSameDay(entry.date, day))
      .toList();
  final countedEntries = dayEntries
      .where((entry) => !entry.isCheatMeal)
      .toList();
  final dayTraining = trainingEntries
      .where((entry) => DateUtils.isSameDay(entry.date, day))
      .toList();

  final totalCalories = dayEntries.fold<int>(
    0,
    (sum, entry) => sum + entry.calories,
  );
  final totalProtein = dayEntries.fold<double>(
    0,
    (sum, entry) => sum + entry.protein,
  );
  final totalFat = dayEntries.fold<double>(0, (sum, entry) => sum + entry.fat);
  final totalCarbs = dayEntries.fold<double>(
    0,
    (sum, entry) => sum + entry.carbs,
  );
  final goalCalories = countedEntries.fold<int>(
    0,
    (sum, entry) => sum + entry.calories,
  );
  final goalProtein = countedEntries.fold<double>(
    0,
    (sum, entry) => sum + entry.protein,
  );
  final goalFat = countedEntries.fold<double>(
    0,
    (sum, entry) => sum + entry.fat,
  );
  final goalCarbs = countedEntries.fold<double>(
    0,
    (sum, entry) => sum + entry.carbs,
  );
  final steps = dayTraining.fold<int>(0, (sum, entry) => sum + entry.steps);
  final trainingMinutes = dayTraining.fold<int>(
    0,
    (sum, entry) => sum + entry.durationMinutes,
  );

  return _HealthDaySummary(
    date: day,
    totalCalories: totalCalories,
    totalProtein: totalProtein,
    totalFat: totalFat,
    totalCarbs: totalCarbs,
    goalCalories: goalCalories,
    goalProtein: goalProtein,
    goalFat: goalFat,
    goalCarbs: goalCarbs,
    steps: steps,
    trainingMinutes: trainingMinutes,
    trainingCount: dayTraining.length,
    cheatMeals: dayEntries.where((entry) => entry.isCheatMeal).length,
    checks: [
      _GoalCheck(
        label: 'Kcal',
        value: goalCalories.toDouble(),
        goal: (goal?.dailyCalories ?? 0).toDouble(),
        suffix: 'kcal',
        allowOverTarget: false,
      ),
      _GoalCheck(
        label: 'Bialko',
        value: goalProtein,
        goal: goal?.dailyProtein ?? 0,
        suffix: 'g',
        allowOverTarget: false,
      ),
      _GoalCheck(
        label: 'Tluszcze',
        value: goalFat,
        goal: goal?.dailyFat ?? 0,
        suffix: 'g',
        allowOverTarget: false,
      ),
      _GoalCheck(
        label: 'Weglowodany',
        value: goalCarbs,
        goal: goal?.dailyCarbs ?? 0,
        suffix: 'g',
        allowOverTarget: false,
      ),
      _GoalCheck(
        label: 'Kroki',
        value: steps.toDouble(),
        goal: (goal?.dailySteps ?? 0).toDouble(),
        suffix: 'krokow',
        allowOverTarget: true,
      ),
      _GoalCheck(
        label: 'Minuty treningu',
        value: trainingMinutes.toDouble(),
        goal: (goal?.dailyTrainingMinutes ?? 0).toDouble(),
        suffix: 'min',
        allowOverTarget: true,
      ),
    ],
  );
}

_HealthWeekSummary _weekSummary({
  required DateTime date,
  required List<NutritionEntry> entries,
  required List<TrainingEntry> trainingEntries,
  required NutritionGoal? goal,
}) {
  final start = _weekStart(date);
  final end = start.add(const Duration(days: 6));
  final days = List.generate(
    7,
    (index) => _daySummary(
      date: start.add(Duration(days: index)),
      entries: entries,
      trainingEntries: trainingEntries,
      goal: goal,
    ),
  );
  final weekTraining = trainingEntries
      .where(
        (entry) =>
            !entry.date.isBefore(start) &&
            entry.date.isBefore(end.add(const Duration(days: 1))),
      )
      .toList();
  final trainingMinutes = weekTraining.fold<int>(
    0,
    (sum, entry) => sum + entry.durationMinutes,
  );
  final steps = weekTraining.fold<int>(0, (sum, entry) => sum + entry.steps);
  final distanceKm = weekTraining.fold<double>(
    0,
    (sum, entry) => sum + entry.distanceKm,
  );
  final averageCalories =
      days.fold<double>(0, (sum, day) => sum + day.totalCalories) / 7;
  final averageProtein =
      days.fold<double>(0, (sum, day) => sum + day.totalProtein) / 7;

  return _HealthWeekSummary(
    weekStart: start,
    weekEnd: end,
    trainingMinutes: trainingMinutes,
    trainingCount: weekTraining.length,
    steps: steps,
    distanceKm: distanceKm,
    goalDays: days.where((day) => day.isComplete).length,
    averageCalories: averageCalories,
    averageProtein: averageProtein,
    days: days,
    checks: [
      _GoalCheck(
        label: 'Minuty treningu',
        value: trainingMinutes.toDouble(),
        goal: (goal?.weeklyTrainingMinutes ?? 0).toDouble(),
        suffix: 'min',
        allowOverTarget: true,
      ),
      _GoalCheck(
        label: 'Treningi',
        value: weekTraining.length.toDouble(),
        goal: (goal?.weeklyTrainingCount ?? 0).toDouble(),
        suffix: 'x',
        allowOverTarget: true,
      ),
      _GoalCheck(
        label: 'Kroki',
        value: steps.toDouble(),
        goal: (goal?.weeklySteps ?? 0).toDouble(),
        suffix: 'krokow',
        allowOverTarget: true,
      ),
      _GoalCheck(
        label: 'Dystans',
        value: distanceKm,
        goal: goal?.weeklyDistanceKm ?? 0,
        suffix: 'km',
        allowOverTarget: true,
      ),
    ],
  );
}

_StreakSummary _streakSummary({
  required List<NutritionEntry> entries,
  required List<TrainingEntry> trainingEntries,
  required NutritionGoal? goal,
}) {
  if (goal == null) {
    return const _StreakSummary(current: 0, best: 0, completedDays: {});
  }
  final dates = <DateTime>[
    ...entries.map((entry) => DateUtils.dateOnly(entry.date)),
    ...trainingEntries.map((entry) => DateUtils.dateOnly(entry.date)),
    DateUtils.dateOnly(DateTime.now()),
  ]..sort();
  if (dates.isEmpty) {
    return const _StreakSummary(current: 0, best: 0, completedDays: {});
  }
  final first = dates.first;
  final today = DateUtils.dateOnly(DateTime.now());
  final completed = <String>{};
  var currentRun = 0;
  var bestRun = 0;
  for (
    var date = first;
    !date.isAfter(today);
    date = date.add(const Duration(days: 1))
  ) {
    final summary = _daySummary(
      date: date,
      entries: entries,
      trainingEntries: trainingEntries,
      goal: goal,
    );
    if (summary.isComplete) {
      currentRun++;
      bestRun = max(bestRun, currentRun);
      completed.add(_dateKey(date));
    } else {
      currentRun = 0;
    }
  }

  var current = 0;
  for (var date = today; ; date = date.subtract(const Duration(days: 1))) {
    if (!completed.contains(_dateKey(date))) {
      break;
    }
    current++;
  }
  return _StreakSummary(
    current: current,
    best: bestRun,
    completedDays: completed,
  );
}

List<_Achievement> _achievements({
  required _StreakSummary streak,
  required List<TrainingEntry> trainingEntries,
}) {
  final trainings = trainingEntries.length.toDouble();
  final minutes = trainingEntries.fold<double>(
    0,
    (sum, entry) => sum + entry.durationMinutes,
  );
  final distance = trainingEntries.fold<double>(
    0,
    (sum, entry) => sum + entry.distanceKm,
  );
  return [
    _Achievement(
      title: 'Pierwszy trening',
      icon: Icons.fitness_center,
      current: trainings,
      target: 1,
      unit: 'trening',
    ),
    _Achievement(
      title: '7 dni passy',
      icon: Icons.local_fire_department,
      current: streak.best.toDouble(),
      target: 7,
      unit: 'dni',
    ),
    _Achievement(
      title: '30 dni passy',
      icon: Icons.emoji_events_outlined,
      current: streak.best.toDouble(),
      target: 30,
      unit: 'dni',
    ),
    _Achievement(
      title: '100 treningow',
      icon: Icons.workspace_premium_outlined,
      current: trainings,
      target: 100,
      unit: 'treningow',
    ),
    _Achievement(
      title: '100 km',
      icon: Icons.directions_run,
      current: distance,
      target: 100,
      unit: 'km',
    ),
    _Achievement(
      title: '1000 minut treningu',
      icon: Icons.timer_outlined,
      current: minutes,
      target: 1000,
      unit: 'min',
    ),
  ];
}

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

DateTime _weekStart(DateTime date) {
  final day = DateUtils.dateOnly(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

String _dateKey(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(DateUtils.dateOnly(date));
}

DateTime? _rangeStart(_HistoryRange range, DateTime date) {
  final day = DateUtils.dateOnly(date);
  return switch (range) {
    _HistoryRange.week => _weekStart(day),
    _HistoryRange.month => DateTime(day.year, day.month),
    _HistoryRange.year => DateTime(day.year),
    _HistoryRange.all => null,
  };
}

DateTime? _rangeEnd(_HistoryRange range, DateTime date) {
  final day = DateUtils.dateOnly(date);
  return switch (range) {
    _HistoryRange.week => _weekStart(day).add(const Duration(days: 6)),
    _HistoryRange.month => DateTime(day.year, day.month + 1, 0),
    _HistoryRange.year => DateTime(day.year, 12, 31),
    _HistoryRange.all => null,
  };
}

IconData _goalIcon(String label) {
  return switch (label) {
    'Kcal' => Icons.local_fire_department_outlined,
    'Bialko' => Icons.fitness_center,
    'Tluszcze' => Icons.water_drop_outlined,
    'Weglowodany' => Icons.grain_outlined,
    'Kroki' => Icons.directions_walk,
    'Minuty treningu' => Icons.timer_outlined,
    'Treningi' => Icons.monitor_heart_outlined,
    'Dystans' => Icons.directions_run,
    _ => Icons.flag_outlined,
  };
}

enum _HistoryRange {
  week('Tydzien'),
  month('Miesiac'),
  year('Rok'),
  all('Cala historia');

  const _HistoryRange(this.label);

  final String label;
}
