import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

class GoogleAccountProfile {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;

  const GoogleAccountProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
      };

  factory GoogleAccountProfile.fromMap(Map<String, dynamic> map) {
    final email = map['email']?.toString() ?? '';
    final name = map['displayName']?.toString() ?? '';
    return GoogleAccountProfile(
      id: map['id']?.toString() ?? '',
      email: email,
      displayName: name.isNotEmpty ? name : email,
      photoUrl: map['photoUrl']?.toString(),
    );
  }
}

class DriveBackupFile {
  final String id;
  final String name;
  final int sizeBytes;
  final DateTime createdTime;
  final DateTime modifiedTime;
  final String kind;
  final int accountCount;
  final int transactionCount;
  final int receiptCount;
  final int newReceiptsUploaded;

  const DriveBackupFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.createdTime,
    required this.modifiedTime,
    this.kind = 'db_snapshot',
    this.accountCount = 0,
    this.transactionCount = 0,
    this.receiptCount = 0,
    this.newReceiptsUploaded = 0,
  });

  factory DriveBackupFile.fromJson(Map<String, dynamic> json) {
    final props = json['appProperties'] is Map
        ? Map<String, dynamic>.from(json['appProperties'] as Map)
        : <String, dynamic>{};
    return DriveBackupFile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'backup.smbak',
      sizeBytes: int.tryParse(json['size']?.toString() ?? '') ?? 0,
      createdTime: DateTime.tryParse(json['createdTime']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
      modifiedTime: DateTime.tryParse(json['modifiedTime']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
      kind: props['kind']?.toString() ?? 'db_snapshot',
      accountCount:
          int.tryParse(props['accountCount']?.toString() ?? '') ?? 0,
      transactionCount:
          int.tryParse(props['transactionCount']?.toString() ?? '') ?? 0,
      receiptCount:
          int.tryParse(props['receiptCount']?.toString() ?? '') ?? 0,
      newReceiptsUploaded:
          int.tryParse(props['newReceiptsUploaded']?.toString() ?? '') ?? 0,
    );
  }
}

class GoogleDriveException implements Exception {
  final String message;
  final int? statusCode;

  GoogleDriveException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class GoogleDriveService {
  GoogleDriveService._();
  static final GoogleDriveService instance = GoogleDriveService._();

  static const String driveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';
  static const List<String> allAuthScopes = [
    'openid',
    'email',
    'profile',
    driveAppDataScope,
  ];

  static const String settingGoogleProfileKey = '@google_account_info';
  static const String settingServerClientIdKey = '@google_server_client_id';
  static const int maxRetainedBackups = 5;

  bool _isInitialized = false;
  String? _initializedServerClientId;
  GoogleSignInAccount? _currentGoogleUser;
  GoogleAccountProfile? _cachedProfile;
  String? _cachedServerClientId;
  String? _lastAccessToken;

  Future<String?> getServerClientId() async {
    if (_cachedServerClientId != null && _cachedServerClientId!.isNotEmpty) {
      return _cachedServerClientId;
    }
    try {
      final raw = await DatabaseHelper.instance.getSetting(settingServerClientIdKey);
      if (raw != null && raw.toString().trim().isNotEmpty) {
        _cachedServerClientId = raw.toString().trim();
        return _cachedServerClientId;
      }
    } catch (e) {
      debugPrint('GoogleDriveService getServerClientId error: $e');
    }
    return null;
  }

  Future<void> saveServerClientId(String clientId) async {
    final trimmed = clientId.trim();
    _cachedServerClientId = trimmed;
    await DatabaseHelper.instance.saveSetting(settingServerClientIdKey, trimmed);
    if (_isInitialized && _initializedServerClientId != trimmed) {
      _isInitialized = false;
    }
  }

  Future<GoogleAccountProfile?> getSavedProfile() async {
    if (_cachedProfile != null) return _cachedProfile;
    try {
      final raw =
          await DatabaseHelper.instance.getSetting(settingGoogleProfileKey);
      if (raw is Map) {
        _cachedProfile =
            GoogleAccountProfile.fromMap(Map<String, dynamic>.from(raw));
        return _cachedProfile;
      }
    } catch (e) {
      debugPrint('GoogleDriveService getSavedProfile error: $e');
    }
    return null;
  }

  Future<void> _saveProfile(GoogleAccountProfile? profile) async {
    _cachedProfile = profile;
    try {
      await DatabaseHelper.instance.saveSetting(
        settingGoogleProfileKey,
        profile?.toMap(),
      );
    } catch (e) {
      debugPrint('GoogleDriveService _saveProfile error: $e');
    }
  }

  Future<void> ensureInitialized() async {
    final serverClientId = await getServerClientId();
    if (_isInitialized && _initializedServerClientId == serverClientId) {
      return;
    }
    await GoogleSignIn.instance.initialize(
      serverClientId:
          (serverClientId != null && serverClientId.isNotEmpty)
              ? serverClientId
              : null,
    );
    _isInitialized = true;
    _initializedServerClientId = serverClientId;
  }

  /// Attempts lightweight silent authentication for returning users.
  Future<GoogleAccountProfile?> trySilentSignIn() async {
    try {
      await ensureInitialized();
      final serverClientId = await getServerClientId();
      if (serverClientId != null && serverClientId.isNotEmpty) {
        final future = GoogleSignIn.instance.attemptLightweightAuthentication();
        final user = future != null ? await future : null;
        if (user != null) {
          _currentGoogleUser = user;
          final profile = GoogleAccountProfile(
            id: user.id,
            email: user.email,
            displayName: (user.displayName ?? '').isNotEmpty
                ? user.displayName!
                : user.email,
            photoUrl: user.photoUrl,
          );
          await _saveProfile(profile);
          return profile;
        }
      } else {
        final saved = await getSavedProfile();
        if (saved != null) {
          final authz = await GoogleSignIn.instance.authorizationClient
              .authorizationForScopes(allAuthScopes);
          if (authz != null && authz.accessToken.isNotEmpty) {
            _lastAccessToken = authz.accessToken;
            return saved;
          }
        }
      }
    } catch (e) {
      debugPrint('GoogleDriveService trySilentSignIn error: $e');
    }
    return await getSavedProfile();
  }

  /// Interactive sign-in + Drive appDataFolder authorization.
  ///
  /// Uses Credential Manager when a Web Client ID ([serverClientId]) is set,
  /// otherwise triggers Google's native OAuth Authorization flow directly using
  /// the Android Client ID (Package Name + SHA-1) without requiring a Web Client ID.
  Future<GoogleAccountProfile> signInInteractive() async {
    await ensureInitialized();

    final serverClientId = await getServerClientId();

    try {
      if (serverClientId != null && serverClientId.isNotEmpty) {
        final user = await GoogleSignIn.instance.authenticate(
          scopeHint: const [driveAppDataScope],
        );
        _currentGoogleUser = user;

        final authz =
            await user.authorizationClient.authorizationForScopes(
              const [driveAppDataScope],
            ) ??
            await user.authorizationClient.authorizeScopes(
              const [driveAppDataScope],
            );

        if (authz.accessToken.isEmpty) {
          throw GoogleDriveException(
            'Izin akses Google Drive (drive.appdata) tidak diberikan.',
          );
        }
        _lastAccessToken = authz.accessToken;

        final profile = GoogleAccountProfile(
          id: user.id,
          email: user.email,
          displayName: (user.displayName ?? '').isNotEmpty
              ? user.displayName!
              : user.email,
          photoUrl: user.photoUrl,
        );
        await _saveProfile(profile);
        return profile;
      }

      // Direct Android OAuth flow via AuthorizationClient (pops up Google
      // account picker + Drive consent immediately using Android Client ID).
      final authz = await GoogleSignIn.instance.authorizationClient
          .authorizeScopes(allAuthScopes);

      if (authz.accessToken.isEmpty) {
        throw GoogleDriveException(
          'Izin akses Google Drive (drive.appdata) tidak diberikan.',
        );
      }
      _lastAccessToken = authz.accessToken;

      final profile = await _fetchGoogleUserProfile(authz.accessToken);
      await _saveProfile(profile);
      return profile;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw GoogleDriveException('Login Google dibatalkan.');
      }
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError) {
        throw GoogleDriveException(
          'Konfigurasi Google OAuth belum sesuai (${e.description ?? e.code.name}). Pastikan Package Name dan SHA-1 sudah benar di Google Cloud Console.',
        );
      }
      throw GoogleDriveException(
        'Gagal masuk ke Google: ${e.description ?? e.code.name}',
      );
    }
  }

  Future<GoogleAccountProfile> _fetchGoogleUserProfile(
    String accessToken,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final email = data['email']?.toString() ?? 'google-user';
        final name = data['name']?.toString() ?? '';
        return GoogleAccountProfile(
          id: data['sub']?.toString() ?? email,
          email: email,
          displayName: name.isNotEmpty ? name : email,
          photoUrl: data['picture']?.toString(),
        );
      }
    } catch (e) {
      debugPrint('GoogleDriveService _fetchGoogleUserProfile error: $e');
    }

    return const GoogleAccountProfile(
      id: 'google_drive_user',
      email: 'Akun Google Terhubung',
      displayName: 'Pengguna Google',
    );
  }

  Future<void> signOut() async {
    try {
      await ensureInitialized();
      if (_lastAccessToken != null && _lastAccessToken!.isNotEmpty) {
        try {
          await GoogleSignIn.instance.authorizationClient
              .clearAuthorizationToken(accessToken: _lastAccessToken!);
        } catch (_) {}
      }
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('GoogleDriveService signOut error: $e');
    } finally {
      _currentGoogleUser = null;
      _lastAccessToken = null;
      await _saveProfile(null);
    }
  }

  Future<String> _getAccessToken({required bool interactive}) async {
    await ensureInitialized();

    final serverClientId = await getServerClientId();
    GoogleSignInAccount? user = _currentGoogleUser;
    if (user == null && serverClientId != null && serverClientId.isNotEmpty) {
      final future = GoogleSignIn.instance.attemptLightweightAuthentication();
      user = future != null ? await future : null;
      _currentGoogleUser = user;
    }

    final authClient =
        user?.authorizationClient ?? GoogleSignIn.instance.authorizationClient;
    final scopes = (user != null) ? const [driveAppDataScope] : allAuthScopes;

    var authz = await authClient.authorizationForScopes(scopes);
    if (authz == null && interactive) {
      if (user == null &&
          serverClientId != null &&
          serverClientId.isNotEmpty) {
        user = await GoogleSignIn.instance.authenticate(
          scopeHint: const [driveAppDataScope],
        );
        _currentGoogleUser = user;
        authz = await user.authorizationClient.authorizeScopes(
          const [driveAppDataScope],
        );
      } else {
        authz = await authClient.authorizeScopes(scopes);
      }
    }

    if (authz == null || authz.accessToken.isEmpty) {
      throw GoogleDriveException(
        interactive
            ? 'Izin Google Drive tidak tersedia. Silakan login ulang.'
            : 'Token Google Drive tidak tersedia di background.',
      );
    }

    _lastAccessToken = authz.accessToken;
    return authz.accessToken;
  }

  Future<DriveBackupFile> uploadBackupBytes({
    required Uint8List bytes,
    required String fileName,
    Map<String, String> appProperties = const {},
    String mimeType = 'application/zip',
    bool pruneOldSnapshots = true,
    bool interactive = true,
  }) async {
    final token = await _getAccessToken(interactive: interactive);
    const boundary = 'smart_money_drive_multipart_boundary_v1';

    final metadataJson = jsonEncode({
      'name': fileName,
      'parents': ['appDataFolder'],
      if (appProperties.isNotEmpty) 'appProperties': appProperties,
    });

    final bodyBuilder = BytesBuilder();
    bodyBuilder.add(utf8.encode(
      '--$boundary\r\n'
      'Content-Type: application/json; charset=UTF-8\r\n\r\n'
      '$metadataJson\r\n'
      '--$boundary\r\n'
      'Content-Type: $mimeType\r\n\r\n',
    ));
    bodyBuilder.add(bytes);
    bodyBuilder.add(utf8.encode('\r\n--$boundary--\r\n'));

    final uri = Uri.parse(
      'https://www.googleapis.com/upload/drive/v3/files'
      '?uploadType=multipart&fields=id,name,size,createdTime,modifiedTime,appProperties',
    );

    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: bodyBuilder.takeBytes(),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleDriveException(
        'Gagal upload ke Google Drive (${response.statusCode}): ${_extractDriveError(response.body)}',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final uploaded = DriveBackupFile.fromJson(decoded);

    // Prune only old DB snapshots beyond maxRetainedBackups (never delete synced receipts)
    if (pruneOldSnapshots) {
      try {
        await _pruneOldBackups(token);
      } catch (e) {
        debugPrint('GoogleDriveService prune error: $e');
      }
    }

    return uploaded;
  }

  /// Returns a map of `receiptFileName -> driveFileId` for all receipt photos
  /// currently synced in `appDataFolder`.
  Future<Map<String, String>> listSyncedReceipts({
    bool interactive = false,
  }) async {
    final token = await _getAccessToken(interactive: interactive);
    final Map<String, String> synced = {};
    String? pageToken;

    do {
      final params = <String, String>{
        'spaces': 'appDataFolder',
        'q': "appProperties has { key='kind' and value='receipt' }",
        'fields': 'nextPageToken,files(id,name,appProperties)',
        'pageSize': '1000',
        'pageToken': ?pageToken,
      };
      final uri = Uri.https('www.googleapis.com', '/drive/v3/files', params);
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GoogleDriveException(
          'Gagal membaca daftar foto tersinkron (${response.statusCode}): ${_extractDriveError(response.body)}',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final files = decoded['files'] as List<dynamic>? ?? [];
      for (final raw in files) {
        final f = Map<String, dynamic>.from(raw as Map);
        final id = f['id']?.toString() ?? '';
        final props = f['appProperties'] is Map
            ? Map<String, dynamic>.from(f['appProperties'] as Map)
            : const <String, dynamic>{};
        final receiptName = props['receiptName']?.toString() ?? '';
        final fallbackName = (f['name']?.toString() ?? '')
            .replaceFirst(RegExp(r'^receipt_sync_'), '');
        final key = receiptName.isNotEmpty ? receiptName : fallbackName;
        if (id.isNotEmpty && key.isNotEmpty) {
          synced[key] = id;
        }
      }
      pageToken = decoded['nextPageToken']?.toString();
    } while (pageToken != null && pageToken.isNotEmpty);

    return synced;
  }

  Future<List<DriveBackupFile>> listBackups({bool interactive = false}) async {
    final token = await _getAccessToken(interactive: interactive);
    return _listBackupsWithToken(token);
  }

  Future<List<DriveBackupFile>> _listBackupsWithToken(String token) async {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'spaces': 'appDataFolder',
      'q': "not (appProperties has { key='kind' and value='receipt' })",
      'fields':
          'files(id,name,size,createdTime,modifiedTime,appProperties)',
      'orderBy': 'createdTime desc',
      'pageSize': '20',
    });

    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleDriveException(
        'Gagal membaca daftar backup Drive (${response.statusCode}): ${_extractDriveError(response.body)}',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final files = decoded['files'] as List<dynamic>? ?? [];
    return files
        .map((f) => DriveBackupFile.fromJson(Map<String, dynamic>.from(f as Map)))
        .where((f) => f.kind != 'receipt' && !f.name.startsWith('receipt_sync_'))
        .toList();
  }

  Future<Uint8List> downloadBackup(
    String fileId, {
    bool interactive = true,
  }) async {
    final token = await _getAccessToken(interactive: interactive);
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$fileId?alt=media',
    );

    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleDriveException(
        'Gagal mengunduh backup dari Drive (${response.statusCode}): ${_extractDriveError(response.body)}',
        statusCode: response.statusCode,
      );
    }

    return response.bodyBytes;
  }

  Future<void> deleteBackup(String fileId, {bool interactive = true}) async {
    final token = await _getAccessToken(interactive: interactive);
    final uri = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId');
    final response = await http
        .delete(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GoogleDriveException(
        'Gagal menghapus backup Drive (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> _pruneOldBackups(String token) async {
    final files = await _listBackupsWithToken(token);
    if (files.length <= maxRetainedBackups) return;

    final toDelete = files.sublist(maxRetainedBackups);
    for (final file in toDelete) {
      final uri =
          Uri.parse('https://www.googleapis.com/drive/v3/files/${file.id}');
      await http
          .delete(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
    }
  }

  String _extractDriveError(String body) {
    try {
      final decoded = jsonDecode(body);
      final msg = decoded['error']?['message'];
      if (msg != null) return msg.toString();
    } catch (_) {}
    return body;
  }
}
