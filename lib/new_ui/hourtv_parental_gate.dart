import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/channel.dart';
import '../services/parental_control_service.dart';
import 'hourtv_settings_kit.dart';

/// One-shot PIN challenge for content opened before restricted mode became
/// active or received through a direct route.
Future<bool> ensureParentalAccess(BuildContext context, Channel content) async {
  if (!ParentalControlService.isEnabled ||
      !ParentalControlService.isAdultChannel(content)) {
    return true;
  }
  final pin = await requestParentalPin(
    context,
    title: 'Contenido restringido',
    confirmLabel: 'Desbloquear',
  );
  if (pin == null) return false;
  if (ParentalControlService.verifyPin(pin)) return true;
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PIN incorrecto.')));
  }
  return false;
}

/// Dialogo generico para pedir el PIN ya configurado. No lo verifica: el
/// llamador decide que hacer con el resultado. Null si se cancela.
Future<String?> requestParentalPin(
  BuildContext context, {
  required String title,
  String confirmLabel = 'Confirmar',
}) async {
  final controller = TextEditingController();
  final pin = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: kSetSurface,
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'PIN parental',
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  // No se llama a controller.dispose(): la transicion de cierre del dialogo
  // puede seguir animando el TextField un instante mas alla del pop, y
  // liberar el controller ahi crashea ("used after being disposed"). Es un
  // controller de un solo uso, el garbage collector se encarga.
  return pin;
}

/// Dialogo para crear/cambiar el PIN: pide el numero dos veces. Null si se
/// cancela; el llamador compara que ambos coincidan.
Future<(String, String)?> requestNewParentalPin(
  BuildContext context, {
  required String title,
}) async {
  final pin = TextEditingController();
  final repeated = TextEditingController();
  final result = await showDialog<(String, String)>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: kSetSurface,
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'PIN (4–6 dígitos)',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: repeated,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Confirmar PIN',
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(dialogContext, (pin.text, repeated.text)),
          child: const Text('Confirmar'),
        ),
      ],
    ),
  );
  // Sin dispose por la misma razon que en requestParentalPin: liberar el
  // controller mientras el dialogo todavia esta animando su cierre crashea.
  return result;
}
