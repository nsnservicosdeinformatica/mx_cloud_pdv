// Stub para o loader do Stone POS Adapter
// Este arquivo é usado no Windows/iOS onde o SDK Stone não está disponível
// Evita erro de compilação ao tentar importar stone_pos_adapter.dart

import '../../../../core/payment/payment_provider.dart';
import '../../../../core/config/flavor_config.dart';

/// Factory function stub para criar Stone POS Adapter
/// Esta função nunca será chamada no Windows/iOS
/// Retorna uma função que lança exceção
PaymentProvider Function(Map<String, dynamic>?) createStonePosAdapterLoader() {
  return (settings) {
    throw UnimplementedError('Stone POS Adapter não disponível nesta plataforma');
  };
}

