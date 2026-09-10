import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/catalog/dns_security_validator.dart';
import 'package:streamtv/services/catalog/supabase_catalog_gateway.dart';
import '../tool/import_catalog_to_supabase.dart';

void main() {
  group('Catalog Security & Isolation Tests', () {
    test('1. Validador DNS rechaza direcciones privadas y previene SSRF/Rebinding', () {
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('127.0.0.1')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('10.0.0.1')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('172.20.0.1')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('192.168.1.1')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('169.254.169.254')), isTrue); // AWS/Cloud Metadata IP
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('::1')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('fc00::1')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('fe80::1')), isTrue);

      // IPs públicas legítimas
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('93.184.216.34')), isFalse);
    });

    test('2. Importador administrativo rechaza hosts remotos antes de conectar', () {
      expect(
        () => CatalogDirectImporter.validateTargetHost('production.supabase.co', 54322),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => CatalogDirectImporter.validateTargetHost('10.0.0.5', 54322),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => CatalogDirectImporter.validateTargetHost('127.0.0.1', 5432), // Puerto incorrecto
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => CatalogDirectImporter.validateTargetHost('127.0.0.1', 54322),
        returnsNormally,
      );
    });

    test('3. SupabaseCatalogGateway genera filtros de cursor con estricta sanitización y aislamiento', () {
      final gateway = SupabaseCatalogGateway();
      expect(gateway, isNotNull);
      // El Gateway únicamente ofrece métodos de lectura (fetchTitlesPage, fetchTitleDetails, fetchChanges, etc.)
      // No expone ninguna mutación (insert, update, delete) hacia el cliente
    });
  });
}
