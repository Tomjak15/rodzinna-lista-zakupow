import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/app_state.dart';
import '../models/entities.dart';

enum OnboardingMode { create, join }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _newMemberValue = '__new_member__';

  final _formKey = GlobalKey<FormState>();
  final _familyNameController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _avatarController = TextEditingController();

  OnboardingMode _mode = OnboardingMode.create;
  bool _saving = false;
  bool _loadingAccounts = false;
  String? _selectedExistingMemberId;
  String? _loadedFamilyCode;
  String? _accountsMessage;
  List<Member> _existingMembers = [];

  @override
  void dispose() {
    _familyNameController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedExistingMember = _selectedExistingMember;
    final usingExistingAccount = selectedExistingMember != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Icon(
                      Icons.shopping_basket_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Rodzinna Lista Zakupów',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 28),
                    SegmentedButton<OnboardingMode>(
                      segments: const [
                        ButtonSegment(
                          value: OnboardingMode.create,
                          label: Text('Utwórz rodzinę'),
                          icon: Icon(Icons.add_home_work_outlined),
                        ),
                        ButtonSegment(
                          value: OnboardingMode.join,
                          label: Text('Dołącz do rodziny'),
                          icon: Icon(Icons.group_add_outlined),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (value) {
                        setState(() {
                          _mode = value.first;
                          _clearExistingAccounts();
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_mode == OnboardingMode.create)
                      TextFormField(
                        controller: _familyNameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nazwa rodziny',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Wpisz nazwę rodziny'
                            : null,
                      )
                    else ...[
                      TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Kod rodziny',
                          prefixIcon: Icon(Icons.key_outlined),
                        ),
                        onChanged: (_) => _clearExistingAccountsIfCodeChanged(),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Wpisz kod rodziny'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loadingAccounts ? null : _loadAccounts,
                        icon: _loadingAccounts
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.devices_other_outlined),
                        label: const Text('Pokaż konta z tej rodziny'),
                      ),
                      if (_accountsMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _accountsMessage!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (_existingMembers.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedExistingMemberId ?? _newMemberValue,
                          decoration: const InputDecoration(
                            labelText: 'Konto na tym urządzeniu',
                            prefixIcon: Icon(Icons.account_circle_outlined),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: _newMemberValue,
                              child: Text('Nowe konto w rodzinie'),
                            ),
                            ..._existingMembers.map(
                              (member) => DropdownMenuItem(
                                value: member.id,
                                child: Text(member.name),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedExistingMemberId =
                                  value == _newMemberValue ? null : value;
                              _fillSelectedMemberFields();
                            });
                          },
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      enabled: !usingExistingAccount,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Twoje imię',
                        prefixIcon: const Icon(Icons.person_outline),
                        helperText: usingExistingAccount
                            ? 'Używasz istniejącego konta: ${selectedExistingMember.name}'
                            : null,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Wpisz swoje imię'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      enabled: !usingExistingAccount,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      enabled: !usingExistingAccount,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _avatarController,
                      enabled: !usingExistingAccount,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Avatar',
                        prefixIcon: Icon(Icons.face_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _mode == OnboardingMode.create
                                  ? Icons.add_home_work
                                  : Icons.login,
                            ),
                      label: Text(
                        _mode == OnboardingMode.create
                            ? 'Utwórz rodzinę'
                            : usingExistingAccount
                            ? 'Zaloguj to konto'
                            : 'Dołącz do rodziny',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Member? get _selectedExistingMember {
    final selectedId = _selectedExistingMemberId;
    if (selectedId == null) {
      return null;
    }
    for (final member in _existingMembers) {
      if (member.id == selectedId) {
        return member;
      }
    }
    return null;
  }

  Future<void> _loadAccounts() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _accountsMessage = 'Najpierw wpisz kod rodziny.');
      return;
    }

    setState(() {
      _loadingAccounts = true;
      _accountsMessage = null;
      _existingMembers = [];
      _selectedExistingMemberId = null;
    });

    try {
      final members = await AppScope.of(
        context,
      ).fetchFamilyMembersForCode(code);
      if (!mounted) {
        return;
      }
      setState(() {
        _existingMembers = members;
        _loadedFamilyCode = code.toUpperCase();
        if (members.length == 1) {
          _selectedExistingMemberId = members.single.id;
          _fillSelectedMemberFields();
        }
        _accountsMessage = members.isEmpty
            ? 'Nie ma jeszcze kont w tej rodzinie. Utworzysz nowe.'
            : 'Wybierz swoje konto albo zostaw nowe konto.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is AppActionException
          ? error.message
          : 'Nie udało się pobrać kont rodziny.';
      setState(() => _accountsMessage = message);
    } finally {
      if (mounted) {
        setState(() => _loadingAccounts = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final appState = AppScope.of(context);
    try {
      if (_mode == OnboardingMode.create) {
        await appState.createFamily(
          familyName: _familyNameController.text,
          memberName: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          avatar: _avatarController.text,
        );
      } else {
        await appState.joinFamily(
          code: _codeController.text,
          memberName: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          avatar: _avatarController.text,
          existingMemberId: _selectedExistingMemberId,
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error is AppActionException
            ? error.message
            : 'Nie udało się połączyć z serwerem.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  void _clearExistingAccounts() {
    _existingMembers = [];
    _selectedExistingMemberId = null;
    _loadedFamilyCode = null;
    _accountsMessage = null;
  }

  void _clearExistingAccountsIfCodeChanged() {
    final currentCode = _codeController.text.trim().toUpperCase();
    if (_loadedFamilyCode != null && currentCode != _loadedFamilyCode) {
      setState(_clearExistingAccounts);
    }
  }

  void _fillSelectedMemberFields() {
    final member = _selectedExistingMember;
    if (member == null) {
      return;
    }
    _nameController.text = member.name;
    _emailController.text = member.email ?? '';
    _phoneController.text = member.phone ?? '';
    _avatarController.text = member.avatar ?? '';
  }
}
