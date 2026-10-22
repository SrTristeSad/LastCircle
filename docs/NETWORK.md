# LastCircle — Survev WebSocket (fase de integração)

Este cliente continua um **porte fiel para Lua/LÖVE2D**. Os transportes e pacotes seguem `survev/survev` fixado no commit `c6185e31fe25a4a07def77a2bb25b1710bda90ac`, **protocolo 1028**.

## O que funciona

- `ws_connection.lua` usa LuaSocket para conexão TCP real e handshake RFC 6455 validado (Upgrade, Connection e Sec-WebSocket-Accept).
- `ws_codec.lua` calcula SHA-1, Base64 e obtém mascaramento da fonte aleatória do sistema operacional. Sem fonte segura, falha explicitamente.
- `ws_frame.lua` mascara quadros de cliente, suporta tamanhos estendidos e segmentos incompletos, rejeitando erros de protocolo.
- `ws_connection.lua` recebe mensagens binárias, suporta fragmentação com ping entre fragmentos e responde PONG.
- `network_client.lua` conecta o transporte à `protocol_session.lua` e aplica Joined, Map, Update e demais mensagens portadas ao `client_state.lua`.
- A sessão envia Join após WebSocket abrir, Input quando houver alterações, e gerencia seq, ack e latência.
- A tela do LÖVE usa **F6** para diagnóstico. Enquanto recebe dados, desenha o terreno pela seed, os sprites originais de obstáculos, os pisos e os tetos de construções e as posições de jogadores. **A visão dos interiores já utiliza varredura de cinco raios e colisões de paredes, com interpolação visual de portas; ainda faltam composição por camadas/máscaras PIXI, interação completa e o renderizador do jogador. Isso não equivale ao jogo completo.**

## Como usar no LÖVE

1. Instale o [LÖVE2D](https://love2d.org/) 11.x e execute o `LastCircle-Lua.love` da Action de empacotamento.
2. Pressione **F6** para abrir o modo de conexão.
3. Informe **URL WebSocket completa da partida**, o **joinToken válido concedido pelo matchmaking** e o nome.
4. Pressione **ENTER**. Após JoinedMsg, MapMsg e as atualizações, o cliente mostra terreno, edifícios e entidades cujos dados foram efetivamente recebidos do servidor.
5. WASD, mouse e as teclas originais enviam InputMsg, **sem simular movimento local**: só o servidor determina posições.

O repositório ainda **não busca partidas pela API**. A tela de teste não cria tokens nem garante aceitação em servidores de produção. **Isso ainda não é um cliente jogável completo.**

### Endereços seguros

- `ws://127.0.0.1:PORTA/caminho` ou `ws://localhost:PORTA/caminho`: permitido para testes locais.
- `ws://` remoto: bloqueado por padrão para não transmitir token em texto claro. A exceção `allowInsecure=true` é apenas para ambiente controlado.
- `wss://`: requer LuaSec e arquivo/diretório de CA confiável, com verificação de certificado e hostname; **nunca há downgrade automático para ws://**.
- A distribuição .love **não inclui LuaSec nativo para Windows nem CA bundle**. Portanto WSS não funciona automaticamente no Windows sem dependências adicionais.
- Não publicar joinTokens em logs ou issues.

### Limites de protocolo

Pacotes binários recebidos são limitados a 8 MiB por frame. Tipos Survev não implementados interrompem a análise, pois o protocolo não contém prefixo de comprimento genérico. Texto inesperado é rejeitado.

## Testes reproduzíveis

O workflow [WebSocket Survev Integration](https://github.com/SrTristeSad/LastCircle/actions/workflows/websocket-tests.yml) roda `tests/ws_frame.lua` (vetores RFC 6455) e `tests/ws_fixture_server.mjs`, servidor local que **gera mensagens com o TypeScript original** de `reference/survev`.

Com **Lua 5.4 e LuaJIT**, valida:
- handshake TCP/WebSocket;
- Join do Lua desserializado pelo TypeScript original;
- Joined, Map, Update fragmentados com PING no meio;
- PONG automático, Input Lua desserializado pelo TypeScript original;
- Update de retorno com ack reconhecido pelo Lua.

Isso demonstra interoperabilidade de transporte com as mensagens testadas, **não valida servidores públicos nem uma partida jogável completa**.

## Próximas dependências

1. Descoberta de partidas pela API e obtenção correta de URL/token.
2. `client/src/map.ts` e `shared/utils/terrainGen.ts`: terreno, margens e rios fiéis à semente.
3. `client/src/renderer.ts` e entidades: objetos em camadas, texturas e animações reais.
4. HUD/menus/inventário/loot/combate como no original.
5. Teste ponta a ponta contra servidor Survev configurado para desenvolvimento.

## Inventario multiplayer — descarte (2026-10-22)

Na tela **F6** com uma partida valida conectada, abra o inventario com **I/TAB** e clique com o **botao direito** sobre uma linha com quantidade conhecida e maior que zero. O cliente envia o `DropItemMsg` original com o tipo registrado no Survev e `weapIdx=0` (itens de bolsa nao usam slot de arma). Ao enviar, a interface mostra apenas **pedido enviado**, nao sucesso garantido.

O inventario local **nao e reduzido no clique**: quantidades e loot no chao so mudam apos os `UpdateMsg` do servidor. Solicitacoes sao bloqueadas para observadores, estado offline, personagem morto, partida encerrada, quantidade zero/desconhecida e conexao fechada. Com o painel aberto, cliques nao acionam tiro no mundo.

`tests/drop_item_smoke.lua` verifica serializacao binaria, portao de permissao, ausencia de mutacoes otimistas, selecao das linhas e avisos; `lua-check.yml` executa o teste em Lua 5.4 e LuaJIT. **Ainda nao e uma validacao contra servidor multiplayer real**. O descarte de armas, armaduras e perks pelo painel nao esta incluido nesta etapa.

### Descarte de armas e armaduras no HUD (2026-10-22)

No modo de rede `F6` conectado, **clique com o botao direito sobre os slots de armas** no HUD (primaria, secundaria ou corpo a corpo) para enviar a solicitacao `DropItemMsg` usando o indice **zero-based** do slot. Nao e possivel descartar punhos ou um slot sem arma. **Capacetes e coletes** equipados podem ser solicitados pelo botao direito sobre suas etiquetas acima do HUD; mochilas sao apenas informativas e nao sao descartadas nessa interface.

Os itens, indices e tipos sao lidos do `UpdateMsg`; a acao nao altera o estado local. O servidor decide se o pedido e permitido, inclusive regras especificas sobre itens que nao podem ser soltos. A mensagem na interface indica **pedido enviado**, nunca um sucesso nao confirmado.

`tests/equipment_drop_smoke.lua` verifica a serializacao binaria do DropItemMsg, os indices corretos, cliques nos slots, blindagem contra slots vazios ou invalidos, observadores, jogadores caidos e ausencia de mutacao otimista. `lua-check.yml` executa o teste em Lua 5.4 e LuaJIT. **Ainda falta validar o fluxo contra uma partida multiplayer real**.

### Selecao de armas pelo HUD

No modo de rede, o **clique esquerdo** em um slot de arma conhecido (inclusive os punhos) envia a acao `Input.EquipPrimary/Secondary/Melee/Throwable` do Survev, em vez de disparar. Um slot desconhecido ou vazio nao produz comando de equipamento. O **clique direito** continua enviando pedidos de descarte de armas e armaduras elegiveis. Nenhum clique altera o equipamento no cliente ate o `UpdateMsg` do servidor. O HUD de teste offline continua apenas demonstrativo.


### Animações recebidas do servidor

O renderizador de rede agora processa `animSeq`/`animType` do próprio jogador e usa quadros originais para golpes de **punhos** e **frigideira**. Essas animações não simulam acerto nem dano. Outras animações de combate ainda usam a pose de espera.

O HUD apresenta o tempo de **recarga**, **uso de itens** e **reviver** se a atualização completa do jogador informar `actionType`/`actionItem` e o servidor enviar `activePlayerData.action.time/duration`. Não há contador local sem dados do servidor. O indicador é uma adaptação visual; o indicador circular original ainda precisa ser portado.

### Recuo visual ao disparar (2026-10-22)

O HUD/mundo **F6** utiliza eventos de disparo `shotFx` recebidos do servidor, não o clique local. O sprite da arma acompanha a mão deslocada pelo recuo, inclusive em pistolas duplas. O recuo diminui pela equação original de `player.ts`. A fila de eventos numerados preserva disparos caso o WebSocket entregue múltiplos `UpdateMsg` antes de desenhar um novo quadro (limite: 256 eventos). A troca de partida, dados inválidos e morte cancelam o efeito. Isso não representa implementação de balística, dano, projéteis completos ou efeitos sonoros.
