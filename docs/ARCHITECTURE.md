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
  tipo, boss a cada 5 níveis, `cycle_completed` a cada 3 níveis.
- `world_streamer.gd` — grelha 8 × 8; setores gerados construídos em
  **WorkerThreadPool** e adicionados prontos à árvore; carga a 72 m, descarga a
  96 m; estado por setor em memória (loot, arma, emboscada) + emboscadas
  re-armadas por ciclo; seed do mundo, setores visitados e farol persistidos via
  `SaveManager`.
- `terrain3d_world.gd` — monta nove regiões Terrain3D persistentes para cobrir
  os 512 × 512 m, aplica o shader leve, quatro LODs e colisão dinâmica a 48 m.
  A cena contém também um único plano de água; o mar não altera os recursos de
  altura nem cria uma segunda superfície física.
- `sector_generator.gd` — não constrói geometria visível: coloca caches, caixa
  de munições, caixa de arma (~1/3), spawn markers, limites e navegação sobre a
  altura determinística do Terrain3D. Na ilha, rejeita colocações submersas e
  não gera polígonos de navegação abaixo da linha costeira.
- `normal_zombie.gd` — no mapa principal consulta `Terrain3DWorld` e usa a altura
  dos dados realmente carregados; não repete a fórmula do gerador. Isto permite
  esculpir ou importar um heightmap sem fazer os inimigos flutuar.
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
- `imported_model_animation.gd` — componente único de animação por nomes de
  clips: locomoção (idle/walk/run/crouch/airborne) conforme o estado do corpo e
  a arma ativa (gun vs melee), `Slash`/`Stab` no melee, e por sinais do corpo:
  `attacked` → `Idle_Attack`, `health_changed` → `HitReact` (cooldown 0,9 s),
  `died` → `Death` (trava a locomoção).
- `normal_zombie.gd` — base dos inimigos: perseguição por `NavigationAgent3D`
  com repath 0,35 s escalonado; **orçamento de IA**: > 40 m o repath passa a
  1,2 s e o steering (query de caminho) é cacheado e refrescado a 0,3 s; modo
  ranged (Spitter) aproxima/recua/dispara; morte deixa cadáver 2,5 s sem
  colisão/grupos/hitboxes. O alvo é reavaliado a cada 0,75 s entre o jogador e
  torres construídas, evitando uma pesquisa por frame. No mapa Terrain3D, os
  zombies consultam diretamente a altura e deixam a colisão facetada apenas ao
  jogador. `boss_breaker.gd` estende com invocação periódica.
- Dano por zonas via `DamageHitbox` (Area3D corpo 1× / cabeça 2×) separado da
  cápsula física.

## Armas e pickups

- `weapon_controller.gd` — loadout permanente 1/2 escolhido no `ARMORY`, troca
  em runtime (`equip_field_weapon`), sinal `active_weapon_changed`.
- `hitscan_weapon.gd` — raycast câmara→ponto + cano→impacto, dano por zonas,
  munição carregador/reserva, recarga, **auto-fire a 6 m** com raycasts
  throttled; `melee_weapon.gd` — golpe frontal em área.
- Pickups (`scrap/ammo/health/weapon`): auto-pickup por corpo (layer 2) para
  Scrap/munições, `F` para medkit/armas; sinais `collected` alimentam o estado
  por setor.

## Layers de física

1 = World · 2 = Player · 3 = Enemy hitboxes · valor 8 (bit 4) = Pickups/interações.

## Grupos-chave

`player`, `enemy`, `enemy_target`, `enemy_spawn_point`, `weapon_controller`,
`wave_manager`, `camp_economy`, `world_streamer`, `camp_core`, `defense_tower`,
`point_of_interest`, `navigation_blocker`, `scrap_pickup`/`ammo_pickup`/
`health_pickup`/`weapon_pickup`, `world_sector`, `poi_interior_point`.

## Save (`ConfigFile`)

- `[profile]` — credits, selected_character.
- `[world]` — **seed** (fixo por perfil), **visited_sectors** (Array de
  Vector2i), **east_beacon_activated**.
- `[<classe>]` — unlocked, level, xp, skill_nodes, purchased_weapons,
  selected_primary/secondary_weapon, **mastery_<objetivo>**.

## Dados estáticos

`CharacterData`, `WeaponData` (`data/characters`, `data/weapons`, incluindo a
Spear do Medic) como
`Resource` tipados; `WaveData` legado (não usado pelo diretor contínuo).

## Validação

Headless: `--import` (parsing), cena N frames (`--quit-after`), scripts
`extends SceneTree` com asserts `TEST:`/`TEST FAIL:`; capturas OpenGL com
`--rendering-driver opengl3` + `get_viewport().get_texture()`. Autoloads só
estão na árvore após o primeiro `process_frame` num script `--script`.
