# Como Limpar Cache no GitHub Actions

## Problema
Se você está fazendo build no Mac e enviando para Windows via GitHub Actions, o cache pode estar usando versões antigas do código.

## Soluções

### 1. Verificar se as mudanças foram commitadas
```bash
# Verificar status
git status

# Se houver arquivos modificados, adicionar e commitar
git add .
git commit -m "Fix: Ajustes de layout para Windows (navegação, teclado, seleção)"
git push
```

### 2. Limpar cache do GitHub Actions

#### Opção A: Via Interface do GitHub
1. Vá para o repositório no GitHub
2. Clique em **Actions**
3. Encontre o workflow que faz o build
4. Clique nos **3 pontos** (⋯) no canto superior direito
5. Selecione **"Delete all workflow runs"** ou **"Clear cache"**

#### Opção B: Forçar rebuild sem cache
Adicione um comentário no commit ou force um novo push:
```bash
# Fazer um commit vazio para forçar rebuild
git commit --allow-empty -m "Force rebuild - clear cache"
git push
```

#### Opção C: Modificar o workflow para limpar cache
Se você tem acesso ao arquivo `.github/workflows/*.yml`, adicione:

```yaml
- name: Clear Flutter cache
  run: |
    flutter clean
    flutter pub cache clean
    rm -rf build/
    rm -rf .dart_tool/
```

### 3. Verificar se o código está correto

#### Arquivo: `lib/presentation/widgets/common/home_navigation.dart`
- Linha 3: Deve ter `import 'dart:io' show Platform;`
- Linha 198-199: Deve ter detecção de desktop
- Linha 282: Deve retornar `content` direto para desktop (sem SafeArea)

#### Arquivo: `lib/core/widgets/teclado_numerico_dialog.dart`
- Linha 79: Deve ter `height = maxHeight.clamp(500.0, 800.0)`
- Linha 208: Header deve ter `padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)`
- Linha 217: Título deve ter `fontSize: 18`

#### Arquivo: `lib/screens/pedidos/restaurante/dialogs/selecionar_mesa_comanda_dialog.dart`
- Linha 876: Padding deve ser `adaptive.isMobile ? 32 : 28`
- Linha 890: Ícone deve ser `adaptive.isMobile ? 64 : 56`
- Linha 910: Fonte do número deve ser `adaptive.isMobile ? 24 : 22`

### 4. Verificar logs do GitHub Actions
1. Vá para **Actions** no GitHub
2. Clique no último workflow run
3. Verifique se há erros de compilação
4. Procure por mensagens como "cache hit" ou "cache miss"

### 5. Forçar rebuild completo
No workflow do GitHub Actions, adicione um step antes do build:

```yaml
- name: Clean build
  run: |
    flutter clean
    flutter pub cache clean
    rm -rf build/
    rm -rf .dart_tool/
    flutter pub get
```

## Checklist antes de fazer push

- [ ] Todas as mudanças foram salvas
- [ ] `git status` mostra os arquivos modificados
- [ ] Não há erros de lint (`flutter analyze`)
- [ ] O código compila localmente no Mac
- [ ] Commit e push foram feitos

## Se ainda não funcionar

1. **Verificar se o build está usando a branch correta**
   - Confirme que o GitHub Actions está buildando a branch com suas mudanças

2. **Verificar versão do Flutter no GitHub Actions**
   - Pode haver incompatibilidade de versão

3. **Adicionar logs de debug**
   - Adicione `print('isDesktop: $isDesktop')` no código para verificar se está detectando corretamente

