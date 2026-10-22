# LastCircle — porte fiel Survev → Lua / LÖVE2D

## Referência

O código original está integralmente espelhado em [referencia-survev](https://github.com/SrTristeSad/LastCircle/tree/referencia-survev/reference/survev), fixado no commit `c6185e31fe25a4a07def77a2bb25b1710bda90ac`, com 2.562 entradas incluindo diretórios. O protótipo genérico anterior está apenas no ramo `historico-prototipo-generico`. O fonte original — não interpretações aproximadas — é a especificação de comportamento e visual.

## Módulos Lua efetivamente implementados

| Origem Survev | Lua | Status |
|---|---|---|
| `shared/utils/v2.ts` | `src/survev/v2.lua` | Operações vetoriais portadas |
| `client/src/camera.ts` | `src/survev/camera.lua` | Câmera, zoom e coordenadas testados |
| `shared/gameConfig.ts` e `inputBinds.ts` | `game_config.lua` e `input_bindings.lua` | Constantes selecionadas, enums e controles |
| `shared/defs/register.ts` | `type_registry.lua` | 757 IDs de game e 1.072 IDs de mapa, incluindo ID 0, gerados da fonte original |
| `shared/lib/bitBuffer.ts` | `bit_stream.lua` | Bits, números, strings, floats e limites; paridade binária testada |
| `shared/net/net.ts` | `net.lua` | Quantização, coordenadas, colliders, listas e enquadramento de mensagens |
| `shared/net/joinMsg.ts` | `join_msg.lua` | Mensagem de conexão |
| `shared/net/inputMsg.ts` | `input_msg.lua` | Mensagem de controles do jogador |
| `shared/net/mapMsg.ts` | `map_msg.lua` | Metadados de mapa, seed, rios, locais, objetos e patches |
| `shared/net/joinedMsg.ts` | `joined_msg.lua` | Entrada na partida |
| `shared/net/aliveCountsMsg.ts` | `alive_counts_msg.lua` | Sobreviventes |
| `shared/net/pickupMsg.ts` | `pickup_msg.lua` | Coleta de item |
| `shared/net/killMsg.ts` | `kill_msg.lua` | Eliminações |
| `shared/net/emoteMsg.ts` | `emote_msg.lua` | Emotes e pings |
| `shared/net/dropItemMsg.ts` | `drop_item_msg.lua` | Soltar equipamento |
| `shared/net/spectateMsg.ts` | `spectate_msg.lua` | Comandos de espectador |
| `shared/net/playerStatsMsg.ts` | `player_stats_msg.lua` | Estatísticas |
| `shared/net/gameOverMsg.ts` | `game_over_msg.lua` | Resultado da partida |
| `shared/net/roleAnnouncementMsg.ts` | `role_announcement_msg.lua` | Função e equipe |
| `shared/net/net.ts` | `packet_decoder.lua` | Várias mensagens sequenciais; aborta com erro para tipos não portados |
| `shared/net/updateMsg.ts` | `update_msg.lua` | **16 flags**, corpo completo de atualização; pacote testado byte a byte em Lua 5.4 e LuaJIT |
| `shared/net/objectSerializeFns.ts` | `object_serialize_fns.lua` | **11 tipos** de entidades, com formatos parcial e completo; teste de cada categoria no UpdateMsg |
| `client/src/gas.ts` | `gas.lua` | Dados e interpolação do círculo, sem renderizador gráfico |
| `client/src/game.ts:m_processGameUpdate` | `client_state.lua` | Retenção de dados autoritativos, exclusão, criação e atualizações parciais sem inventar mecânicas |
| `client/src/game.ts:tryJoinGame` e envio de Input | `protocol_session.lua` | Handshake, enquadramento, ACK, sequência e redução de tráfego com transporte WebSocket real implementado e testado em loopback |
| `shared/net/connection.ts` e `client/src/game.ts` | `ws_codec.lua`, `ws_frame.lua`, `ws_connection.lua`, `network_client.lua` | RFC 6455, TCP/LuaSocket, TLS opcional com verificação de CA/hostname, mensagens fragmentadas, ping/pong, Join, Input e recepção de pacotes; **teste TCP real com gerador TS original** |
| `client/src/objects/player.ts` (sprites/equipamento) | `player_renderer.lua`, `live_debug.lua` | **Corpo/mãos/pés, armas de fogo/melee, magazine, coletes, capacetes e mochilas originais**; posições e escalas provenientes de `GameObjectDefs`; disparos/recoil/efeitos ainda pendentes |
| `client/src/animData.ts` e `outfitDefs.ts` | `player_art.lua` | **90 outfits, 16 poses, 3 quadros do soco**, gerados automaticamente e comparados com o TypeScript original |
| `client/src/ui/ui2.ts` e `shared/net/updateMsg.ts` | `hud.lua` | **4 espaços de armas reais, vida, 4 segmentos de boost, ammo e reserva a partir de UpdateMsg**; layout LÖVE parcial, sem simular inventário real de servidor |
| `client/src/objects/loot.ts` e `shared/gameConfig.ts` | `loot_art.lua`, `loot_renderer.lua` | **337 tipos de loot, 232 imagens originais distintas**, sprites/bordas/cor/escala e seleção por raio/camada/dono; posicionamento no zOrd 13 antes do personagem |
| `client/src/ui/ui2.ts` (inventário e interação) | `inventory_panel.lua`, `interaction_hint.lua`, `offline_demo.lua` | **25 categorias e 5 níveis de capacidade por categoria**, inventário visual expansível I/TAB e simulação offline de coleta limitada a pilhas; valores reais vêm de UpdateMsg |
| `shared/defs/gameObjects/{gun,melee,gear}Defs.ts` | `equipment_art.lua` | **Imagens e dados autênticos de armas, carregadores e armaduras**, gerados do registro TypeScript fixado e validados em Lua 5.4/LuaJIT |
| `shared/utils/terrainGen.ts` e `util.seededRand` | `terrain_gen.lua` | Curvas de costa, praia/grama e ground patches: pontos comparados com original em Lua 5.4 e LuaJIT |
| `shared/utils/spline.ts` | `spline.lua` | Splines Catmull–Rom, normais, comprimentos e proximidade, testados contra fonte original |
| `shared/utils/river.ts` | `river.lua` | Rios e lagos, margens, conexões, recortes e polígonos equivalentes aos originais |
| `shared/defs/mapDefs.ts` | `map_colors.lua` | **Cores, atlases, ajuste de brilho e tipo de margem oficial** extraídos de TypeScript, sem valores aproximados |
| `client/src/map.ts:renderTerrain` | `map_renderer.lua` | Malhas cacheadas de água, praia, gramado, rios, patches e grade, testadas no LÖVE2D real |
| `client/src/map.ts:getMinimapRender` e `MapObjectDefs` | `minimap_defs.lua`, `minimap.lua` | **252 definições originais visíveis de minimapa**, cores, círculos, AABBs, ordem zIdx, posições do MapMsg; canvas cacheado e marcador de jogador atualizado em tempo real; PIXI/CSS final pendentes |
| `client/src/ui/ui2.ts` e `objects/obstacle.ts:getInteraction` | `interaction_hint.lua` | Seleção de porta por **penetração em colisor, raio original, camada e canUse**, não pela distância inventada ao centro; simulação local com F, uso real depende de InputMsg e servidor |
| `shared/defs/register.ts` (obstáculos e imagens) | `map_obstacle_art.lua` | **741 definições** extraídas, com **511 sprites principais localizados** nos assets originais |
| `client/src/objects/obstacle.ts` (renderização e porta) | `obstacle_art_renderer.lua`, `door_visual.lua` | Artes reais, tint, escala, âncora, **interpolação de portas**, rotação de ângulo mais curto e molduras; ordenação/máscaras finais pendentes |
| `shared/defs/mapObjects/buildings/**` | `map_building_art.lua` | **228 definições originais**, 342 imagens de piso e 242 de teto; 537 camadas associadas aos arquivos originais |
| `client/src/objects/building.ts` (sprites e z-order) | `building_renderer.lua` | Pisos/tetos com offsets, escala, rotação, tint e z-index originais; comparação com TypeScript; imagens carregadas sob demanda |
| `client/src/objects/building.ts` (visibilidade) | `building_visibility.lua`, `los_geometry.lua` | Regiões `zoomIn`, **5 raios com colisões originais**, filtro de paredes/janelas/escadas, efeitos de teto destruído e fade; geometria cacheada por UpdateMsg; máscaras PIXI pendentes |
| `client/src/map.ts:getGroundSurface` (edificações) | `building_surfaces.lua` | Materiais de piso e colliders transformados/ordenados; testes comparativos usando `collider.transform` original |

**Testes:** [Paridade binária](https://github.com/SrTristeSad/LastCircle/actions/workflows/protocol-parity.yml) executa o TypeScript original para gerar os pacotes Join, Input, Map e uma sequência de 10 mensagens; [Survev UpdateMsg Fidelity](https://github.com/SrTristeSad/LastCircle/actions/workflows/update-parity.yml) exercita todos os 16 flags e os 11 formatos de objetos, comparando byte a byte e depois conferindo a aplicação de deltas. As verificações são feitas em Lua 5.4 e LuaJIT. A [Lua CI](https://github.com/SrTristeSad/LastCircle/actions/workflows/lua-check.yml) verifica sintaxe em ambos os ambientes.

**Validação gráfica real:** [LOVE Render Terrain](https://github.com/SrTristeSad/LastCircle/actions/workflows/love-render.yml) executa um LÖVE instalado em um display virtual, renderizando praias, rios, lagos e sprites rasterizados do **barril, porta e edifício com piso/teto originais**. [Survev Terrain Fidelity](https://github.com/SrTristeSad/LastCircle/actions/workflows/terrain-port.yml) compara pontos contra TypeScript. [Obstacle Artwork Metadata](https://github.com/SrTristeSad/LastCircle/actions/workflows/obstacle-art.yml) gera as definições oficiais. [Survev Building Definitions](https://github.com/SrTristeSad/LastCircle/actions/workflows/building-defs.yml) gera os metadados das construções, e [Building Sprite Fidelity](https://github.com/SrTristeSad/LastCircle/actions/workflows/building-parity.yml) compara offsets, rotações, materiais, **centenas de varreduras de linha de visão** e **quadros de interpolação de portas** contra o TypeScript. Nenhuma dessas verificações significa que mapas completos e interiores já estejam concluídos.

## Artes e empacotamento

`scripts/prepare_assets.py` rasteriza **1.616 SVG** originais como PNG e copia **492 arquivos** de recursos adicionais sem redesenhar. O workflow `build-love.yml` cria o pacote `LastCircle-Lua.love` com os recursos e módulos Lua.

O `main.lua` **agora abre automaticamente um cenário de TESTE LOCAL**, sem servidor, sem token e sem uso do backend Moo-Quest. O módulo `offline_demo.lua` monta um `MapMsg` e um estado `UpdateMsg` com dados derivados das definições originais para demonstrar terreno, rio, casas, árvores, pedras, barris, um jogador visível, colisões de inspeção e portas. **O movimento e a interação local são simulados exclusivamente para pré-visualização**; não representam a física nem a autorização de um servidor Survev.

O controle no teste local usa WASD (movimento), mouse (direção), F (porta), R ou F5 (reiniciar), F6 (conexão WebSocket verdadeira), F7 (inspeção de artes). **ESC** sai ou volta. O modo F6 continua exigindo endereço e joinToken emitidos por um servidor Survev compatível.

O workflow de build compila o `.love` com imagens originais, **executa o modo local em LÖVE2D/OpenGL real**, verifica a captura da tela e publica `LastCircle-Teste-Windows.zip` com o jogo, um BAT de inicialização, instruções e screenshot. Os testes Lua 5.4/LuaJIT validam a inicialização, o movimento, os dados derivados do Survev e as interações locais.

Ainda faltam matchmaking oficial, camadas subterrâneas/máscaras PIXI, animações completas, **interface HUD final com minimapa, loot, efeitos e telas**, disparos e combate, inventário de verdade e servidor de jogo. O HUD atual exibe as armas e reservas a partir dos dados recebidos; os valores do modo offline são apenas um conjunto demonstrativo. **O cenário offline não deve ser confundido com uma partida completa.** A renderização do personagem agora inclui corpo, mãos, roupas originais, poses de soco e passagens de profundidade entre jogadores/arbustos/árvores; [Player Outfit And Pose Metadata](https://github.com/SrTristeSad/LastCircle/actions/workflows/player-art.yml) verifica os cálculos em Lua 5.4 e LuaJIT (175 verificações numéricas).

## Pendências prioritárias

1. **Matchmaking/API:** obter endereço e `joinToken` da API original e testar a sessão com um servidor Survev de verdade. `ws://` local já funciona; `wss://` exige LuaSec e CA confiável. O teste atual é contra servidor local que emite pacotes do TS original.
2. **Mapa e edifícios:** costa, rios, biomas, pisos/tetos, **raios de visibilidade contra paredes** e **portas animadas visualmente** estão portados. Faltam compor as quatro camadas com máscaras, interação real de portas, física/colisão funcional e sons de pisos.
3. **Personagens:** sprites básicos do corpo, mãos, roupas e armas já são desenhados; faltam animações completas, loot, disparo, feedback de combate e efeitos. O estado de entidades recebido pelo servidor já pode ser mantido.
4. **Interface:** HUD, minimapa, indicador de portas, loot no chão e inventário expansível de 25 categorias já estão implementados. Faltam coleta/equipagem completas em partida real, layout final PIXI/CSS, menus, tela de morte/resultado, controles mobile, áudio e partículas.
5. **Integração:** testar entrada na partida, renderização e movimento, dano, troca de arma e saída, com servidor multiplayer original.

**O `UpdateMsg` e a camada WebSocket possuem testes aprovados; os bloqueadores principais agora são matchmaking real, renderização completa e teste ponta a ponta em partida.**

**Situação:** código original completo preservado; protocolo, WebSocket e geometria de terreno validados; renderer parcial de biomas, obstáculos e interiores de construções com imagens originais. **O cliente Lua completo e plenamente jogável ainda não existe.** 

## Licenciamento

O Survev é distribuído sob licença GNU GPL-3.0-or-later. `LICENSE` e `ATTRIBUTION-SURVEV.txt` foram preservados. A existência de uma licença open source no código não assegura que todas as marcas e recursos gráficos possam ser redistribuídos comercialmente sem verificação adicional.

## Tela de resultados (2026-10-22)

`src/survev/results_overlay.lua` projeta exclusivamente `GameOverMsg` recebido do servidor: encerramento, vitoria e classificacao da equipe. Integrado em `main.lua` na tela de rede. Nao calcula danos, kills ou classificacoes locais, nem substitui o menu final original do Survev. Teste de regressao: `lua scripts/test_results_overlay.lua` (requer Lua e modulos locais; executa sem LÖVE). **Pendente:** renderizacao fiel do resultado original, dados detalhados por jogador e teste de integracao com partida real.

### Estatisticas de encerramento — etapa adicional

A tela de resultados agora le `GameOverMsg.playerStats` para mostrar por jogador `playerId`, `kills`, `damageDealt`, `damageTaken` e `timeAlive`, sem calcular nenhum valor local. `scripts/test_results_overlay.lua` valida derrota, vitoria, estatisticas e reset. O workflow `.github/workflows/lua-check.yml` executa o teste com Lua 5.4 e LuaJIT. O layout ainda e uma adaptacao LÖVE, nao pixel-paridade da interface original. A execucao da CI precisa ser conferida no GitHub Actions.

### Controles de rede (2026-10-22)

`main.lua` encaminha rolagem da roda do mouse aos IDs originais `EquipPrevWeap` e `EquipNextWeap` apenas durante a conexao de jogo. A fila de ações enviadas respeita o limite de sete entradas do `InputMsg` e elimina duplicatas. Trocas de modo e `GameOverMsg` limpam entradas pendentes para evitar comandos atrasados. O teste de inicializacao `tests/main_smoke.lua` exercita os callbacks sem servidor. **Nao validado contra uma partida multiplayer real.**

### InputMsg e confirmacao de coleta (2026-10-22)

* A referencia Survev `client/src/game.ts` envia atalhos de cura por `InputMsg.useItem`, e nao como entradas `Input.UseBandage` etc. `src/survev/live_input.lua` corrige a transmissao de `7` (bandage), `8` (healthkit), `9` (soda) e `0` (painkiller), mantendo limite de 7 acoes distintas por pacote, F/Interact, cancelar, trocar arma e rodinha do mouse.
* O estado de rede numera respostas `PickupMsg` recebidas do servidor (`pickupSeq`); `pickup_feedback.lua` apresenta por tres segundos os seis avisos de falha definidos no `client/src/ui/ui2.ts`. `PickupMsgType.Success` nao inventa um item no inventario nem exibe sucesso grafico falso: a atualizacao de inventario deve vir de `UpdateMsg`.
* `tests/live_input_smoke.lua` verifica serializacao binaria de InputMsg com `useItem`; `tests/pickup_feedback_smoke.lua` verifica avisos, expiração, reset e ausencia de coleta otimista. `lua-check.yml` testa os dois scripts em Lua 5.4 e LuaJIT.
* Pendencias: captura de uma partida multiplayer real, efeitos sonoros de coleta, outras interacoes (reviver/usar objetos) e equipamentos finais. Os resultados locais e a CI nao comprovam compatibilidade completa com servidores publicos.

### Mudancas de equipamentos confirmadas pelo servidor (2026-10-22)

O modulo `src/survev/equipment_tracker.lua` observa apenas `UpdateMsg` aplicado no `client_state.lua`. Ele compara os quatro slots de armas e os campos de capacete, colete e mochila do jogador ativo, exibindo breves avisos quando o servidor muda um tipo conhecido para outro. O tracker nao altera inventario, nao supoe aquisicoes a partir de `InputMsg` ou `PickupMsg`, e ignora mudancas apenas no numero de cartuchos. A primeira fotografia do estado, a troca do jogador observado e a entrada em nova partida sao tratadas como linha de base, sem eventos inventados.

`main.lua` integra o indicador somente na tela de rede; a demonstracao offline nao produz os avisos. `tests/equipment_tracker_smoke.lua` cobre troca de arma, equipamento, recarga, `PickupMsg`, observacao e reinicializacao em Lua 5.4 e LuaJIT. O workflow `lua-check.yml` foi confirmado **verde na execucao 39722129014**, para o commit `24946086e910e06dead93b2c7129a6cb1dfc4190` (2026-10-22).

Continua pendente validar a aparencia/temporizacao em uma partida real, os sons de equipamento e a fidelidade grafica completa de Survev.

### HUD e protocolo de descarte de equipamentos (2026-10-22)

A implementacao atual foi comparada com o Survev original (`client/src/game.ts`, fluxo de UI `action=="drop"`, e `server/src/game/objects/player.ts:dropItem`).

- `network_client.lua` envia `DropItemMsg` para **armas primarias e secundarias**, **melee** (exceto punhos) e armaduras atualmente equipadas (**helmet/chest**). Para armas, `weapIdx` e o indice zero-based recebido em `UpdateMsg`; para armaduras usa-se o tipo real recebido no objeto do jogador. Mochilas continuam somente leitura.
- `hud.lua` apresenta regioes de clique compartilhadas com o desenho dos quatro slots, e indicadores individuais de mochila/capacete/colete. **Esquerdo:** `InputMsg` com `EquipPrimary/Secondary/Melee/Throwable`, incluindo os punhos. **Direito:** pedido de descarte nos slots elegiveis ou nas etiquetas de capacete/colete. A interface nao modifica armas nem armaduras ate o servidor confirmar por `UpdateMsg`.
- Pedidos sao bloqueados para itens desconhecidos, slots vazios, modo de teste, jogo encerrado, personagem morto/caido, espectador e transporte desconectado. O aviso `Descarte solicitado` indica apenas envio.
- `tests/equipment_drop_smoke.lua` verifica dados binarios e zonas clicaveis em Lua 5.4 e LuaJIT; `lua-check.yml` inclui o teste. **Execucao de CI `39723614131` aprovada** no commit `ab23399b98e42380cfbef289aa772a33a93ae20a`. A compilacao/empacotamento real do LÖVE tambem havia passado apos a integracao inicial do HUD (`39723575640`). Nao ha ainda confirmacao de uma partida multiplayer end-to-end.


### Animações autenticadas pelo servidor (2026-10-22)

`src/survev/player_animation.lua` acompanha jogadores por `__id` e segue a atualização de `animType` + `animSeq` da mensagem completa de jogador `UpdateMsg`, em conformidade com `client/src/objects/player.ts:m_updateData`. Reexecuta a animação somente quando muda o número de sequência de 3 bits; os números podem dar a volta de 7 para 0. Ao morrer, mudar de sessão ou perder o objeto, a animação deixa de ser aplicada.

As duas primeiras animações ofensivas implementadas são **punhos** e **frigideira**, com quadros verificados no `client/src/animData.ts`. `player_renderer.lua` recebe as poses por parâmetro, preservando sua renderização anterior para outros tipos de armas. Nenhum disparo, dano, colisão, som ou efeito de tiro é inventado. A seleção aleatória de variantes/espelhamento e a composição completa de animações permanecem pendentes.

`src/survev/action_progress.lua` projeta `actionType` e `actionItem` do jogador junto dos tempos de `UpdateMsg.activePlayerData.action`. O HUD desenha uma barra de progresso somente quando recebe dados válidos para recarga, uso de consumível ou revive. Trata-se de uma adaptação visual LÖVE do indicador do jogo; não é o temporizador circular CSS original nem uma predição da ação.

`tests/player_animation_smoke.lua` valida poses, durações, sequências repetidas, wrap-around, desligamento e integração com sprites. `tests/action_progress_smoke.lua` valida eventos autoritativos, durações desconhecidas e término. Ambas as suítes entram no workflow `lua-check.yml` com Lua 5.4 e LuaJIT. A confirmação em partida online completa ainda está pendente.

### Recuo de tiros confirmado pelo servidor (2026-10-22)

`src/survev/shot_recoil.lua` usa exclusivamente o `UpdateMsg.bullets` original com `shotFx==true`, `playerId` e `shotSourceType` válido. O impulso é obtido da propriedade original `GameObjectDefs.weapons[type].worldImg.recoil` já registrada em `equipment_art.lua`. O código replica `client/src/objects/shot.ts`: armas normais deslocam ambas as mãos, armas duplas deslocam apenas a mão definida por `shotOffhand`. O decaimento visual replica `client/src/objects/player.ts`: `max(0, recoil - recoil * dt * 5 - dt)`. `player_renderer.lua` incorpora a posição negativa em X `-recoil * 1.125` no osso da mão; arma e mão compartilham a transformação.

**Não** são produzidos tiro, projétil, dano, partículas, ruído ou consumo de munição pelo cliente. Eventos inválidos, armas inexistentes e jogadores mortos não produzem recuo. O teste offline permanece sem esse efeito autoritativo.

`client_state.lua` mantém `shotFxEvents` com `shotFxSeq` crescente e limite de 256 eventos, pois vários `UpdateMsg` podem chegar durante um único `love.update`; o módulo consome apenas eventos ainda não vistos e reseta quando o estado da partida é reiniciado. Se houver mais de 256 disparos sem renderização, os eventos mais antigos são descartados para limitar memória.

`tests/shot_recoil_smoke.lua` verifica recuo individual, pistolas duplas, deslocamento dos sprites, decaimento, eventos inválidos, duas mensagens de rede no mesmo quadro, deduplicação, limite da fila e reinicialização. O workflow `lua-check.yml` passou em Lua 5.4 e LuaJIT na execução **39730222508** (commit `1b1c570e63fe3cc241431155602db61eae2259d0`). O empacotamento LÖVE anterior passou na execução **39730131164**. Ainda faltam efeitos de disparo, projéteis visuais fiéis, áudio e teste end-to-end em servidor real.


### Rastros de projeteis Survev (2026-10-22)

`src/survev/bullet_art.lua` contem **63 definicoes de bullets/shrapnel e 13 paletas de cores** geradas diretamente de `reference/survev/shared/defs/gameObjects/bulletDefs.ts` e `shared/gameConfig.ts`, fixados no commit original `c6185e31`. Os parâmetros sao usados somente na visualizacao do cliente. O asset de rastro e o SVG original `player/player-bullet-trail-02.svg`, rasterizado em `assets/survev/img/player/player-bullet-trail-02.png` pelo workflow LÖVE.

`client_state.lua` preserva `UpdateMsg.bullets` em `bulletEvents` numerados por `bulletSeq`, com capacidade maxima de 512; isso inclui **todos** os projeteis, nao apenas os `shotFx` usados pelo recuo. `src/survev/bullet_trails.lua` implementa a parte visual de `client/src/objects/bullet.ts`: velocidade com `varianceT` e `speedMult`, alcance com `reflectDistDecay`, `clipDistance`, `distanceMult` e `distAdjIdx`; tamanhos `trailSmall`/`trailThick`, cor de tracer, AP e saturacao, alpha de supressor, e desvanecimento `scale -= dt*6`. A escala, ancora e rotacao usam o asset original e o pivot PIXI de 14.5, em `zOrd=20`. Flare segue pendente para `FlareBarn`; rastro invisivel nao e desenhado.

**Estado atual:** rastros param em obstaculos solidos, portas, personagens ou na superficie de frigideira ativa e ajustam a camada visual em escadas/mascaras de estruturas conhecidas. Ainda faltam efeitos reais de particulas/som, novas balas de ricochete, interpolacao fiel por quadro em todas as condicoes, efeitos especias e paletas de bioma. Sem dano calculado pelo cliente. O mundo e o servidor nunca sao alterados pelo renderizador.

`tests/bullet_trails_smoke.lua` confere o total de tipos/paletas, equacoes, sprites, cores, distancias, desaparecimento, nao duplicacao de eventos, lotes de WebSocket e limite de memoria. Testes foram adicionados ao `lua-check.yml` para Lua 5.4 e LuaJIT. Uma partida multiplayer real ainda nao foi verificada.

### Intersecoes visuais de projeteis (2026-10-22)

O novo `src/survev/bullet_collision.lua` percorre os *colliders* originais fornecidos por `los_geometry.lua` e `map_obstacle_art.lua`, que ja possuem geometria de paredes, portas, pedras e demais obstaculos cadastrados. Aplica a altura de colisao de projetil `0.25`, o mesmo filtro de camadas usado pelo codigo original e ignora obstaculos destruidos, nao colidiveis e o objeto de onde partiu um ricochete informado no pacote. Para jogadores, usa circulo com raio `GameConfig.player.radius * scale`; nao considera o atirador salvo se for fragmento/ricochete. Seleciona a intersecao mais proxima por distancia percorrida e encerra **somente o rastro visual**, preservando o estado dos personagens.

`bullet_trails.lua` passa a mover cada tracer apenas ate a primeira colisao calculada e utiliza o decaimento original após colisao. Os colliders sao atualizados quando chega um novo `UpdateMsg`; um filtro conservador por caixa envolvente evita testar trajetorias contra objetos muito distantes. Nao gera acertou/alvo morto, dano, queda de itens nem efeitos nao verificados do Survev.

`tests/bullet_collision_smoke.lua` cobre portas, paredes, personagens, escala, morte, camadas, auto-colisao de ricochete, obstaculos nao solidos, limites do rastro, atualizacao/delecao de objetos, caixas envolventes com centenas de objetos distantes e serializacao binaria real `UpdateMsg -> packet_decoder -> client_state -> bullet_trails`. Incluido no workflow `lua-check.yml` em Lua 5.4 e LuaJIT. **Partida real contra servidor externo permanece pendente.**


### Interceptacao por frigideira e escadas de estruturas (2026-10-22)

`bullet_collision.lua` implementa `Player.m_hasActivePan`, `m_getPanSegment` e `coldet.intersectSegmentSegment` do original. Utiliza as coordenadas exatas de `meleeDefs.ts:pan.reflectSurface.equipped/unequipped`, incluindo a regra original de escala especial para frigideira equipada, rotacao pela direcao da entidade e capturas de posicao/direcao anterior por UpdateMsg. Se a bala encontra a frigideira antes do circulo do jogador, registra colisao visual `pan`; o cliente NAO cria refletor/bala nova nem calcula acerto. `tests/pan_collision_smoke.lua` cobre os dois modos, escala, orientacao, animacao Melee, pacote visual e estado anterior da rede.

`scripts/generate_structure_collision.mjs` extrai de `reference/survev/shared/defs/mapObjects/structureDefs.ts` via `MapObjectDefs` todas as geometrias `stairs`, `lootOnly` e `mask` da versao fixada `c6185e31`, em `src/survev/map_structure_collision.lua`. O workflow `structure-colliders.yml` gerou, verificou e publicou esses metadados originais automaticamente. `structure_layer.lua` aplica a transicao `layer |= 2` quando o segmento atravessa uma escada permitida sem atravessar a mascara da estrutura, respeitando o algoritmo visual de `client/src/objects/bullet.ts`. `bullet_trails.lua` integrou essa transformacao apos a verificacao das intersecoes.

`tests/structure_layer_smoke.lua` confirma escadas verdadeiras do bunker, restricoes de mascaras, pontes com `lootOnly`, transformacoes por rotacao e posicao, e o caminho completo do tracer `UpdateMsg -> bullet_trails`. `lua-check.yml` executa ambas as novas suites com Lua 5.4 e LuaJIT. CI verde na execucao [39748426408](https://github.com/SrTristeSad/LastCircle/actions/runs/39748426408).

Continuam pendentes a paridade completa de efeitos de impactos, sons, reflexoes de balas criadas na fisica do jogo, detalhes do sistema de andares/sombras e a validacao de uma partida online real; testes isolados nao implicam partida completa.
