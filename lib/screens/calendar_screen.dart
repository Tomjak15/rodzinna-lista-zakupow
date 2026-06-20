import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_scope.dart';
import '../models/entities.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _CalendarHeader(
          selectedDate: _selectedDate,
          onDateChanged: (date) => setState(() => _selectedDate = date),
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.restaurant_menu),
              label: Text('Posiłki'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.event_note),
              label: Text('Wydarzenia'),
            ),
          ],
          selected: {_section},
          onSelectionChanged: (value) => setState(() => _section = value.first),
        ),
        const SizedBox(height: 12),
        if (_section == 0)
          _MealCalendar(date: _selectedDate)
        else
          _EventCalendar(date: _selectedDate),
      ],
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.selectedDate,
    required this.onDateChanged,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = List.generate(21, (index) => today.add(Duration(days: index)));

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
                    _fullDate(selectedDate),
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
                  final selected = DateUtils.isSameDay(day, selectedDate);
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) => onDateChanged(day),
                    label: SizedBox(
                      width: 52,
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
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Wybierz dzień',
      cancelText: 'Anuluj',
      confirmText: 'Wybierz',
    );
    if (picked != null) {
      onDateChanged(DateUtils.dateOnly(picked));
    }
  }

  String _fullDate(DateTime date) {
    return '${_longDayName(date)}, ${DateFormat('dd.MM.yyyy').format(date)}';
  }
}

class _MealCalendar extends StatelessWidget {
  const _MealCalendar({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final plans = appState.mealPlansForDate(date);
    final meals = [...appState.data.activeMeals]
      ..sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Posiłki na ten dzień',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: meals.isEmpty
                  ? null
                  : () => _openMealPlanDialog(context, date, meals),
              icon: const Icon(Icons.add),
              label: const Text('Zaplanuj'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (meals.isEmpty)
          const _CalendarInfo(
            icon: Icons.restaurant_menu_outlined,
            text: 'Najpierw dodaj obiad w zakładce Obiady.',
          )
        else if (plans.isEmpty)
          const _CalendarInfo(
            icon: Icons.calendar_month_outlined,
            text: 'Brak zaplanowanych posiłków.',
          )
        else
          ...plans.map((plan) => _MealPlanTile(plan: plan)),
      ],
    );
  }

  Future<void> _openMealPlanDialog(
    BuildContext context,
    DateTime date,
    List<Meal> meals,
  ) async {
    final draft = await showDialog<_MealPlanDraft>(
      context: context,
      builder: (_) => _MealPlanDialog(meals: meals),
    );
    if (draft == null || !context.mounted) {
      return;
    }
    await AppScope.of(context).addMealPlanToCalendar(
      date: date,
      meal: draft.meal,
      recipeIds: draft.recipeIds,
      servings: draft.servings,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Posiłek zaplanowany, składniki dodane do listy.'),
        ),
      );
    }
  }
}

class _MealPlanTile extends StatelessWidget {
  const _MealPlanTile({required this.plan});

  final MealPlan plan;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final meal = appState.mealById(plan.mealId);
    final recipeNames = appState.data.activeRecipes
        .where((recipe) => plan.recipeIds.contains(recipe.id))
        .map((recipe) => recipe.name)
        .join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        leading: const Icon(Icons.restaurant),
        title: Text(meal?.name ?? 'Usunięty obiad'),
        subtitle: Text(
          '${plan.servings} porcji • ${recipeNames.isEmpty ? 'składniki' : recipeNames}',
        ),
        trailing: Wrap(
          spacing: 2,
          children: [
            _SmallSyncIcon(status: plan.syncStatus),
            IconButton(
              tooltip: 'Usuń z kalendarza',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => appState.deleteMealPlan(plan),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealPlanDialog extends StatefulWidget {
  const _MealPlanDialog({required this.meals});

  final List<Meal> meals;

  @override
  State<_MealPlanDialog> createState() => _MealPlanDialogState();
}

class _MealPlanDialogState extends State<_MealPlanDialog> {
  late String _mealId;
  final _servingsController = TextEditingController(text: '4');
  bool _includeMain = true;
  final Set<String> _selectedSubRecipes = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _mealId = widget.meals.first.id;
  }

  @override
  void dispose() {
    _servingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final meal = widget.meals.firstWhere((item) => item.id == _mealId);
    final mainRecipe = appState.mainRecipeFor(meal);
    final subRecipes = mainRecipe == null
        ? <Recipe>[]
        : appState.subRecipesFor(mainRecipe);

    return AlertDialog(
      title: const Text('Zaplanuj posiłek'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _mealId,
                decoration: const InputDecoration(labelText: 'Obiad'),
                items: widget.meals
                    .map(
                      (meal) => DropdownMenuItem(
                        value: meal.id,
                        child: Text(meal.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _mealId = value;
                    _includeMain = true;
                    _selectedSubRecipes.clear();
                    _error = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _servingsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Liczba porcji'),
              ),
              const SizedBox(height: 12),
              if (mainRecipe == null)
                const Text('Ten obiad nie ma przepisu głównego.')
              else ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _includeMain,
                  onChanged: (value) => setState(() {
                    _includeMain = value ?? true;
                    _error = null;
                  }),
                  title: Text(mainRecipe.name),
                  subtitle: const Text('Przepis główny'),
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Dodatki / podprzepisy',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (subRecipes.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Brak dodatków'),
                    ),
                  )
                else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _selectedSubRecipes.clear();
                            _error = null;
                          }),
                          icon: const Icon(Icons.restaurant_outlined),
                          label: const Text('Tylko główny'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => setState(() {
                            _selectedSubRecipes
                              ..clear()
                              ..addAll(subRecipes.map((recipe) => recipe.id));
                            _error = null;
                          }),
                          icon: const Icon(Icons.done_all),
                          label: const Text('Wszystkie'),
                        ),
                      ],
                    ),
                  ),
                  ...subRecipes.map(
                    (recipe) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _selectedSubRecipes.contains(recipe.id),
                      onChanged: (value) => setState(() {
                        if (value ?? false) {
                          _selectedSubRecipes.add(recipe.id);
                        } else {
                          _selectedSubRecipes.remove(recipe.id);
                        }
                        _error = null;
                      }),
                      title: Text(recipe.name),
                    ),
                  ),
                ],
              ],
              if (_error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
        FilledButton(
          onPressed: () => _save(context, meal, mainRecipe),
          child: const Text('Zapisz'),
        ),
      ],
    );
  }

  void _save(BuildContext context, Meal meal, Recipe? mainRecipe) {
    final recipeIds = <String>[
      if (_includeMain && mainRecipe != null) mainRecipe.id,
      ..._selectedSubRecipes,
    ];
    if (recipeIds.isEmpty) {
      setState(() => _error = 'Wybierz przepis albo dodatek.');
      return;
    }
    Navigator.pop(
      context,
      _MealPlanDraft(
        meal: meal,
        recipeIds: recipeIds,
        servings: int.tryParse(_servingsController.text) ?? 1,
      ),
    );
  }
}

class _MealPlanDraft {
  const _MealPlanDraft({
    required this.meal,
    required this.recipeIds,
    required this.servings,
  });

  final Meal meal;
  final List<String> recipeIds;
  final int servings;
}

class _EventCalendar extends StatelessWidget {
  const _EventCalendar({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final events = appState.calendarEventsForDate(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Wydarzenia',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (appState.isFamilyCreator) ...[
              IconButton.filledTonal(
                tooltip: 'Dodaj osobę',
                onPressed: () => _openPersonDialog(context),
                icon: const Icon(Icons.person_add_alt_1),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton.icon(
              onPressed: () => _openEventDialog(context, date),
              icon: const Icon(Icons.add),
              label: const Text('Dodaj'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const _CalendarInfo(
            icon: Icons.event_available_outlined,
            text: 'Brak wydarzeń na ten dzień.',
          )
        else
          ...events.map((event) => _EventTile(event: event)),
      ],
    );
  }

  Future<void> _openPersonDialog(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _PersonDialog(),
    );
    if (name == null || !context.mounted) {
      return;
    }
    try {
      await AppScope.of(context).addCalendarMember(name: name);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _openEventDialog(
    BuildContext context,
    DateTime date, {
    CalendarEvent? event,
  }) async {
    final draft = await showDialog<_EventDraft>(
      context: context,
      builder: (_) => _EventDialog(date: date, event: event),
    );
    if (draft == null || !context.mounted) {
      return;
    }
    final appState = AppScope.of(context);
    if (event == null) {
      await appState.addCalendarEvent(
        date: draft.date,
        title: draft.title,
        notes: draft.notes,
        memberId: draft.memberId,
        isFamilyWide: draft.isFamilyWide,
      );
    } else {
      await appState.updateCalendarEvent(
        event: event,
        date: draft.date,
        title: draft.title,
        notes: draft.notes,
        memberId: draft.memberId,
        isFamilyWide: draft.isFamilyWide,
      );
    }
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final target = event.isFamilyWide
        ? 'Cała rodzina'
        : appState.memberById(event.memberId ?? '')?.name ?? 'Osoba';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        leading: Icon(event.isFamilyWide ? Icons.groups : Icons.person),
        title: Text(event.title),
        subtitle: Text(
          event.notes.isEmpty ? target : '$target • ${event.notes}',
        ),
        trailing: Wrap(
          spacing: 2,
          children: [
            _SmallSyncIcon(status: event.syncStatus),
            IconButton(
              tooltip: 'Edytuj',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _EventCalendar(
                date: DateUtils.dateOnly(event.date.toLocal()),
              )._openEventDialog(context, event.date, event: event),
            ),
            IconButton(
              tooltip: 'Usuń',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => appState.deleteCalendarEvent(event),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDialog extends StatefulWidget {
  const _EventDialog({required this.date, this.event});

  final DateTime date;
  final CalendarEvent? event;

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  String _target = 'family';

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _date = DateUtils.dateOnly((event?.date ?? widget.date).toLocal());
    _titleController = TextEditingController(text: event?.title ?? '');
    _notesController = TextEditingController(text: event?.notes ?? '');
    _target = event == null || event.isFamilyWide
        ? 'family'
        : event.memberId ?? 'family';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = [...AppScope.of(context).data.activeMembers]
      ..sort((a, b) => a.name.compareTo(b.name));

    return AlertDialog(
      title: Text(
        widget.event == null ? 'Nowe wydarzenie' : 'Edytuj wydarzenie',
      ),
      content: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_fullDate(_date))),
                    TextButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Zmień'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Wydarzenie'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Wpisz wydarzenie'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: members.any((member) => member.id == _target)
                      ? _target
                      : 'family',
                  decoration: const InputDecoration(labelText: 'Dla kogo'),
                  items: [
                    const DropdownMenuItem(
                      value: 'family',
                      child: Text('Cała rodzina'),
                    ),
                    ...members.map(
                      (member) => DropdownMenuItem(
                        value: member.id,
                        child: Text(member.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _target = value ?? 'family'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notatka'),
                ),
              ],
            ),
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Wybierz dzień',
      cancelText: 'Anuluj',
      confirmText: 'Wybierz',
    );
    if (picked != null) {
      setState(() => _date = DateUtils.dateOnly(picked));
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.pop(
      context,
      _EventDraft(
        date: _date,
        title: _titleController.text.trim(),
        notes: _notesController.text.trim(),
        memberId: _target == 'family' ? null : _target,
        isFamilyWide: _target == 'family',
      ),
    );
  }
}

class _EventDraft {
  const _EventDraft({
    required this.date,
    required this.title,
    required this.notes,
    required this.memberId,
    required this.isFamilyWide,
  });

  final DateTime date;
  final String title;
  final String notes;
  final String? memberId;
  final bool isFamilyWide;
}

class _PersonDialog extends StatefulWidget {
  const _PersonDialog();

  @override
  State<_PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends State<_PersonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dodaj osobę'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Imię'),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Wpisz imię' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _nameController.text.trim());
            }
          },
          child: const Text('Dodaj'),
        ),
      ],
    );
  }
}

class _CalendarInfo extends StatelessWidget {
  const _CalendarInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _SmallSyncIcon extends StatelessWidget {
  const _SmallSyncIcon({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == SyncStatus.synced) {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: status == SyncStatus.failed
          ? 'Nie udało się zsynchronizować'
          : 'Oczekuje na synchronizację',
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Icon(
          status == SyncStatus.failed
              ? Icons.cloud_off_outlined
              : Icons.schedule_outlined,
          size: 20,
          color: status == SyncStatus.failed
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}

String _shortDayName(DateTime date) {
  const names = ['pon', 'wt', 'śr', 'czw', 'pt', 'sob', 'ndz'];
  return names[date.weekday - 1];
}

String _longDayName(DateTime date) {
  const names = [
    'Poniedziałek',
    'Wtorek',
    'Środa',
    'Czwartek',
    'Piątek',
    'Sobota',
    'Niedziela',
  ];
  return names[date.weekday - 1];
}

String _fullDate(DateTime date) {
  return '${_longDayName(date)}, ${DateFormat('dd.MM.yyyy').format(date)}';
}
