import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/config/env_config.dart';
import 'core/config/connection_config_service.dart';
import 'core/storage/preferences_service.dart';
import 'core/storage/secure_storage_service.dart';
import 'data/services/core/auth_service.dart';
import 'data/database/app_database.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/services_provider.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/providers/pedido_provider.dart';
import 'presentation/providers/venda_balcao_provider.dart';
import 'presentation/providers/payment_flow_provider.dart'; // 🆕 Import do PaymentFlowProvider
import 'core/theme/app_theme.dart';
import 'core/adaptive_layout/adaptive_layout.dart';
import 'screens/splash/splash_screen.dart';
import 'presentation/screens/server_config/server_config_screen.dart';
import 'core/payment/payment_service.dart';
import 'core/config/flavor_config.dart';
import 'package:flutter/foundation.dart';

// NavigatorKey global para acessar context em qualquer lugar
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Tratamento de erros global para capturar crashes silenciosos
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('❌ FLUTTER ERROR: ${details.exception}');
    debugPrint('📚 Stack: ${details.stack}');
  };
  
  // Trata erros assíncronos não capturados
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('❌ PLATFORM ERROR: $error');
    debugPrint('📚 Stack: $stack');
    return true;
  };
  
  try {
    await initializeApp();
  } catch (e, stack) {
    debugPrint('❌ ERRO FATAL NA INICIALIZAÇÃO: $e');
    debugPrint('📚 Stack trace completo: $stack');
    
    // Tenta mostrar uma tela de erro para não fechar silenciosamente
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Erro ao inicializar o aplicativo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Função helper para inicializar o app (pode ser chamada novamente após configurar servidor)
Future<void> initializeApp() async {
  try {
    debugPrint('🚀 [INIT] Iniciando initializeApp...');
    
    // Remove a splash screen branca do Flutter
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
    debugPrint('✅ [INIT] SystemChrome configurado');
    
    // Inicializa FlavorConfig primeiro (para detectar o flavor correto)
    debugPrint('🔍 [INIT] Inicializando FlavorConfig...');
    await FlavorConfig.detectFlavorAsync();
    debugPrint('✅ [INIT] Flavor detectado: ${FlavorConfig.currentFlavor}');
    
    // Inicializa serviços
    debugPrint('📦 [INIT] Inicializando PreferencesService...');
    await PreferencesService.init();
    debugPrint('✅ [INIT] PreferencesService inicializado');
    
    // Verifica se o servidor está configurado
    debugPrint('🔍 [INIT] Verificando configuração do servidor...');
    final isServerConfigured = ConnectionConfigService.isConfigured();
    debugPrint('📋 [INIT] Servidor configurado: $isServerConfigured');
  
    // Se não estiver configurado, inicia direto na tela de configuração
    if (!isServerConfigured) {
      debugPrint('⚙️ [INIT] Servidor não configurado, abrindo tela de configuração...');
      runApp(
        MaterialApp(
          title: 'MX Cloud PDV',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: const AdaptiveLayout(
            child: ServerConfigScreen(allowBack: false),
          ),
        ),
      );
      debugPrint('✅ [INIT] App configurado (tela de configuração)');
      return;
    }
    
    // Inicializa Hive (banco de dados local)
    debugPrint('💾 [INIT] Inicializando AppDatabase (Hive)...');
    await AppDatabase.init();
    debugPrint('✅ [INIT] AppDatabase inicializado');
  
    // Cria instâncias dos serviços primeiro (para ter acesso ao ApiClient)
    debugPrint('🔧 [INIT] Criando serviços...');
    final config = Environment.config;
    debugPrint('🔍 [INIT] Environment.config retornou: ${config.runtimeType}');
    debugPrint('🔍 [INIT] config.apiUrl: ${config.apiUrl}');
    debugPrint('🔍 [INIT] ConnectionConfigService.getApiUrl(): ${ConnectionConfigService.getApiUrl()}');
    final secureStorage = SecureStorageService();
    final authService = AuthService(
      config: config,
      secureStorage: secureStorage,
    );
    debugPrint('✅ [INIT] AuthService criado com apiUrl: ${config.apiUrl}');
    
    // Cria ServicesProvider temporário para obter serviços
    debugPrint('🏭 [INIT] Criando ServicesProvider...');
    final tempServicesProvider = ServicesProvider(authService);
    debugPrint('✅ [INIT] ServicesProvider criado');
    
    // Configura PaymentService
    debugPrint('💳 [INIT] Configurando PaymentService...');
    final paymentService = await PaymentService.getInstance();
    debugPrint('✅ [INIT] PaymentService configurado');
    
    debugPrint('🎨 [INIT] Iniciando app principal...');
    runApp(
      MXCloudPDVApp(
        authService: authService,
        paymentService: paymentService, // 🆕 Passa PaymentService para o app
      ),
    );
    debugPrint('✅ [INIT] App iniciado com sucesso!');
  } catch (e, stack) {
    debugPrint('❌ [INIT] ERRO em initializeApp: $e');
    debugPrint('📚 [INIT] Stack trace: $stack');
    rethrow; // Re-lança para ser capturado no main()
  }
}

class MXCloudPDVApp extends StatelessWidget {
  final AuthService authService;
  final PaymentService paymentService; // 🆕 PaymentService para criar PaymentFlowProvider

  const MXCloudPDVApp({
    super.key,
    required this.authService,
    required this.paymentService, // 🆕 Novo parâmetro
  });

  @override
  Widget build(BuildContext context) {
    final servicesProvider = ServicesProvider(authService);
    
    // Inicializar repositories após criar o provider
    servicesProvider.initRepositories();
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService),
        ),
        ChangeNotifierProvider.value(
          value: servicesProvider,
        ),
        ChangeNotifierProxyProvider<ServicesProvider, SyncProvider>(
          create: (_) => servicesProvider.syncProvider,
          update: (_, services, __) => services.syncProvider,
        ),
        ChangeNotifierProxyProvider<ServicesProvider, PedidoProvider>(
          create: (_) => PedidoProvider(),
          update: (_, services, previous) {
            final provider = previous ?? PedidoProvider();
            // ✅ Configura PedidoService no PedidoProvider para permitir envio direto ao servidor
            provider.setPedidoService(services.pedidoService);
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => VendaBalcaoProvider(),
        ),
        // 🆕 Provider para gerenciar fluxo de pagamento
        // PaymentService já foi inicializado no initializeApp() e passado para o app
        ChangeNotifierProvider(
          create: (_) => PaymentFlowProvider(paymentService),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey, // NavigatorKey global para dialogs
        title: 'MX Cloud PDV',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        // Remove a splash screen branca do Flutter
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
            child: child!,
          );
        },
        home: const AdaptiveLayout(
          child: SplashScreen(),
        ),
      ),
    );
  }
}
