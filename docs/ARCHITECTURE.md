# Horde Breaker — Arquitetura Técnica

Sincronizado com o código real a 2026-08-01. Godot 4.7 (mono, renderer
Forward+), GDScript tipado, sem C#.

## Princípios

- Construir verticalmente: uma experiência completa antes de expandir.
- Separar dados estáticos (`Resource .tres`) de estado em execução.
- Sinais para eventos importantes; grupos para descoberta de nós.
- Primitivas e CC0 até o gameplay estar fechado; não otimizar prematuramente.

## Autoloads

- `SettingsManager` — definições em `user://horde_breaker_settings.cfg`
  (janela/fullscreen, resolução, VSync, sensibilidade, volume), aplicação por
  corrotina sobre o `Window`.
- `SaveManager` — progresso permanente em `user://horde_breaker_save.cfg`
  (`user://horde_breaker_test.cfg` no editor, semeado por `main_menu.gd`).
- `GameManager` — transições de cena com fade.
- `FpsOverlay` — contador FPS (`F3`) + métricas de streaming (setores carregados,
  ms do último build).

## Sistemas locais (cena da arena)

- `wave_manager.gd` — **diretor de horda contínuo**: threat level sobe a cada
  75 s, spawns em lotes nos 6 pontos mais próximos (≥ 12 m do jogador), pesos por
  tipo, boss a cada 5 níveis, `cycle_completed` a cada 3 níveis. Um orçamento
  global inclui todos os nós do grupo `enemy`: máximo normal de 90, guarda
  absoluta de 120, fila de 12 reservas e instanciação limitada a 2 por frame.
  Emboscadas, POIs e boss respeitam o mesmo teto.
- `world_streamer.gd` — grelha 8 × 8; setores gerados construídos em
  **WorkerThreadPool** e adicionados prontos à árvore; carga a 72 m, descarga a
  96 m; estado por setor em memória (loot, arma, emboscada) + emboscadas
  re-armadas por ciclo; seed do mundo, setores visitados e farol persistidos via
  `SaveManager`.
- `terrain3d_world.gd` — monta nove regiões Terrain3D persistentes para cobrir
  os 512 × 512 m, aplica o shader leve, quatro LODs e colisão dinâmica a 48 m.
  A cena contém também um único plano de água; o mar não altera os recursos de
  altura nem cria uma segunda superfície física.
- `terrain3d_coastline.gd` — deriva 128 segmentos da costa determinística e
  constrói um único `StaticBody3D` persistente 24 m offshore. A parede vai da
  margem inferior do fundo marinho até 8 m acima da água, deixando costa/espuma
  livres sem permitir passar por baixo. A curva original continua a gerar uma
  faixa de espuma animada com uma superfície e um draw call.
- `shipwreck_rocks_prototype.gd` — vertical slice isolado do arquipélago. Monta
  uma região Terrain3D persistente de 256 × 256 m com margem de partida e uma
  micro-ilha, compõe dois cais e dressing CC0 já existente, e mantém o protótipo
  fora da arena, do save e do diretor de horda.
- `automatic_ferry.gd` / `ferry_terminal.gd` — transporte finito entre dois
  pontos. Durante 4,5 s, o passageiro acompanha um ferry low-poly gerado em
  runtime; input e colisão do jogador são repostos no ponto seguro de desembarque.
  Não existe ainda navegação livre nem física naval.
- `IslandData`, `IslandRouteData` e `ArchipelagoData` — Resources que separam a
  topologia do arquipélago da cena 3D: identidade, posição, dificuldade,
  terreno, ligações dirigidas e mecânica de cada rota. `validate_graph()` deteta
  ilhas, destinos ou rotas em falta antes de montar o mapa.
- `destiny_archipelago_prototype.gd` — protótipo isolado de 512 × 512 m e quatro
  regiões Terrain3D. Constrói Dawn Beach, Shadow Forest, High Cliffs e Volcano
  Peak, acompanha descoberta em memória e expõe as rotas A–D sem tocar no save,
  streaming ou diretor de horda da arena principal.
- `dawn_beach_hub.gd`, `dawn_beach_power_cell.gd` e
  `dawn_route_terminal.gd` — vertical slice da ilha inicial. O hub distribui
  três células interativas por Dawn Beach e mantém Shallow Reef e Sea Cave
  bloqueadas até o jogador alimentar e escolher um dos dois terminais. Route A
  usa uma barreira física; Route B reutiliza o estado bloqueado do gate da gruta.
- `archipelago_route_gate.gd` representa a travessia curta da gruta inundada;
  `destructible_route_bridge.gd` fornece uma ponte física com 400 HP;
  `archipelago_graph_map.gd` desenha o grafo dirigido e destaca ilhas visitadas.
  O recife e as ruínas usam `MultiMesh`; só as superfícies atravessáveis recebem
  colisão.
- `sector_generator.gd` — não constrói geometria visível: coloca caches, caixa
  de munições, caixa de arma (~1/3), spawn markers e navegação sobre a altura
  determinística do Terrain3D. Na ilha, rejeita colocações submersas, não gera
  polígonos abaixo da costa e já não cria as antigas paredes quadradas exteriores.
- `normal_zombie.gd` — no mapa principal consulta `Terrain3DWorld` e usa a altura
  dos dados realmente carregados; não repete a fórmula do gerador. Além da
  origem física, mede os ossos `Foot` do rig depois da animação e corrige
  `VisualRoot`, respeitando o orçamento que congela animações distantes.
- `tactical_map.gd` — recorta cada setor pelo polígono costeiro; desenha mar,
  dois anéis de caminho, três ligações e os quatro landmarks sem apresentar os
  cantos marítimos como terreno quadrado.
- `arena_navigation.gd` — grelha de navegação em runtime que exclui células
  ocupadas por `navigation_blocker`. **Decisão:** navmesh de editor não se
  aplica — os setores são gerados em runtime; a grelha é construída na worker
  thread junto com o setor. Rever apenas se a qualidade de navegação se tornar
  um problema de gameplay.
- `camp_economy.gd` — Scrap transportado/armazenado, multiplicadores (skill +
  upgrade), **melhorias da base** (Resupply Rate/Range, Scavenging; 3 níveis,
  custos crescentes), feedback do HUD, progresso de mastery do Scrap.
- `camp_core.gd` — vida/reparação do núcleo, **zona de reabastecimento**
  (raio/cura/munição efetivos = base + bónus de upgrade), spawn dos 3 pedestais
  (`camp_upgrade_station.gd`).
- `defense_tower_site.gd` — 3 torres exteriores opcionais; construção,
  reparação e upgrades com Scrap armazenado, requisitos de nível da run,
  aquisição de inimigos, disparo automático, flashes reutilizáveis de tiro e
  impacto e regeneração da navegação.
- `build_camp_visuals.gd` — gera a camada visual do acampamento e quatro acessos
  exteriores. Estradas e modelos são decorativos; apenas coberturas e marcos
  sólidos recebem colisões simples e entram em `navigation_blocker`.
- `character_progression.gd` — XP por kill/nível/ciclo (multiplicador da skill
  tree), Credits por ciclo, **mastery** (kills, threat level) e feedback de
  mastery completa.
- `pickup_randomizer.gd` — posições de Scrap/munições do acampamento por partida.
- `skill_tree.gd` / `character_skills.gd` — definições da árvore, níveis mínimos
  2/5/9/14/20 por tier e aplicação dos bónus à partida; o `SaveManager` deriva
  um ponto a cada dois níveis e preserva skills de saves antigos.
- `weapon_catalog.gd` — catálogo único dos `WeaponData` jogáveis usado pelo
  `WeaponController` e pelo ecrã `ARMORY`.
- `character_mastery.gd` — definições dos objetivos de mastery (goal, recompensa,
  modo acumular vs. máximo).

## Personagens e inimigos

- `player.tscn` — `CharacterBody3D` (layer 2) com cápsula de colisão separada do
  visual, `VisualRoot` (modelo + `WeaponPivot`), câmara ao ombro
  (`SpringArm3D`), `InteractionArea` (mask 8), mapa tático em CanvasLayer.
  `renegade.tscn`/`medic.tscn` herdam e trocam o modelo (`ClassModel`).
- `player.gd` inclui um noclip apenas para builds de desenvolvimento, acionado
  pela action `toggle_noclip` (`Mouse 4`). Suspende colisão, gravidade, combate,
  interação e targeting; `WASD`/`Space`/`Ctrl`/`Shift` controlam o voo e a saída
  procura chão físico antes de usar a última posição segura.
- `imported_model_animation.gd` — componente único de animação por nomes de
  clips: locomoção (idle/walk/run/crouch/airborne) com postura de arma de fogo e,
  por sinais do corpo:
  `attacked` → `Idle_Attack`, `health_changed` → `HitReact` (cooldown 0,9 s),
  `died` → `Death` (trava a locomoção). Corpos alinhados pela altura Terrain3D
  contam como grounded mesmo sem colisão facetada, evitando a pose airborne.
- `normal_zombie.gd` — base dos inimigos: perseguição por `NavigationAgent3D`
  com repath 0,35 s escalonado; **orçamento de IA**: > 40 m o repath passa a
  1,2 s e o steering (query de caminho) é cacheado e refrescado a 0,3 s; modo
  ranged (Spitter) aproxima/recua/dispara; morte deixa cadáver 2,5 s sem
  colisão/grupos/hitboxes. O alvo é reavaliado a cada 0,75 s entre o jogador e
  torres construídas, evitando uma pesquisa por frame. No mapa Terrain3D, os
  zombies consultam diretamente a altura, alinham os pés animados e deixam a
  colisão facetada apenas ao jogador. `boss_breaker.gd` estende com invocação
  periódica.
- Dano por zonas via `DamageHitbox` (Area3D corpo 1× / cabeça 2×) separado da
  cápsula física.

## Armas e pickups

- `weapon_controller.gd` — loadout permanente 1/2 escolhido no `ARMORY`, troca
  em runtime (`equip_field_weapon`), sinal `active_weapon_changed`.
- `hitscan_weapon.gd` — raycast câmara→ponto + cano→impacto, dano por zonas,
  munição carregador/reserva, recarga, **auto-fire a 6 m** com raycasts
  throttled. O catálogo ativo só aceita as categorias de armas de fogo;
  ficheiros melee legados permanecem fora do catálogo para permitir rollback.
- Pickups (`scrap/ammo/health/weapon`): auto-pickup por corpo (layer 2) para
  Scrap/munições, `F` para medkit/armas; sinais `collected` alimentam o estado
  por setor.

## Layers de física

1 = World · 2 = Player · 3 = Enemy hitboxes · valor 8 (bit 4) = Pickups/interações.

## Grupos-chave

`player`, `enemy`, `enemy_target`, `enemy_spawn_point`, `weapon_controller`,
`wave_manager`, `camp_economy`, `world_streamer`, `camp_core`, `defense_tower`,
`point_of_interest`, `navigation_blocker`, `scrap_pickup`/`ammo_pickup`/
`health_pickup`/`weapon_pickup`, `world_sector`, `poi_interior_point`,
`shoreline_boundary`, `terrain3d_coast_foam`.

## Save (`ConfigFile`)

- `[profile]` — credits, selected_character.
- `[world]` — **seed** (fixo por perfil), **visited_sectors** (Array de
  Vector2i), **east_beacon_activated**.
- `[<classe>]` — unlocked, level, xp, skill_nodes, purchased_weapons,
  selected_primary/secondary_weapon, **mastery_<objetivo>**.
- Ao carregar um save antigo, `SaveManager` remove IDs melee das compras e
  substitui slots inválidos pelos loadouts Recruit AR/Pistol, Renegade
  Shotgun/SMG e Medic Pistol/SMG. Contadores históricos de abates são preservados.

## Dados estáticos

`CharacterData`, `WeaponData` (`data/characters`, `data/weapons`; o catálogo
ativo contém apenas armas de fogo) como `Resource` tipados; `WaveData` legado
(não usado pelo diretor contínuo).

## Validação

Headless: `--import` (parsing), cena N frames (`--quit-after`), scripts
`extends SceneTree` com asserts `TEST:`/`TEST FAIL:`; capturas no renderer
Forward+ com `get_viewport().get_texture()`. Autoloads só estão na árvore após
o primeiro `process_frame` num script `--script`.
