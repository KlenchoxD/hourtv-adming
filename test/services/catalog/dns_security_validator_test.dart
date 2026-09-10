import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamtv/services/catalog/dns_security_validator.dart';

void main() {
  group('DnsSecurityValidator Anti-Rebinding & IP Range Tests', () {
    test('1. Rechaza loopback IPv4 e IPv6', () {
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('127.0.0.1')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('127.0.1.5')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('::1')), isTrue);
    });

    test('2. Rechaza rangos privados RFC 1918 y ULA IPv6', () {
      // 10.0.0.0/8
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('10.0.0.1')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('10.255.255.254')), isTrue);

      // 172.16.0.0/12
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('172.16.0.1')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('172.31.255.255')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('172.32.0.1')), isFalse); // Público

      // 192.168.0.0/16
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('192.168.1.1')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('192.168.100.200')), isTrue);

      // IPv6 ULA (fc00::/7)
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('fc00::1')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('fd12:3456:789a::1')), isTrue);
    });

    test('3. Rechaza link-local y multicast', () {
      // Link-local IPv4 (169.254.0.0/16)
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('169.254.1.1')), isTrue);

      // Link-local IPv6 (fe80::/10)
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('fe80::1')), isTrue);

      // Multicast (224.0.0.0/4 y ff00::/8)
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('224.0.0.1')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('239.255.255.255')), isTrue);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('ff02::1')), isTrue);
    });

    test('4. Acepta IPs públicas legítimas', () {
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('8.8.8.8')), isFalse);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('1.1.1.1')), isFalse);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('104.26.10.15')), isFalse);
      expect(DnsSecurityValidator.isPrivateOrReservedIp(InternetAddress('2606:4700:4700::1111')), isFalse);
    });

    test('5. Valida URL con resolver simulado contra DNS rebinding', () async {
      // Simulador que resuelve 'legit-cdn.com' a IP pública y 'attacker-rebinding.com' a loopback
      Future<List<InternetAddress>> mockLookup(String host) async {
        if (host == 'legit-cdn.com') {
          return [InternetAddress('104.26.10.15')];
        }
        if (host == 'attacker-rebinding.com') {
          return [InternetAddress('127.0.0.1')];
        }
        return [];
      }

      final validator = DnsSecurityValidator(lookupProvider: mockLookup);

      final validResult = await validator.validateStreamUrl('https://legit-cdn.com/stream.m3u8');
      expect(validResult.isValid, isTrue);

      final rebindingResult = await validator.validateStreamUrl('https://attacker-rebinding.com/secret');
      expect(rebindingResult.isValid, isFalse);
      expect(rebindingResult.reason, contains('privada'));
    });
  });
}
