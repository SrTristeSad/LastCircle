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
| `client/src/objects/player.ts` (arte) | `live_debug.lua`, `main.lua` | Inspeção da posição dos jogadores usando sprite original; **não equivale ao renderer final** |
| `shared/utils/terrainGen.ts` e `util.seededRand` | `terrain_gen.lua` | Curvas de costa, praia/grama e ground patches: pontos comparados com original em Lua 5.4 e LuaJIT |
| `shared/utils/spline.ts` | `spline.lua` | Splines Catmull–Rom, normais, comprimentos e proximidade, testados contra fonte original |
| `shared/utils/river.ts` | `river.lua` | Rios e lagos, margens, conexões, recortes e polígonos equivalentes aos originais |
| `shared/defs/mapDefs.ts` | `map_colors.lua` | **Cores, atlases, ajuste de brilho e tipo de margem oficial** extraídos de TypeScript, sem valores aproximados |
| `client/src/map.ts:renderTerrain` | `map_renderer.lua` | Malhas cacheadas de água, praia, gramado, rios, patches e grade, testadas no LÖVE2D real |
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

O `main.lua` apresenta as artes originais e, via **F6**, uma tela WebSocket que renderiza **terreno real pela seed, rios, obstáculos e imagens originais de pisos/tetos das construções**, junto dos jogadores recebidos do servidor. O teto se torna transparente quando o jogador entra em regiões internas já portadas. **A linha de visão já usa os obstáculos e regras originais**, mas faltam as máscaras de renderização PIXI, camadas subterrâneas completas, interações de portas, efeitos e o HUD. Não é uma partida plenamente jogável.

## Pendências prioritárias

1. **Matchmaking/API:** obter endereço e `joinToken` da API original e testar a sessão com um servidor Survev de verdade. `ws://` local já funciona; `wss://` exige LuaSec e CA confiável. O teste atual é contra servidor local que emite pacotes do TS original.
2. **Mapa e edifícios:** costa, rios, biomas, pisos/tetos, **raios de visibilidade contra paredes** e **portas animadas visualmente** estão portados. Faltam compor as quatro camadas com máscaras, interação real de portas, física/colisão funcional e sons de pisos.
3. **Personagens:** portar `client/src/objects/player.ts`, sprites, animações, armas, loot, feedback de combate e efeitos. O estado das entidades recebido pelo servidor já pode ser mantido.
4. **Interface:** menus, HUD, inventário, loot, tela de morte/resultado, controles mobile, áudio e partículas.
5. **Integração:** testar entrada na partida, renderização e movimento, dano, troca de arma e saída, com servidor multiplayer original.

**O `UpdateMsg` e a camada WebSocket possuem testes aprovados; os bloqueadores principais agora são matchmaking real, renderização completa e teste ponta a ponta em partida.**

**Situação:** código original completo preservado; protocolo, WebSocket e geometria de terreno validados; renderer parcial de biomas, obstáculos e interiores de construções com imagens originais. **O cliente Lua completo e plenamente jogável ainda não existe.** 

## Licenciamento

O Survev é distribuído sob licença GNU GPL-3.0-or-later. `LICENSE` e `ATTRIBUTION-SURVEV.txt` foram preservados. A existência de uma licença open source no código não assegura que todas as marcas e recursos gráficos possam ser redistribuídos comercialmente sem verificação adicional.
