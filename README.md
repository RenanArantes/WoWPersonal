# WoWPersonal - Expansão de Opções de Visibilidade

Addon para World of Warcraft que expande as opções de visibilidade do Gerenciador de Recargas (Cooldown Manager), adicionando novas condições baseadas em localização e tipo de conteúdo.

## Funcionalidades

Este addon adiciona novas opções de visibilidade além das opções padrão:

### Opções Disponíveis

- **Na cidade** - Visível apenas quando em áreas de descanso (cidades, tavernas)
- **Na instância PVE** - Visível apenas quando em instâncias PVE (raides, dungeons, cenários)
- **Na instância PvP** - Visível apenas quando em instâncias PvP (arenas, campos de batalha, campos de batalha ranqueados)
- **No mundo aberto** - Visível apenas quando no mundo aberto (fora de cidades e instâncias)

**Controle de Transparência**: Cada opção de visibilidade possui dois controles de transparência:
- **Em Combate**: Define a transparência quando o jogador está em combate (0% = invisível, 100% = totalmente opaco)
- **Fora de Combate**: Define a transparência quando o jogador está fora de combate (0% = invisível, 100% = totalmente opaco)

Exemplos:
- **Cidade**: Fora de combate 0%, Em combate 100% (visível apenas quando em combate na cidade)
- **Instância**: Fora de combate 40%, Em combate 100% (semi-transparente fora de combate, totalmente opaco em combate)

## Instalação

1. Copie a pasta `WoWPersonal` para `World of Warcraft\_retail_\Interface\AddOns\`
2. Reinicie o jogo ou recarregue a interface (`/reload`)

## Uso

### Interface Principal

O addon possui uma interface gráfica própria que pode ser acessada de duas formas:

1. **Botão no Minimapa**: Clique no ícone do WoWPersonal no minimapa para abrir a interface
2. **Comando de Chat**: Digite `/wowp` no chat para abrir a interface

A interface permite:
- Selecionar o modo de visibilidade desejado (com todas as 4 opções disponíveis)
- Controlar transparência em combate com slider
- Controlar transparência fora de combate com slider
- Ver o estado atual do jogador em tempo real
- Registrar frames do Cooldown Manager para controle
- Ver lista de frames registrados
- Ativar/desativar modo de debug

### Interface de Configuração (Alternativa)

1. Abra o menu de configurações do jogo (ESC > Interface > AddOns)
2. Procure por "WoWPersonal" na lista de addons
3. Selecione o modo de visibilidade desejado no dropdown "Modo de Visibilidade"

### Registrando Frames do Cooldown Manager

No painel de configuração (Opções > AddOns > WoWPersonal > Visibility Options), na seção "Cooldown Manager Frames", há dois interruptores que registram automaticamente os frames do Gerenciador de Recargas para controle de visibilidade por cenário:

- **Control Essential Cooldown Viewer** — registra o frame `EssentialCooldownViewer` (gerenciador de recargas essenciais).
- **Control Utility Cooldown Viewer** — registra o frame `UtilityCooldownViewer` (recarga de utilitários).

Você também pode registrar outros frames usando comandos de chat (veja abaixo).

### Comandos de Chat (Avançado)

- `/wowp` ou `/wowpersonal` - Abre a interface principal
- `/wowp status` - Mostra o estado atual do jogador (combate, cidade, instância, etc.)
- `/wowp debug` - Alterna o modo de depuração (mostra mensagens de debug no chat)
- `/wowp register <nomeFrame>` - Registra um frame específico para controle de visibilidade
- `/wowp unregister <nomeFrame>` - Remove o registro de um frame
- `/wowp list` - Lista todos os frames registrados

**Nota**: A interface gráfica é a forma recomendada de usar o addon. Os comandos de chat são principalmente para uso avançado.

## Integração com Cooldown Manager

O addon tenta automaticamente integrar com o Cooldown Manager quando ambos estão carregados. A integração expande o dropdown de visibilidade nas configurações do Cooldown Manager com as novas opções.

## Detecção de Condições

O addon monitora os seguintes eventos do jogo para detectar mudanças de estado:

- `PLAYER_ENTERING_WORLD` - Quando o jogador entra no mundo
- `ZONE_CHANGED_NEW_AREA` - Quando muda de zona
- `PLAYER_REGEN_DISABLED` - Entra em combate
- `PLAYER_REGEN_ENABLED` - Sai de combate
- `GROUP_ROSTER_UPDATE` - Quando grupo/raide muda
- `INSTANCE_ENCOUNTER_ENGAGE_UNIT` - Quando entra em encontro de instância
- `PLAYER_UPDATE_RESTING` - Quando o estado de descanso muda

## Notas

- A detecção de Delve está em desenvolvimento e pode precisar de ajustes quando mais informações sobre a API de Delve estiverem disponíveis
- O addon funciona de forma independente e pode ser usado para controlar qualquer frame do jogo
- As configurações são salvas automaticamente e persistem entre sessões

## Requisitos

- World of Warcraft: The War Within (Interface 120000)
- Cooldown Manager (opcional, para integração completa)

## Suporte

Para problemas ou sugestões, use os comandos de debug (`/wowp debug`) para obter mais informações sobre o funcionamento do addon.
