# Solução: Erro de DLL no Windows

## Problema

O app está dando erro ao tentar iniciar no Windows porque não consegue encontrar as DLLs necessárias. Isso geralmente acontece quando:

1. Dependências nativas não foram compiladas corretamente
2. O SDK Stone (`stone_payments`) está sendo importado no Windows, causando erro de compilação
3. Arquivos DLL não foram copiados para o diretório de build

## Solução Implementada

### 1. Remoção do Import Direto do SDK Stone

O arquivo `payment_provider_registry.dart` estava importando diretamente o `stone_pos_adapter_loader.dart`, que por sua vez importa o SDK Stone. No Windows, isso causa erro de compilação porque o SDK Stone não existe para Windows.

**Solução**: Removemos o import direto e implementamos uma verificação de plataforma antes de tentar usar o SDK Stone.

### 2. Verificação de Plataforma

Agora o código verifica se está rodando em Android antes de tentar usar o SDK Stone:

```dart
if (FlavorConfig.isStoneP2 && Platform.isAndroid) {
  // Só registra o provider Stone em Android
}
```

### 3. Tratamento de Erros

O código agora trata erros graciosamente quando o SDK Stone não está disponível:

```dart
try {
  registerProvider('stone_pos', (settings) {
    return _createStonePosAdapter(settings);
  });
} catch (e) {
  debugPrint('⚠️ Stone POS Adapter não disponível: $e');
}
```

## Como Resolver o Erro de DLL

### Passo 1: Limpar o Build

```bash
flutter clean
flutter pub get
```

### Passo 2: Reconstruir para Windows

```bash
flutter build windows --release
```

### Passo 3: Verificar se as DLLs foram copiadas

Após o build, verifique se a pasta `build/windows/x64/runner/Release/` contém:
- `mx_cloud_pdv.exe`
- Todas as DLLs necessárias (geralmente na mesma pasta)

### Passo 4: Se ainda houver erro

Se ainda houver erro de DLL, tente:

1. **Verificar se o Visual Studio está instalado corretamente**:
   ```bash
   flutter doctor -v
   ```

2. **Verificar se o CMake está instalado**:
   ```bash
   cmake --version
   ```

3. **Reinstalar as dependências**:
   ```bash
   flutter pub cache clean
   flutter pub get
   ```

## Observações Importantes

1. **SDK Stone**: O SDK Stone (`stone_payments`) não funciona no Windows, apenas no Android. O código agora verifica a plataforma antes de tentar usar.

2. **Flavors**: Os flavors (mobile/stoneP2) funcionam no Windows, mas o SDK Stone não estará disponível.

3. **Dependências Nativas**: Algumas dependências podem não ter suporte Windows. Verifique os pacotes usados:
   - `flutter_secure_storage` - ✅ Suporta Windows
   - `hive` - ✅ Suporta Windows
   - `path_provider` - ✅ Suporta Windows
   - `stone_payments` - ❌ Apenas Android

## Próximos Passos

Se o problema persistir, verifique:

1. Se há outras dependências nativas que não suportam Windows
2. Se o Visual Studio está configurado corretamente
3. Se o CMake está instalado e no PATH
4. Se há erros de compilação que não estão sendo mostrados

