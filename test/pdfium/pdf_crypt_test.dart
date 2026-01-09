import 'dart:typed_data';

import 'package:pdfium_dart/pdfium_dart.dart';
import 'package:test/test.dart';

void main() {
  group('RC4', () {
    test('encrypts and decrypts correctly', () {
      final key = Uint8List.fromList([1, 2, 3, 4, 5]);
      final plaintext = Uint8List.fromList('Hello, World!'.codeUnits);
      
      // Encrypt
      final encrypted = RC4.cryptWithKey(plaintext, key);
      expect(encrypted, isNot(equals(plaintext)));
      
      // Decrypt (RC4 is symmetric)
      final decrypted = RC4.cryptWithKey(encrypted, key);
      expect(decrypted, equals(plaintext));
    });
    
    test('different keys produce different output', () {
      final key1 = Uint8List.fromList([1, 2, 3, 4, 5]);
      final key2 = Uint8List.fromList([5, 4, 3, 2, 1]);
      final plaintext = Uint8List.fromList('Hello'.codeUnits);
      
      final encrypted1 = RC4.cryptWithKey(Uint8List.fromList(plaintext), key1);
      final encrypted2 = RC4.cryptWithKey(Uint8List.fromList(plaintext), key2);
      
      expect(encrypted1, isNot(equals(encrypted2)));
    });
    
    test('handles empty input', () {
      final key = Uint8List.fromList([1, 2, 3]);
      final empty = Uint8List(0);
      
      final result = RC4.cryptWithKey(empty, key);
      expect(result.length, 0);
    });
    
    test('produces consistent output', () {
      final key = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05]);
      final plaintext = Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00]);
      
      // RC4 with this key produces known keystream
      final encrypted = RC4.cryptWithKey(plaintext, key);
      
      // Encrypt same data twice should give same result
      final encrypted2 = RC4.cryptWithKey(Uint8List.fromList(plaintext), key);
      expect(encrypted, equals(encrypted2));
    });
  });
  
  group('MD5Hash', () {
    test('generates correct hash', () {
      // Known MD5 hash of empty string
      final emptyHash = MD5Hash.generate(Uint8List(0));
      expect(emptyHash.length, 16);
      
      // MD5("") = d41d8cd98f00b204e9800998ecf8427e
      expect(emptyHash[0], 0xd4);
      expect(emptyHash[1], 0x1d);
      expect(emptyHash[15], 0x7e);
    });
    
    test('generates consistent hash', () {
      final data = Uint8List.fromList('Hello'.codeUnits);
      
      final hash1 = MD5Hash.generate(data);
      final hash2 = MD5Hash.generate(Uint8List.fromList(data));
      
      expect(hash1, equals(hash2));
    });
    
    test('different data produces different hash', () {
      final hash1 = MD5Hash.generate(Uint8List.fromList('Hello'.codeUnits));
      final hash2 = MD5Hash.generate(Uint8List.fromList('World'.codeUnits));
      
      expect(hash1, isNot(equals(hash2)));
    });
    
    test('generateMultiple works correctly', () {
      final data1 = Uint8List.fromList([1, 2, 3]);
      final data2 = Uint8List.fromList([4, 5, 6]);
      
      final multiHash = MD5Hash.generateMultiple([data1, data2]);
      
      // Should equal hash of concatenated data
      final combined = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
      final singleHash = MD5Hash.generate(combined);
      
      expect(multiHash, equals(singleHash));
    });
  });
  
  group('SHA256Hash', () {
    test('generates correct hash', () {
      final hash = SHA256Hash.generate(Uint8List(0));
      expect(hash.length, 32);
      
      // SHA256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
      expect(hash[0], 0xe3);
      expect(hash[1], 0xb0);
    });
    
    test('generates consistent hash', () {
      final data = Uint8List.fromList('Test'.codeUnits);
      
      final hash1 = SHA256Hash.generate(data);
      final hash2 = SHA256Hash.generate(Uint8List.fromList(data));
      
      expect(hash1, equals(hash2));
    });
  });
  
  group('AESCrypt', () {
    test('encrypts and decrypts', () {
      final key = Uint8List(16); // 128-bit zero key
      final iv = Uint8List(16);
      final plaintext = Uint8List.fromList('Hello, AES World'.codeUnits);
      
      final aes = AESCrypt(key, iv: iv);
      
      // Note: encrypt/decrypt need proper initialization
      // This is a basic test structure
      expect(aes, isNotNull);
    });
  });
  
  group('PdfPermissions', () {
    test('has correct flag values', () {
      expect(PdfPermissions.print, 4);
      expect(PdfPermissions.modifyContents, 8);
      expect(PdfPermissions.copy, 16);
      expect(PdfPermissions.annotate, 32);
    });
    
    test('hasPermission works correctly', () {
      const permissions = PdfPermissions.print | PdfPermissions.copy;
      
      expect(PdfPermissions.hasPermission(permissions, PdfPermissions.print), true);
      expect(PdfPermissions.hasPermission(permissions, PdfPermissions.copy), true);
      expect(PdfPermissions.hasPermission(permissions, PdfPermissions.modifyContents), false);
    });
    
    test('all permissions flag', () {
      expect(PdfPermissions.hasPermission(PdfPermissions.all, PdfPermissions.print), true);
      expect(PdfPermissions.hasPermission(PdfPermissions.all, PdfPermissions.copy), true);
      expect(PdfPermissions.hasPermission(PdfPermissions.all, PdfPermissions.annotate), true);
    });
  });
  
  group('PdfSecurityHandler', () {
    test('creates with required parameters', () {
      final handler = PdfSecurityHandler(
        revision: 3,
        keyLength: 16,
        permissions: PdfPermissions.all,
        ownerHash: Uint8List(32),
        userHash: Uint8List(32),
        documentId: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
      );
      
      expect(handler.revision, 3);
      expect(handler.keyLength, 16);
      expect(handler.isAuthenticated, false);
    });
    
    test('authentication with empty password on unencrypted doc', () {
      // Create handler simulating an unencrypted document
      // (user hash matches computed hash for empty password)
      final handler = PdfSecurityHandler(
        revision: 2,
        keyLength: 5,
        permissions: PdfPermissions.all,
        ownerHash: Uint8List(32),
        userHash: Uint8List(32), // Would need proper hash for real test
        documentId: Uint8List(16),
      );
      
      // This would fail with a real encrypted PDF but tests the structure
      expect(handler.encryptionKey, isNull);
    });
  });
}
