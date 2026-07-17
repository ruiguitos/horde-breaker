# Horde Breaker — Progresso

## Estado atual

Fase: Milestone 11 — Menu and Character Selection concluído.

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
- [x] Câmara deslocada 0,9 m sobre o ombro direito para o jogador não ficar sobreposto à mira.
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
- [x] Ponto de mira com centro claro e contorno escuro adicionado ao centro do HUD.
- [x] Jogador e arma alinhados com a direção da câmara enquanto o rato está capturado.
- [x] Disparo corrigido com raycast da câmara para o ponto visado e segundo raycast do cano para o impacto.
- [x] Tracer corrigido para sair do cano e seguir até ao impacto real, incluindo bloqueio por paredes próximas.
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
- [x] Cinco pontos de spawn de inimigos distribuídos pela arena.
- [x] `WaveManager` local criado para instanciar e acompanhar a primeira ronda.
- [x] Primeira ronda configurada com cinco Normal Zombies.
- [x] Contagem de inimigos vivos atualizada através do sinal `died`.
- [x] Painel de vitória apresentado quando a contagem chega a zero.
- [x] Reinício da vitória configurado para criar novamente uma ronda completa.
- [x] HUD criado com vida, munição, ronda e inimigos restantes.
- [x] Barra de vida ligada ao sinal `health_changed` do jogador.
- [x] Assault Rifle configurada com carregador de 30 munições.
- [x] Ação `reload` configurada para a tecla `R`.
- [x] Recarga de 1,5 segundos implementada com feedback no HUD.
- [x] Contadores de ronda e inimigos ligados aos sinais do `WaveManager`.
- [x] `WaveData` criado como `Resource` tipado para configurar composições de rondas.
- [x] Três rondas configuradas: `5 Normal`, `10 Normal` e `15 Normal + 2 Runners`.
- [x] Spawn espaçado em 0,2 segundos para reduzir sobreposição nos marcadores.
- [x] Intervalo de três segundos implementado entre rondas.
- [x] HUD configurado para indicar a próxima ronda durante o intervalo.
- [x] Runner provisório criado por herança com 30 de vida, velocidade 4,5 e material laranja.
- [x] Vitória adiada até à conclusão das três rondas.
- [x] `CharacterData` e `WeaponData` criados como recursos tipados.
- [x] Dados estáticos do Recruit, Assault Rifle e Shotgun adicionados.
- [x] `SaveManager` configurado como Autoload com `ConfigFile` em `user://horde_breaker_save.cfg`.
- [x] Save inicial configurado com Recruit nível 1, 0 XP, 0 Credits e Assault Rifle comprada.
- [x] Fórmula de XP e progressão até nível 10 implementadas.
- [x] Normal Zombie e Runner configurados para atribuir 5 e 8 XP.
- [x] Bónus de XP por ronda configurado como `20 × ronda`.
- [x] Vitória configurada para atribuir 100 Credits permanentes.
- [x] Requisitos, compra e seleção permanente de armas implementados nos dados.
- [x] Shotgun configurada para Recruit nível 5 e custo de 750 Credits, sem criar ainda a arma jogável.
- [x] `GameManager` configurado como Autoload para transições entre menus e arena.
- [x] Menu principal criado com Credits, personagem, arma, nível, XP e início de partida.
- [x] Ecrã de personagem e armas criado para Recruit e Renegade.
- [x] Desbloqueio do Renegade configurado por 500 Credits e persistido no save.
- [x] Renegade provisório criado por herança, com material distinto e sem antecipar o combate corpo a corpo.
- [x] Worn Sword adicionada como arma inicial estática do Renegade.
- [x] `PlayerSpawn` alterado para instanciar a personagem selecionada.
- [x] XP da sessão atribuído à personagem atualmente selecionada.
- [x] Armas ainda não jogáveis impedidas de serem equipadas através de `WeaponData.is_playable`.
- [x] Painéis de vitória e derrota atualizados com regresso ao menu principal.

## Milestone atual

**Milestone 11 — Menu and Character Selection (concluído)**

## Próxima tarefa

Preparar o **Milestone 12 — Mixamo**, mantendo as mecânicas atuais durante a substituição visual.

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
- Teste automatizado confirmou o jogador 12,9% à esquerda do centro com a câmara sobre o ombro.
- Teste automatizado confirmou que o disparo mantém erro de projeção de `0 px` e aplica 25 de dano após o deslocamento da câmara.
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
- Teste automatizado confirmou a criação de exatamente cinco Normal Zombies em cinco pontos de spawn.
- Teste automatizado confirmou a sequência de inimigos vivos `[4, 3, 2, 1, 0]`.
- Teste automatizado confirmou uma única conclusão de ronda e apresentação do painel de vitória apenas aos zero inimigos.
- Teste automatizado confirmou que reiniciar a vitória repõe os cinco inimigos.
- Teste automatizado confirmou os valores iniciais do HUD: vida `100/100`, munição `30/30`, ronda 1 e cinco inimigos.
- Teste automatizado confirmou atualização da vida para `90/100` após dano.
- Teste automatizado confirmou consumo de munição `30 → 29`, estado de recarga e reposição `29 → 30` após 1,5 segundos.
- Inspeção visual confirmou os painéis do HUD legíveis nos cantos superiores sem ocultar o centro da arena.
- Teste automatizado percorreu as composições de 5, 10 e 17 inimigos pela ordem prevista.
- Teste automatizado confirmou dois intervalos e vitória apenas após a terceira ronda.
- Teste automatizado confirmou exatamente dois Runners na terceira ronda através da velocidade configurada.
- Inspeção visual confirmou que o Runner usa material laranja e se distingue dos Normal Zombies verdes.
- Importação confirmou o registo das classes `CharacterData`, `WeaponData` e `WaveData` sem erros.
- Teste com Autoload real e save isolado confirmou os valores iniciais do Recruit e da Assault Rifle.
- Teste automatizado confirmou progressão de nível 1 para nível 5 com 700 XP.
- Teste automatizado confirmou que a Shotgun permanece bloqueada sem requisitos e pode ser comprada por 750 Credits no nível 5.
- Teste automatizado confirmou persistência da compra da Shotgun e bloqueio da seleção enquanto a arma não for jogável.
- Teste integrado das três rondas confirmou 286 XP de sessão, nível 3 com 36 XP restante e 100 Credits.
- Teste automatizado confirmou persistência das recompensas após novo carregamento do save.
- Teste automatizado rodou a câmara 90 graus e confirmou alinhamento do jogador e da arma com a mira.
- Teste automatizado confirmou impacto exatamente no centro do ecrã, com erro de projeção de `0 px`.
- Alvo colocado sob a mira recebeu 25 de dano, a munição passou de 30 para 29 e o tracer nasceu no cano.
- Inspeção visual confirmou o ponto de mira centrado e legível sobre a arena.
- Cena principal de menu executada em modo headless durante dois frames com código de saída 0.
- Teste com save isolado confirmou Recruit inicial, progressão até nível 5, compra da Shotgun e saldo correto.
- Teste automatizado confirmou desbloqueio do Renegade por 500 Credits e persistência da seleção.
- Teste automatizado instanciou a arena com Recruit e Renegade e confirmou personagem, arma e visibilidade da mira esperadas.
- Menus renderizados com OpenGL a 1152 × 648 sem texto cortado, sobreposição ou botões fora do ecrã.
- Não foram encontrados erros de parsing ou de carregamento.

## Decisões pendentes

- resolução inicial;
- layout definitivo de controlos.

## Problemas conhecidos

- O protótipo atual termina após três rondas; Brute, Spitter, boss e cinco rondas completas ficam para etapas posteriores.
- A Shotgun existe apenas como `WeaponData`; a arma jogável ainda não foi implementada.
- O Renegade pode ser selecionado e movimentado, mas o ataque com Worn Sword só entra no Milestone 13.
- Modelos e animações Mixamo continuam pendentes para o Milestone 12.
