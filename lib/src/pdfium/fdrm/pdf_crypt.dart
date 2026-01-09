

/// PDF Cryptography module
/// 
/// Port of core/fdrm/fx_crypt.h and related files
/// Provides encryption/decryption for PDF documents

import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart' hide Digest;

/// RC4 stream cipher implementation
class RC4 {
  late Uint8List _s;
  int _i = 0;
  int _j = 0;
  
  RC4(Uint8List key) {
    _s = Uint8List(256);
    _initialize(key);
  }
  
  void _initialize(Uint8List key) {
    // Key-scheduling algorithm (KSA)
    for (int i = 0; i < 256; i++) {
      _s[i] = i;
    }
    
    int j = 0;
    for (int i = 0; i < 256; i++) {
      j = (j + _s[i] + key[i % key.length]) & 0xFF;
      // Swap s[i] and s[j]
      final temp = _s[i];
      _s[i] = _s[j];
      _s[j] = temp;
    }
  }
  
  /// Encrypt/decrypt data in place
  void crypt(Uint8List data) {
    for (int k = 0; k < data.length; k++) {
      _i = (_i + 1) & 0xFF;
      _j = (_j + _s[_i]) & 0xFF;
      
      // Swap s[i] and s[j]
      final temp = _s[_i];
      _s[_i] = _s[_j];
      _s[_j] = temp;
      
      // XOR with keystream byte
      data[k] ^= _s[(_s[_i] + _s[_j]) & 0xFF];
    }
  }
  
  /// Encrypt/decrypt block and return result
  Uint8List cryptBlock(Uint8List data) {
    final result = Uint8List.fromList(data);
    crypt(result);
    return result;
  }
  
  /// Static method to encrypt/decrypt a block with a key
  static Uint8List cryptWithKey(Uint8List data, Uint8List key) {
    final rc4 = RC4(key);
    return rc4.cryptBlock(data);
  }
}

/// AES cipher implementation wrapper
class AESCrypt {
  late BlockCipher _cipher;
  late Uint8List _iv;
  
  AESCrypt(Uint8List key, {Uint8List? iv}) {
    _iv = iv ?? Uint8List(16);
    
    // Use CBC mode
    final params = ParametersWithIV(KeyParameter(key), _iv);
    _cipher = CBCBlockCipher(AESEngine())..init(false, params);
  }
  
  /// Set the initialization vector
  void setIV(Uint8List iv) {
    _iv = iv;
    final params = ParametersWithIV(KeyParameter(_cipher.algorithmName == 'AES' ? Uint8List(16) : Uint8List(32)), _iv);
    _cipher.reset();
    _cipher.init(false, params);
  }
  
  /// Decrypt data using AES-CBC
  Uint8List decrypt(Uint8List ciphertext) {
    if (ciphertext.length % 16 != 0) {
      throw ArgumentError('Ciphertext length must be multiple of 16');
    }
    
    final plaintext = Uint8List(ciphertext.length);
    var offset = 0;
    
    while (offset < ciphertext.length) {
      _cipher.processBlock(ciphertext, offset, plaintext, offset);
      offset += 16;
    }
    
    return _removePadding(plaintext);
  }
  
  /// Encrypt data using AES-CBC
  Uint8List encrypt(Uint8List plaintext) {
    final padded = _addPadding(plaintext);
    final ciphertext = Uint8List(padded.length);
    var offset = 0;
    
    _cipher.init(true, ParametersWithIV(KeyParameter(Uint8List(16)), _iv));
    
    while (offset < padded.length) {
      _cipher.processBlock(padded, offset, ciphertext, offset);
      offset += 16;
    }
    
    return ciphertext;
  }
  
  /// Add PKCS#7 padding
  Uint8List _addPadding(Uint8List data) {
    final padLength = 16 - (data.length % 16);
    final padded = Uint8List(data.length + padLength);
    padded.setRange(0, data.length, data);
    for (int i = data.length; i < padded.length; i++) {
      padded[i] = padLength;
    }
    return padded;
  }
  
  /// Remove PKCS#7 padding
  Uint8List _removePadding(Uint8List data) {
    if (data.isEmpty) return data;
    
    final padLength = data[data.length - 1];
    if (padLength > 16 || padLength == 0) return data;
    
    // Verify padding
    for (int i = data.length - padLength; i < data.length; i++) {
      if (data[i] != padLength) return data;
    }
    
    return Uint8List.fromList(data.sublist(0, data.length - padLength));
  }
}

/// MD5 hash utilities
class MD5Hash {
  /// Generate MD5 hash
  static Uint8List generate(Uint8List data) {
    final digest = crypto.md5.convert(data);
    return Uint8List.fromList(digest.bytes);
  }
  
  /// Generate MD5 hash from multiple inputs
  static Uint8List generateMultiple(List<Uint8List> inputs) {
    // Concatenate all inputs and hash
    var totalLength = 0;
    for (final input in inputs) {
      totalLength += input.length;
    }
    
    final combined = Uint8List(totalLength);
    var offset = 0;
    for (final input in inputs) {
      combined.setRange(offset, offset + input.length, input);
      offset += input.length;
    }
    
    return generate(combined);
  }
}

/// SHA-256 hash utilities
class SHA256Hash {
  /// Generate SHA-256 hash
  static Uint8List generate(Uint8List data) {
    final digest = crypto.sha256.convert(data);
    return Uint8List.fromList(digest.bytes);
  }
}

/// SHA-384 hash utilities
class SHA384Hash {
  /// Generate SHA-384 hash
  static Uint8List generate(Uint8List data) {
    final digest = crypto.sha384.convert(data);
    return Uint8List.fromList(digest.bytes);
  }
}

/// SHA-512 hash utilities
class SHA512Hash {
  /// Generate SHA-512 hash
  static Uint8List generate(Uint8List data) {
    final digest = crypto.sha512.convert(data);
    return Uint8List.fromList(digest.bytes);
  }
}

/// PDF encryption handler
class PdfSecurityHandler {
  static const _paddingBytes = <int>[
    0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41,
    0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
    0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
    0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A,
  ];
  
  /// Encryption revision
  final int revision;
  
  /// Key length in bytes
  final int keyLength;
  
  /// Permissions flags
  final int permissions;
  
  /// Owner password hash (O entry)
  final Uint8List ownerHash;
  
  /// User password hash (U entry)
  final Uint8List userHash;
  
  /// Document ID
  final Uint8List documentId;
  
  /// Encryption key (computed)
  Uint8List? _encryptionKey;
  
  PdfSecurityHandler({
    required this.revision,
    required this.keyLength,
    required this.permissions,
    required this.ownerHash,
    required this.userHash,
    required this.documentId,
  });
  
  /// Check if user password is valid
  bool authenticateUser(String password) {
    final key = _computeEncryptionKey(password);
    final computedU = _computeUserHash(key);
    
    // For revision 2, compare all 32 bytes
    // For revision 3+, compare first 16 bytes
    final compareLength = revision == 2 ? 32 : 16;
    
    for (int i = 0; i < compareLength; i++) {
      if (computedU[i] != userHash[i]) return false;
    }
    
    _encryptionKey = key;
    return true;
  }
  
  /// Check if owner password is valid
  bool authenticateOwner(String password) {
    final ownerKey = _computeOwnerKey(password);
    
    Uint8List userPassword;
    if (revision == 2) {
      userPassword = RC4.cryptWithKey(ownerHash, ownerKey);
    } else {
      // Revision 3+
      userPassword = Uint8List.fromList(ownerHash);
      for (int i = 19; i >= 0; i--) {
        final xorKey = Uint8List(ownerKey.length);
        for (int j = 0; j < ownerKey.length; j++) {
          xorKey[j] = ownerKey[j] ^ i;
        }
        userPassword = RC4.cryptWithKey(userPassword, xorKey);
      }
    }
    
    // Try to authenticate with recovered user password
    final passwordStr = String.fromCharCodes(userPassword.takeWhile((b) => b != 0));
    return authenticateUser(passwordStr);
  }
  
  /// Decrypt object data
  Uint8List decryptObject(int objNum, int genNum, Uint8List data) {
    if (_encryptionKey == null) {
      throw StateError('Document not authenticated');
    }
    
    final objKey = _computeObjectKey(objNum, genNum);
    
    if (revision >= 4) {
      // AES encryption
      final aes = AESCrypt(objKey, iv: data.sublist(0, 16));
      return aes.decrypt(data.sublist(16));
    } else {
      // RC4 encryption
      return RC4.cryptWithKey(data, objKey);
    }
  }
  
  /// Compute encryption key from password
  Uint8List _computeEncryptionKey(String password) {
    // Pad or truncate password to 32 bytes
    final paddedPassword = _padPassword(password);
    
    // Build input for MD5
    final inputs = <Uint8List>[
      paddedPassword,
      ownerHash,
      _int32ToBytes(permissions),
      documentId,
    ];
    
    // For revision 4 with AES, add 0xFFFFFFFF
    if (revision >= 4) {
      inputs.add(Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]));
    }
    
    var hash = MD5Hash.generateMultiple(inputs);
    
    // For revision 3+, do 50 iterations of MD5
    if (revision >= 3) {
      for (int i = 0; i < 50; i++) {
        hash = MD5Hash.generate(hash.sublist(0, keyLength));
      }
    }
    
    return hash.sublist(0, keyLength);
  }
  
  /// Compute user hash (U entry)
  Uint8List _computeUserHash(Uint8List key) {
    if (revision == 2) {
      return RC4.cryptWithKey(Uint8List.fromList(_paddingBytes), key);
    }
    
    // Revision 3+
    final hash = MD5Hash.generateMultiple([
      Uint8List.fromList(_paddingBytes),
      documentId,
    ]);
    
    var result = RC4.cryptWithKey(hash, key);
    
    for (int i = 1; i <= 19; i++) {
      final xorKey = Uint8List(key.length);
      for (int j = 0; j < key.length; j++) {
        xorKey[j] = key[j] ^ i;
      }
      result = RC4.cryptWithKey(result, xorKey);
    }
    
    // Pad to 32 bytes
    final padded = Uint8List(32);
    padded.setRange(0, 16, result);
    return padded;
  }
  
  /// Compute owner key
  Uint8List _computeOwnerKey(String password) {
    final paddedPassword = _padPassword(password);
    var hash = MD5Hash.generate(paddedPassword);
    
    if (revision >= 3) {
      for (int i = 0; i < 50; i++) {
        hash = MD5Hash.generate(hash);
      }
    }
    
    return hash.sublist(0, keyLength);
  }
  
  /// Compute object-specific encryption key
  Uint8List _computeObjectKey(int objNum, int genNum) {
    final key = _encryptionKey!;
    
    final input = Uint8List(key.length + 5);
    input.setRange(0, key.length, key);
    input[key.length] = objNum & 0xFF;
    input[key.length + 1] = (objNum >> 8) & 0xFF;
    input[key.length + 2] = (objNum >> 16) & 0xFF;
    input[key.length + 3] = genNum & 0xFF;
    input[key.length + 4] = (genNum >> 8) & 0xFF;
    
    final hash = MD5Hash.generate(input);
    final keyLen = (key.length + 5).clamp(0, 16);
    
    return hash.sublist(0, keyLen);
  }
  
  /// Pad password to 32 bytes
  Uint8List _padPassword(String password) {
    final bytes = Uint8List(32);
    final passwordBytes = password.codeUnits;
    
    final copyLen = passwordBytes.length.clamp(0, 32);
    for (int i = 0; i < copyLen; i++) {
      bytes[i] = passwordBytes[i];
    }
    
    for (int i = copyLen; i < 32; i++) {
      bytes[i] = _paddingBytes[i - copyLen];
    }
    
    return bytes;
  }
  
  /// Convert int32 to bytes (little endian)
  Uint8List _int32ToBytes(int value) {
    return Uint8List.fromList([
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ]);
  }
  
  /// Get encryption key (after authentication)
  Uint8List? get encryptionKey => _encryptionKey;
  
  /// Check if document is authenticated
  bool get isAuthenticated => _encryptionKey != null;
}

/// Permission flags for PDF documents
class PdfPermissions {
  /// Print the document
  static const int print = 1 << 2;
  
  /// Modify contents
  static const int modifyContents = 1 << 3;
  
  /// Copy text and graphics
  static const int copy = 1 << 4;
  
  /// Add or modify annotations
  static const int annotate = 1 << 5;
  
  /// Fill in form fields
  static const int fillForms = 1 << 8;
  
  /// Extract for accessibility
  static const int extractForAccessibility = 1 << 9;
  
  /// Assemble document
  static const int assemble = 1 << 10;
  
  /// High quality print
  static const int printHighQuality = 1 << 11;
  
  /// All permissions
  static const int all = 0xFFFFFFFC;
  
  /// Check if permission is granted
  static bool hasPermission(int permissions, int flag) {
    return (permissions & flag) != 0;
  }
}
