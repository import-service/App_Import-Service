import 'package:flutter/material.dart';
import 'package:import_service_app/core/themes/app_theme.dart';
import 'package:import_service_app/presentation/models/demo_car_filter_status.dart';
import 'package:import_service_app/presentation/widgets/app_bar/brand_primary_app_bar.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_primary_filled_wide_button.dart';
import 'package:import_service_app/presentation/widgets/buttons/app_primary_outlined_wide_button.dart';
import 'package:import_service_app/presentation/widgets/filters/filter_status_checkbox_tile.dart';

class CarsFiltersPage extends StatefulWidget {
  const CarsFiltersPage({super.key});

  @override
  State<CarsFiltersPage> createState() => _CarsFiltersPageState();
}

class _CarsFiltersPageState extends State<CarsFiltersPage> {
  final Set<DemoCarFilterStatus> _selected = <DemoCarFilterStatus>{};

  bool get _isAllSelected => _selected.length == DemoCarFilterStatus.values.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandPrimaryAppBar(title: 'Фильтр'),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 180),
            children: [
              Row(
                children: [
                  Text(
                    'Статусы',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_isAllSelected) {
                          _selected.clear();
                        } else {
                          _selected
                            ..clear()
                            ..addAll(DemoCarFilterStatus.values);
                        }
                      });
                    },
                    child: Text(_isAllSelected ? 'Снять все' : 'Выбрать все'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final status in DemoCarFilterStatus.values)
                FilterStatusCheckboxTile(
                  label: status.label,
                  value: _selected.contains(status),
                  onChanged: (checked) {
                    setState(() {
                      if (checked) {
                        _selected.add(status);
                      } else {
                        _selected.remove(status);
                      }
                    });
                  },
                ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                color: AppTheme.white,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppPrimaryFilledWideButton(
                      label: 'Применить',
                      onPressed: () => Navigator.of(context).pop(_selected),
                      height: 56,
                    ),
                    const SizedBox(height: 12),
                    AppPrimaryOutlinedWideButton(
                      label: 'Сбросить фильтр',
                      onPressed: () {
                        setState(_selected.clear);
                      },
                      height: 56,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
