import 'print_data.dart';
import 'nfce_print_data.dart';

/// Interface base para providers de impressão
abstract class PrintProvider {
  /// Nome do provider (ex: "Elgin", "Bematech", "PDF")
  String get providerName;
  
  /// Tipo de impressão (thermal, pdf, network)
  PrintType get printType;
  
  /// Se o provider está disponível
  bool get isAvailable;
  
  /// Imprime uma comanda (cada provider formata como seu SDK precisa)
  Future<PrintResult> printComanda(PrintData data);
  
  /// Imprime uma NFC-e (cada provider formata como seu SDK precisa)
  Future<PrintResult> printNfce(NfcePrintData data);
  
  /// Verifica status da impressora
  Future<bool> checkPrinterStatus();
  
  /// Inicializa o provider
  Future<void> initialize();
  
  /// Desconecta/limpa recursos
  Future<void> disconnect();
}

/// Tipo de impressão
enum PrintType {
  thermal,    // Impressora térmica (SDK)
  pdf,        // Gera PDF
  network,    // Impressora de rede
}

/// Resultado de uma impressão
class PrintResult {
  final bool success;
  final String? errorMessage;
  final String? printJobId;
  
  PrintResult({
    required this.success,
    this.errorMessage,
    this.printJobId,
  });
}

