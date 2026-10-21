# LastCircle

Battle royale 2D top-down. Primeira etapa: cliente offline em **Lua / LÖVE2D 11.5**.

## Executar

1. Instale o LÖVE2D: https://love2d.org/
2. Baixe este repositório (Code > Download ZIP) e extraia.
3. Arraste a pasta \`LastCircle\` sobre \`love.exe\`, ou no terminal execute \`love .\` dentro da pasta.

### Controles

- **WASD**: movimentar
- **Mouse**: mirar
- **Botão esquerdo**: atirar (segure)
- **R**: recarregar
- **1 / 2**: alternar armas
- **E**: usar kit médico
- **Espaço**: correr (consome energia)
- **Enter**: reiniciar depois de morrer/vencer
- **Esc**: sair

## Incluído no protótipo v0.1

- Câmera seguindo o personagem, mundo 3200×3200, terreno procedural
- Árvores, pedras, caixas e obstáculos com colisão
- Duas armas, projéteis, recarga, dano e HUD
- Bots inimigos, munição e kits médicos coletáveis
- Círculo seguro que encolhe, dano fora da zona, vitória e derrota
- Minimapa e reinício da partida

**Status:** protótipo offline inicial; não é um porte completo do Survev e não tem multiplayer, casas com interiores ou sprites finais.

## Referência técnica

- Survev: https://github.com/survev/survev
- O código do Survev é TypeScript e seu repositório está sob GPL-3.0. Este cliente é uma implementação Lua inicial original, sem copiar código-fonte ou sprites do Survev.
- Para integração com o servidor Survev será necessário estudar e implementar o protocolo, incluindo serialização, autenticação/handshake e sincronização de entidades. **Não existe compatibilidade de rede nesta versão.**
- Não foram incluídos sprites nem marcas do Surviv.io/Survev. O visual desenhado por código é provisório, até integrar assets licenciados.

## Estrutura

\`\`\`
conf.lua
main.lua
src/
  world.lua
  game.lua
\`\`\`

## Próximas etapas

1. Importar arte com licença verificada e montar atlas/objetos.
2. Criar edifícios com interiores, portas e colisão mais precisa.
3. Inventário, loot de chão, armas adicionais, áudio e animações.
4. Cliente de rede com protocolo baseado no servidor Survev, validado por testes.
