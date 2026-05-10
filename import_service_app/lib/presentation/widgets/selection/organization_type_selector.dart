import 'package:flutter/material.dart';
import 'package:import_service_app/data/models/registration_request_model.dart';

/// Переключатель типа организации (не поле ввода — без обводки как у текстовых полей).
class OrganizationTypeSelector extends StatelessWidget {
  const OrganizationTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.oooLabel,
    required this.ipLabel,
  });

  final OrganizationType selected;
  final ValueChanged<OrganizationType> onChanged;
  final String oooLabel;
  final String ipLabel;

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
        ],
        selected: {selected},
        onSelectionChanged: (value) => onChanged(value.first),
        showSelectedIcon: false,
      ),
    );
  }
}
