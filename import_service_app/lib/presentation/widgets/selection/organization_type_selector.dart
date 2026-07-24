import 'package:flutter/material.dart';
import 'package:import_service_app/data/models/registration_request_model.dart';

/// Переключатель типа заявителя при регистрации (ООО / ИП / Физлицо).
class OrganizationTypeSelector extends StatelessWidget {
  const OrganizationTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.oooLabel,
    required this.ipLabel,
    required this.personLabel,
  });

  final OrganizationType selected;
  final ValueChanged<OrganizationType> onChanged;
  final String oooLabel;
  final String ipLabel;
  final String personLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<OrganizationType>(
        segments: [
          ButtonSegment<OrganizationType>(
            value: OrganizationType.ooo,
            label: Text(oooLabel),
          ),
          ButtonSegment<OrganizationType>(
            value: OrganizationType.ip,
            label: Text(ipLabel),
          ),
          ButtonSegment<OrganizationType>(
            value: OrganizationType.person,
            label: Text(personLabel),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (value) => onChanged(value.first),
        showSelectedIcon: false,
      ),
    );
  }
}
