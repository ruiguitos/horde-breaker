# Horde Breaker — Progresso

## Estado atual

Fase: Milestone 6 — Health and Game Over concluído.

Última atualização: 2026-07-17.

## Concluído

- [x] Conceito inicial definido.
- [x] Godot e GDScript escolhidos.
- [x] Core loop definido.
- [x] Recruit e Renegade definidos conceptualmente.
- [x] Progressão com Credits, Scrap e XP por personagem definida.
- [x] Desbloqueio de armas por nível mínimo e compra definido.
- [x] Roadmap inicial criado.
- [x] Projeto Godot inspecionado.
- [x] Estrutura mínima criada.
- [x] Cena principal configurada.
- [x] Primeiro teste headless executado.
- [x] Projeto configurado para Godot 4.7 com o renderer GL Compatibility.
- [x] Cena vazia `scenes/world/bootstrap.tscn` definida como cena principal.
- [x] Cache `.godot/` adicionado ao `.gitignore`.
- [x] Arena de teste criada apenas com primitivas e recursos internos do Godot.
- [x] Chão e quatro paredes configurados como corpos estáticos com colisão na layer 1 (`World`).
- [x] Iluminação direcional e ambiente simples configurados.
- [x] `PlayerSpawn` adicionado no centro da arena.
- [x] `PreviewCamera` temporária adicionada para visualizar a arena.
- [x] `scenes/world/test_arena.tscn` definida como cena principal.
- [x] Jogador provisório criado como `CharacterBody3D` com cápsula visual e colisão.
- [x] Jogador configurado na layer 2 (`Player`) com máscara para a layer 1 (`World`).
- [x] Ações `move_forward`, `move_backward`, `move_left` e `move_right` configuradas para WASD.
- [x] Movimento relativo ao mundo implementado com velocidade exportada e diagonais normalizadas.
- [x] Gravidade e rotação básica na direção do movimento implementadas.
- [x] Jogador instanciado no `PlayerSpawn` da arena.
- [x] `CameraPivot`, `SpringArm3D` e `Camera3D` integrados na cena do jogador.
- [x] Rotação horizontal da câmara controlada pelo rato.
- [x] Rotação vertical limitada entre -50 e 30 graus.
- [x] `SpringArm3D` configurado para colidir apenas com a layer 1 (`World`).
- [x] Ação `pause` configurada para `Esc`, alternando captura e libertação do rato.
- [x] Movimento do jogador convertido de relativo ao mundo para relativo à câmara.
- [x] Rotação separada no `VisualRoot` para não interferir com a órbita da câmara.
- [x] `PreviewCamera` temporária removida da arena.
- [x] TODOs de pausa real e integração futura do Mixamo registados em `docs/TODO.md`.
- [x] Hitscan escolhido e documentado para o disparo básico do Recruit.
- [x] Ação `attack` configurada para o botão esquerdo do rato.
- [x] Assault Rifle provisória criada apenas com primitivas internas do Godot.
- [x] Dano, cadência e alcance configurados como propriedades exportadas.
- [x] Raycast configurado para as layers `World` e `Enemies`.
- [x] Integração de dano preparada através de `take_damage(amount)`.
- [x] Clarão do cano e tracer temporário adicionados como feedback visual.
- [x] Jogador adicionado ao grupo `player` para descoberta do alvo sem caminhos frágeis.
- [x] `NavigationRegion3D` e malha de navegação retangular adicionados à arena de protótipo.
- [x] Normal Zombie provisório criado como `CharacterBody3D` com cápsula visual e colisão.
- [x] Zombie configurado na layer 3 (`Enemies`) com máscara para `World` e `Player`.
- [x] Vida, receção de dano e morte do zombie implementadas.
- [x] Perseguição do jogador implementada com `NavigationAgent3D`.
- [x] Ataque por proximidade implementado com `Area3D` e cooldown de um segundo.
- [x] Normal Zombie instanciado no ponto de spawn da arena de teste.
- [x] Jogador configurado com 100 pontos de vida e receção de dano através de `take_damage(amount)`.
- [x] Sinais `health_changed` e `died` adicionados ao jogador.
- [x] Movimento do jogador interrompido quando a vida chega a zero.
- [x] Painel de game over criado com fundo escurecido e botão de reinício.
- [x] Game over configurado para libertar o rato e pausar a árvore.
- [x] Reinício configurado para remover a pausa e recarregar a cena atual.

## Milestone atual

**Milestone 6 — Health and Game Over (concluído)**

## Próxima tarefa

Preparar uma tarefa específica para o **Milestone 7 — Wave 1**.

## Validação

- Godot disponível: `4.7.stable.mono.official.5b4e0cb0f`.
- Importação do projeto em modo headless concluída com código de saída 0.
- Cena principal executada em modo headless durante dois frames com código de saída 0.
- Cena executada com o renderer OpenGL e gravada durante dois frames com código de saída 0.
- Inspeção visual confirmou o enquadramento completo da arena, materiais e iluminação.
- Cena do jogador e script GDScript importados sem erros.
- Teste automatizado confirmou as quatro direções WASD e a normalização do movimento diagonal.
- Teste automatizado confirmou o spawn em `(0, 1, 0)`, contacto com o chão e bloqueio na parede norte em `z = -11.49984`.
- Inspeção visual confirmou a cápsula provisória dentro da arena.
- Teste automatizado confirmou rotação horizontal, limites verticais e captura/libertação do rato.
- Teste automatizado confirmou movimento relativo à câmara e orientação correta do visual.
- Teste automatizado confirmou que o `SpringArm3D` encurta de 5 para `2.83203125` junto a uma parede.
- Inspeção visual confirmou o enquadramento padrão atrás do jogador.
- Cena e script da Assault Rifle importados sem erros.
- Teste automatizado confirmou 6 disparos por segundo com cadência configurada para 6.
- Alvo temporário na layer `Enemies` recebeu 25 de dano por tiro e 150 de dano total.
- Teste automatizado confirmou criação e limpeza do clarão e do tracer.
- Inspeção visual confirmou arma e clarão legíveis na vista em terceira pessoa.
- Cena e script do Normal Zombie importados sem erros.
- Teste automatizado confirmou perseguição através da navegação, reduzindo a distância ao jogador de `7.75000095367432` para `5.25001049041748` num segundo.
- Teste automatizado confirmou três ataques em 2,5 segundos com cooldown de um segundo e payload de 10 de dano.
- Teste automatizado confirmou dois eventos de vida e morte após dois disparos de 25 de dano.
- Inspeção visual confirmou o zombie na arena, a aproximação ao jogador e o contacto correto com o chão.
- Cena e script do painel de game over importados sem erros.
- Teste automatizado confirmou que um ataque real do zombie reduz a vida do jogador de 100 para 90.
- Teste automatizado confirmou morte aos zero pontos, uma única emissão de `died`, interrupção do movimento e rejeição de dano posterior.
- Teste automatizado confirmou apresentação do painel, pausa da árvore e libertação do rato.
- Teste automatizado acionou o botão de reinício e confirmou uma nova arena sem pausa, painel oculto e jogador novamente com 100 pontos de vida.
- Inspeção visual confirmou o fundo escurecido, a mensagem de derrota e o botão de reinício centrados.
- Não foram encontrados erros de parsing ou de carregamento.

## Decisões pendentes

- resolução inicial;
- layout definitivo de controlos.

## Problemas conhecidos

- Existe apenas um zombie de teste; a ronda com cinco zombies fica para o Milestone 7.
- A vida já funciona, mas a respetiva apresentação permanente no HUD fica para o Milestone 8.
- Munição, recarga e mira ficam para etapas posteriores.
