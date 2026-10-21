# LastCircle: port fiel Survev -> Lua / LÖVE2D

## A fonte da verdade

**Repositório original:** https://github.com/survev/survev

**Commit fixado:** \`c6185e31fe25a4a07def77a2bb25b1710bda90ac\` (30/09/2026)

**Cópia INTEGRAL verificada:** ramo \`referencia-survev\`, pasta \`reference/survev\`, 2.562 entradas incluindo diretórios. O ramo foi criado sem apagar o código de trabalho original.

**Histórico do protótipo descartado:** ramo \`historico-prototipo-generico\`. As mecânicas que foram imaginadas para esse protótipo não são a base de especificação do porte.

## Regras de implementação

1. Cada comportamento Lua deve referenciar um arquivo e constante do Survev. Não inventar armas, dano, construções, regras de movimentação, itens, mapa ou interface.
2. Manter IDs, ordem de enumerações, precisão e unidades do protocolo; verificar alterações contra o commit fixado.
3. Usar os recursos do próprio repositório quando sua licença permitir, preservando attribution.txt. Converter SVG -> PNG sem redesenhar.
4. A câmera e a lógica de mundo originais usam eixo Y+ para cima; LÖVE usa Y+ para baixo na tela. Aplicar a transformação ao renderizar.
5. Manter código-fonte original como referência, sem vendê-lo como porte Lua pronto.
6. Compatibilidade com servidor só existe após testes de pacotes reais de entrada/saída; antes disso é **incompatível**.

## Auditoria e estado

| Código Survev | Destino Lua | Estado |
|---|---|---|
| \`client/src/camera.ts\` | \`src/survev/camera.lua\` | Traduzido, teste de escala e coordenadas |
| \`shared/gameConfig.ts\` | \`src/survev/game_config.lua\` | Parcial: campos selecionados transcritos |
| \`client/src/inputBinds.ts\` e \`shared/gameConfig.ts\` | \`src/survev/input_bindings.lua\` | Enum e teclas padrão transcritos |
| \`client/public/img/**\` | \`assets/survev/img/**\` | Pipeline de conversão, integração ao renderer pendente |
| \`client/public/audio/**\` | \`assets/survev/audio/**\` | Cópia no pipeline, reprodução pendente |
| \`shared/net/**\` | \`src/survev/net/**\` | Não portado |
| \`client/src/game.ts\` | \`src/survev/game.lua\` | Não portado |
| \`client/src/map.ts\`, \`shared/defs/maps/**\` | Mapas Lua | Não portado |
| \`client/src/objects/player.ts\` | Entidades Lua | Não portado |
| \`client/src/objects/building.ts\`, \`obstacle.ts\` | Construções Lua | Não portado |
| \`client/src/objects/bullet.ts\`, \`projectile.ts\` | Combate Lua | Não portado |
| \`client/src/ui/**\` | UI Lua | Não portado |
| \`client/src/gas.ts\` | Zona Lua | Não portado |
| \`client/src/resources.ts\` | Asset loader Lua | Não portado |
| \`client/src/audioManager.ts\` | Áudio Lua | Não portado |

**Estado geral:** cópia completa do código original disponível; cliente Lua completo NÃO está implementado.

## Licenciamento

O projeto fonte tem LICENSE GPL-3.0 e attribution.txt para vários recursos de terceiros (inclui CC BY 3.0). Preservar ambos. A licença do código não basta para declarar que todas as imagens, logos e áudios podem ser usados em qualquer distribuição comercial. Conferir individualmente direitos de arte e marcas antes de publicar.
