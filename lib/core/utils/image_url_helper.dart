import '../config/env_config.dart';

/// Helper para construir URLs de imagens do S3
class ImageUrlHelper {
  /// URL base do S3 (obtida do env_config)
  /// Usa a configuração do frontend (debug = hml, release = prod)
  static String get s3BaseUrl => Environment.config.s3BaseUrl;

  /// Constrói a URL completa da imagem original
  /// 
  /// [fileName] Caminho relativo do arquivo (ex: "exibicoes-produto/original/abc123.jpg")
  /// O backend retorna apenas o caminho, o frontend adiciona o s3BaseUrl correto
  /// Retorna a URL completa ou null se fileName for null/vazio
  static String? getOriginalImageUrl(String? fileName) {
    if (fileName == null || fileName.isEmpty) return null;
    
    // Se fileName já é uma URL completa (caso raro), extrai apenas o path
    String path = fileName;
    if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
      final uri = Uri.tryParse(fileName);
      if (uri != null && uri.path.isNotEmpty) {
        path = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
      } else {
        return null;
      }
    }
    
    // Garantir que s3BaseUrl não tenha barra final e path não comece com barra
    final baseUrl = s3BaseUrl.endsWith('/') 
        ? s3BaseUrl.substring(0, s3BaseUrl.length - 1) 
        : s3BaseUrl;
    final normalizedPath = path.startsWith('/') 
        ? path.substring(1) 
        : path;
    return '$baseUrl/$normalizedPath';
  }

  /// Constrói a URL completa do thumbnail
  /// 
  /// [fileName] Caminho relativo do arquivo original (ex: "exibicoes-produto/original/abc123.jpg")
  /// O backend retorna apenas o caminho, o frontend adiciona o s3BaseUrl correto
  /// Retorna a URL completa do thumbnail ou null se fileName for null/vazio
  static String? getThumbnailImageUrl(String? fileName) {
    if (fileName == null || fileName.isEmpty) return null;
    
    // Se fileName já é uma URL completa (caso raro), extrai apenas o path
    String normalizedFileName = fileName;
    if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
      final uri = Uri.tryParse(fileName);
      if (uri != null && uri.path.isNotEmpty) {
        normalizedFileName = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
      } else {
        return null;
      }
    }
    
    // Substitui /original/ por /thumbnails/
    // O backend salva thumbnails sempre como .jpg (mesmo que o original seja .png)
    String thumbnailPath = normalizedFileName.replaceAll('/original/', '/thumbnails/');
    
    // Se não encontrou /original/, tenta substituir original/ por thumbnails/
    if (thumbnailPath == normalizedFileName) {
      thumbnailPath = normalizedFileName.replaceAll('original/', 'thumbnails/');
    }
    
    // Se ainda não encontrou, pode ser que o path não tenha /original/
    // Nesse caso, tenta adicionar thumbnails/ antes do nome do arquivo
    if (thumbnailPath == normalizedFileName) {
      // Extrai o nome do arquivo (última parte do path)
      final parts = normalizedFileName.split('/');
      final fileNameOnly = parts[parts.length - 1];
      // Remove a extensão original e adiciona .jpg (thumbnails são sempre jpg)
      final lastDotIndex = fileNameOnly.lastIndexOf('.');
      final fileNameWithoutExt = lastDotIndex > 0 
          ? fileNameOnly.substring(0, lastDotIndex) 
          : fileNameOnly;
      // Reconstrói o path com thumbnails
      final newParts = <String>[];
      for (int i = 0; i < parts.length - 1; i++) {
        newParts.add(parts[i]);
      }
      newParts.add('thumbnails');
      newParts.add('$fileNameWithoutExt.jpg');
      thumbnailPath = newParts.join('/');
    } else {
      // Se encontrou /original/, substitui a extensão por .jpg (thumbnails são sempre jpg)
      final lastDotIndex = thumbnailPath.lastIndexOf('.');
      if (lastDotIndex > 0) {
        thumbnailPath = thumbnailPath.substring(0, lastDotIndex) + '.jpg';
      }
    }
    
    // Garantir que s3BaseUrl não tenha barra final e thumbnailPath não comece com barra
    final baseUrl = s3BaseUrl.endsWith('/') 
        ? s3BaseUrl.substring(0, s3BaseUrl.length - 1) 
        : s3BaseUrl;
    final path = thumbnailPath.startsWith('/') 
        ? thumbnailPath.substring(1) 
        : thumbnailPath;
    return '$baseUrl/$path';
  }
}

