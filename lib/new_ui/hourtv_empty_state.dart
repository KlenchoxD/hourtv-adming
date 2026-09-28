import 'package:flutter/material.dart';

/// Estado vacío honesto: mientras carga, un indicador; si no hay nada, lo
/// dice y permite reintentar. Reemplaza al contenido de ejemplo que antes se
/// mostraba cuando el catálogo no cargaba (títulos inventados que no
/// reproducían nada).
class HourTvEmptyState extends StatelessWidget {
  const HourTvEmptyState({
    super.key,
    required this.loading,
    required this.title,
    required this.message,
    this.icon = Icons.tv_off_rounded,
    this.onRetry,
  });

  final bool loading;
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00C781)),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFA6A6B0), size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFA6A6B0), fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00C781),
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
