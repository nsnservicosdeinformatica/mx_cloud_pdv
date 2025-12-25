# Como Limpar Cache do Flutter no Windows

## Comandos para executar no terminal do Windows (PowerShell ou CMD):

### 1. Limpar build do Flutter
```bash
flutter clean
```

### 2. Limpar cache do pub (pacotes)
```bash
flutter pub cache clean
```

### 3. Limpar cache do Flutter completamente
```bash
flutter clean
flutter pub get
```

### 4. Limpar pasta build manualmente (se necessário)
No Windows Explorer, navegue até a pasta do projeto e delete:
- `build/` (pasta inteira)
- `.dart_tool/` (pasta inteira)

### 5. Reconstruir o projeto
```bash
flutter pub get
flutter run -d windows
```

## Se ainda não funcionar:

### 6. Limpar cache global do Flutter
```bash
# No PowerShell (como Administrador)
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Pub\Cache"
```

### 7. Verificar se está usando hot reload vs hot restart
- **Hot Reload** (F5 ou botão de reload): Pode não aplicar mudanças estruturais
- **Hot Restart** (Ctrl+Shift+F5 ou botão de restart): Reinicia o app completamente
- **Stop e Run novamente**: Para garantir que todas as mudanças sejam aplicadas

### 8. Verificar se está rodando a versão correta
```bash
# Verificar qual dispositivo está ativo
flutter devices

# Rodar especificamente no Windows
flutter run -d windows
```

## Comandos completos (copiar e colar):

```bash
# Limpar tudo
flutter clean
flutter pub cache clean
flutter pub get

# Reconstruir e rodar
flutter run -d windows
```

## Dica importante:
Se você está usando VS Code ou outro IDE, **feche e reabra o projeto** após limpar o cache para garantir que o IDE reconheça as mudanças.

