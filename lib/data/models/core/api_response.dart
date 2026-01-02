/// Resposta padrão da API
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final List<String> errors;
  final String timestamp;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    required this.errors,
    required this.timestamp,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: fromJsonT(json['data']),
      errors: List<String>.from(json['errors'] ?? []),
      timestamp: json['timestamp'] ?? '',
    );
  }

  /// Cria uma resposta de sucesso
  factory ApiResponse.success({
    required T data,
    String message = '',
  }) {
    return ApiResponse<T>(
      success: true,
      message: message,
      data: data,
      errors: [],
      timestamp: DateTime.now().toIso8601String(),
    );
  }

  /// Cria uma resposta de erro
  factory ApiResponse.error({
    required String message,
    List<String> errors = const [],
  }) {
    return ApiResponse<T>(
      success: false,
      message: message,
      data: null, // ✅ Corrigido: null é válido para T? (nullable)
      errors: errors,
      timestamp: DateTime.now().toIso8601String(),
    );
  }
}


