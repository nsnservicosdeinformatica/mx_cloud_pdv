# 📱 Atualização: Tipos de Controle Mesa/Comanda no PDV

## ✅ Alterações Realizadas

### 1. Enum Criado
- **Arquivo**: `lib/data/models/modules/restaurante/tipo_controle_venda.dart`
- **Enum**: `TipoControleVenda` com 3 valores:
  - `porMesa(1)` - Apenas Mesa
  - `porComanda(2)` - Apenas Comanda
  - `porMesaOuComanda(3)` - Mesa ou Comanda (híbrido)

### 2. DTO Atualizado
- **Arquivo**: `lib/data/models/modules/restaurante/configuracao_restaurante_dto.dart`
- **Adicionado**: Propriedade `controlePorMesaOuComanda`
- **Adicionado**: Métodos helper:
  - `tipoControleVendaEnum` - Retorna o enum
  - `isControlePorMesa` - Verifica se é por Mesa
  - `isControlePorComanda` - Verifica se é por Comanda
  - `isControlePorMesaOuComanda` - Verifica se é híbrido

### 3. Modelo Local Atualizado
- **Arquivo**: `lib/data/models/local/configuracao_restaurante_local.dart`
- **Adicionado**: Campo `controlePorMesaOuComanda` (HiveField 12)
- **Atualizado**: `updatedAt` agora é HiveField 14 (era 13)

### 4. Lógica de Sincronização Atualizada
- **Arquivo**: `lib/data/services/sync/sync_service.dart`
- **Ajustado**: Lógica para suportar os 3 tipos de controle
- **Comportamento**:
  - **PorMesa**: Força `comandaId = null`
  - **PorComanda**: Permite ambos (mesa opcional como referência)
  - **PorMesaOuComanda**: Permite ambos, nenhum obrigatório

### 5. Debug Prints Atualizados
- **Arquivos**: 
  - `lib/presentation/providers/services_provider.dart`
  - `lib/data/services/modules/restaurante/configuracao_restaurante_service.dart`
- **Ajustado**: Para mostrar corretamente os 3 tipos

---

## ⚠️ Ação Necessária: Regenerar Arquivo Hive

O arquivo `configuracao_restaurante_local.g.dart` precisa ser regenerado porque adicionamos um novo campo.

**Execute:**
```bash
cd h4nd-pdv
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 📋 Próximos Passos: Comportamento do App

Agora que os DTOs estão atualizados, precisamos ajustar o comportamento do app conforme cada tipo:

### **1. Tipo: Mesa (PorMesa = 1)**
- ✅ Comanda não deve aparecer na UI
- ✅ Apenas seleção de mesa
- ✅ Ao criar pedido, `comandaId` sempre `null`

### **2. Tipo: Mesa ou Comanda (PorMesaOuComanda = 3)**
- ✅ Mostrar opção de selecionar mesa, comanda ou ambos
- ✅ Nenhum é obrigatório
- ✅ Pode criar pedido sem mesa nem comanda (venda avulsa)

### **3. Tipo: Comanda (PorComanda = 2)**
- ✅ Mesa não é obrigatória (apenas referência)
- ✅ Comanda é o controle principal
- ✅ Pode criar pedido apenas com comanda

---

## 🔍 Onde Ajustar a Lógica

### **Telas que Precisam Ajuste:**

1. **`lib/screens/mesas_comandas/mesas_comandas_screen.dart`**
   - Mostrar/esconder opções conforme tipo de controle
   - Ajustar fluxo de seleção

2. **`lib/screens/pedidos/restaurante/novo_pedido_restaurante_screen.dart`**
   - Validar obrigatoriedade de mesa/comanda conforme tipo
   - Ajustar fluxo de criação

3. **`lib/screens/mesas/detalhes_produtos_mesa_screen.dart`**
   - Ajustar exibição conforme tipo de controle
   - Mostrar/esconder informações de comanda

4. **`lib/screens/dialogs/selecionar_mesa_comanda_dialog.dart`**
   - Ajustar opções disponíveis conforme tipo
   - Validar seleção obrigatória/opcional

---

## 📝 Exemplo de Uso

```dart
// Obter configuração
final config = servicesProvider.configuracaoRestaurante;

if (config == null) {
  // Usar valores padrão ou mostrar erro
  return;
}

// Verificar tipo de controle
if (config.isControlePorMesa) {
  // Apenas mesa - esconder comanda
  // Forçar comandaId = null
} else if (config.isControlePorComanda) {
  // Apenas comanda - mesa opcional
  // Comanda é obrigatória
} else if (config.isControlePorMesaOuComanda) {
  // Ambos opcionais
  // Pode ter mesa, comanda, ambos ou nenhum
}
```

---

## ✅ Checklist

- [x] Enum `TipoControleVenda` criado
- [x] DTO atualizado com novo campo
- [x] Modelo local atualizado
- [x] Lógica de sincronização ajustada
- [x] Debug prints atualizados
- [ ] **Regenerar arquivo Hive** (build_runner)
- [ ] Ajustar UI de seleção de mesa/comanda
- [ ] Ajustar validações de criação de pedido
- [ ] Ajustar exibição nas telas de detalhes
- [ ] Testar todos os 3 tipos

