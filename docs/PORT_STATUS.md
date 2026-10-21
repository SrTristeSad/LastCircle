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

**Testes:** a Action [Paridade binária](https://github.com/SrTristeSad/LastCircle/actions/workflows/protocol-parity.yml) usa o TypeScript **original**, em execução, para gerar bytes esperados. O Lua precisa produzir bytes idênticos para Join, Input, Map e pacote de 10 mensagens. A [Lua CI](https://github.com/SrTristeSad/LastCircle/actions/workflows/lua-check.yml) executa testes e verifica sintaxe em Lua 5.4 e LuaJIT.

## Artes e empacotamento

`scripts/prepare_assets.py` rasteriza **1.616 SVG** originais como PNG e copia **492 arquivos** de recursos adicionais sem redesenhar. O workflow `build-love.yml` cria o pacote `LastCircle-Lua.love` com os recursos e módulos Lua.

O `main.lua` atual é somente um **inspector da arte original**. Não é uma partida jogável e não se deve apresentá-lo como reprodução completa do Survev.

## Pendências prioritárias

1. Completar `shared/net/updateMsg.ts`, serialização de entidades e estado replicado.
2. Conectar WebSocket: token de entrada, pacotes, recebimento, sincronização, desconexão e testes reais com o servidor.
3. Portar geração de mapa, renderer em camadas, edifícios, obstáculos, colisões e interiores a partir das definições reais.
4. Portar modelos dos jogadores, armas, movimento, dano, loot e inventário.
5. Portar menus, HUD, tela de morte/resultado, controles mobile, áudio e partículas.
6. Testar ponta a ponta partida e multiplayer.

**Situação:** código original completo preservado, vários módulos de protocolo Lua validados, mas cliente Lua completo e multiplayer **ainda não existem**. A interface atual serve apenas para conferir arte. 

## Licenciamento

O Survev é distribuído sob licença GNU GPL-3.0-or-later. `LICENSE` e `ATTRIBUTION-SURVEV.txt` foram preservados. A existência de uma licença open source no código não assegura que todas as marcas e recursos gráficos possam ser redistribuídos comercialmente sem verificação adicional.
