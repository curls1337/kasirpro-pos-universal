import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BcaGatewayException implements Exception {
  final String message;
  final int? statusCode;

  const BcaGatewayException(this.message, {this.statusCode});

  @override
  String toString() =>
      statusCode != null ? 'BcaGatewayException($statusCode): $message' : message;
}

class BcaChargeResult {
  final int transactionId;
  final String externalId;
  final int amount;
  final String qrisString;
  final String qrisImageBase64;
  final String status;
  final bool exactAmount;

  const BcaChargeResult({
    required this.transactionId,
    required this.externalId,
    required this.amount,
    required this.qrisString,
    required this.qrisImageBase64,
    required this.status,
    this.exactAmount = true,
  });

  factory BcaChargeResult.fromJson(Map<String, dynamic> json) {
    final rawTxId = json['transaction_id'];
    final txId = rawTxId is int
        ? rawTxId
        : (rawTxId is num ? rawTxId.toInt() : int.tryParse('$rawTxId') ?? 0);

    final rawAmt = json['amount'];
    final amt = rawAmt is int
        ? rawAmt
        : (rawAmt is num ? rawAmt.toInt() : int.tryParse('$rawAmt') ?? 0);

    return BcaChargeResult(
      transactionId: txId,
      externalId: (json['external_id'] ?? '') as String,
      amount: amt,
      qrisString: (json['qris_string'] ?? '') as String,
      qrisImageBase64:
          (json['qris_image'] ?? json['qris_image_base64'] ?? '') as String,
      status: (json['status'] ?? 'pending') as String,
      exactAmount: json['exact_amount'] == true,
    );
  }
}

class BcaStatusResult {
  final String externalId;
  final String status;
  final int amount;
  final String paymentMethod;
  final String? createdAt;
  final String? updatedAt;

  const BcaStatusResult({
    required this.externalId,
    required this.status,
    required this.amount,
    this.paymentMethod = 'qris',
    this.createdAt,
    this.updatedAt,
  });

  bool get isPaid => status.toLowerCase() == 'paid' || status.toLowerCase() == 'settled';

  factory BcaStatusResult.fromJson(Map<String, dynamic> json) {
    final rawAmt = json['amount'];
    final amt = rawAmt is int
        ? rawAmt
        : (rawAmt is num ? rawAmt.toInt() : int.tryParse('$rawAmt') ?? 0);

    return BcaStatusResult(
      externalId: (json['external_id'] ?? '') as String,
      status: (json['status'] ?? 'pending') as String,
      amount: amt,
      paymentMethod: (json['payment_method'] ?? 'qris') as String,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }
}

class BcaConnectionResult {
  final bool success;
  final String message;
  final int? statusCode;

  const BcaConnectionResult({
    required this.success,
    required this.message,
    this.statusCode,
  });
}

class BarcodeProductLookupResult {
  final String barcode;
  final String name;
  final String brand;
  final String category;
  final String unit;
  final String imageUrl;
  final int estimatedPrice;
  final String source; // 'server' | 'openfoodfacts'

  const BarcodeProductLookupResult({
    required this.barcode,
    required this.name,
    this.brand = '',
    this.category = '',
    this.unit = 'pcs',
    this.imageUrl = '',
    this.estimatedPrice = 0,
    required this.source,
  });

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  factory BarcodeProductLookupResult.fromServerJson(
    Map<String, dynamic> json,
    String fallbackBarcode,
  ) {
    final raw = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : ((json['product'] is Map<String, dynamic>)
            ? json['product'] as Map<String, dynamic>
            : json);
    return BarcodeProductLookupResult(
      barcode: (raw['barcode'] ?? fallbackBarcode).toString().trim(),
      name: (raw['name'] ?? raw['product_name'] ?? '').toString().trim(),
      brand: (raw['brand'] ?? raw['brands'] ?? '').toString().trim(),
      category: (raw['category'] ?? raw['categories'] ?? '').toString().trim(),
      unit: ((raw['unit'] ?? raw['quantity'] ?? 'pcs').toString().trim())
              .isEmpty
          ? 'pcs'
          : (raw['unit'] ?? raw['quantity'] ?? 'pcs').toString().trim(),
      imageUrl: (raw['image_url'] ?? raw['imageUrl'] ?? '').toString().trim(),
      estimatedPrice: _parseInt(
        raw['estimated_price'] ?? raw['estimatedPrice'] ?? raw['price'],
      ),
      source: 'server',
    );
  }
}

class BcaGatewayService {
  BcaGatewayService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 20);

  String _normalizeBaseUrl(String baseUrl) {
    var trimmed = baseUrl.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Map<String, String> _buildHeaders(String apiKey, {bool jsonBody = false}) {
    final cleanKey = apiKey.trim();
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-api-key': cleanKey,
      'Authorization': 'Bearer $cleanKey',
    };
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const BcaGatewayException('Respon server bukan JSON object yang valid');
  }

  Future<BcaChargeResult> createQrisCharge({
    required String baseUrl,
    required String apiKey,
    required String externalId,
    required double amount,
    bool exactAmount = true,
  }) async {
    final normalizedUrl = _normalizeBaseUrl(baseUrl);
    if (normalizedUrl.isEmpty || apiKey.trim().isEmpty) {
      throw const BcaGatewayException(
        'URL Gateway dan API Key wajib dikonfigurasi terlebih dahulu',
      );
    }

    final uri = Uri.parse('$normalizedUrl/api/v1/charge');
    try {
      final response = await _client
          .post(
            uri,
            headers: _buildHeaders(apiKey, jsonBody: true),
            body: jsonEncode({
              'external_id': externalId,
              'amount': amount.round(),
              'exact_amount': exactAmount,
            }),
          )
          .timeout(_timeout);

      final data = _decodeJsonMap(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return BcaChargeResult.fromJson(data);
      }
      throw BcaGatewayException(
        (data['message'] ?? 'Gagal membuat tagihan QRIS').toString(),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const BcaGatewayException('Koneksi ke BCA Gateway timeout');
    } on BcaGatewayException {
      rethrow;
    } catch (e) {
      throw BcaGatewayException('Gagal menghubungi BCA Gateway: $e');
    }
  }

  Future<BcaStatusResult> checkPaymentStatus({
    required String baseUrl,
    required String apiKey,
    required String externalId,
  }) async {
    final normalizedUrl = _normalizeBaseUrl(baseUrl);
    if (normalizedUrl.isEmpty || apiKey.trim().isEmpty) {
      throw const BcaGatewayException(
        'URL Gateway dan API Key wajib dikonfigurasi terlebih dahulu',
      );
    }

    final uri = Uri.parse(
      '$normalizedUrl/api/v1/status/${Uri.encodeComponent(externalId)}',
    );
    try {
      final response = await _client
          .get(uri, headers: _buildHeaders(apiKey))
          .timeout(_timeout);

      final data = _decodeJsonMap(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return BcaStatusResult.fromJson(data);
      }
      throw BcaGatewayException(
        (data['message'] ?? 'Gagal mengecek status pembayaran').toString(),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const BcaGatewayException('Koneksi ke BCA Gateway timeout');
    } on BcaGatewayException {
      rethrow;
    } catch (e) {
      throw BcaGatewayException('Gagal mengecek status pembayaran: $e');
    }
  }

  Future<BcaConnectionResult> testConnection({
    required String baseUrl,
    required String apiKey,
  }) async {
    final normalizedUrl = _normalizeBaseUrl(baseUrl);
    final parsed = Uri.tryParse(normalizedUrl);
    if (normalizedUrl.isEmpty ||
        parsed == null ||
        !(parsed.isScheme('http') || parsed.isScheme('https')) ||
        parsed.host.isEmpty) {
      return const BcaConnectionResult(
        success: false,
        message: 'URL Gateway tidak valid (gunakan http:// atau https://)',
      );
    }
    if (apiKey.trim().isEmpty) {
      return const BcaConnectionResult(
        success: false,
        message: 'API Key tidak boleh kosong',
      );
    }

    final uri = Uri.parse('$normalizedUrl/api/v1/status/__connection_test__');
    try {
      final response = await _client
          .get(uri, headers: _buildHeaders(apiKey))
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 404) {
        return BcaConnectionResult(
          success: true,
          message: 'Koneksi dan API Key valid',
          statusCode: response.statusCode,
        );
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        String msg = 'API Key tidak valid atau merchant dinonaktifkan';
        try {
          final data = _decodeJsonMap(response.body);
          if (data['message'] != null) {
            msg = data['message'].toString();
          }
        } catch (_) {}
        return BcaConnectionResult(
          success: false,
          message: msg,
          statusCode: response.statusCode,
        );
      }

      return BcaConnectionResult(
        success: false,
        message: 'Server merespons status HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return const BcaConnectionResult(
        success: false,
        message: 'Koneksi timeout saat menghubungi server gateway',
      );
    } catch (e) {
      return BcaConnectionResult(
        success: false,
        message: 'Gagal terhubung ke gateway: $e',
      );
    }
  }

  Future<BarcodeProductLookupResult?> lookupBarcodeProduct({
    required String baseUrl,
    String apiKey = '',
    required String barcode,
  }) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

    final normalizedUrl = _normalizeBaseUrl(baseUrl);
    if (normalizedUrl.isNotEmpty) {
      final serverUri = Uri.tryParse(
        '$normalizedUrl/api/v1/barcode/${Uri.encodeComponent(cleanBarcode)}',
      );
      if (serverUri != null &&
          (serverUri.isScheme('http') || serverUri.isScheme('https')) &&
          serverUri.host.isNotEmpty) {
        try {
          final response = await _client
              .get(serverUri, headers: _buildHeaders(apiKey))
              .timeout(_timeout);
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final data = _decodeJsonMap(response.body);
            final result = BarcodeProductLookupResult.fromServerJson(
              data,
              cleanBarcode,
            );
            if (result.name.isNotEmpty || result.imageUrl.isNotEmpty) {
              return result;
            }
          }
        } catch (_) {
          // Fallback ke OpenFoodFacts jika server gagal / tidak merespons
        }
      }
    }

    // Fallback otomatis ke OpenFoodFacts API v3
    final offUri = Uri.parse(
      'https://world.openfoodfacts.org/api/v3/product/${Uri.encodeComponent(cleanBarcode)}.json',
    );
    try {
      final response = await _client.get(
        offUri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'KasirProPOS/1.0',
        },
      ).timeout(_timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = _decodeJsonMap(response.body);
        final product = data['product'];
        if (product is Map<String, dynamic>) {
          final rawName = (product['product_name_id'] ??
                  product['product_name'] ??
                  product['product_name_en'] ??
                  product['generic_name'] ??
                  '')
              .toString()
              .trim();
          final brand = (product['brands'] ?? '').toString().trim();
          final rawCats = (product['categories'] ?? '').toString().trim();
          final firstCat = rawCats.isEmpty
              ? ''
              : rawCats.split(',').first.trim();
          final imageUrl = (product['image_front_url'] ??
                  product['image_url'] ??
                  product['image_front_small_url'] ??
                  '')
              .toString()
              .trim();

          final displayName = rawName.isNotEmpty
              ? rawName
              : (brand.isNotEmpty ? '$brand ($cleanBarcode)' : '');

          if (displayName.isNotEmpty || imageUrl.isNotEmpty) {
            return BarcodeProductLookupResult(
              barcode: cleanBarcode,
              name: displayName,
              brand: brand,
              category: firstCat,
              unit: 'pcs',
              imageUrl: imageUrl,
              estimatedPrice: 0,
              source: 'openfoodfacts',
            );
          }
        }
      }
    } catch (_) {
      // Abaikan kegagalan jaringan saat lookup fallback
    }
    return null;
  }
}
