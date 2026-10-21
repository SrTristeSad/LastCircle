# LastCircle — porte fiel do Survev para Lua

O objetivo é **reproduzir fielmente o cliente Survev** em Lua/LÖVE2D, respeitando seus sistemas, interface e recursos originais. **Não** é um novo battle royale com mecânicas imaginadas.

> O cliente Lua ainda NÃO é o jogo completo. A cópia completa do Survev está disponível no ramo de referência; o desenvolvimento Lua é um porte incremental.

## Onde está a cópia completa?

- [Cópia integral do Survev no LastCircle](https://github.com/SrTristeSad/LastCircle/tree/referencia-survev/reference/survev) — cliente, servidor, shared, imagens, sons e arquivos originais, 2.562 entradas, commit fixado `c6185e31fe25a4a07def77a2bb25b1710bda90ac`.
- [Original dos autores](https://github.com/survev/survev).
- [Histórico do protótipo genérico (descartado)](https://github.com/SrTristeSad/LastCircle/tree/historico-prototipo-generico). **Não** usar como referência de gameplay.
- [Acompanhamento do porte Lua](docs/PORT_STATUS.md).

## Lua / LÖVE2D

**Já traduzido:** câmera original (`client/src/camera.ts`), constantes verificadas de gameplay e controles padrão (`shared/gameConfig.ts`, `client/src/inputBinds.ts`), com testes de paridade.

**Não traduzido:** simulação de partidas, rede/protocolo, renderizador de mapa, players, combate, prédios, loot, HUD e menus. Esses módulos precisam ser portados do fonte acima; não serão substituídos por versões fictícias.

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
