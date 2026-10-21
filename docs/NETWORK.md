# LastCircle — Survev WebSocket (fase de integração)

Este cliente continua um **porte fiel para Lua/LÖVE2D**. Os transportes e pacotes seguem `survev/survev` fixado no commit `c6185e31fe25a4a07def77a2bb25b1710bda90ac`, **protocolo 1028**.

## O que funciona

- `ws_connection.lua` usa LuaSocket para conexão TCP real e handshake RFC 6455 validado (Upgrade, Connection e Sec-WebSocket-Accept).
- `ws_codec.lua` calcula SHA-1, Base64 e obtém mascaramento da fonte aleatória do sistema operacional. Sem fonte segura, falha explicitamente.
- `ws_frame.lua` mascara quadros de cliente, suporta tamanhos estendidos e segmentos incompletos, rejeitando erros de protocolo.
- `ws_connection.lua` recebe mensagens binárias, suporta fragmentação com ping entre fragmentos e responde PONG.
- `network_client.lua` conecta o transporte à `protocol_session.lua` e aplica Joined, Map, Update e demais mensagens portadas ao `client_state.lua`.
- A sessão envia Join após WebSocket abrir, Input quando houver alterações, e gerencia seq, ack e latência.
- A tela do LÖVE usa **F6** para diagnóstico. Enquanto recebe dados, mostra posições de jogadores e o recurso gráfico original `player-base-01`. Outros objetos são **marcadores de debug**, não a arte final.

## Como usar no LÖVE

1. Instale o [LÖVE2D](https://love2d.org/) 11.x e execute o `LastCircle-Lua.love` da Action de empacotamento.
2. Pressione **F6** para abrir o modo de conexão.
3. Informe **URL WebSocket completa da partida**, o **joinToken válido concedido pelo matchmaking** e o nome.
4. Pressione **ENTER**. Após JoinedMsg e MapMsg, a visualização de debug mostra dados enviados pelo servidor.
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
