import 'package:flutter/material.dart';

import '../services/storage_service.dart';

const _red = Color(0xFFF20A1A);
const _black = Color(0xFF050505);
const _surface = Color(0xFF101012);
const _line = Color(0xFF25252A);
const _muted = Color(0xFFA6A6B0);

class HourTvParentalSettingsPage extends StatefulWidget {
  const HourTvParentalSettingsPage({super.key});

  @override
  State<HourTvParentalSettingsPage> createState() =>
      _HourTvParentalSettingsPageState();
}

class _HourTvParentalSettingsPageState
    extends State<HourTvParentalSettingsPage> {
  late bool enabled;

  @override
  void initState() {
    super.initState();
    enabled =
        StorageService.getSetting('parentalControlEnabled',
            defaultValue: false) ==
        true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      appBar: AppBar(
        backgroundColor: _black,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Control parental',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _surface,
                  border: Border.all(color: _line),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.family_restroom_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activar control parental',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Restringe contenido para adultos cuando esté '
                            'disponible en el catálogo.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: enabled,
                      activeThumbColor: _red,
                      onChanged: (value) {
                        setState(() => enabled = value);
                        StorageService.saveSetting(
                          'parentalControlEnabled',
                          value,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
