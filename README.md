# LastCircle — porte fiel do Survev para Lua

O objetivo é **reproduzir fielmente o cliente Survev** em Lua/LÖVE2D, respeitando seus sistemas, interface e recursos originais. **Não** é um novo battle royale com mecânicas imaginadas.

> O cliente Lua ainda NÃO é o jogo completo. A cópia completa do Survev está disponível no ramo de referência; o desenvolvimento Lua é um porte incremental.

## Onde está a cópia completa?

- [Cópia integral do Survev no LastCircle](https://github.com/SrTristeSad/LastCircle/tree/referencia-survev/reference/survev) — cliente, servidor, shared, imagens, sons e arquivos originais, 2.562 entradas, commit fixado `c6185e31fe25a4a07def77a2bb25b1710bda90ac`.
- [Original dos autores](https://github.com/survev/survev).
- [Histórico do protótipo genérico (descartado)](https://github.com/SrTristeSad/LastCircle/tree/historico-prototipo-generico). **Não** usar como referência de gameplay.
- [Acompanhamento do porte Lua](docs/PORT_STATUS.md).

## Lua / LÖVE2D

**Já portado e testado:** biblioteca vetorial 2D, câmera original, parte do GameConfig, controles, registro automático de **757 IDs de game e 1.072 IDs de mapa**, leitura/escrita de bits e mensagens (Join, Input, Map, **UpdateMsg**, Joined, Kill, Pickup, Emote, DropItem, Spectate, AliveCounts, PlayerStats, GameOver e RoleAnnouncement). Foram portados os formatos de **11 categorias de entidades**, os 16 flags do UpdateMsg e a aplicação de deltas no estado do cliente (criação, exclusão, atualização parcial, vida, inventário e zona).

**Paridade real:** os workflows [protocolo](https://github.com/SrTristeSad/LastCircle/actions/workflows/protocol-parity.yml) e [UpdateMsg](https://github.com/SrTristeSad/LastCircle/actions/workflows/update-parity.yml) executam o TypeScript original para produzir pacotes de referência; exigem bytes idênticos no Lua 5.4 e LuaJIT. O teste completo cobre 16 flags e 11 categorias de entidades. Consulte o [status detalhado](docs/PORT_STATUS.md).

**Ainda não portado:** transporte WebSocket real, token de entrada via API, renderização fiel de mapa/personagens, interpolação gráfica, armas/combate do cliente, interiores, menus/HUD, áudio e multiplayer. O módulo `protocol_session.lua` prepara a conexão e os envios com um transporte injetado, **mas ainda não estabelece conexão com um servidor**. O `main.lua` permanece como visualizador de arte e não é um jogo pronto.

### Inspeção das artes no LÖVE

O `main.lua` atual **não simula uma partida**. Ele é um verificador que mostra arquivos gráficos reais do Survev, convertidos sem redesenho. Use A/D ou setas para alternar e ESC para sair.

O LÖVE não suporta SVG diretamente. Para testar com recursos:
1. Na guia [Actions](https://github.com/SrTristeSad/LastCircle/actions/workflows/build-love.yml), abra um pacote bem-sucedido chamado **LastCircle-Lua**.
2. Baixe o artefato e extraia o arquivo `LastCircle-Lua.love`.
3. Instale o [LÖVE 11.5](https://love2d.org/) e arraste o arquivo `.love` sobre o `love.exe` (ou execute `love LastCircle-Lua.love`).

Você também pode preparar recursos localmente, desde que tenha Python 3 e `rsvg-convert`:
```sh
git clone --branch referencia-survev --depth 1 https://github.com/SrTristeSad/LastCircle.git upstream-ref
python scripts/prepare_assets.py upstream-ref/reference/survev/client/public assets/survev
love .
```

## Licenças e direitos

Este porte e o código-fonte derivado do Survev seguem as condições da **GNU GPL-3.0** (consulte [LICENSE](LICENSE)). O upstream disponibiliza [attribution.txt](ATTRIBUTION-SURVEV.txt) com créditos de diversos recursos de terceiros, incluindo CC BY 3.0. Todas as licenças e atribuições pertinentes precisam ser preservadas. A licença GPL do código não assegura direitos sobre todas as marcas e recursos gráficos do jogo original; isso exige verificação adicional antes de distribuição comercial.

## Filosofia

A regra do LastCircle é **copiar funcionalidades verificadas do projeto de referência, não inventá-las**. Só marcar uma funcionalidade como portado após código Lua e teste correspondente.
