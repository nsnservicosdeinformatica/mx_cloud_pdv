# Script para criar stubs dos arquivos que importam stone_payments
# Isso permite compilar o código no Windows sem o pacote stone_payments

Write-Host "=========================================="
Write-Host "CREATING STONE PAYMENTS STUBS"
Write-Host "=========================================="

$filesToStub = @(
    @{
        Original = "lib/data/adapters/payment/providers/stone_pos_adapter.dart"
        Stub = "lib/data/adapters/payment/providers/stone_pos_adapter.dart.stub"
        Backup = "lib/data/adapters/payment/providers/stone_pos_adapter.dart.bak"
    }
)

foreach ($file in $filesToStub) {
    $originalPath = $file.Original
    $stubPath = $file.Stub
    $backupPath = $file.Backup
    
    if (Test-Path $originalPath) {
        Write-Host "   Criando stub para: $originalPath"
        
        # Cria backup do original
        if (-not (Test-Path $backupPath)) {
            Copy-Item $originalPath $backupPath
            Write-Host "     Backup criado: $backupPath"
        }
        
        # Cria stub que não importa stone_payments
        $stubContent = @"
// STUB: Este arquivo substitui stone_pos_adapter.dart quando stone_payments não está disponível
// (ex: build Windows)
import '../../../../core/payment/payment_provider.dart';
import 'package:flutter/foundation.dart';

/// Stub do Stone POS Adapter (não disponível no Windows)
class StonePOSAdapter implements PaymentProvider {
  final Map<String, dynamic>? _settings;
  
  StonePOSAdapter({Map<String, dynamic>? settings}) : _settings = settings;
  
  @override
  String get providerName => 'Stone';
  
  @override
  PaymentType get paymentType => PaymentType.pos;
  
  @override
  bool get isAvailable => false;
  
  @override
  bool get requiresUserInteraction => true;
  
  @override
  Future<void> initialize() async {
    throw UnimplementedError('Stone POS Adapter não disponível no Windows');
  }
  
  @override
  Future<PaymentResult> processPayment(PaymentRequest request) async {
    throw UnimplementedError('Stone POS Adapter não disponível no Windows');
  }
  
  @override
  Future<void> cancelPayment() async {
    throw UnimplementedError('Stone POS Adapter não disponível no Windows');
  }
  
  @override
  Future<void> dispose() async {
    // Nada a fazer
  }
}
"@
        
        # Substitui o arquivo original pelo stub
        Set-Content -Path $originalPath -Value $stubContent -NoNewline
        Write-Host "     ✅ Stub criado: $originalPath"
    } else {
        Write-Host "   ⚠️ Arquivo não encontrado: $originalPath"
    }
}

Write-Host "✅ Stubs criados com sucesso"

