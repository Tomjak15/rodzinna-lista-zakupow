import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/app_state.dart';

enum OnboardingMode { create, join }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _familyNameController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _avatarController = TextEditingController();
  OnboardingMode _mode = OnboardingMode.create;
  bool _saving = false;

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
                        setState(() => _mode = value.first);
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
                    else
                      TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Kod rodziny',
                          prefixIcon: Icon(Icons.key_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Wpisz kod rodziny'
                            : null,
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Twoje imię',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Wpisz swoje imię'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
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
}
