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


### Tracers dos disparos do servidor

O mundo em **F6** desenha rastros de projeteis vindos de `UpdateMsg.bullets`, em cima dos personagens. A aparencia vem da arte original `player-bullet-trail-02` e das definicoes originais de 63 balas, com velocidade, alcance, cor e largura. Disparos nao sao criados pelo clique local. Mensagens WebSocket recebidas no mesmo quadro nao sao perdidas: os rastros sao armazenados em uma fila de no maximo 512 eventos.

**Portado parcialmente:** rastros param visualmente em obstaculos, jogadores e superfícies de frigideira, e trocam a camada visual em escadas que nao sao exclusivas para loot, desde que nao atravessem mascaras. Isso nao comprova acerto real nem gera dano. **Ainda pendente:** reflexoes que geram novos projeteis, outros efeitos especiais, efeitos especiais de impacto, flares, cores de biomas e validacao ponta a ponta.

As intersecoes sao verificadas apenas contra geometrias reconhecidas no estado do servidor; objetos sem definicao visual/colisao, camadas especiais e situacoes de porta/estrutura ainda nao representadas podem produzir divergencias. A fase de detecao descartará objetos fora da caixa envolvente do trajeto para reduzir custo de CPU.


### Colisao da frigideira e transicao de escadas

Ao receber `UpdateMsg` contendo um jogador com frigideira, o cliente testa os segmentos exatos de reflexao, diferentes para o item equipado ou na cintura. A animacao de ataque da frigideira desativa a sua defesa quando nao estiver guardada. Em estruturas, os colliders de escadas e mascaras foram gerados do `StructureDefs` original, e as escadas `lootOnly` nao mudam a camada da bala. **Nao existe fisica de ricochete autoritativa no cliente**: essas operacoes so alteram os rastros locais. Testes: `tests/pan_collision_smoke.lua` e `tests/structure_layer_smoke.lua`.


### Efeitos de impacto no cliente multiplayer

Uma colisao visual confirmada por `bullet_trails.lua` pode gerar **particulas e som cosmeticos** derivados do Survev original: materiais de obstaculo usam `MapObjectDefs.hitParticle` e `sound.bullet`, jogadores usam `bloodSplat` e `player_bullet_hit`, e frigideiras usam `barrelChip` e `pan_bullet`. Sao 34 definicoes graficas transcritas e 22 grupos sonoros com MP3 originais; nenhuma destas animacoes indica que o servidor aceitou um dano.

Os efeitos sao limitados e emitidos somente uma vez por impacto visual. A CI valida sprites PNG, duracao, decaimento, reutilizacao dos sons e supressao de efeitos apos troca de partida. O cliente agora reproduz a particula `bloodSplat` anexada ao `player.container` com deslocamento local, movimento do personagem, zoom da camera e remocao apos morte/desaparecimento. Outros efeitos anexados, efeitos especiais/ambientais e o audio espacial completo do motor original ainda nao foram portados. A disponibilidade de MP3 depende do decodificador da versao do LÖVE usada no dispositivo.


### Sangue visual ligado ao jogador

O `bloodSplat` emitido por uma colisao visual em um jogador passa a permanecer relativo ao corpo daquele personagem. O renderer desenha a textura no passe do jogador correspondente, em vez de desenha-la como partícula fixa do mapa. O deslocamento X/Y conserva a referencia original `player.container` (sem girar o sangue junto com a pose do corpo) e respeita a conversao atual de pixels por unidade e o zoom do LÖVE. Se o personagem deixa de existir no estado ou morre, suas particulas anexadas sao descartadas. O som original de impacto usa a posicao do jogador. A flag interna `impactFx.bloodEnabled=false` suprime apenas o efeito grafico de sangue; ainda nao esta disponivel na interface de configuracoes. `tests/attached_blood_smoke.lua` testa essas propriedades.


### Camada superior de folhagem e mascaras

O renderizador do mundo em `F6` agora aplica parte da regra de `Obstacle.render` original: arvores e arbustos altos na camada 0, ao serem observados por jogador na camada 0, sao desenhados no passe superior com `zOrd` ajustado, **depois dos telhados**, respeitando as mascaras reais das estruturas `StructureDefs.mask`. A mascara utiliza `love.graphics.stencil` e e removida antes do HUD. Obstaculos destruidos voltam a `zOrd=5`, exibem o resíduo com `alpha=0.75` ou ficam invisiveis quando nao existe arte de residuo. A composicao de outros objetos das quatro camadas e a transicao completa de solo/subsolo continuam pendentes.


### Matchmaking e login na partida original (2026-10-22)

O porte do `client/src/main.ts:findGame` e `joinGame` usa `src/survev/matchmaking.lua` e um parser JSON Lua sem execucao dinamica. A partir de um endereco real da API, consulta primeiro `GET /api/site_info` e valida quais modos estao habilitados, como faz `client/src/siteInfo.ts`. Depois faz `POST /api/find_game_v2` com `GameConfig.protocolVersion=1028`, `region`, `zones=[]`, `playerCount=1`, `autoFill=true` e `gameModeIdx`. Espera as tres categorias de resposta originais (`success`, `error`, `banned`); valida `joinToken` e a lista de `urls`. Em sucesso, `network_client.lua:connectMatch` tenta os URLs recebidos um a um com **o mesmo token emitido pelo servidor**, chamando o `JoinMsg` e os codecs ja existentes. Nao e autorizada a fabricacao de tokens ou de enderecos de partida.

Em `main.lua`, a interface de rede e a tela inicial. `ENTER` consulta a API, `SHIFT+ENTER` usa manualmente URL/token reais, `F1/F2/F3` selecionam indice do modo, e `F5` abre somente a demonstracao local. O cliente nao obtém a URL original do servidor automaticamente da Web: deve ser informada a origem da API. HTTPS/WSS exigem LuaSec e cadeia CA verificada; o cliente informa erro se indisponiveis. CAPTCHA e sessao de conta do site original ainda nao foram portados, e a API pode bloquear o ingresso com `invalid_captcha`, `rate_limited` ou outras respostas reais.

Cobertura: `tests/matchmaking_smoke.lua` (contrato, JSON, seguranca, erros), `tests/match_connect_smoke.lua` (fallback) e `tests/matchmaking_http_smoke.lua` com servidor HTTP local real. Os testes confirmam o fluxo de descoberta, **nao a jogabilidade multiplayer ponta a ponta**.


O modo de rede esconde as etiquetas de depuracao durante uma partida; **F8** alterna os indicadores para diagnosticar a conexao. As artes e o HUD continuam em processo de porte do cliente original. A CI executa o teste de entrada pelo menu real `tests/main_quickplay_smoke.lua`, alem dos testes HTTP/WebSocket.


### SpectateMsg real e controles pos-morte

Quando o servidor marcar o jogador local como morto no `UpdateMsg`, o LastCircle pode enviar o `SpectateMsg` original (`MsgType.Spectate=11`) com `Begin=1` por botao na tela ou tecla **B**. Depois que o servidor enviar um novo `UpdateMsg.activePlayerId`, o usuario pode selecionar **Next=2** ou **Prev=3** com as setas ou os botoes. Nenhum alvo e escolhido do lado do cliente. O estado `gameOver=false` de `GameOverMsg` nao encerra a conexao; apenas `gameOver=true` encerra a partida. `InputMsg` neutraliza movimento/disparo retidos ao morrer ou assistir outro jogador, evitando comandar o personagem sob observacao. A logica segue `client/src/game.ts`, `shared/net/spectateMsg.ts` e `server/src/game/client.ts`.

`tests/ws_spectate_network.lua` conecta via WebSocket a `tests/ws_fixture_server.mjs`, que importa os serializadores da branch de referencia do Survev em TypeScript: reproduz a morte do jogador, recebe `Begin/Next/Prev` e fornece novos `UpdateMsg` de troca de alvo. Sao verificados tambem os bytes da mensagem, a ausencia de efeito otimista local e a neutralizacao de comandos `InputMsg` (Lua 5.4 e LuaJIT). **Nao e evidencia de partida online completa.**
