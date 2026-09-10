import 'dart:io';

class DnsValidationResult {
  final bool isValid;
  final String? reason;
  final List<InternetAddress> resolvedAddresses;

  const DnsValidationResult({
    required this.isValid,
    this.reason,
    this.resolvedAddresses = const [],
  });
}

/// Validador de seguridad DNS y prevención de ataques de DNS Rebinding / SSRF
/// para fuentes de reproducción del catálogo de HourTV.
class DnsSecurityValidator {
  final Future<List<InternetAddress>> Function(String host)? lookupProvider;

  const DnsSecurityValidator({this.lookupProvider});

  /// Determina si una dirección IP pertenece a rangos privados, loopback,
  /// link-local, multicast o reservados.
  static bool isPrivateOrReservedIp(InternetAddress ip) {
    if (ip.isLoopback || ip.isLinkLocal || ip.isMulticast) {
      return true;
    }

    if (ip.type == InternetAddressType.IPv4) {
      final raw = ip.rawAddress;
      final b0 = raw[0];
      final b1 = raw[1];

      // 0.0.0.0/8 (red actual)
      if (b0 == 0) return true;

      // 10.0.0.0/8 (RFC 1918 privada)
      if (b0 == 10) return true;

      // 127.0.0.0/8 (Loopback)
      if (b0 == 127) return true;

      // 169.254.0.0/16 (Link-local)
      if (b0 == 169 && b1 == 254) return true;

      // 172.16.0.0/12 (172.16.0.0 - 172.31.255.255)
      if (b0 == 172 && (b1 >= 16 && b1 <= 31)) return true;

      // 192.168.0.0/16 (RFC 1918 privada)
      if (b0 == 192 && b1 == 168) return true;

      // 224.0.0.0/4 (Multicast 224 - 239)
      if (b0 >= 224 && b0 <= 239) return true;

      // 240.0.0.0/4 (Reservado para investigación futura / broadcast 255.255.255.255)
      if (b0 >= 240) return true;

      return false;
    } else if (ip.type == InternetAddressType.IPv6) {
      final raw = ip.rawAddress;
      final b0 = raw[0];
      final b1 = raw[1];

      // ::1 (Loopback) o :: (Unspecified)
      if (ip.isLoopback || raw.every((b) => b == 0)) return true;

      // fc00::/7 (Unique Local Address - ULA privada: fc00:: - fdff::)
      if ((b0 & 0xFE) == 0xFC) return true;

      // fe80::/10 (Link-local: fe80:: - febf::)
      if (b0 == 0xFE && (b1 & 0xC0) == 0x80) return true;

      // ff00::/8 (Multicast)
      if (b0 == 0xFF) return true;

      // 2001:db8::/32 (Documentación)
      if (b0 == 0x20 && b1 == 0x01 && raw[2] == 0x0D && raw[3] == 0xB8) return true;

      return false;
    }

    return true; // Cualquier otro tipo desconocido se rechaza por defecto
  }

  /// Valida sintaxis y resolución DNS de una URL de stream contra DNS Rebinding.
  Future<DnsValidationResult> validateStreamUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme || uri.scheme.toLowerCase() != 'https') {
      return const DnsValidationResult(
        isValid: false,
        reason: 'La URL debe ser un enlace HTTPS válido.',
      );
    }

    final host = uri.host.trim();
    if (host.isEmpty) {
      return const DnsValidationResult(
        isValid: false,
        reason: 'Host inválido o vacío.',
      );
    }

    // Comprobar si el host es un literal IP directo
    final literalIp = InternetAddress.tryParse(host);
    if (literalIp != null) {
      if (isPrivateOrReservedIp(literalIp)) {
        return DnsValidationResult(
          isValid: false,
          reason: 'Dirección IP privada o reservada denegada ($host).',
          resolvedAddresses: [literalIp],
        );
      }
      return DnsValidationResult(
        isValid: true,
        resolvedAddresses: [literalIp],
      );
    }

    // Resolución DNS
    try {
      final resolver = lookupProvider ?? InternetAddress.lookup;
      final addresses = await resolver(host);

      if (addresses.isEmpty) {
        return const DnsValidationResult(
          isValid: false,
          reason: 'No se pudo resolver ninguna dirección IP para el host.',
        );
      }

      for (final ip in addresses) {
        if (isPrivateOrReservedIp(ip)) {
          return DnsValidationResult(
            isValid: false,
            reason: 'El dominio resuelve a una dirección IP privada o reservada (${ip.address}). Mitigación DNS Rebinding.',
            resolvedAddresses: addresses,
          );
        }
      }

      return DnsValidationResult(
        isValid: true,
        resolvedAddresses: addresses,
      );
    } catch (e) {
      return DnsValidationResult(
        isValid: false,
        reason: 'Error en la resolución DNS: $e',
      );
    }
  }
}
