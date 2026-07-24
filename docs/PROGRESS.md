# Horde Breaker — Progresso

## Estado atual

Fase: mundo aberto compacto 4×4 com diretor de horda contínuo, cidade procedural
enriquecida, acampamento com construção livre e todo o jogo em inglês.

Última atualização: 2026-07-24.

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
- [x] Configuração inicial da Shotgun criada para Recruit nível 5; esta configuração foi posteriormente substituída pelo loadout do Renegade no Milestone 14.
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
- [x] Worn Sword provisória criada apenas com caixas e materiais internos do Godot.
- [x] Ataque frontal do Renegade ligado à ação `attack` com 35 de dano e cooldown de 0,6 segundos.
- [x] Volume melee configurado para atingir vários inimigos na layer 3 sem acertar em alvos atrás do jogador.
- [x] Animação curta de balanço da espada adicionada por código como feedback provisório.
- [x] HUD melee configurado para apresentar a mira e a Worn Sword equipada.
- [x] Objetivo futuro de um mapa jogável com obstáculos, navegação e spawns registado em `docs/TODO.md`.
- [x] Perfil de progresso para testes no editor configurado num save separado, com 2000 Credits e Recruit nível 5.
- [x] Mira de disparo reduzida de 10 × 10 para 6 × 6 píxeis, com centro de 2 × 2 píxeis.
- [x] Menu de pausa próprio implementado com `Esc`, pausa real da árvore, libertação do rato e foco no botão de continuação.
- [x] Pausa configurada para continuar, regressar ao menu principal ou sair sem se sobrepor aos painéis de vitória e derrota.
- [x] Arena graybox expandida para 32 × 32 metros, mantendo apenas primitivas internas do Godot.
- [x] Três coberturas estáticas adicionadas e identificadas através do grupo `navigation_blocker`.
- [x] Navegação em runtime convertida para uma grelha que exclui as células ocupadas pelos obstáculos com margem de segurança.
- [x] Jogador reposicionado e seis pontos de spawn distribuídos à volta da arena expandida.
- [x] Worn Sword impedida de causar dano através das coberturas da layer `World`.
- [x] `CharacterData` expandido com arma principal, arma secundária, regeneração, multiplicador de recarga e descrição da classe.
- [x] `WeaponController` local criado para instanciar loadouts e trocar de arma através das teclas `1` e `2`.
- [x] Recruit configurado com Assault Rifle, Pistol e recarga 30% mais rápida.
- [x] Renegade configurado com Shotgun, Worn Sword e 140 pontos de vida.
- [x] Medic provisório criado com Pistol, 100 pontos de vida e regeneração de 4 pontos por segundo após 3 segundos sem dano.
- [x] Regeneração base de 1 ponto por segundo após 6 segundos configurada para Recruit e Renegade.
- [x] Pistol semiautomática criada com carregador de 12 munições.
- [x] Shotgun jogável criada com oito pellets, dispersão, carregador de oito munições e disparo semiautomático.
- [x] HUD atualizado com arma ativa, loadout e indicação das teclas dos dois slots.
- [x] Menus atualizados para apresentar as três classes, passivos e loadouts.
- [x] Migração de save configurada para acrescentar Pistol, Shotgun, Medic e os novos slots sem apagar valores existentes.
- [x] Jogos semelhantes e ideias de evolução registados em `docs/INSPIRATIONS.md`.
- [x] Seleção reduzida do Quaternius Zombie Apocalypse Kit importada em glTF com origem e licença CC0 documentadas.
- [x] Recruit, Renegade e Medic configurados com modelos visuais distintos, preservando as cápsulas de colisão e os scripts existentes.
- [x] Normal Zombie e Runner configurados com modelos visuais distintos sem alterar navegação, vida, dano ou recompensas.
- [x] Assault Rifle, Pistol e Shotgun configuradas com modelos importados, mantendo raycasts, munição, cadência e recarga existentes.
- [x] Animações provisórias de idle e movimento ligadas à velocidade do `CharacterBody3D`.
- [x] Primitivas visuais anteriores preservadas nas cenas, mas ocultas, para permitirem comparação e reversão simples.
- [x] Visual da Worn Sword corrigido no Renegade através da lâmina integrada no modelo animado, eliminando a espada primitiva suspensa.
- [x] Ataque da Worn Sword ligado à animação `Slash` do modelo importado.
- [x] Velocidade base alterada para andar a 4 m/s e corrida adicionada com `Shift` a 7 m/s.
- [x] Salto adicionado com `Space`, limitado ao contacto com o chão e bloqueado durante o agachamento.
- [x] Agachamento adicionado com `Ctrl`, incluindo cápsula reduzida, câmara mais baixa, velocidade própria e verificação de espaço para levantar.
- [x] Interação adicionada com `F` através de uma área local e pickup de munições de teste colocado junto ao spawn.
- [x] Vista frontal temporária adicionada ao manter `C`, com reposição da órbita anterior ao libertar a tecla.
- [x] Mira sobre o ombro adicionada ao botão direito do rato, com transição de FOV, distância e deslocamento lateral.
- [x] Estados provisórios de andar, correr, salto, agachamento e ataque ligados às animações dos modelos importados.
- [x] Munição de reserva própria adicionada à Assault Rifle, Pistol e Shotgun.
- [x] Recarga alterada para transferir apenas munições disponíveis da reserva para o carregador.
- [x] HUD atualizado para apresentar `carregador / reserva`.
- [x] Pickup de munições alterado para abastecer a reserva, incluindo a Shotgun quando o Renegade tem a Worn Sword ativa.
- [x] Oito modelos ambientais CC0 selecionados do mesmo Quaternius Zombie Apocalypse Kit e importados em glTF.
- [x] Primeiro mapa urbano modular criado com 16 peças de estrada, contentores, camião blindado, iluminação, barreiras e torre de água.
- [x] Piso e caixas graybox ocultados visualmente, preservando as colisões funcionais por baixo dos novos modelos.
- [x] Quatro paredes graybox ocultadas e limites temporários assinalados por barreiras visuais.
- [x] Componente reutilizável `DamageHitbox` criado com zona e multiplicador configuráveis.
- [x] Normal Zombie e Runner configurados com corpo a `1 ×` e cabeça a `2 ×` dano.
- [x] Cápsula física do zombie separada das hitboxes de dano para o raycast distinguir corretamente corpo e cabeça.
- [x] Assault Rifle, Pistol e Shotgun configuradas para detetar hitboxes `Area3D`, mantendo colisão com o mundo.
- [x] Worn Sword configurada para aplicar headshot ao alvo apontado sem duplicar dano quando o volume sobrepõe corpo e cabeça.
- [x] Mira mantida visível com a Worn Sword para permitir ataques melee apontados à cabeça.
- [x] Tema visual partilhado criado para menus, HUD e ecrãs sobrepostos, sem dependências ou assets externos.
- [x] Menu principal redesenhado com identidade visual própria, hierarquia mais clara e resumo destacado da classe/loadout.
- [x] Seleção de personagens reorganizada em cartões de classe com estado visual selecionado, bloqueado e desbloqueado.
- [x] Loadout da classe selecionada apresentado num painel próprio com os dois slots separados.
- [x] HUD reorganizado em módulos independentes para vida, ronda, ameaças, arma e munição.
- [x] Mira substituída por um retículo compacto e os valores de vida passam a mudar de cor em níveis de alerta.
- [x] Atalhos essenciais adicionados ao HUD sem tapar a área central de combate.
- [x] Pausa, derrota e vitória redesenhadas com mensagens, ações e cores de estado consistentes.
- [x] Indicador `DamageNumber3D` criado para apresentar valores pequenos no ponto atingido, subindo e desaparecendo automaticamente.
- [x] Dano realmente retirado à vida devolvido pelas hitboxes ao sistema de feedback, incluindo overkill limitado à vida restante.
- [x] Impactos no corpo apresentados a claro e headshots apresentados a dourado, sem alterar os multiplicadores existentes.
- [x] Pellets da Shotgun agregados por inimigo para mostrar apenas um total por disparo.
- [x] Worn Sword configurada para apresentar um número por inimigo atingido pelo mesmo golpe.
- [x] Vida base do Normal Zombie aumentada de 50 para 100 e vida do Runner aumentada de 30 para 60.
- [x] Assault Rifle, Pistol, Shotgun e Worn Sword balanceadas provisoriamente para 30, 35, 12 por pellet e 50 de dano base.
- [x] Dano das quatro armas configurado explicitamente nas respetivas cenas, sem depender dos valores genéricos dos scripts.
- [x] Matriz corpo/cabeça documentada com multiplicador `2 ×` preservado e valores finais visíveis no ponto atingido.
- [x] Vitória automática após três rondas substituída por ataques contínuos que reutilizam os três `WaveData` existentes.
- [x] Escalada provisória configurada para acrescentar dois Normal Zombies a cada composição por ciclo completo.
- [x] `CampCore` físico adicionado à arena com 500 pontos de vida, sinal de destruição, luz e identificação no mundo.
- [x] Jogador e núcleo registados como `enemy_target`, permitindo aos zombies escolher o alvo vivo mais próximo.
- [x] Ataques dos zombies adaptados ao volume do núcleo sem alterar o alcance existente contra o jogador.
- [x] Dano inimigo do núcleo separado de `take_damage`, impedindo fogo amigo sem deixar os tiros atravessarem a estrutura.
- [x] HUD atualizado com painel próprio para a vida do núcleo e designação de `ATAQUE`.
- [x] Derrota configurada para ocorrer tanto pela morte do jogador como pela destruição do núcleo, com mensagens distintas.
- [x] Recompensa permanente de 100 Credits transferida da vitória final para a conclusão de cada ciclo de três ataques.
- [x] Painel de vitória removido da arena e preservado como cena não utilizada para evitar apagar trabalho anterior.
- [x] Arena expandida de 32 × 32 para 64 × 64 metros através de quatro bairros modulares rodados.
- [x] Colisões e navegação expandidas até aos novos limites; seis spawns inimigos deslocados para zonas exteriores.
- [x] Exclusão da navegação corrigida para respeitar as dimensões projetadas dos obstáculos rodados.
- [x] Colisões das antigas coberturas graybox desativadas e nós preservados; contentores e camião do mapa recebem colisões próprias.
- [x] Oito caches estáticos de 25 Scrap distribuídos pelas zonas exteriores para incentivar exploração.
- [x] `CampEconomy` implementado com Scrap transportado e Scrap armazenado apenas durante a partida.
- [x] Interação `F` permite recolher caches e depositar todo o Scrap transportado no núcleo.
- [x] Núcleo reparável durante a exploração a 5 pontos de vida por Scrap, até 50 pontos por interação.
- [x] Preparação inicial de 30 segundos e exploração de 45 segundos entre ataques, ambas com contagem decrescente.
- [x] HUD atualizado com recursos da expedição e feedback curto para recolha, depósito e reparação.
- [x] Primeiro ponto fixo de defesa adicionado junto do núcleo, sem introduzir construção livre.
- [x] Barricada configurada com custo de 30 Scrap armazenado e 200 pontos de vida.
- [x] Construção e reparação limitadas às fases de exploração; reparação mantém a taxa de 5 pontos por Scrap e máximo de 50 por interação.
- [x] Barricada construída adicionada a `enemy_target`, permitindo aos zombies escolhê-la e causar-lhe dano real.
- [x] Destruição remove a barricada como alvo, desativa a colisão e disponibiliza novamente o ponto para reconstrução.
- [x] Navegação regenerada em runtime quando a barricada é construída ou destruída.
- [x] Modelo provisório legível criado com primitivas, marcador de construção e estado/vida apresentados no mundo.
- [x] Grelha modular de 16 estradas extraída para `city_road_grid.tscn`, sem adereços repetidos.
- [x] Quatro instâncias repetidas de `city_test_map.tscn` removidas da arena; a cena original foi preservada como referência.
- [x] `exploration_pois.tscn` criado com hospital, armazém, posto militar e estação de combustível.
- [x] Quatro POIs diferenciados por escala, cor, silhueta, etiqueta e elementos ambientais já disponíveis.
- [x] Edifícios e adereços principais configurados como `navigation_blocker` com colisão na layer `World`.
- [x] Cada POI recebeu um `AccessPoint` navegável e manteve pelo menos uma cache de Scrap a menos de 10 metros.
- [x] Estradas, oito caches, seis spawns, núcleo e fortificação preservados sem adicionar novos assets ou controlos.
- [x] Armazém convertido de bloco fechado para um edifício com paredes segmentadas, teto e entrada central aberta.
- [x] Interior graybox do armazém equipado com iluminação e uma prateleira simples, sem descarregar novos assets.
- [x] `InteriorPoint` adicionado ao grupo `poi_interior_point` para validar a navegação para dentro do edifício.
- [x] Uma cache de 25 Scrap e um pickup de 12 munições reutilizados como loot funcional no interior.
- [x] Hospital, posto militar e estação de combustível preservados fechados para limitar este slice ao primeiro interior.
- [x] `WarehouseEncounter` adicionado ao interior, ativando dois Normal Zombies quando o jogador entra durante a exploração.
- [x] Emboscada limitada a uma ativação por ciclo e impedida de duplicar enquanto os inimigos anteriores estiverem vivos.
- [x] Zombies da exploração ligados à recompensa normal de XP sem alterar a contagem ou conclusão das vagas.
- [x] Scrap e munições do armazém repostos após cada ciclo apenas quando já foram recolhidos.
- [x] Mensagens do HUD reutilizadas para comunicar a emboscada e a reposição do loot.
- [x] Hospital convertido de bloco fechado para um edifício com entrada central de cinco metros e interior navegável.
- [x] Interior do hospital distinguido com iluminação fria, duas camas graybox e sinalização exterior preservada.
- [x] `HealthPickup` reutilizável criado com interação por `F`, cura máxima de 40 pontos e rejeição segura com vida cheia.
- [x] Medkit ocultado após uma cura válida e reposto na mesma instância após `cycle_completed`, sem duplicação.
- [x] Posto militar convertido de bloco fechado para um bunker com entrada aberta e interior navegável.
- [x] Duas caixas de 12 munições adicionadas como recompensa e repostas por ciclo apenas quando recolhidas.
- [x] `MilitaryOutpostEncounter` criado com dois Normal Zombies e um Runner durante a exploração.
- [x] Encontro militar limitado a uma ativação por ciclo, 18 XP total e separado da contagem das vagas.
- [x] Estação de combustível convertida de bloco fechado para uma loja com entrada aberta, balcão e interior navegável.
- [x] Duas caches de 25 Scrap adicionadas à estação e repostas por ciclo apenas quando recolhidas.
- [x] `FuelStationEncounter` criado com três Runners, uma ativação por ciclo, 24 XP total e contagem das vagas inalterada.
- [x] Proposta de mundo aberto compacto por setores documentada em `docs/OPEN_WORLD_PLAN.md`, sem implementar ainda streaming.
- [x] Ataques agendados com aviso longo escolhidos para exploração distante; implementação do aviso permanece pendente.
- [x] Normal Zombie e Runner registados no grupo `enemy` para aquisição estável de alvo.
- [x] Assault Rifle, Pistol e Shotgun configuradas para disparar automaticamente contra o inimigo visível mais próximo até 3 metros.
- [x] Disparo manual preservado durante o protótipo e Worn Sword mantida fora do sistema automático.
- [x] `east_sector.tscn` criado como segundo setor graybox de 64 × 64 metros, ligado à fronteira leste.
- [x] `WorldStreamer` criado com carregamento em `x = 18`, descarregamento em `x = 8` e uma única instância do setor.
- [x] Jogador, acampamento e sistemas globais mantidos fora de `LoadedSectors` durante a transição.
- [x] Segunda região de navegação alinhada com o setor persistente através da fronteira em `x = 32`.
- [x] Farol de reconhecimento adicionado como primeiro objetivo do setor, com estado preservado em memória após recarregar.
- [x] Direção futura da IA registada: os inimigos devem perseguir apenas o jogador
  e não atacar diretamente o acampamento, o núcleo ou as fortificações.
- [x] `SettingsManager` criado como Autoload com definições persistidas em `user://horde_breaker_settings.cfg`, separadas do save de progresso.
- [x] Menu de definições criado com modo de janela, resolução, VSync, MSAA, qualidade das sombras, sensibilidade do rato e volume geral, aplicados e guardados de imediato.
- [x] Definições acessíveis a partir do menu principal e como sobreposição no menu de pausa, sem sair da partida.
- [x] Sensibilidade do rato aplicada como multiplicador à câmara em terceira pessoa.
- [x] Transição de fade entre cenas centralizada no `GameManager`.
- [x] Animações de entrada adicionadas ao menu principal, seleção de personagens, pausa e derrota através do helper partilhado `UiAnimations`.
- [x] Barras de vida do jogador e do núcleo mudam de cor consoante o rácio (verde, laranja, vermelho).
- [x] Vinheta de dano adicionada ao HUD com pulso ao sofrer dano e intensidade base quando a vida está baixa.
- [x] Hit-marker no retículo ao acertar em inimigos, tanto com armas de fogo como com a Worn Sword.
- [x] Barra de progresso de recarga adicionada sob o retículo, sincronizada com a duração real da recarga.
- [x] Banner central animado no início de cada ataque e de cada fase de exploração.
- [x] Feedback do HUD convertido num feed empilhável de até quatro mensagens com desvanecimento individual.
- [x] Tema partilhado alargado a `OptionButton` e `CheckButton` para consistência do menu de definições.
- [x] Tema partilhado reescrito com identidade de horde-shooter inspirada em `docs/INSPIRATIONS.md`: painéis enviesados (`skew`), cantos retos, acentos âmbar sobre aço escuro e nova variação `HudValueLabel` para números grandes.
- [x] Menu principal refeito com coluna de comando à esquerda (título grande e botões enviesados) e cartão do operacional ativo à direita com emblema de classe.
- [x] Seleção de personagens refeita como ecrã de classes com emblemas em losango nas cores de cada classe, cartões compactos centrados e loadout na base.
- [x] Menu de pausa refeito como painel lateral esquerdo com slide-in, mantendo continuar, definições, menu principal e sair.
- [x] Painel de derrota refeito com barras superiores/inferiores vermelhas e título em destaque.
- [x] HUD refeito em módulos flutuantes: placas enviesadas para núcleo e recursos, módulo de vaga central com número grande e contagem de ameaças, vida com número grande e barra fina, e munição em números grandes com sublinhado âmbar.
- [x] Emblemas de classe construídos apenas com `ColorRect` rodados, sem assets externos.
- [x] Resolução por defeito alterada para 1920 × 1080 em ecrã completo, com stretch `canvas_items` para o UI escalar de forma consistente em qualquer resolução.
- [x] Aplicação das definições de ecrã corrigida: o tamanho da janela é aplicado de forma diferida após a troca de modo, evitando que a mudança se perca.
- [x] Secção de gráficos (MSAA e sombras) removida do menu de definições e do `SettingsManager` por não fazer sentido nesta fase.
- [x] `WorldStreamer` generalizado para um registo de setores (chunks) com carregamento em background através de `ResourceLoader.load_threaded_request`, mantendo a instanciação na thread principal.
- [x] Gatilhos de carregamento convertidos de limiares em `x` para distância ao centro do setor, preparando uma futura grelha de chunks em qualquer direção.
- [x] Tempo de carregamento de cada setor medido e impresso em milissegundos, conforme pedia o plano de mundo aberto.
- [x] Céu procedural de entardecer adicionado à arena com `ProceduralSkyMaterial`, luz ambiente derivada do céu e nevoeiro subtil de profundidade, sem assets externos.
- [x] Estado híbrido janela/ecrã completo no arranque corrigido: o projeto arranca em janela 1920 × 1080 e o `SettingsManager` muda para ecrã completo no primeiro frame, contornando a limitação do Godot no Windows que impede sair de fullscreen quando o jogo arranca nativamente em fullscreen com o viewport igual à resolução do monitor.
- [x] Modo de janela corrigido para ser carregado e persistido; o jogo já não
  força ecrã completo quando a preferência guardada é Janela.
- [x] Aplicação de modo e tamanho da janela reescrita como corrotina por passos sobre o nó `Window`, com fila para pedidos repetidos.
- [x] Menu de definições sincronizado com o estado ativo: em fullscreen mostra a
  resolução real do monitor e, em Janela, aplica, centra e apresenta a resolução
  selecionada após a transição.
- [x] IA alterada para perseguir apenas o jogador: núcleo, acampamento e barricada removidos da seleção de alvos dos zombies.
- [x] Derrota reduzida à morte do jogador; a destruição do núcleo deixou de terminar a partida.
- [x] Flash aditivo no modelo do inimigo ao receber dano, aplicado por overlay de material sem assets externos.
- [x] Sons de impacto sintetizados em runtime (`AudioStreamWAV`): tom grave para corpo e tom agudo para headshot, tocados no ponto de impacto pelos números de dano.
- [x] Primeira escolha de melhoria entre rondas: painel com três vantagens aleatórias em cada exploração (dano +20%, +25 vida máxima, velocidade +10%, recarga −20%, cura total), aplicadas apenas à sessão.
- [x] `RunUpgrades` criado como sistema local da arena com feedback no HUD ao ativar cada vantagem.
- [x] Mapa tático 2D adicionado à cena base do jogador e alternado com `Tab`, com
  grelha 4 × 4, setores carregados, jogador orientado, acampamento, POIs e inimigos.
- [x] Mundo aberto compacto 4 × 4 (256 × 256 m) implementado: acampamento persistente em (0, 0), setor leste desenhado à mão em (1, 0) e catorze setores gerados proceduralmente por seed.
- [x] `SectorGenerator` criado: estradas modulares com rotação de quarto de volta por setor, marcos primitivos como `navigation_blocker`, contentores CC0 decorativos, caches de Scrap e muros invisíveis apenas na borda exterior do mundo.
- [x] Estado de sessão por setor: seed determinística por partida e caches recolhidas que não reaparecem ao recarregar o setor.
- [x] Navegação por setor alinhada nas fronteiras, com regiões fundidas pelo mapa de navegação e caminhos contínuos entre acampamento e setores gerados.
- [x] Fronteiras norte, sul e oeste do acampamento abertas e muros do setor leste removidos para ligar a grelha completa.
- [x] `ScrapPickup` passou a emitir `collected`, permitindo registar loot por setor.
- [x] Mapa tático em `Tab` corrigido: a ação `toggle_map` estava ligada a Backspace (keycode 4194308) em vez de Tab (4194306).
- [x] Mapa tático movido de `_unhandled_input` para `_input`, porque o Tab é também o atalho nativo `ui_focus_next` e qualquer botão com foco (como o painel de melhorias) consumia a tecla antes de chegar ao mapa.
- [x] Layer do mapa tático baixada de 20 para 8, ficando acima do HUD e abaixo dos painéis de derrota e pausa.
- [x] Geração de setores distribuída por frames: casca imediata, um quadrante de estradas por frame, conteúdo e navegação em frames próprios, com cancelamento seguro se o jogador se afastar a meio.
- [x] Setores gerados ganharam vida: três marcadores de spawn próprios, uma caixa de munições com estado por setor e uma emboscada única por partida (2–3 inimigos por seed) disparada ao entrar durante a exploração, com aviso no HUD.
- [x] Hordas passaram a nascer nos oito pontos de spawn mais próximos do jogador, juntando os marcadores do acampamento aos dos setores carregados.
- [x] `AmmoPickup` passou a emitir `collected` para suportar estado de loot por setor.
- [x] Spawns das vagas tornados aleatórios por feedback do playtest: o conjunto dos seis pontos mais próximos é baralhado a cada vaga e cada inimigo nasce com desvio aleatório de ±1,5 m, evitando padrões e empilhamento.
- [x] Vantagens entre rondas dependentes do nível permanente da classe: nível 1 desbloqueia as três básicas e os níveis 3, 5, 7 e 9 desbloqueiam recarga, dano, Carregadores Alargados (+25% carregador) e Adrenalina (+15% cadência e golpes mais rápidos).
- [x] Painel de vantagens passou a indicar o progresso de desbloqueio (por exemplo, "Vantagens desbloqueadas 6 / 7").
- [x] Rondas removidas e substituídas por um diretor de horda contínuo: os inimigos nascem em lotes à volta do jogador durante a viagem, com o nível de ameaça a subir a cada 75 s (mais zombies, mais Runners e intervalos de spawn mais curtos), limite simultâneo escalável e HUD com "THREAT LEVEL", "HOSTILES" e contagem para a próxima subida.
- [x] Spawns garantidos a pelo menos 12 m do jogador para dar tempo de reação, mantendo os seis pontos mais próximos e o desvio aleatório.
- [x] Alcance do disparo automático das armas de fogo aumentado de 3 para 6 metros.
- [x] Posições do Scrap e das munições do acampamento randomizadas a cada partida por `PickupRandomizer`, evitando marcos e o centro e sem sobreposição.
- [x] Setores gerados enriquecidos com torre de água e camião destroçado (com colisão e como `navigation_blocker`) e quatro postes de iluminação decorativos.
- [x] Acampamento transformado em zona de reabastecimento: ficar a menos de 12 m do núcleo cura o jogador e repõe munição de reserva por segundo, com aviso no HUD.
- [x] Mapa tático melhorado: setor atual destacado com moldura de acento, marcadores em losango para Scrap, munição e medkit, chip de acento no estilo do HUD e legenda alargada.
- [x] Todo o texto do jogo convertido para inglês: menus, HUD, painéis, etiquetas do mundo, feedback e descrições das classes.
- [x] Etiquetas 3D removidas das caches de Scrap e das caixas de munições; ambas passam a ser recolhidas automaticamente ao passar por cima (deteção do corpo do jogador na layer 2).
- [x] Delay de carregamento eliminado aumentando o raio de streaming para 95 m (descarga a 120 m), gerando os setores antes de entrarem no campo de visão.
- [x] Mapa tático melhorado: bússola Norte, moldura de acento no setor atual, tonalidade própria para setores já visitados, triângulos para caixas de arma, anéis para objetivos e legenda alargada.
- [x] HUD in-game reduzido ao essencial: vida compacta em baixo à esquerda, munição grande em baixo à direita com o nome da arma ativa, faixa de ameaça discreta no topo e contador de Scrap pequeno; removidas a placa do núcleo, a placa grande de recursos, o loadout `[1]/[2]` e a barra de atalhos.
- [x] Armas encontráveis pela exploração: caixas de arma geradas em cerca de um terço dos setores por seed, recolhidas com `F`, que substituem a arma secundária durante a partida e ficam com estado por setor.
- [x] `WeaponController.equip_field_weapon` adicionado para trocar o slot secundário em runtime; `AmmoPickup` e `ScrapPickup` emitem `collected` e suportam auto-recolha.
- [x] Variedade de inimigos alargada: **Brute** (tanque lento, 320 de vida, ataque forte com knockback), **Spitter** (mantém distância e dispara projéteis de ácido) e o boss **The Breaker** (1200 de vida, knockback e invocação periódica de minions).
- [x] Base `normal_zombie.gd` estendida com knockback configurável e modo de ataque à distância (aproximar/recuar/disparar) reutilizável; projétil `spit_projectile` criado.
- [x] Knockback do jogador implementado como impulso que decai por cima do input, aplicado por Brute e Boss.
- [x] Diretor de horda passou a escolher o tipo de inimigo por peso conforme o nível de ameaça (Runners cedo, Brutes a partir do nível 2, Spitters do nível 3) e a invocar um Boss a cada cinco níveis, com aviso no HUD.
- [x] Resolução por defeito baixada para janela 1152 × 648 (projeto e `SettingsManager`) para facilitar os testes; fullscreen e resoluções maiores continuam opcionais e persistidos.
- [x] Contador de FPS global adicionado como autoload `FpsOverlay`, sempre visível, com cor por faixa (verde/amarelo/vermelho) e alternável com `F3`.
- [x] Primeira ronda de otimização de desempenho: aquisição de alvo do disparo automático passou a fazer os raycasts por inimigo só algumas vezes por segundo (cache entre varreduras), corrigindo também um erro de objeto libertado; repath dos inimigos throttlado e escalonado (0,35 s) com cache do alvo do jogador; setores carregados em simultâneo reduzidos de ~9 para ~5 baixando o raio de streaming (72 m / descarga 96 m) para cortar draw calls no renderer GL Compatibility.
- [x] Geração de setores movida para threads de trabalho (`WorkerThreadPool`): a construção da subárvore (estradas, adereços, navegação) deixou de correr na thread principal, eliminando o "break" de ~230 ms ao entrar numa zona nova; o setor pronto é apenas adicionado à cena na thread principal, com o resultado descartado em segurança se o jogador se afastar entretanto.
- [x] Limite de níveis removido: as personagens sobem de nível sem teto e ganham um ponto de habilidade a cada dois níveis.
- [x] Árvore de habilidades permanente por personagem (`SkillTree`): três ramos (Ofensiva, Sobrevivência, Expedição) de cinco níveis, com pré-requisitos e níveis mínimos 2/5/9/14/20 por tier, guardada no save e aplicada a cada partida (dano, cadência, recarga, vida, regeneração, redução de dano, velocidade, reserva de munição, e multiplicadores de Scrap e XP).
- [x] Ecrã de skill tree acessível por um botão na seleção de personagens, que constrói os cartões dinamicamente com estados desbloqueado/disponível/bloqueado e pontos disponíveis.
- [x] "Field Upgrade" (painel de melhorias entre rondas) removido por completo, substituído pela skill tree permanente.
- [x] Ao equipar uma arma encontrada, a arma substituída é largada no chão como pickup, podendo ser reapanhada com `F`.
- [x] POIs com interiores exploráveis nos setores gerados: cerca de metade dos
  setores recebe um edifício graybox de 11 × 11 m (`SectorGenerator._add_poi_building`)
  com três muros sólidos e uma frente partida à volta de uma porta de 4 m. Os
  muros são `navigation_blocker`, por isso a porta é a única abertura que a grelha
  de navegação em runtime deixa livre — o jogador entra para recolher a cache de
  recompensa (50 de Scrap) e os inimigos perseguem-no para dentro pela mesma porta.
- [x] Cache interior do POI reutiliza o estado por setor sob um índice reservado
  (`POI_CACHE_INDEX`), não reaparecendo depois de recolhida durante a partida.
- [x] Cada POI ganhou um marcador no grupo `point_of_interest` (visível no mapa
  tático em `Tab`) e uma etiqueta 3D (OUTPOST/DEPOT/BUNKER/RUINS).
- [x] Ataques dos inimigos animados: novo `attack_animation` no componente
  `imported_model_animation.gd`, ligado ao sinal `attacked` que os zombies já
  emitem; Normal, Runner, Brute, Spitter (herdado) e Boss tocam `Idle_Attack`
  (1,67 s, sem loop) ao atacar, voltando à locomoção quando o clip termina. O
  jogador não é afetado (ataques continuam a vir dos sinais das armas).
- [x] Decisão de assets: manter Quaternius para todos os movimentos (Mixamo
  parqueado); todos os clips necessários já existem nos modelos atuais.
- [x] Emboscadas dos setores repostas por ciclo em vez de uma única por partida:
  o `WorldStreamer` liga-se ao sinal `cycle_completed` do diretor de horda e, a
  cada ciclo (~3 níveis de ameaça), re-arma a emboscada de todos os setores; uma
  guarda de inimigos vivos (`_ambush_enemies_cleared`) impede que uma nova vaga
  se sobreponha à anterior enquanto ainda está a ser combatida.

- [x] Estado do mundo persistido no save: seed fixo por perfil (o layout dos
  setores mantém-se entre partidas; loot volta a cada partida por decisão de
  design), setores visitados (memória do mapa tático) e farol este; secção
  `[world]` no `SaveManager`.
- [x] Melhorias da base compradas com Scrap armazenado: três pedestais junto ao
  núcleo (`camp_upgrade_station`) — Resupply Rate (+cura/+munição por segundo),
  Resupply Range (+raio) e Scavenging (+% Scrap), 3 níveis com custos crescentes,
  estado e efeitos no `CampEconomy`, raio/valores efetivos no `CampCore`.
- [x] `HitReact` nos inimigos ao levar dano (via `health_changed`, cooldown de
  0,9 s, nunca interrompe o ataque) e animação de morte `Death`: o inimigo emite
  `died` como antes e fica como cadáver 2,5 s sem colisão, grupos ou hitboxes
  (os tiros atravessam para os inimigos vivos atrás).
- [x] Dois pontos de fortificação extra (oeste e este do núcleo), reutilizando a
  cena existente — total de 3 barricadas construíveis.
- [x] Objetivos de mastery por personagem (`character_mastery.gd` + API no
  `SaveManager`): EXTERMINATOR (100 abates), STORM RIDER (nível de ameaça 5 numa
  partida, guarda o máximo), SCAVENGER (500 Scrap); recompensa em Credits paga
  uma única vez, progresso persistido, resumo nos cartões da seleção de classes
  e detalhe no painel de loadout, feedback no HUD ao completar.
- [x] Orçamento de IA para inimigos distantes: a mais de 40 m o repath passa de
  0,35 s para 1,2 s e o steering (query de caminho por frame) é cacheado e
  refrescado a 0,3 s; comportamento de perto inalterado.
- [x] Métricas de streaming no overlay de FPS (`F3`): setores carregados e
  duração do último build de setor.
- [x] Painel de vitória antigo removido (`wave_complete_panel` cena+script) e o
  sinal morto `all_waves_completed` retirado do diretor de horda.
- [x] Decisão registada: navmesh de editor não se aplica (setores gerados em
  runtime); mantém-se a grelha de navegação construída na worker thread.
- [x] `GDD.md`, `ARCHITECTURE.md` e `ROADMAP.md` reescritos e sincronizados com
  o jogo real (horda contínua, mundo aberto, inglês, skill tree, mastery).
- [x] Facelift visual Tier 1 dos menus: backdrop 3D leve no menu principal com
  estrada urbana, props existentes, núcleo apenas visual, céu/nevoeiro de
  entardecer e órbita lenta; pré-visualização animada da classe selecionada com
  os GLTF Quaternius diretos; hover/press reutilizáveis, entrada com fade+slide
  e contagem animada de Credits; painéis com sombra, acento âmbar, gradiente,
  ruído e scanlines procedurais subtis, sem assets externos nem gameplay.

- [x] **Pack "Animated Guns" experimentado e revertido** (decisão de playtest):
  os visuais animados nas cenas das armas, ancorados ao `WeaponPivot` estático,
  nunca assentaram bem nas mãos do personagem — mesmo após recentrar o pivot, a
  arma "flutua" porque as mãos mexem com as animações do rig e o pivot não.
  Rollback completo: malhas embutidas restauradas, pivot original, armas novas
  (Hunting/Marksman/Revolver) removidas com limpeza de save, assets apagados.
  Aprendizagem registada: modelos de armas futuros exigem `BoneAttachment3D` ao
  osso da mão ou vir embutidos no rig do personagem.

- [x] Progressão da skill tree abrandada: um ponto a cada dois níveis, tiers
  bloqueados até aos níveis 2/5/9/14/20 e migração conservadora que nunca remove
  skills já desbloqueadas nem mostra pontos negativos em saves antigos.
- [x] `ARMORY` funcional adicionado à seleção de classes: catálogo por classe,
  requisitos de nível/Créditos, compra permanente e equipamento persistente nos
  slots `[1]`/`[2]`, incluindo troca automática quando a mesma arma muda de slot.
- [x] Medic concluído com Pistol + Spear, malha `Spear` embutida no rig, golpe
  melee de 42 de dano, alcance superior e animação `Stab`.
- [x] Primeiro passe de equilíbrio das classes: Recruit mantém 100 HP, 1 HP/s
  após 6 s e recarga 30% mais rápida; Renegade passa a 150 HP; Medic mantém
  100 HP e regenera 3 HP/s após 4 s. Alcances automáticos iniciais: AR 6 m,
  Pistol 5,5 m e Shotgun 4,5 m.
- [x] Overlay do flash de dano dos inimigos corrigido para usar transparência
  alfa explícita no renderer Compatibility, preservando as cores originais dos
  modelos quando não estão a receber dano.


- [x] Menu de definições reorganizado em três separadores (DISPLAY / CONTROLS /
  AUDIO) com botões-tab no estilo do tema, mantendo o visual do facelift.
- [x] **Keybindings rebindable**: lista das 16 ações de jogo no separador
  CONTROLS (o `pause` fica fixo em Esc por segurança), captura da próxima tecla
  ou botão do rato ao clicar, **swap automático quando a tecla já está em uso**,
  botão de reset a defaults, persistência na secção `[input]` de
  `user://horde_breaker_settings.cfg` (keycodes físicos — WASD mantém a posição
  em qualquer layout de teclado) e aplicação ao `InputMap` no arranque pelo
  `SettingsManager`; como todo o jogo usa ações, os rebinds funcionam em todo o
  lado de imediato. `load_settings(path)` adicionado como hook de teste isolado.

- [x] Munição do chão escala com o nível de ameaça: cada caixa vale
  `base + 4 × (nível − 1)`, com teto em 4× a base (12 → 48), e a recolha mostra
  "+N AMMO" no feed do HUD. Sem wave manager (menus/testes) mantém a base.

- [x] **Variantes de classe** (`character_variants.gd` + API no SaveManager +
  aplicação em `character_skills.gd`): desbloqueadas ao completar as 3 masteries
  da classe, alternáveis por um toggle persistido na seleção de classes (linha
  própria no painel de loadout com estados locked/on/off). VETERAN troca a
  recarga rápida do Recruit por +15% de cadência; BERSERKER baixa o Renegade
  para 110 HP mas o melee rouba 2 HP por golpe; COMBAT MEDIC enfraquece a regen
  (1,5 HP/s após 5 s) mas cada abate cura 5 HP. Overrides base aplicados antes
  dos bónus da skill tree; hooks de runtime (lifesteal via `attack_performed`,
  cura via `enemy_defeated`) ligados no arranque; tint aditivo subtil no modelo
  (com transparência alfa, seguindo a lição do hit-flash).

- [x] **SMG** e **Fire Axe** compráveis no ARMORY (Milestone 20): SMG hitscan
  automática (dano 16, cadência 11, carregador 35, auto-fire 7 m; nível 3 · 400
  Credits) com a malha embutida `SMG`; Fire Axe melee (dano 70, cooldown 0,9 s,
  swing `Slash`; nível 4 · 500 Credits) com a malha embutida `Axe`. Registadas
  no `WeaponCatalog`, com stance correta (SMG = gun, Axe = melee), nomes na UI e
  ícones gerados pela ferramenta (`weapon_smg.png`/`weapon_fire_axe.png`).
- [x] Auto-fire por arma confirmado/afinado (AR 6, Pistol 5,5, Shotgun 4,5,
  SMG 7 m) — item do Milestone 22 que dependia de implementação.

- [x] **Milestone 24 — cidade a sério (1ª fatia):** os setores gerados deixaram
  de usar cubos graybox como landmarks. `SectorGenerator._add_city_buildings`
  coloca agora **edifícios CC0 reais** do Quaternius Downtown MegaKit
  (Building_Small/Medium/Large, 1 mesh cada, ~12–20 m de footprint) como
  `navigation_blocker` com colisão por footprint e rotação por quarto de volta;
  `_add_city_props` espalha planters (com colisão), bollards e tampas de
  esgoto (decoração pura) pelos quarteirões. A geração continua por seed em
  worker threads e a navegação em runtime mantém-se (2842 polígonos com um
  edifício na cena). As estradas atuais já são tiles Quaternius texturados, por
  isso o swap para as Downtown ficou como polish opcional. Pack CC0 aligeirado
  de 247 MB → 91 MB (Textures/FBX redundantes removidas; a pasta glTF é
  auto-suficiente). Fonte/licença em `assets/models/city_test_model/SOURCE.md`.

- [x] **Fix:** as malhas dos edifícios Quaternius não estão centradas na origem
  (footprint deslocado até ~8 m em z), o que deixava a caixa de colisão ao lado
  do prédio visível — paredes invisíveis no vazio e atravessar o edifício. O
  visual passa a ser deslocado por `-center` para o footprint coincidir com a
  origem/colisão; teste confirmou 28 edifícios com colisão a <1,5 m do visível
  (antes 5–8 m).

- [x] **Cidade mais densa + passadeiras corrigidas:** mais edifícios por setor
  (3–6, média 4 vs 2,6), cada um com um **lote de betão** por baixo que esconde
  as marcações/passadeiras da rua sob o prédio (assim os edifícios assentam num
  lote em vez de flutuarem sobre a rua). O lote não tem colisão (a navegação
  continua a usar só o nó `Collision`); a área do lote é reservada para os
  edifícios manterem distância. Navegação saudável (min 2426 polígonos em 8
  setores).

- [x] **Layout urbano refeito (quarteirões e ruas):** o setor deixou de ser uma
  grelha uniforme de 64 tiles de estrada (que punha passadeiras por todo o lado
  e edifícios em cima delas). Passou a ser uma malha de 8×8 células de 8 m onde
  as células do eixo central formam uma **cruz de ruas de 16 m** (com tiles
  retos e cruzamento 4-way) e os quatro cantos são **quarteirões de 24×24 m**
  pavimentados com passeio. Os **edifícios só são colocados dentro dos
  quarteirões** (`_find_free_position_in_block`), pelo que nunca mais assentam
  sobre marcações ou passadeiras. Os quarteirões são lajes planas (sem degrau,
  movimento inalterado); as constantes mortas do antigo `city_road_grid` foram
  removidas.

## Milestone atual

**Milestone 20 — Arsenal e progressão controlada**

## Próxima tarefa

Fazer um playtest curto das três classes: ritmo de pontos/requisitos da skill
tree, compra e troca de slots no `ARMORY`, alcance/dano das armas, regeneração
do Medic e golpe da Spear. O facelift adicional dos menus fica adiado a pedido
do utilizador; Mixamo e armas externas continuam parqueados.

## Validação

- Godot disponível: `4.7.stable.mono.official.5b4e0cb0f`.
- Cidade: teste headless confirmou 21 edifícios em 8 setores, todos como
  `navigation_blocker` com colisão e mesh, e navegação a construir com 2842
  polígonos com um edifício presente; arena real 400 frames (geração em worker
  threads) sem erros; captura OpenGL de um setor com edifícios de tijolo,
  janelas, cornijas e estradas com marcações.
- SMG/Fire Axe: teste headless (9 asserts) — presença no catálogo e ícones,
  SMG automática com carregador 35, Fire Axe melee com swing Slash, e compra no
  ARMORY bloqueada abaixo do nível 3 / permitida ao nível 3 com Credits; captura
  OpenGL do ARMORY confirmou as duas armas com ícones e custos.
- Variantes: teste headless ponta-a-ponta com save isolado (13 asserts) —
  bloqueio até à mastery completa, toggle persistente, e em arena real: Veteran
  com cadência 6,9 e recarga de classe removida; Berserker com 110 HP e +4 HP
  por golpe duplo de melee; Combat Medic com regen 1,5/5 s e +5 HP por abate.
  Seleção de personagens validada em headless e captura OpenGL (linha da
  variante com estado LOCKED).
- Munição escalável: teste headless (5 asserts) — base 12 sem diretor, 36 ao
  nível 7, teto 48, e entrega escalada ao jogador (28 ao nível 5).
- Keybindings: teste headless com settings isoladas confirmou rebind (Space→K),
  texto do binding, swap em conflito (crouch→K trocou com jump, que recebeu
  Ctrl), binding de rato (MOUSE MIDDLE), reaplicação após reload e reset a
  defaults (9 asserts); menu de definições headless 60 frames sem erros e
  capturas OpenGL dos três separadores validadas visualmente.
- Milestone 20: importação headless sem erros; `armory_screen`,
  `character_selection`, `skill_tree_screen`, `spear`, `medic` e `test_arena`
  executados isoladamente durante 60 frames sem `SCRIPT ERROR`.
- Teste integrado com save isolado confirmou 33 verificações: níveis mínimos,
  pontos a cada dois níveis, preservação de skills antigas, migração do loadout
  do Medic, catálogo, compra da Pistol pelo Renegade, persistência/troca dos
  slots e Spear ativa com malha embutida e animação `Stab`.
- Capturas OpenGL a 1152 × 648 confirmaram o novo `ARMORY` e o botão na seleção
  de classes sem cortes nem sobreposições.
- Facelift Tier 1: importação headless concluída sem erros; `main_menu.tscn` e
  `character_selection.tscn` executados isoladamente durante 60 frames sem
  `SCRIPT ERROR`.
- Facelift Tier 1: teste headless alternou Recruit, Renegade e Medic no mesmo
  `SubViewport`, confirmando uma única instância, `Idle_Gun` em reprodução e as
  malhas embutidas Rifle, Shotgun e Pistol visíveis, respetivamente.
- Facelift Tier 1: capturas OpenGL a 1152 × 648 confirmaram o backdrop 3D, a
  vinheta, o modelo animado do Recruit, os cartões/mastery e o loadout sem
  cortes nem sobreposições; o overlay F3 foi ocultado apenas durante a captura.
- Emboscadas por ciclo: teste headless (`SceneTree`) confirmou que um inimigo
  vivo impede o re-arme, que uma lista limpa conta como pronta, que
  `_on_cycle_completed` repõe `ambush_triggered` em todos os setores e que o
  `WorldStreamer` se liga ao sinal `cycle_completed` de um wave manager fictício
  e re-arma ao recebê-lo.
- Emboscadas por ciclo: `test_arena` em headless durante 300 frames correu sem
  erros com a ligação ao diretor de horda real ativa.
- Ataques animados: teste com renderer OpenGL confirmou que os cinco inimigos
  tocam `Idle_Attack` (sem loop) ao emitir `attacked`, com captura visual do
  pose de ataque; `test_arena` em headless durante 240 frames sem erros.
- Persistência do mundo: teste headless com save isolado confirmou seed estável
  entre chamadas e reloads, deduplicação de setores visitados, farol persistido
  e o `WorldStreamer` a usar o seed do save (9 asserts).
- Upgrades da base: teste headless confirmou custos 40→80→120, recusa quando
  maxado ou sem Scrap, bónus (+12 cura/s, +6 munição/s no nível 3), Scavenging
  a converter 100→115, compra pela estação com etiqueta atualizada, 3 estações
  nomeadas no núcleo e raio efetivo 12→16 (14 asserts).
- HitReact/Death: teste headless confirmou HitReact ao dano com cooldown sem
  restart, prioridade do ataque, `died` emitido uma vez, cadáver com `Death`,
  sem colisão/grupo/hitboxes, imune a dano e libertado após 2,5 s (9 asserts).
- Mastery: teste headless com save isolado confirmou acumulação, modo máximo,
  clamp no objetivo, recompensa paga uma única vez, persistência após reload e
  captura OpenGL da seleção de classes com resumo e detalhe legíveis (7 asserts).
- Arena completa: 3 fortificações e 3 estações verificadas por script; run
  headless de 1700 frames (~28 s com horda ativa) sem erros com o orçamento de
  IA e as métricas de streaming ativos.
- Armas animadas: teste confirmou o clip de Fire a tocar em `shot_fired` e o de
  Reload à velocidade certa (0,54×) em `reload_started`; orientações das três
  armas validadas por capturas de perfil com guias de muzzle; arena com o
  renderer OpenGL sem erros (os avisos de material em headless são ruído do
  renderer dummy com FBX skinned).
- POIs: teste headless (`SceneTree`) sobre 60 seeds confirmou POIs em 33/60
  setores (55%), os cinco muros no grupo `navigation_blocker` com `Collision`, o
  marcador em `point_of_interest`, a cache interior de 50 de Scrap e — via malha
  de navegação em runtime — a célula caminhável mais próxima do centro interior a
  0,56 m e da porta a 0,42 m (interior alcançável pela porta, não murado).
- POIs: `test_arena` em headless durante 240 frames carregou dois setores gerados
  (com POIs) em worker threads sem erros de navegação ou de colisão.
- POIs: captura OpenGL a 1152 × 648 confirmou os muros, a porta, o chão interior
  e a cache de recompensa dentro do edifício, entre os marcos existentes.
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
- Teste integrado das três rondas confirmou 286 XP de sessão, nível 3 com 36 XP restante e 100 Credits.
- Teste automatizado confirmou persistência das recompensas após novo carregamento do save.
- Teste automatizado rodou a câmara 90 graus e confirmou alinhamento do jogador e da arma com a mira.
- Teste automatizado confirmou impacto exatamente no centro do ecrã, com erro de projeção de `0 px`.
- Alvo colocado sob a mira recebeu 25 de dano, a munição passou de 30 para 29 e o tracer nasceu no cano.
- Inspeção visual confirmou o ponto de mira centrado e legível sobre a arena.
- Cena principal de menu executada em modo headless durante dois frames com código de saída 0.
- Teste automatizado confirmou desbloqueio do Renegade por 500 Credits e persistência da seleção.
- Teste automatizado instanciou a arena com Recruit e Renegade e confirmou personagem, arma e visibilidade da mira esperadas.
- Menus renderizados com OpenGL a 1152 × 648 sem texto cortado, sobreposição ou botões fora do ecrã.
- Teste melee com o driver Windows confirmou dois alvos frontais atingidos pelo mesmo golpe e um alvo traseiro intacto.
- Teste automatizado confirmou 35 de dano por ataque, rejeição de ataques durante o cooldown e novo ataque após o intervalo.
- Normal Zombie real morreu após dois ataques acionados através da ação `attack` e emitiu o sinal `died` esperado.
- Arena instanciada com o Renegade confirmou Worn Sword ativa, Assault Rifle oculta e HUD `Arma: Worn Sword`; a mira passou posteriormente a permanecer visível para permitir headshots melee.
- Inspeção visual OpenGL confirmou a espada provisória visível na vista sobre o ombro.
- Primeiro arranque criou `horde_breaker_test.cfg` com 2000 Credits, Recruit nível 5 e progressão normal das duas personagens.
- Segundo arranque manteve o hash do perfil de teste, confirmando que os valores iniciais não são adicionados novamente.
- Hash do save normal permaneceu inalterado durante os dois arranques com o perfil de teste.
- Teste integrado confirmou 846 polígonos navegáveis, exclusão das três coberturas e caminhos válidos dos seis spawns até ao jogador.
- Teste integrado confirmou exatamente cinco zombies na primeira ronda e movimento normal antes e depois da pausa.
- Teste integrado confirmou que os zombies não mudam de posição enquanto a árvore está pausada.
- Teste integrado confirmou mira com 6 × 6 píxeis e centro com 2 × 2 píxeis.
- Teste de física confirmou que a Worn Sword tem linha direta para um alvo livre e fica bloqueada pela barricada central.
- Inspeção visual OpenGL confirmou as três coberturas, espaço de circulação, mira reduzida e painel de pausa legível.
- Teste com save legado isolado preservou 1234 Credits, Recruit nível 5 com 42 XP e Renegade nível 2 com 17 XP.
- A migração acrescentou Pistol ao Recruit, Shotgun ao Renegade e valores iniciais do Medic sem remover compras existentes.
- Teste automatizado confirmou Assault Rifle/Pistol no Recruit, Shotgun/Worn Sword no Renegade e Pistol/slot vazio no Medic.
- Teste automatizado confirmou recargas do Recruit reduzidas de 1,5 para 1,05 segundos e de 1,3 para 0,91 segundos.
- Teste automatizado confirmou 140 de vida no Renegade e regeneração de 4 pontos por segundo no Medic contra 1 ponto no Recruit.
- Teste de física confirmou dano de múltiplos pellets da Shotgun sem ultrapassar o máximo de oito pellets.
- Teste automatizado confirmou as ações `weapon_primary` e `weapon_secondary` e a rejeição segura do slot secundário vazio do Medic.
- Menu de classes e arena com Shotgun renderizados em OpenGL a 1152 × 648 sem texto cortado ou sobreposição.
- Oito ficheiros glTF do Quaternius foram importados pelo Godot 4.7 em modo headless com código de saída 0.
- Cenas do Recruit, Renegade, Medic, Assault Rifle, Pistol e Shotgun executadas isoladamente em modo headless sem erros.
- Arena de teste executada durante 30 frames em modo headless com o Recruit e os zombies importados sem erros de carregamento ou de animação.
- Teste automatizado confirmou a arma visual ativa em cada loadout: Rifle/Pistol no Recruit, Shotgun no Renegade e Pistol no Medic.
- Captura OpenGL a 1152 × 648 confirmou o Recruit no chão, orientado para a mira, sem as armas internas não equipadas visíveis.
- Teste automatizado confirmou as ações `jump`, `sprint`, `crouch`, `interact`, `camera_front` e `aim` no `InputMap`.
- Teste de física confirmou andar a 4 m/s, corrida a 7 m/s, salto ascendente e agachamento a 2,5 m/s com cápsula reduzida de 2 para 1,2 metros.
- Teste de física confirmou que uma cobertura superior impede a personagem de se levantar e que a altura normal é reposta depois de libertar o espaço.
- Teste integrado confirmou que `F` transfere munições para a reserva e remove o pickup apenas quando a transferência é válida.
- Teste automatizado confirmou que o botão direito reduz o FOV de 70 para 55 e o comprimento do braço de 5 para 3,2 metros.
- Teste automatizado confirmou que manter `C` roda a câmara aproximadamente 180 graus e que libertar a tecla repõe a órbita anterior.
- Teste integrado confirmou que selecionar a Worn Sword mostra a lâmina integrada, mantém a primitiva antiga oculta e reproduz `Slash` ao atacar.
- Capturas OpenGL confirmaram a espada na mão do Renegade em idle e ataque, a postura agachada, a mira aproximada e a vista frontal sem o objeto suspenso.
- Oito modelos ambientais e de veículo foram importados em modo headless sem erros.
- Teste automatizado confirmou Assault Rifle com `30 / 90`, recolha de 12 munições com o carregador cheio e reserva resultante de 102.
- Teste automatizado confirmou que uma recarga com cinco munições de reserva transfere apenas essas cinco e deixa a reserva a zero.
- Teste integrado confirmou que o Renegade recolhe munições para a Shotgun enquanto a Worn Sword está ativa, aumentando a reserva de 32 para 44.
- Teste integrado confirmou 16 módulos de estrada, piso e quatro paredes visuais ocultos e navegação ainda disponível.
- Captura OpenGL a 1152 × 648 confirmou o mapa urbano completo, contentores, camião, torre, barreiras e ausência das paredes graybox.
- Teste direto confirmou 10 de dano no corpo e 20 de dano na cabeça através das `DamageHitbox`.
- Teste com raycast real confirmou 25 de dano no corpo e 50 de dano na cabeça com a Assault Rifle.
- Teste com a Worn Sword confirmou 35 de dano no corpo e 70 de dano na cabeça, aplicado uma única vez apesar da sobreposição das duas hitboxes.
- Teste de herança confirmou `BodyHitbox`, `HeadHitbox` e multiplicador `2.0` no Runner.
- Inspeção OpenGL com volumes de depuração confirmou a esfera de cabeça alinhada com a cabeça visível do Normal Zombie e a cápsula do corpo até ao pescoço.
- Tema partilhado, seis cenas de UI e scripts associados importados pelo Godot 4.7 sem erros.
- Menu principal e seleção de personagens executados isoladamente em modo headless com código de saída 0.
- Arena de teste executada durante 60 frames em modo headless com o HUD revisto e código de saída 0.
- Capturas OpenGL a 1152 × 648 confirmaram menu principal, seleção, HUD, pausa, derrota e vitória sem texto cortado ou painéis sobrepostos.
- Teste automatizado confirmou números `10` no corpo e `20` na cabeça com dano base 10, incluindo a cor dourada exclusiva do headshot.
- Teste automatizado confirmou que os oito pellets da Shotgun produzem um único número agregado no mesmo inimigo.
- Teste automatizado confirmou um único número por alvo atingido pela Worn Sword e remoção automática de todos os indicadores após 0,65 segundos.
- Captura OpenGL a 1152 × 648 confirmou o número de headshot pequeno, legível e sem interferir com o HUD.
- Teste automatizado carregou as cenas reais e confirmou 100/60 de vida no Normal Zombie/Runner e multiplicador de cabeça `2 ×`.
- Teste automatizado confirmou dano corpo/cabeça de `30/60` na Assault Rifle, `35/70` na Pistol, `12/24` por pellet na Shotgun e `50/100` na Worn Sword.
- Teste integrado com raycasts reais confirmou números `30/60` da Assault Rifle no corpo/cabeça, `35` da Pistol, `96` para oito pellets da Shotgun e `50` da Worn Sword.
- Arena executada durante 60 frames em modo headless após o balanceamento sem erros de carregamento ou execução.
- Importação headless após o Milestone 15 concluída sem erros de parsing ou de recursos.
- Cena principal executada durante 120 frames em modo headless sem erros.
- Teste integrado percorreu os ataques `1–4` com `5`, `10`, `17` e `7` inimigos, confirmando repetição contínua e aumento de dois Normal Zombies no novo ciclo.
- Teste integrado confirmou uma única emissão de `cycle_completed` após três ataques e ausência do painel de vitória na arena.
- Teste integrado confirmou zombies a escolher tanto jogador como núcleo, dano real causado ao núcleo e remoção do núcleo do grupo de alvos aos zero pontos de vida.
- Teste integrado confirmou que o núcleo aceita dano real dos zombies, mas não expõe o método usado pelas armas do jogador.
- Teste integrado confirmou mensagem específica de destruição do núcleo, apresentação do painel de derrota e pausa da árvore.
- Captura OpenGL a 1152 × 648 confirmou o núcleo legível no mapa e o novo painel de vida sem sobreposição com ataque, ameaças ou retículo.
- Importação headless após o primeiro slice do Milestone 16 concluída sem erros de parsing ou de recursos.
- Arena expandida executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou arena de 64 × 64 metros, quatro bairros e malha de navegação com 3344 polígonos.
- Teste integrado confirmou caminhos dos seis spawns inimigos até ao núcleo e oito caches de Scrap presentes.
- Teste integrado confirmou recolha de 25 Scrap, depósito, reparação de 50 pontos por 10 Scrap e bloqueio da reparação durante um ataque.
- Teste integrado confirmou o início do primeiro ataque após a fase de preparação.
- Captura OpenGL a 1152 × 648 confirmou o centro desimpedido, maior distância visual, contagem de exploração e painéis de Scrap sem sobreposição.
- Importação headless após a fortificação concluída sem erros de parsing ou de recursos.
- Arena com a fortificação executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou construção por 30 Scrap, 200 pontos de vida e reparação de 50 pontos por 10 Scrap.
- Teste integrado confirmou bloqueio da construção durante ataques e reconstrução durante a exploração.
- Teste integrado confirmou atualização da navegação de `3344` para `3332` polígonos ao construir e reposição para `3344` ao destruir.
- Teste integrado confirmou que um Normal Zombie real escolhe a barricada próxima e lhe causa dano.
- Captura OpenGL a 1152 × 648 confirmou marcador, barricada construída, etiqueta no mundo e feedback sem sobreposição crítica com o HUD.
- Importação headless do primeiro slice do Milestone 17 concluída sem erros de parsing ou de recursos.
- Arena com os quatro POIs executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou quatro grelhas de estrada, quatro POIs e ausência das antigas instâncias repetidas na arena.
- Teste integrado confirmou 3424 polígonos navegáveis, caminhos dos seis spawns ao núcleo e caminhos do acampamento aos quatro acessos.
- Teste integrado confirmou os oito caches preservados, alcançáveis e com uma cache a menos de 10 metros de cada POI.
- Captura OpenGL frontal confirmou hospital e armazém legíveis a partir do acampamento sem bloquear a área central.
- Captura OpenGL aérea confirmou as quatro silhuetas distintas, distribuição por quadrantes e rotas abertas entre zonas.
- Importação headless após a abertura do armazém concluída sem erros de parsing ou de recursos.
- Arena com o interior do armazém executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou 3468 polígonos navegáveis, caminho do acampamento até ao interior, quatro acessos e seis rotas de spawn preservadas.
- Teste integrado confirmou nove caches de Scrap e recolha funcional do loot interior: 25 Scrap e 12 munições.
- Capturas OpenGL a 1152 × 648 confirmaram a entrada aberta, o interior iluminado, a prateleira e os dois pickups legíveis.
- Importação headless após a emboscada do armazém concluída sem erros de parsing ou de recursos.
- Arena com `WarehouseEncounter` executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou dois Normal Zombies por ativação, 10 XP total e `alive_enemy_count` inalterado em zero.
- Teste integrado confirmou uma ativação por ciclo, reposição de Scrap e munições após `cycle_completed` e ausência de duplicação quando o loot permanece por recolher.
- Captura OpenGL a 1152 × 648 confirmou os dois zombies separados, no chão e legíveis em redor do loot interior.
- Importação headless após a abertura do hospital concluída sem erros de parsing ou de recursos.
- Arena com o hospital explorável executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou 3498 polígonos navegáveis, percurso de 29 pontos do acampamento ao interior e os quatro acessos dos POIs preservados.
- Teste integrado confirmou uma única instância do medkit, rejeição com vida cheia, cura de 40 pontos, limite na vida máxima e reposição após `cycle_completed`.
- Capturas OpenGL a 1152 × 648 confirmaram a entrada aberta, sinalização, duas camas, iluminação fria e medkit legível no interior.
- Importação headless após a abertura do posto militar concluída sem erros de parsing ou de recursos.
- Arena com o posto militar explorável executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou 3516 polígonos navegáveis, percurso de 25 pontos do acampamento ao interior e os quatro acessos preservados.
- Teste integrado confirmou dois Normal Zombies, um Runner, 18 XP total e `alive_enemy_count` inalterado em zero.
- Teste integrado confirmou duas caixas de munições, reposição após `cycle_completed` e ausência de duplicação quando o loot permanece por recolher.
- Capturas OpenGL a 1152 × 648 confirmaram a entrada aberta, bunker iluminado, duas caixas e elementos militares legíveis.
- Importação headless após a abertura da estação de combustível concluída sem erros de parsing ou de recursos.
- Arena com a estação de combustível explorável executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou 3522 polígonos navegáveis, percurso de 26 pontos do acampamento ao interior e os quatro acessos preservados.
- Teste integrado confirmou três Runners, 24 XP total, `alive_enemy_count` inalterado em zero e reposição seletiva das duas caches sem duplicação.
- Capturas OpenGL a 1152 × 648 confirmaram a loja aberta, iluminação quente, duas caches legíveis e Runners separados na zona das bombas.
- Importação headless do primeiro slice do Milestone 18 concluída sem erros de parsing ou recursos.
- Menu principal e arena do primeiro slice executados durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou ausência de disparo a 4 metros e através de uma parede, seguida de dano automático real a 2,5 metros.
- Teste integrado confirmou configuração comum na Pistol e Shotgun, herança do grupo `enemy` no Runner e exclusão da Worn Sword.
- Teste integrado confirmou duas regiões de navegação e um percurso contínuo de 33 pontos até ao farol do setor leste.
- Teste integrado confirmou carregamento, descarregamento e novo carregamento com uma única instância do setor.
- Teste integrado confirmou preservação das instâncias do jogador e do acampamento e do estado ativado do farol.
- Capturas OpenGL a 1152 × 648 confirmaram os dois setores alinhados, estrada contínua e farol visualmente destacado no graybox leste.
- Não foram encontrados erros de parsing ou de carregamento.
- Importação headless após as melhorias de UI concluída sem erros e com registo da classe `UiAnimations`.
- Menu principal, menu de definições, seleção de personagens, menu de pausa e arena executados em modo headless com código de saída 0.
- Capturas OpenGL a 1152 × 648 confirmaram o menu principal com o botão de definições, o painel de definições completo sem cortes e o banner de exploração do HUD legível sem sobreposição com os painéis existentes.
- O pulso da vinheta de dano, o hit-marker e a barra de recarga ainda não foram exercitados num playtest manual com combate real.
- Importação headless após o redesign visual concluída sem erros de parsing ou de recursos.
- Menu principal, seleção de personagens, definições, pausa e arena executados em modo headless com código de saída 0 após o redesign.
- Capturas OpenGL a 1152 × 648 confirmaram o menu principal com botões enviesados, a seleção de classes com emblemas e cartões centrados, o menu de definições com o novo tema e o HUD modular sem sobreposição de elementos.
- O painel de vitória (`wave_complete_panel.tscn`) continua fora de uso e mantém o estilo antigo; será atualizado se voltar a ser necessário.
- Importação headless e cena de definições executadas sem erros após remover a secção de gráficos.
- Teste integrado do streamer confirmou: zero setores no arranque, carregamento em background do setor leste em 15 ms (3 frames físicos após o gatilho), descarregamento ao afastar e recarregamento em 9 ms sem duplicação.
- Captura OpenGL a 1920 × 1080 confirmou o céu de entardecer, o nevoeiro no horizonte e o HUD corretamente escalado com o novo stretch.
- Teste com janela real confirmou o ciclo completo: arranque em ecrã completo 1920 × 1080, mudança para janela 1600 × 900 centrada, regresso a ecrã completo e nova mudança para janela, tudo com o modo e o tamanho corretos.
- Diagnóstico frame a frame confirmou a causa original: pedir modo janela com o jogo arrancado em fullscreen nativo deixava a janela presa em exclusive fullscreen e a ignorar redimensionamentos.
- Teste integrado confirmou o núcleo fora do grupo de alvos, o painel de melhorias aberto durante a preparação inicial e um zombie a 10 metros a perseguir o jogador até aos 3,17 metros, onde o disparo automático o abateu, com a vida do núcleo intacta.
- Teste integrado confirmou o flash de dano ativo após `take_damage`, os dois sons sintetizados com dados válidos e as cinco melhorias a aplicar os efeitos numéricos exatos (dano ×1,2, +25 vida, velocidade ×1,1, recarga ×0,8 e cura total).
- Captura OpenGL confirmou o painel de três vantagens legível sobre o HUD durante a exploração.
- Teste integrado do mundo aberto confirmou: zero setores no acampamento, geração do setor norte com três caches e muro exterior, caminho de navegação contínuo de 51 pontos do acampamento até ao interior do setor gerado, layout determinístico após descarregar e recarregar, cache recolhida sem reaparecer e dois setores vizinhos carregados num canto.
- Geração de um setor medida em 134–144 ms (dominada pela instanciação das estradas) e carregamento do setor leste em background em 12–20 ms.
- Capturas com janela real confirmaram ruas contínuas, marcos, contentores e caches legíveis nos setores gerados sob o céu de entardecer.
- Teste integrado do mapa tático confirmou o pior cenário real: com o botão do painel de melhorias focado, o Tab abre e fecha o mapa na mesma.
- Captura com janela real confirmou o mapa tático com a grelha 4 × 4, a base destacada, os setores carregados, o marcador do jogador com direção e os POIs.
- Teste integrado da vida dos setores confirmou: geração faseada completa (4 quadrantes + navegação) em ~180–220 ms totais espalhados por 7 frames, marcadores de spawn e caixa de munições presentes, emboscada de 3 inimigos disparada uma única vez, munições recolhidas sem reaparecer e vaga a nascer dentro do setor do jogador.
- Regressão completa dos testes do mundo aberto, streamer e funcionalidades anteriores sem falhas após a geração faseada.
- Teste integrado com save isolado confirmou o pool de vantagens a crescer com o nível (3 no nível 1, 6 no nível 7, 7 no nível 9) e os efeitos exatos das novas vantagens (carregador 30 → 38 e cadência ×1,15).
- Teste integrado com registo das posições de nascimento confirmou spawns aleatórios: inimigos dentro de 2,6 m de um marcador válido, com desvio visível e vaga a nascer dentro do setor do jogador (3 em 5).
- Captura em jogo real confirmou o painel com Carregadores Alargados no pool e o rodapé "Vantagens desbloqueadas 6 / 7".
- Teste integrado confirmou auto-recolha de Scrap e munições ao sobrepor o corpo do jogador, e que a caixa de arma exige `F` (não é auto-recolhida) e troca a arma secundária para Shotgun, tornando-a ativa.
- Teste do mundo aberto atualizado para o streaming antecipado (raio 95 m) confirmou setor distante não carregado no acampamento, geração ao entrar, layout determinístico, cache recolhida persistente e cinco setores vizinhos num canto.
- Capturas em jogo real confirmaram o HUD minimalista sem as placas antigas e o mapa tático com bússola, setor atual, triângulos de arma, anel de objetivo e legenda alargada.
- Teste integrado dos inimigos confirmou: o Brute dá dano e empurra o jogador, o Spitter dispara um projétil à distância, o Boss invoca minions ao longo do tempo e o diretor gera um Boss no nível configurado.
- Cenas de Brute, Spitter e Boss executadas isoladamente e a arena durante 90 frames sem erros.
- Teste automatizado confirmou que o modo guardado é apresentado corretamente,
  que uma janela muda realmente para `1280 × 720` e que o estado anterior é reposto.
- Teste automatizado confirmou a ação `toggle_map`, o mapa inicialmente oculto e
  a abertura através de `Tab` na arena real.
- Captura OpenGL a `1152 × 648` confirmou o mapa legível e centrado sobre o HUD,
  com grelha, setor da base, orientação do jogador e marcadores de POI.
- Importação e execução headless de menu e arena sem erros após o diretor de horda contínuo, o reabastecimento, os setores enriquecidos e a localização em inglês.
- Testes integrados atualizados para o diretor contínuo confirmaram geração faseada, emboscadas por setor com estado, munições com estado, spawns aleatórios à volta do jogador e o pool de vantagens por nível (3 → 6 → 7).
- Regressão dos testes de mundo aberto, mapa tático e funcionalidades anteriores sem falhas.
- Pesquisa por caracteres acentuados confirmou zero strings em português nos scripts, cenas e dados do jogo.
- Capturas com janela real a `1152 × 648` confirmaram o menu principal em inglês, o mapa tático com setor atual destacado e marcadores de Scrap/munição, e um setor gerado com postes de iluminação, camião e a zona de reabastecimento ativa.

- [x] Inimigos passaram a poder largar um único pickup de Scrap ao morrer:
  Normal 15% (1–2), Runner 20% (1–2), Spitter 30% (2–3), Brute 60% (4–6)
  e Boss 100% (15–20). Os drops desaparecem ao fim de 25 segundos e ficam
  limitados aos 40 mais recentes, sem alterar as caches e POIs existentes.
- Teste headless determinístico confirmou uma taxa Normal de 14,5% em 2000
  mortes, quantidades e overrides corretos, máximo de um pickup por inimigo,
  despawn e limite de 40. Importação headless e arena durante 240 frames
  terminaram sem SCRIPT ERROR.

- [x] UI Tier 2 concluído: Rajdhani Regular/SemiBold/Bold integrada no tema,
  títulos e números com pesos próprios, mapa tático/FPS/dano 3D atualizados,
  oito retratos/ícones transparentes gerados a partir dos modelos Quaternius e
  usados na seleção, ARMORY e HUD, e sons subtis de hover/clique sintetizados
  em runtime. A fonte veio do Google Fonts sob SIL OFL 1.1 e a origem/licença
  ficaram guardadas em `assets/fonts/`.
- Validação Tier 2: importação headless sem erros, gerador OpenGL produziu os
  oito PNGs, inspeção visual confirmou retratos e armas centrados, e main menu,
  seleção, ARMORY, skill tree, definições e arena correram 60 frames headless
  sem `SCRIPT ERROR`.

- [x] UI Tier 3 concluído: vida do HUD interpolada, pulso discreto de munição
  baixa e ameaça, skill tree com ligações e cores por ramo, pausa e derrota com
  profundidade em dois níveis, estados mais claros no ARMORY, controlos das
  definições alinhados com o tema e mapa tático com grelha/legenda refinadas.
- O menu principal passou a mostrar o loadout persistente escolhido no ARMORY,
  incluindo a Spear; os ícones das armas receberam maior contraste e suporte
  visual sem alterar compras, saves ou equipamento.
- Foi acrescentada `tools/capture_ui_screen.gd` para regenerar capturas dos nove
  ecrãs. A inspeção final OpenGL confirmou todos os ecrãs sem texto cortado a
  1152 × 648 e 1920 × 1080; o overlay técnico de FPS é ocultado apenas durante
  esta validação.
- Validação Tier 3: importação headless sem erros; main menu, seleção, ARMORY,
  skill tree e definições executados isoladamente; arena executada durante 240
  frames; capturas finais de HUD, pausa, derrota e mapa tático inspecionadas nas
  duas resoluções sem regressões do fluxo funcional.


## M24/M25 — cidade e construção livre

- [x] Setores procedurais enriquecidos com AC de cobertura, drenos, carros
  abandonados e lixo; a colocação usa `sector_seed + 999`, respeita os limites
  de 15 props com colisão e 40 visuais e reserva corretamente veículos rodados.
- [x] POIs gerados passaram a escolher deterministicamente entre fachadas de
  esquadra, hospital e supermercado através de `POIRegistry`, mantendo o piso,
  entrada, marcador e cache de loot existentes.
- [x] Ambiente mundial isolado em cena própria e quatro presets de céu, luz e
  nevoeiro ligados aos níveis de ameaça 0, 5, 10 e 15+.
- [x] Construção livre integrada na arena: catálogo com cinco estruturas,
  grelha de 2 m, reserva em torno do núcleo, snapping, rotação, ghost
  verde/vermelho, custo em Scrap armazenado e bloqueios por upgrades.
- [x] Estruturas colocadas atualizam a navegação, podem receber dano e ser
  reparadas por interação; destruição liberta células e posição, rotação e vida
  ficam persistidas na secção `base_layout` do save.
- [x] Ações `build_mode_toggle`, `build_confirm`, `build_cancel` e
  `build_rotate` adicionadas ao Input Map e ao sistema de keybindings.
- [x] O modo de construção deixou de bloquear o `CharacterBody3D`: o jogador
  pode deslocar-se com o catálogo aberto e mantém movimento completo, salto e
  controlo da câmara durante o preview; armas e interação normal ficam
  desativadas até sair do modo.
- [x] O acampamento instala visuais adicionais ao atingir Resupply Rate nível 2
  e Scavenging nível 1.
- Validação estática concluída em 52 ficheiros e 157 referências de recursos,
  sem caminhos em falta, IDs por resolver ou erros estruturais detetados.
- A cidade/fachadas/props atuais ficam preservados apenas como protótipo. A
  próxima iteração substitui também as estradas e caminhos por um grafo contínuo
  entre setores, conforme `docs/CITY_REBUILD_PLAN.md`.

## CITY_REBUILD_PLAN — fase 1+2 (grafo de debug e continuidade)

- [x] `SectorEdgeContract` calcula os quatro conectores de aresta de cada
  setor (posição, largura, tipo) a partir só da seed global e das
  coordenadas — dois setores vizinhos chegam ao mesmo ponto sem comunicarem
  entre si, canonicalizando pela coordenada menor no eixo partilhado.
- [x] `RoadGraph` guarda o grafo resultante (nós/arestas idempotentes) e
  valida sem dead-ends não intencionais, segmentos demasiado curtos ou
  cruzamentos impossíveis.
- [x] `CityLayoutGenerator` constrói o grafo para as 16 células da grelha,
  desenha um visual de debug (reutilizando a técnica `ImmediateMesh` de
  `build_grid.gd`) e expõe verificações de continuidade nas 24 fronteiras
  internas e de determinismo com seeds repetidas.
- [x] Overlay `CityGraphDebugOverlay` ligado a `test_arena.tscn`, corre ao
  arrancar e reporta falhas via `push_warning`; ferramenta de editor
  `validate_city_graph.gd` (`@tool extends EditorScript`) testa várias seeds
  fixas de uma vez, fora do Play mode.
- Trabalho inteiramente aditivo: não altera `sector_generator.gd`,
  `city_road_grid.tscn` nem `east_sector.tscn`. Falta validação manual no
  editor (sem binário Godot nem suite de testes neste ambiente) e as fases
  3–7 (geometria real, quarteirões/lotes, reintegração de edifícios/POIs/
  props/navegação).

## Decisões pendentes

- resolução inicial;
- layout definitivo de controlos.
- afinação final da Spear como secundária do Medic.
- afinação final dos 30/45 segundos, custo de 30 Scrap, 200 pontos de vida e limites da reparação/construção no modo survival contínuo.
- alcance final do disparo automático entre 2 e 3 metros e permanência do controlo manual.
- aprovação da expansão do protótipo de dois setores para 16 setores e 256 × 256 metros.

## Problemas conhecidos

- Os ataques contínuos reutilizam apenas três composições e escalam a quantidade de Normal Zombies; Brute, Spitter, boss e progressão por variedade ficam para etapas posteriores.
- Os oito caches exteriores são estáticos; o Scrap do armazém e da estação reaparece por ciclo, ainda sem loot aleatório ou inventário.
- A construção livre está funcional e permite movimento durante a colocação, mas custos, alcance, colisões, leitura do ghost e limites da grelha ainda precisam de playtest. A demolição/reembolso já tem comando próprio (`structure_demolish`, tecla X por omissão): fora do modo construção, junto de uma estrutura, devolve 50% do custo em Scrap armazenado.
- O ataque da Worn Sword usa um volume retangular frontal como aproximação de um arco; alcance, dano e apresentação ainda precisam de playtest.
- A Spear do Medic é funcional, mas dano, alcance e cadência ainda precisam de playtest.
- Os modelos CC0 atuais são provisórios; Mixamo e a escolha de arte final continuam pendentes para o Milestone 12.
- A postura agachada usa uma pose fixa retirada da animação `Duck`; necessita de afinação ou de uma animação final adequada.
- A reserva de munições ainda usa um pickup genérico; o do armazém reaparece por ciclo, mas tipos de munição e regras próprias por arma ainda não existem.
- As colisões das paredes permanecem invisíveis como limite de segurança temporário; devem ser substituídas por limites naturais totalmente legíveis depois do playtest do mapa.
- Os quatro POIs têm interiores próprios, mas continuam a usar geometria graybox e loot fixo.
- O medkit do hospital aplica cura imediata fixa até 40 pontos; ainda não existem inventário, transporte de consumíveis ou tipos diferentes de medicamentos.
- As duas caixas do posto militar usam o pickup genérico de munições; ainda não existem tipos separados por arma nem loot aleatório.
- As duas caches da estação usam o pickup genérico de Scrap; ainda não existem recursos de combustível nem uma tabela de loot própria.
- O setor persistente ainda faz parte de `test_arena.tscn`; apenas o setor leste está isolado numa cena própria.
- O setor leste já usa background loading medido (9–15 ms no graybox); falta repetir a medição com setores de geometria real.
- A geração faseada elimina a pausa única, mas cada quadrante de estradas ainda custa ~35–45 ms no seu frame; dividir por peça de estrada ou usar um pool fica para depois de medir em jogo real.
- Os setores gerados têm POIs com fachada temática, entrada e interior simples, mas ainda não têm interiores detalhados; a emboscada é única por partida em vez de reposta por ciclo.
- O estado por setor cobre caches, munições e emboscada; estruturas locais e descoberta de POIs ainda não têm estado.
- Apenas o estado do farol é preservado ao descarregar; loot, encontros, inimigos e estruturas locais ainda não possuem estado de setor.
- O disparo automático pesquisa o grupo `enemy` a cada frame de física e usa provisoriamente 3 metros; desempenho e sensação precisam de playtest com hordas maiores.
- Com a perseguição exclusiva do jogador, a vida do núcleo e as estruturas
  construídas têm utilidade defensiva limitada; o bloqueio de navegação funciona,
  mas o seu papel no combate precisa de playtest e objetivos próprios.
- Ameaças de exploração não contam para a vaga e podem continuar vivas quando o ataque seguinte começa se forem ativadas perto do fim da exploração.
- As hitboxes de corpo e cabeça acompanham a raiz do zombie, mas ainda não seguem ossos individuais durante as animações.
- O flash de dano e os sons sintetizados são provisórios; arte de reação (animações de hit) e áudio final ficam para milestones de arte.
- Ataque melee, salto e movimento já controlam animações provisórias; recarga, dano e morte ainda não possuem animações próprias.
- O mapa tático ainda não possui fog of war, nomes próprios para todos os POIs,
  filtros de marcadores, zoom ou navegação por cursor.
