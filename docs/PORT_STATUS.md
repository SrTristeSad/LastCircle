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
| `client/src/game.ts:tryJoinGame` e envio de Input | `protocol_session.lua` | Handshake, enquadramento, ACK, sequência e redução de tráfego via transporte injetado; **não é uma conexão WebSocket real** |

**Testes:** [Paridade binária](https://github.com/SrTristeSad/LastCircle/actions/workflows/protocol-parity.yml) executa o TypeScript original para gerar os pacotes Join, Input, Map e uma sequência de 10 mensagens; [Survev UpdateMsg Fidelity](https://github.com/SrTristeSad/LastCircle/actions/workflows/update-parity.yml) exercita todos os 16 flags e os 11 formatos de objetos, comparando byte a byte e depois conferindo a aplicação de deltas. As verificações são feitas em Lua 5.4 e LuaJIT. A [Lua CI](https://github.com/SrTristeSad/LastCircle/actions/workflows/lua-check.yml) verifica sintaxe em ambos os ambientes.

## Artes e empacotamento

`scripts/prepare_assets.py` rasteriza **1.616 SVG** originais como PNG e copia **492 arquivos** de recursos adicionais sem redesenhar. O workflow `build-love.yml` cria o pacote `LastCircle-Lua.love` com os recursos e módulos Lua.

O `main.lua` atual é somente um **inspector da arte original**. Não é uma partida jogável e não se deve apresentá-lo como reprodução completa do Survev.

## Pendências prioritárias

1. **WebSocket real:** transporte `ws/wss`, token obtido da API original, conexão/desconexão e testes contra servidor Survev. O protocolo está preparado, mas a conexão ainda não existe.
2. **Mapas reais:** geração procedural a partir da seed e `MapDefs`, terreno, rios, edifícios, interiores, obstáculos, renderização em camadas e colisões.
3. **Personagens:** portar `client/src/objects/player.ts`, sprites, animações, armas, loot, feedback de combate e efeitos. O estado das entidades recebido pelo servidor já pode ser mantido.
4. **Interface:** menus, HUD, inventário, loot, tela de morte/resultado, controles mobile, áudio e partículas.
5. **Integração:** testar entrada na partida, renderização e movimento, dano, troca de arma e saída, com servidor multiplayer original.

**O `UpdateMsg` não é mais o bloqueador do protocolo; o próximo bloqueador é conectar e apresentar graficamente os dados recebidos.**

**Situação:** código original completo preservado, vários módulos de protocolo Lua validados, mas cliente Lua completo e multiplayer **ainda não existem**. A interface atual serve apenas para conferir arte. 

## Licenciamento

O Survev é distribuído sob licença GNU GPL-3.0-or-later. `LICENSE` e `ATTRIBUTION-SURVEV.txt` foram preservados. A existência de uma licença open source no código não assegura que todas as marcas e recursos gráficos possam ser redistribuídos comercialmente sem verificação adicional.
