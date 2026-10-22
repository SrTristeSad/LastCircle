# LastCircle — porte fiel do Survev para Lua

O objetivo é **reproduzir fielmente o cliente Survev** em Lua/LÖVE2D, respeitando seus sistemas, interface e recursos originais. **Não** é um novo battle royale com mecânicas imaginadas.

> O cliente Lua ainda NÃO é o jogo completo. A cópia completa do Survev está disponível no ramo de referência; o desenvolvimento Lua é um porte incremental.

## Onde está a cópia completa?

- [Cópia integral do Survev no LastCircle](https://github.com/SrTristeSad/LastCircle/tree/referencia-survev/reference/survev) — cliente, servidor, shared, imagens, sons e arquivos originais, 2.562 entradas, commit fixado `c6185e31fe25a4a07def77a2bb25b1710bda90ac`.
- [Original dos autores](https://github.com/survev/survev).
- [Histórico do protótipo genérico (descartado)](https://github.com/SrTristeSad/LastCircle/tree/historico-prototipo-generico). **Não** usar como referência de gameplay.
- [Acompanhamento do porte Lua](docs/PORT_STATUS.md).


### Fluxo real para entrar em uma partida (porte em andamento)

O cliente primeiro consulta `GET /api/site_info` para ler os modos de jogo (mapa, tamanho da equipe e se estao habilitados) e informar se o servidor exige Turnstile, antes de fazer o matchmaking. O Survev original chama `POST /api/find_game_v2` com `version=1028`, `region`, `zones=[]`, `playerCount=1`, `autoFill=true` e `gameModeIdx`. `matchmaking.lua` implementa a mesma solicitacao; o servidor devolve `{type:"success",res:{urls:[...],joinToken:"..."}}`, `{type:"error",error:"..."}` ou `{type:"banned",...}`. O cliente NAO fabrica token nem enderecos de partida e tenta os WebSockets devolvidos na ordem original. Exige o endereco **real** do servidor de API; nunca presume que um servidor de jogo esta online.

A tela inicial pede a API do servidor. Os modos F1/F2/F3 sao validados com `site_info`; um modo desabilitado nao faz solicitacao de partida. Em **ENTER**, consulta o matchmaking; em **SHIFT+ENTER**, opcionalmente conecta direto ao WebSocket/token fornecidos pelo administrador. F1/F2/F3 escolhem indice de modo 0/1/2 configurado na API. O nome do jogador e a regiao tambem sao editaveis. Para a API local de desenvolvimento use, por exemplo, `http://127.0.0.1:8000` se essa realmente for a porta da API configurada; HTTP/WS remoto sem criptografia sao bloqueados. HTTPS/WSS exigem LuaSec e certificado CA confiavel (caminho editavel); se inexistentes, a conexao informa falha e NAO rebaixa silenciosamente para HTTP/WS. Servidores que exijam Cloudflare Turnstile ou contas permanecem indisponiveis ate que o fluxo legitimo de autenticacao seja portado.

O teste `tests/matchmaking_smoke.lua` cobre a API JSON original e as respostas reais esperadas. `tests/matchmaking_http_smoke.lua` usa uma fixture local para fazer **uma solicitacao HTTP verdadeira** por LuaSocket. `tests/match_connect_smoke.lua` valida retorno de URL/token e fallback entre hosts. Todos estao incluidos em `.github/workflows/lua-check.yml` (Lua 5.4 e LuaJIT). **Isso nao comprova que uma partida multiplayer completa pode ser jogada**: renderizacao e restante dos fluxos de interface ainda sao parciais.

## Lua / LÖVE2D

**Já portado e testado:** biblioteca vetorial 2D, câmera original, parte do GameConfig, controles, registro automático de **757 IDs de game e 1.072 IDs de mapa**, leitura/escrita de bits e mensagens (Join, Input, Map, **UpdateMsg**, Joined, Kill, Pickup, Emote, DropItem, Spectate, AliveCounts, PlayerStats, GameOver e RoleAnnouncement). Foram portados os formatos de **11 categorias de entidades**, os 16 flags do UpdateMsg e a aplicação de deltas no estado do cliente (criação, exclusão, atualização parcial, vida, inventário e zona).

**Paridade real:** os workflows [protocolo](https://github.com/SrTristeSad/LastCircle/actions/workflows/protocol-parity.yml) e [UpdateMsg](https://github.com/SrTristeSad/LastCircle/actions/workflows/update-parity.yml) executam o TypeScript original para produzir pacotes de referência; exigem bytes idênticos no Lua 5.4 e LuaJIT. O teste completo cobre 16 flags e 11 categorias de entidades. Consulte o [status detalhado](docs/PORT_STATUS.md).

**Agora implementado:** descoberta de partidas via `POST /api/find_game_v2` como em `client/src/main.ts` (resposta `urls[]/joinToken`, tentativa sequencial das URLs e erros reais da API). O menu inicial entra na tela de conexao; ENTER consulta a API informada, F1/F2/F3 selecionam o indice do modo e SHIFT+ENTER permite usar URL/token diretamente para testes avancados. **O servidor precisa existir e estar configurado**; CAPTCHA, conta/login e partidas reais completas ainda nao foram validados. Transporte WebSocket real via LuaSocket (`ws://` local e `wss://` condicionado a LuaSec e CA confiável), handshake RFC 6455, quadros binários, mascaramento, mensagens fragmentadas, ping/pong, abertura de sessão, envio de `Join`/`Input`, confirmação `ack` e retenção de entidades por `UpdateMsg`. O programa também oferece um **modo de diagnóstico F6** que mostra posições reais recebidas usando a arte original do jogador. Isso foi testado em rede loopback contra mensagens geradas pelo TypeScript original.

**Mapa e artes agora implementados parcialmente:** costa e praia/grama, rios, lagos, margens e áreas de solo seguem a matemática original (`terrain_gen.lua`, `river.lua`, `spline.lua`). As **cores dos mapas** são geradas diretamente de `MapDefs`. O `map_renderer.lua` desenha terreno e grade no LÖVE2D. Também extraímos **741 definições de obstáculos** (`map_obstacle_art.lua`), com **511 sprites principais encontrados** nos recursos originais: árvores, pedras, barris, portas etc. `obstacle_art_renderer.lua` respeita os caminhos, escalas, âncoras e rotações verificados, sem substituir artes ausentes por figuras falsas. Os cálculos foram comparados com o TypeScript original e houve testes gráficos em LÖVE2D real.

**Edifícios e interiores (nova etapa):** foram exportadas **228 construções originais**, com 342 camadas de piso e 242 de teto. O cliente agora desenha os pisos e tetos pelas imagens e transformações originais, usa transparência progressiva nas regiões internas já suportadas e identifica materiais de chão pelas definições de colisão. Os testes de sprite e de materiais comparam seus resultados ao TypeScript original; há também teste gráfico real do piso/teto no LÖVE2D.

**Nova etapa — visibilidade e portas:** acrescentei a varredura de **cinco raios de linha de visão**, respeitando os colisores originais das paredes, janelas, portas, obstáculos destruídos e regras de escadas. O teto usa os resultados para fazer o fade como no Survev. As portas agora têm interpolação visual de posição e rotação, além das molduras originais. As comparações são geradas a partir do TypeScript original e executadas em Lua 5.4 e LuaJIT.

**Personagem Survev (etapa atual):** `player_renderer.lua` desenha agora corpo, mãos e pés do personagem nas escalas, cores e posições obtidas diretamente de `player.ts` e `animData.ts`. O gerador `scripts/generate_player_art.mjs` importou **90 outfits**, **16 poses** e os **3 quadros-chave do soco original**. A animação de clique no cenário offline é apenas visual e não gera dano. O teste [Player Outfit And Pose Metadata](https://github.com/SrTristeSad/LastCircle/actions/workflows/player-art.yml) compara as transformações de sprite com as calculadas pelo TypeScript original em Lua 5.4 e LuaJIT; o cliente usa passes parciais de z-order para renderizar árvores acima de telhados e personagens.

**Armas e proteção (nova etapa):** o gerador `scripts/generate_equipment_art.mjs` extrai diretamente de `GameObjectDefs` as definições de armas de fogo, corpo a corpo, coletes, capacetes e mochilas. `player_renderer.lua` posiciona as **artes reais de armas, carregadores e equipamentos** nas poses originais, com escalas, tintas, offsets e ordem de camadas. No teste local, `1–5` alternam entre punhos, frigideira, M9, AK-47 e pistolas duplas; `G` mostra/oculta proteção e `C` alterna roupas. **Não há disparos, dano, munição ou inventário autoritativo no modo offline**. Consulte o [workflow de equipamento](https://github.com/SrTristeSad/LastCircle/actions/workflows/equipment-art.yml), que valida os dados extraídos e testes de renderização em Lua e LuaJIT.

**HUD e inventário (nova etapa):** `hud.lua` mostra agora os **4 slots reais** do Survev (primário, secundário, melee, arremessável), a munição no carregador e na reserva, a vida em cores originais e os **4 segmentos de boost**. Os valores no modo F6 vêm exclusivamente de `UpdateMsg.activePlayerData` e dos equipamentos autoritativos recebidos; dados ainda ausentes são exibidos como desconhecidos, sem munição inventada. O modo offline alimenta a mesma interface com um **loadout explicitamente demonstrativo**, sincronizando as teclas `1–5` aos slots originais e usando capacidade de carregadores extraída do Survev. O desenho é uma **adaptação inicial LÖVE do HUD**, não uma cópia completa do CSS/PIXI original. [Testes de fidelidade de HUD](https://github.com/SrTristeSad/LastCircle/actions/workflows/hud-parity.yml) comparam os gradientes de vida e as barras de boost ao `ui2.ts` original em Lua 5.4 e LuaJIT.

**Minimapa e interação (nova etapa):** o cliente mostra um **minimapa com terreno/rios derivados da seed real** e silhuetas dos objetos diretamente de `MapMsg.objects`, `MapObjectDefs` e `client/src/map.ts:getMinimapRender`. O gerador extraiu **252 definições originais de objetos visíveis**, respeitando cor, escala, ordem zIdx, rotação e geometria; a imagem do minimapa é **cacheada por mapa**, enquanto a posição/direção do jogador são atualizadas a cada quadro. As teclas **M** (ampliar/fechar o mapa) e **N** (mostrar/ocultar o minimapa) funcionam no modo local e na visualização de rede. **F** exibe uma dica de porta somente quando o colisor, raio de interação, andar e permissão recebida do servidor permitem, seguindo `client/src/ui/ui2.ts` e `obstacle.ts`; a ação do modo local ainda é simulada. [Comparações do minimapa ao TypeScript](https://github.com/SrTristeSad/LastCircle/actions/workflows/minimap-defs.yml) testam círculos, retângulos e transformações originais em Lua 5.4 e LuaJIT. **A interface/mapa grande são adaptações para LÖVE, não uma cópia pixel a pixel do PIXI/CSS**.

**Itens de chão e inventário expansível (nova etapa):** `scripts/generate_loot_art.mjs` extraiu **337 definições originais de loot, 232 texturas distintas e 25 categorias de inventário**, incluindo sprites, molduras, tamanhos, cores, raios de coleta, categorias e limites de mochila, sem produzir imagens substitutas. O `loot_renderer.lua` desenha no mundo os objetos reais `ObjectType.Loot` recebidos via `UpdateMsg`. O `inventory_panel.lua` apresenta **I/TAB** com as 25 categorias e o limite de cada item conforme a mochila equipada. Na conexão real, quantidades e objetos vêm apenas de `UpdateMsg`; campos ainda não recebidos são apresentados como desconhecidos.

**Teste de coleta sem servidor:** o cenário local inclui munição, bandagens, refrigerantes e uma pistola M9 no chão. Quando um item está no alcance, `F` exibe a quantidade e, para itens empilháveis, permite testar a coleta local com limite de capacidade (incluindo pilhas parciais). **Essa coleta é uma simulação estritamente offline; pegar armas e equipamentos no servidor continua pendente.** Os objetos especiais permanecem para visualização. [Testes de fidelidade de loot](https://github.com/SrTristeSad/LastCircle/actions/workflows/loot-art.yml) comparam definições, raios, limites e a seleção do item mais próximo em Lua 5.4 e LuaJIT com o TypeScript fixado.

**Atualizacao de rede (2026-10-22):** `equipment_tracker.lua` exibe mudancas em armas, mochilas, capacetes e coletes **somente apos `UpdateMsg`**, sem confundir recarga de municao com novo equipamento. No modo **F6**, o inventario aberto por **I/TAB** agora aceita **botao direito em um item de bolsa** para solicitar seu descarte com o `DropItemMsg` original; a quantidade **so muda quando o servidor informar a atualizacao**. As teclas **7/8/9/0** enviam os quatro consumiveis pelo campo `InputMsg.useItem`, como no TypeScript fixado. Existem testes de protocolo e de UI em Lua/LuaJIT, mas descarte, equipamento e coleta ainda nao foram validados em uma partida multiplayer completa. Consulte [rede](docs/NETWORK.md) e [status](docs/PORT_STATUS.md).


**Atalhos no HUD multiplayer:** clique esquerdo em um slot conhecido para enviar `EquipPrimary/Secondary/Melee/Throwable`; clique direito em arma elegivel, capacete ou colete para solicitar `DropItemMsg`. A selecao e o descarte dependem da confirmacao do servidor, sem alterar o inventario antecipadamente. [Controles e limites de rede](docs/NETWORK.md).


**Animações multiplayer (2026-10-22):** `player_animation.lua` lê sequências `animSeq` autorizadas pelo Survev e aplica os keyframes originais dos golpes de **punhos** e **frigideira** ao `player_renderer.lua`. `action_progress.lua` mostra recarga, uso de itens e reviver quando o servidor fornece tipo e tempo da ação. Nenhum movimento implica dano local, nem substitui animações de armas ainda não portadas. Consulte [status do porte](docs/PORT_STATUS.md).


**Recuo das armas (2026-10-22):** `shot_recoil.lua` reproduz o impulso de disparos informados por `UpdateMsg.bullets.shotFx`, com intensidade obtida das definições originais de cada arma, efeitos independentes nas mãos das pistolas duplas e decaimento igual ao código `player.ts`. Os eventos têm sequência própria e uma fila limitada para preservar vários pacotes por quadro, sem duplicar um disparo. O recurso foi testado em Lua 5.4 e LuaJIT; isso **não inclui áudio, trajetória completa das balas nem validação online ponta a ponta**.


**Projeteis visuais (2026-10-22):** o cliente multiplayer agora desenha a imagem original do rastro dos projeteis disparados no `UpdateMsg.bullets`. Sao 63 definicoes de bullet/shrapnel e 13 paletas de cor transcritas do codigo fixado. `bullet_trails.lua` implementa velocidade, alcance, tamanho, cor e desaparecimento visual, e uma fila de ate 512 eventos evita perda entre pacotes. **As colisoes visuais agora cobrem obstaculos solidos, portas e jogadores** via `bullet_collision.lua`; as intersecoes visuais de frigideira e a transicao de escadas/mascaras ja foram portadas; continuam pendentes os impactos, sons, reflexoes completas, outros casos especiais e validacao end-to-end. Os tiros e danos seguem autoritativos do servidor; nao se trata de combate multiplayer completo. Veja [progresso do porte](docs/PORT_STATUS.md).


**Colisao visual de projeteis (2026-10-22):** `bullet_collision.lua` reutiliza os colliders Survev ja portados para portas, paredes e jogadores. Os rastros sao truncados na primeira colisao proxima, ignoram objetos mortos, filtram camadas e nao alteram a vida de nenhum personagem. Os testes tambem abrangem pacotes `UpdateMsg` binarios e uma otimizacao conservadora que evita intersecoes contra obstaculos distantes.


**Defesa da frigideira e escadas (2026-10-22):** `bullet_collision.lua` testa as superficies originais `pan.reflectSurface` (equipada e guardada). `structure_layer.lua` calcula a transicao de camada dos projeteis em escadas e mascaras originais extraidas por `scripts/generate_structure_collision.mjs`. Sem supor dano, novos ricochetes ou partidas completas. Testado em Lua 5.4 e LuaJIT na [CI](https://github.com/SrTristeSad/LastCircle/actions/runs/39748426408).


**Particulas e sons originais de combate (2026-10-22):** `impact_fx.lua` renderiza as particulas de impacto de obstaculos, personagens e frigideiras usando 34 definicoes de `particles.ts` e os PNG originais do Survev. `hit_sound_art.lua` contem 22 grupos do audio original de impactos; MP3s sao reutilizados na memoria com alcance e limite de reproducoes, sem arquivos sonoros inventados. A direcao visual das particulas vem da normal de colisao; o sangue no corpo agora acompanha o personagem atingido. O sistema e cosmetico, com testes Lua/LuaJIT; emissao complexa de particulas, mixagem/filtros originais e multiplayer end-to-end ainda estao pendentes.


**Sangue anexado ao jogador (2026-10-22):** `impact_fx.lua` conserva o offset original `bloodSplat` como filho de `player.container`. Em movimento ou com zoom diferente, o sangue segue o personagem. O desenho fica no passe do corpo, em vez da camada geral de rastros. A textura e descartada quando o ator morre ou sai do estado recebido. `tests/attached_blood_smoke.lua` confirma tambem a mudanca de PPU e o som ancorado no jogador. Sem dano local e sem reivindicar multiplayer completo.


**Camadas de folhagem e residuos (2026-10-22):** `obstacle_art_renderer.lua` reproduz as regras de `obstacle.ts` para `zOrd=5` em obstaculos mortos, residuos com opacidade 75% e prioridades dependentes de escala. Arvores e arbustos altos sobre o solo sao promovidos a uma passagem superior depois dos tetos; `StructureDefs.mask` recorta-os nas areas estruturais do mapa com stencil LÖVE. `tests/foliage_layer_smoke.lua` verifica as regras em Lua 5.4/LuaJIT. **A composicao completa dos quatro planos originais ainda nao foi portada.**


**Espectador original e morte (2026-10-22):** apos o servidor informar a morte, **B** ou o botao na tela solicitam `SpectateMsg.Begin`; durante a observacao, setas **esquerda/direita** ou os botoes solicitam `Prev/Next`. A camera so acompanha um novo alvo quando o servidor informa `UpdateMsg.activePlayerId`. Ao morrer, o cliente envia um `InputMsg` neutro para soltar movimentos/tiros retidos e nao controla o personagem acompanhado. O estado `GameOverMsg.gameOver=false` agora preserva a partida; `true` indica encerramento. Testes Lua/LuaJIT e uma fixture WebSocket com serializadores originais TypeScript validam a cadeia espectador; **ainda nao atestam multiplayer integral em um servidor de producao**.


**Controles de partida e camera (2026-10-22):** implementado o zoom dinamico do `activePlayerData.zoom` recebido via `UpdateMsg`, com transicao rapida de luneta segundo `client/src/game.ts` e largura virtual 16:9. Os testes `tests/main_combat_smoke.lua` e `tests/ws_combat_network.lua` verificam o caminho do clique ao `InputMsg` e ao decodificador TypeScript original: tiro inicial/continuo, F interacao, R recarga, cura, selecao de arma, botoes do HUD, protecao contra cliques no inventario e descarte autorizado pelo servidor. As mensagens de `healthDirty` e `inventoryDirty` controlam o estado; nao ha dano nem saque inventados pelo cliente. Ainda falta provar uma partida completa contra o servidor real.

**Ainda não portado:** API oficial para descobrir partidas/tokens, composição final das quatro camadas e máscaras, interação de portas com o servidor, animações completas de jogadores, **HUD final (saque/equipamento completos, feed, menus e layout final do minimapa/inventário)**, efeitos, áudio e partida multiplayer plenamente jogável. O modo F6 **é uma visualização parcial de estado real, não o jogo completo**.

### Testar agora sem servidor (Windows / LÖVE)

**O LastCircle agora inicia na tela de entrada em partidas reais**, com busca via API original Survev. **F5** abre o teste local offline, sem login, sem joinToken, sem Node.js e sem Moo-Quest. O cenário reproduz terreno, rio, construções, árvores, pedras, barris e portas a partir dos recursos originais do Survev. A movimentação de inspeção é **simulada localmente**, usando a velocidade do Survev e os colisores das artes originais; **isso ainda não é uma partida real, nem prova de compatibilidade com servidores públicos**.

O ZIP `LastCircle-Teste-Windows.zip` está em [Actions / Empacotar cliente Lua](https://github.com/SrTristeSad/LastCircle/actions/workflows/build-love.yml). Extraia-o e execute **`TESTAR-LASTCIRCLE-WINDOWS.bat`** com o LÖVE2D 11.5 instalado. O pacote inclui as artes rasterizadas, o jogo `.love`, instruções e uma captura do teste real feito pela CI.

Controles locais: **WASD** para mover, **mouse** para mirar, **clique esquerdo** para o soco visual quando estiver de punhos, **1–5** para alternar armas, **G** para equipamentos, **C** para roupas, **F** para portas ou coleta de itens próximos no teste local, **M** para ampliar o mapa, **N** para ocultar o minimapa, **I/TAB** para abrir o inventário, **R** ou **F5** para reiniciar o cenário, **F6** para ir à conexão original WebSocket, **F7** para conferir as artes, **ESC** para sair.

O workflow executa o mesmo arquivo `.love` em um runtime **LÖVE/OpenGL real** (Xvfb) antes de publicar o ZIP, e exige que o jogo renderize uma captura da tela. Os testes Lua 5.4/LuaJIT verificam dados do mapa, velocidade, colisão, interação de portas e navegação da interface.

### Inspeção das artes no LÖVE

O **F7** abre o visualizador de arquivos gráficos reais do Survev, convertidos sem redesenho. **A/D ou setas** alternam as artes. **F6** abre a interface de entrada em partida, incluindo URL da API, regiao, modo, login direto avancado com URL/token e campo de certificado CA confiavel. A tela F6 recebe estados reais, desenha **terreno, obstáculos, pisos e tetos das construções a partir das definições originais** e envia controles, mas **ainda não renderiza o jogo completo**. ESC desconecta/volta e F6 retorna ao modo local quando não conectado. Consulte [docs/NETWORK.md](docs/NETWORK.md).

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


O modo de rede esconde as etiquetas de depuracao durante uma partida; **F8** alterna os indicadores para diagnosticar a conexao. As artes e o HUD continuam em processo de porte do cliente original. A CI executa o teste de entrada pelo menu real `tests/main_quickplay_smoke.lua`, alem dos testes HTTP/WebSocket.
