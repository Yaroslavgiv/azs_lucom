import 'package:azs_domain/azs_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/repositories/contract_rule_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_background.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/glass_card.dart';

class ContractRulesPage extends ConsumerStatefulWidget {
  const ContractRulesPage({super.key});

  @override
  ConsumerState<ContractRulesPage> createState() => _ContractRulesPageState();
}

class _ContractRulesPageState extends ConsumerState<ContractRulesPage> {
  final _category = TextEditingController();
  final _hours = TextEditingController();
  var _requiresReview = false;
  var _busy = false;
  List<ContractRule> _rules = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _category.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final repository = await ref.read(contractRuleRepositoryProvider.future);
    final rules = await repository.activeRules();
    if (!mounted) return;
    setState(() => _rules = rules);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final actor = await ref.read(sessionProfileProvider.future);
      if (actor == null || actor.role != AppRole.admin) {
        _show('Правила договора меняет администратор');
        return;
      }
      final hoursText = _hours.text.trim();
      final hours = hoursText.isEmpty ? null : int.tryParse(hoursText);
      if (hoursText.isNotEmpty && hours == null) {
        _show('Часы укажите целым числом');
        return;
      }
      final repository = await ref.read(contractRuleRepositoryProvider.future);
      await repository.publishVersion(
        actor: actor,
        category: _category.text,
        durationHours: hours,
        requiresReview: _requiresReview,
      );
      _category.clear();
      _hours.clear();
      setState(() => _requiresReview = false);
      await _reload();
      _show('Правило опубликовано. Новые заявки возьмут эту версию');
    } on ContractRuleDenied catch (error) {
      _show(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Сроки договора')),
        body: _busy
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const GlassCard(
                    child: Text(
                      'Новая версия начинает действовать для следующих заявок. Уже созданные сроки не пересчитываются. Пустые часы означают, что срок не задан.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _category,
                    decoration: const InputDecoration(
                      labelText: 'Категория заявки',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _hours,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Длительность, часы',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Нужна проверка руководителя'),
                    value: _requiresReview,
                    onChanged: (value) =>
                        setState(() => _requiresReview = value),
                  ),
                  AppPrimaryButton(
                    label: 'Опубликовать версию',
                    icon: Icons.publish_outlined,
                    onPressed: _save,
                  ),
                  const SizedBox(height: 16),
                  for (final rule in _rules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassCard(
                        child: Text(
                          '${rule.category} · версия ${rule.version} · '
                          '${rule.durationHours == null ? 'срок не задан' : '${rule.durationHours} ч'}'
                          '${rule.requiresReview ? ' · с проверкой' : ''}',
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
