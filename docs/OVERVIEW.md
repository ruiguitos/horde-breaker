# Horde Breaker — Overview Completo do Projeto

Ficheiro-mestre único e **ponto de entrada para qualquer sessão nova** (substitui
o antigo HANDOFF): o que é o jogo, como está organizado, o que está feito e o que
falta. Última atualização: 2026-07-30. Detalhe histórico em `PROGRESS.md`;
**o que falta fazer em `PLANO-DE-TRABALHO.md`**; o mapa em `MAP_DESIGN.md`.

---

## 0. ESTADO ATUAL (2026-07-30) — LER PRIMEIRO

Suite: **13 ficheiros em `tests/`, 383 verificações, todas a passar** (~20 s).
A arena corre 400 frames em headless **sem um único erro ou aviso**. Correr
sempre antes de commitar.

### Mudanças de fundo desta fase

| Área | Antes | Agora |
|---|---|---|
| **Renderer** | GL Compatibility | **Forward+** — 140 inimigos a **127–134 FPS** |
| **Mundo** | 4×4 (256 m), chão por setor | **8×8 (512 m)** sobre **solo único** |
| **Mapa** | gerado por código | **pintado à mão**, 3 camadas GridMap (célula 8×4×8 m) |
| **Colocação de peças** | célula a célula, às cegas | **mapa de ocupação global** — 0 sobreposições |
| **POIs** | graybox de caixas | **compostos pintados** + gatilho, 6 no mundo |
| **Atmosfera** | só nevoeiro de profundidade | **SSAO + nevoeiro volumétrico** que engrossa com a ameaça |
| **Conteúdo do setor** | sempre disperso | disperso **ou autorado** (`SectorData.tres`) |
| **Field upgrades** | 10 cartas planas | **11 com raridade e níveis**, painel com 10 s |
| **Arranque** | horda completa aos 20 s | **primeira vaga aos 45 s**, ritmo normal ao nível 5 |
| **Assets** | Quaternius + Downtown | **+448 modelos CC0** (Kenney ×6, KayKit, Quaternius) |
| **Classes** | 3 | **2** (Medic parqueado via `is_selectable`) |
| **Skill tree** | 3 colunas × 5 nós | **3 árvores bifurcadas, 36 nós** |
| **Acampamento** | ao centro (0,0) | **descentrado em (-1,-1)** |

### ⚠️ O QUE FALTA — por ordem

As etapas de código do `PLANO-DE-TRABALHO.md` estão **todas fechadas**. O que
sobra precisa de *jogo*, não de mais código:

1. **Playtest do mapa novo.** A densidade foi reposta em números novos
   (0,4 / 0,65 / 0,55) porque a correção das sobreposições cortava um terço dos
   edifícios. São 1034 peças, nenhuma dentro de outra — mas ninguém as viu.
2. **Balanceamento** (M22): dano/cadência/regen das 2 classes e das variantes,
   curva do diretor de horda. `HARD_ENEMY_CAP` = 140 já não é o constrangimento.
3. **Afinar os 64 setores à mão** no editor, e autorar os que valerem a pena com
   `tools/new_sector_data.gd` (ver secção 4).
4. **M25 — base de volta** como estruturas pintadas (feature grande, pedida).

**Por esclarecer com o utilizador:** "melhorar o menu principal" — é o aspeto,
a estrutura, ou a sensação de arranque? Sem alvo, não começar.

### Armadilhas conhecidas (custaram tempo)

- **`class_name` novo não existe até reimportar.** Um `SectorData` acabado de
  criar faz `world_streamer.gd` falhar a compilar com *"Could not find type"*,
  e o jogo arranca com metade dos sistemas mortos. Correr
  `--headless --path . --import` depois de criar qualquer `class_name`.
- **Um teste sem guarda de saída pendura-se para sempre.** Foi isto — e não o
  mundo 8×8 — que fez uma validação exceder os 600 s. Todo o script `--script`
  precisa de `quit()` em **todos** os caminhos, incluindo os de erro.
- **As malhas Kenney não estão centradas na origem.** `ind_building_h` mede
  7,9 m e estende-se 5,6 m para um dos lados de uma célula de 8 m. Medir pelo
  *alcance a partir da origem* (`AABB.position`), nunca só pelo tamanho.
- **`preload` de scripts que usam autoloads** (`world_streamer`, `tactical_map`)
  a partir de uma ferramenta `--script` compila antes de os autoloads existirem
  e deixa o script partido para quem o carregar a seguir. Usar `load()` em
  runtime. Mordeu três vezes.
- **Ferramentas que reempacotam a arena** já perderam o script do
  `world_streamer` uma vez. `tests/test_arena_wiring.gd` existe para apanhar
  nós presentes mas sem script — correr sempre depois de mexer na cena.
- **A posição do acampamento vive em três ficheiros** que têm de concordar:
  `world_streamer.CAMP_COORDS`, `tools/place_camp.CAMP_COORDS`,
  `tools/paint_world.CENTRE`.
- **Escrever `.tscn`/`.tres` com PowerShell** exige UTF-8 **sem BOM**, senão o
  Godot recusa o ficheiro. As ferramentas em `tools/` escrevem-nos por código
  precisamente para não passar por aí.

### Repositório (ação do utilizador)

`.git` está em **108 MB**; o histórico já foi reescrito mas só encolhe (~23 MB)
depois de `git push --force-with-lease origin master`, seguido de
`git remote prune origin && git reflog expire --expire=now --all && git gc --prune=now`.
A pasta `.godot/` é cache regenerável.

---

## 1. O que é

Horde shooter 3D em **terceira pessoa**, single-player, Windows, feito em
**Godot 4.7 (mono, renderer Forward+)**, GDScript tipado, **sem C#**.

O jogador explora um **mundo aberto** (grelha 8×8 de setores, 512×512 m, sobre um
solo contínuo) enquanto uma **horda contínua** nasce à volta e escala com o tempo.
O acampamento é o porto seguro e a zona de extração. Texto do jogo em **inglês**; documentação
em **português**.

> O acampamento está no setor (-1,-1), descentrado de propósito: ao centro todas
> as runs teriam a mesma forma. A zona de extração é o núcleo do campo.

**Direção atual:** *survivors-like no combate* (inspiração Yet Another Zombie
Survivors) sobre um mundo aberto — cartas de upgrade por nível de run, orbes de
XP e auto-fire; a exploração, POIs e base continuam a ser o diferenciador.

**Core loop:** explorar → combater a horda → recolher Scrap/munições/armas →
reabastecer e melhorar a base → subir de nível e desbloquear skills/mastery →
aguentar níveis de ameaça mais altos → morrer → recomeçar com progressão
permanente. Não há rondas nem vitória formal; a partida acaba com a morte do
jogador.

---

## 2. Como correr e testar

Executável Godot:
`C:\Users\Rui\Downloads\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64_console.exe`

- **Cena principal do jogo:** `scenes/menus/main_menu.tscn`
- **Arena de jogo:** `scenes/world/test_arena.tscn`
- **Arranque:** janela 1152×648 (baixo para testes). `F3` = FPS+métricas, `Tab` = mapa.

Validação headless (padrão do projeto):
```
<godot> --headless --path . --import                          # parsing + regista class_name novos
<godot> --headless --path . <cena.tscn> --quit-after N        # procurar SCRIPT ERROR
<godot> --headless --path . --script res://teste.gd           # extends SceneTree, prints TEST:/TEST FAIL:
<godot> --path . --script res://tests/bench_horde.gd -- 140    # FPS com horda (precisa de janela)
<godot> --headless --path . --script res://tests/bench_arena_startup.gd
<godot> --path . --rendering-driver opengl3 --script ...      # capturas OpenGL (get_viewport().get_texture())
```
Nota: autoloads só entram na árvore após o 1º `process_frame` num script `--script`.

**Arranque medido (2026-07-30, 8×8):** 1,42 s até jogável — 486 ms de arranque do
motor, **588 ms a fazer parse do `.tscn` da arena** (o item dominante), 8 ms a
instanciar, 53 ms de `_ready`, 289 ms até o streaming assentar em 4 setores. O
bake de navegação corre em worker threads, ~50 ms por setor, fora do frame.
**Não** baixar `load_distance` para 48: os setores estão a 64 m e os 72 m
existem para os apanhar a tempo.

Save: `user://horde_breaker_save.cfg` (export) / `horde_breaker_test.cfg` (editor).
Definições: `user://horde_breaker_settings.cfg`. No Windows: `%APPDATA%/Godot/app_userdata/Horde Breaker/`.

---

## 3. Estrutura de pastas

```
autoload/         Autoloads (singletons): settings, save, game manager, fps overlay
data/
  characters/     recruit/renegade/medic .tres (CharacterData)
  weapons/        assault_rifle, pistol, shotgun, smg, worn_sword, spear, fire_axe (WeaponData)
  waves/          WaveData legado (não usado pelo diretor contínuo)
  sectors/        SectorData por setor, à mão — criado por tools/new_sector_data.gd
                  (não existe até se autorar o primeiro; sem ficheiro = disperso)
scenes/
  characters/     player, renegade, medic + mixamo_recruit (parqueado)
  enemies/        normal/runner/brute/spitter/boss + spit_projectile
  menus/          main_menu, character_selection, armory_screen, settings, skill_tree
  pickups/        scrap/ammo/health/weapon
  ui/             hud, tactical_map, damage_number, painéis
  weapons/        cenas das 7 armas (lógica + malhas invisíveis; visual = embutido no rig)
  world/          test_arena (o mapa vive nas 3 camadas de GridMap desta cena)
                  camp_sector, poi_warehouse/military_outpost/fuel_station
                  exploration_pois.tscn = graybox antigo, já não usado
scripts/
  characters/     player, third_person_camera, imported_model_animation
  enemies/        normal_zombie (base), boss_breaker, damage_hitbox, spit_projectile
  weapons/        weapon_controller, hitscan_weapon, melee_weapon
  systems/        (ver secção 4 — o coração do jogo)
  ui/             ecrãs e helpers (armory, selection, hud, mapa, animações)
  pickups/        scrap/ammo/health/weapon
  data/           CharacterData, WeaponData, WaveData, SectorData (Resources tipados)
  dev/            ferramentas de desenvolvimento
assets/
  fonts/          Rajdhani (OFL) — tipografia da UI
  icons/          retratos das classes + ícones das armas (gerados de modelos)
  models/
    quaternius_zombie_apocalypse/  personagens, inimigos, armas embutidas, props
    kenney_city_commercial/        Kenney City Kit Commercial (CC0)
    kenney_city_industrial/        Kenney City Kit Industrial (CC0)
    kenney_factory_kit/            Kenney Factory Kit (CC0)
    kenney_graveyard_kit/          Kenney Graveyard Kit (CC0)
    kenney_car_kit/                Kenney Car Kit (CC0)
    kenney_mini_forest/            Kenney Mini Forest (CC0)
    kenney_skyboxes/               5 panoramas 4096x2048 (CC0)
    kaykit_city_bits/              KayKit City Builder Bits (CC0)
    city_test_model/               Quaternius Downtown MegaKit (CC0)
    mixamo/                        PARQUEADO (não usado)
  shaders/, themes/  tema partilhado da UI e shaders procedurais
tools/            generate_ui_icons.gd     regenera ícones/retratos
                  build_tile_library.gd    packs -> map_tiles_pack.meshlib (+ mede módulos)
                  paint_world.gd           pinta todos os setores (roads -> estruturas -> props)
                  place_camp.gd            põe o acampamento na arena
                  build_poi_scenes.gd      reconstrói as 3 cenas de POI
                  place_pois.gd            põe os POIs na arena, nos pátios pintados
                  new_sector_data.gd       cria um SectorData para um setor
                  apply_skyboxes.gd        céus + SSAO + nevoeiro volumétrico nos presets
                  capture_ui_screen.gd     capturas
tests/            13 scripts headless (extends SceneTree, prints TEST:/TEST FAIL:)
                  + bench_horde.gd e bench_arena_startup.gd (medição, não passa/falha)
docs/             este overview + GDD, ARCHITECTURE, ROADMAP, PROGRESS, TODO, INSPIRATIONS
prompts/          prompts para agentes
```

Números atuais: 80 scripts `.gd`, 64 cenas `.tscn`, 30 `.tres` de dados, 13 testes.

**Ordem de reconstrução do mundo** (correr sempre por esta ordem — o `place_pois`
lê de `paint_world` onde ficaram os pátios):
```
<godot> --headless --path . --script res://tools/paint_world.gd
<godot> --headless --path . --script res://tools/build_poi_scenes.gd
<godot> --headless --path . --script res://tools/place_pois.gd
```

---

## 4. Sistemas principais (`scripts/systems/`)

| Sistema | Função |
|---|---|
| `wave_manager.gd` | **Diretor de horda contínuo**: threat level sobe **por tempo** (75 s/nível), spawns em lotes nos 6 pontos mais próximos (≥12 m), pesos por tipo, boss a cada 5 níveis, `cycle_completed` a cada 3. |
| `world_streamer.gd` | Grelha 8×8 (512 m); setores gerados em **worker threads**; carga 72 m / descarga 96 m; estado por setor; seed e setores visitados persistidos no save. |
| `sector_generator.gd` | **Só conteúdo, nunca geometria**: caches, munições, caixa de arma (~⅓), marcadores de spawn, paredes de limite e o bake de navegação. Coloca **sobre** o mapa pintado — recebe os obstáculos do GridMap e nunca larga loot dentro de paredes. Um `SectorData.tres` substitui a dispersão, lista a lista. |
| `gridmap_obstacles.gd` | Converte células pintadas do GridMap na lista de obstáculos que a navegação usa; lê as **formas por peça**, por isso o armazém fica praticável por dentro. |
| `arena_navigation.gd` | Grelha de navegação em runtime que exclui `navigation_blocker`. Decisão: navmesh de editor não se aplica (setores gerados em runtime). |
| `camp_economy.gd` | Scrap transportado/armazenado, multiplicadores, **melhorias da base** (Resupply Rate/Range, Scavenging), progresso de mastery de Scrap. |
| `camp_core.gd` / `camp_upgrade_station.gd` | Núcleo, **zona de reabastecimento** (raio/valores crescem com upgrades), 3 pedestais de upgrade. |
| `fortification_site.gd` | 3 pontos de barricada construíveis/reparáveis. |
| `character_progression.gd` | XP por kill/nível/ciclo, Credits por ciclo, **mastery** (kills/threat). |
| `skill_tree.gd` / `character_skills.gd` | Árvore permanente (3 ramos × 5 tiers, níveis mín. 2/5/9/14/20) e aplicação dos bónus. |
| `character_mastery.gd` | Objetivos de mastery (EXTERMINATOR/STORM RIDER/SCAVENGER). |
| `character_variants.gd` | **Variantes de classe** (capstone da mastery): VETERAN/BERSERKER/COMBAT MEDIC. |
| `weapon_catalog.gd` | Catálogo único das armas jogáveis (usado pelo controller e pelo ARMORY). |
| `*_encounter.gd`, `pickup_randomizer.gd`, `hit_sound_library.gd` | Encontros dos POIs à mão, randomização de loot do acampamento, sons sintetizados. |

**Layers de física:** 1=World · 2=Player · 3=Enemy hitboxes · bit 4 (valor 8)=Pickups/interações.
**Save (`ConfigFile`):** `[profile]` credits/selected · `[world]` seed/visited_sectors/east_beacon · `[<classe>]` unlocked/level/xp/skill_nodes/purchased_weapons/selected slots/mastery_*/variant_active · `[input]` keybindings.

---

## 5. O QUE ESTÁ FEITO ✅

### Combate & Inimigos
- Hitscan com dano por zonas (corpo 1× / cabeça 2×), auto-fire por proximidade
  **por arma** (AR 6 / Pistol 5,5 / Shotgun 4,5 / SMG 7 m) + disparo manual, melee.
- 5 inimigos por função: Normal, Runner, Brute (knockback), Spitter (à distância), Boss.
- **Animações completas** dos inimigos: ataque (`Idle_Attack`), dano (`HitReact`),
  morte (`Death` + cadáver sem colisão). **Drop de Scrap** ao morrer (por tipo).
- Diretor de horda contínuo com escalada temporal; **orçamento de IA** a >40 m.
- Feedback: números de dano, flash, sons, hit-marker, knockback ao jogador.

### Classes, Armas & Progressão
- 2 classes jogáveis (Recruit/Renegade); Medic parqueado via `is_selectable`.
- **13 armas** em 5 categorias (ASSAULT/SIDEARM/CLOSE RANGE/HEAVY/MELEE): AR,
  Pistol, Shotgun, SMG, **Machine Gun** (−15% velocidade), Worn Sword, Spear,
  Fire Axe, + 5 evoluções (Storm Rifle, Siege Breaker, Hornet, Cleaver,
  **Minigun**). Visuais são **malhas embutidas nos rigs** (decisão firme).
- **ARMORY:** comprar com Credits (nível+custo), slots 1/2 persistentes, agrupado
  por categoria. Evoluções **não aparecem à venda** antes de ganhas por abates.
- **Skill tree** permanente: 3 árvores com bifurcação, **36 nós** em 7 tiers;
  desbloqueio por clique com confirmação. **Mastery** (3 objetivos → variante).
- **Variantes de classe** desbloqueadas ao completar a mastery.
- Munição do chão **escala com o nível de ameaça**.

### Survivors-like (M26 Fase 1)
- **Cartas de upgrade** por nível de run (3 de 11, só duram a run) com painel próprio.
- **Raridade e níveis** (2026-07-30): cada carta tem uma raridade fixa —
  BRONZE / SILVER / GOLD / EPIC / LEGENDARY — que decide quanto aparece e quanto
  vale um nível. Apanhar a mesma carta sobe-lhe o nível até ao máximo (5, ou 3
  nas mais fortes); ao máximo deixa de ser oferecida, para o baralho continuar a
  rodar. A raridade tem cor própria e lê-se igual no painel e na pausa.
- **VAMPIRIC ROUNDS** (legendary, máx. 3): cada abate devolve 2% da vida máxima
  por nível. É a única carta que muda como se joga em vez de quanto os números
  sobem — com ela, entrar na horda cura.
- **10 segundos e escolhe sozinho**: o painel tem barra e contagem; ao fim do
  tempo escolhe uma das três ao acaso. Uma subida de nível é uma decisão sob
  pressão, e uma run não pode ficar parada porque o jogador se levantou.
- **Orbes de XP** largadas por todos os inimigos, com íman até ao jogador.
- **Barra de XP + `LV n`** no HUD; auto-fire alargado e câmara recuada; auto-reload
  assim que o carregador esvazia.
- **Arranque mais lento** (2026-07-30): primeira vaga aos 45 s (era 20), nível 1
  dura 110 s e a duração desce até aos 75 s habituais ao nível 5, horda inicial
  de 20 em vez de 32, spawns de 6 s a descer para os mesmos 2,75 s ao nível 5.
  **Só o início muda** — do nível 5 em diante o ritmo é exatamente o anterior, e
  a munição do chão acompanha por já escalar com o nível de ameaça.

### Mundo aberto — ver `MAP_DESIGN.md`
- **8×8 setores (512 m)** sobre um **solo único**, streaming em worker threads.
- **Mapa autorado à mão** em 3 camadas de GridMap (`MapRoads`, `MapStructures`,
  `MapProps`), célula 8×4×8 m, a partir de **448 peças CC0** medidas e escaladas
  (os packs Kenney/KayKit vêm em miniatura e são ampliados ×1,8 a ×6).
- **Peças nunca se atravessam** (2026-07-30): o pintor mantém um mapa de ocupação
  do mundo inteiro, semeado com as ruas e passeios antes de construir seja o que
  for, e reserva as células que cada peça realmente ocupa — medidas pelo alcance
  a partir da origem da malha, não pela largura. 1034 estruturas, **0
  sobreposições** (eram 16 francas e muitas parciais).
- **Navegação lê as peças pintadas** (`gridmap_obstacles.gd`), pelas formas de
  cada peça — o armazém continua praticável por dentro.
- Gerador de setor reduzido a **conteúdo**: caches, munições, arma, spawns —
  colocados **fora** das paredes pintadas e nunca uns por cima dos outros.
- **Conteúdo autorável por setor**: `data/sectors/sector_<x>_<y>.tres`
  (`SectorData`) substitui a dispersão, **lista a lista** — autorar só os spawns
  deixa o loot disperso. Criar com `tools/new_sector_data.gd -- <x> <y>`.
- **6 pontos de interesse** pintados como compostos à volta de um pátio aberto de
  24 m (2 armazéns, 2 postos militares, 2 depósitos de combustível). A cena de
  cada um leva só o gatilho `Area3D`, os marcadores e uma **cache de 50 Scrap**;
  as paredes são peças pintadas. Aparecem no mapa tático.
- **Atmosfera Forward+**: SSAO e nevoeiro volumétrico nos 4 presets, com a
  densidade a subir 0,008 → 0,042 com o nível de ameaça — o mapa fecha-se à volta
  do jogador à medida que a run aperta.
- Seed **fixo por perfil**, setores visitados persistidos no save.
- **Céu por nível de ameaça** (5 panoramas Kenney nos presets de atmosfera).

### Acampamento — de volta em (-1,-1), desde 2026-07-27
Foi removido a 2026-07-26 com o graybox e reposto no dia seguinte, empacotado em
`scenes/world/camp_sector.tscn`: núcleo, 3 estações de upgrade, 3 pontos de
fortificação e a grelha de construção. Fica **descentrado de propósito** — ao
centro todas as runs teriam a mesma forma. A extração é o núcleo do campo, não a
origem do mundo.

### UI / UX (facelift completo — Tier 1/2/3)
- Menu principal com fundo 3D, seleção de classes com modelo 3D + mastery + variante,
  ARMORY, skill tree (ligações/cores), pausa/derrota com blur, HUD polido.
- **Upgrades da pausa em colunas** (2026-07-30): duas colunas de seis mostram o
  loadout inteiro com nível e cor da raridade. A lista única tinha de ser cortada
  com um "+N more" que escondia exatamente o que se abre a pausa para ver.
- Tipografia **Rajdhani**, ícones gerados dos modelos, som de UI, animações/juice.
- **Definições em separadores** Display/Controls/Audio com **keybindings rebindable**
  (captura, swap de conflito, reset, persistência no save).

### Técnico
- Save robusto com migrações, definições persistidas, overlay F3 com métricas de
  streaming, testes headless sistemáticos, docs sincronizados.

---

## 6. O QUE FALTA ❌ (por milestone)

### M27 — Mapa autorado (código fechado a 2026-07-30)
- [x] **Catalogar as inconsistências** vistas no playtest de 2026-07-26 — eram
      duas: loot e spawns dentro de paredes (o gerador não via o GridMap) e
      edifícios a atravessarem-se (6 peças maiores que a célula, e as malhas
      industriais Kenney descentradas por cima disso). Ambas corrigidas e cobertas
      por `test_sector_content.gd` e `test_painted_map.gd`.
- [x] **Atmosfera Forward+**: SSAO e nevoeiro volumétrico ligados nos 4 presets.
      **SSIL medido e deixado desligado** — custava ~1,6 ms por frame (127/127/134
      FPS sem, 107/105/108 com) por luz indirecta que o nevoeiro esconde.
- [x] **Spawns colocados à mão**: `SectorData.tres` por setor, com fallback
      procedural lista a lista.
- [x] POIs pintados a repor os 50 de Scrap e o encontro por ciclo.
- [x] Investigar o **arranque lento da arena em headless** — não existe. São
      1,42 s até jogável; os 600 s eram um teste que não saía.
- [ ] **Afinar densidade e composição dos 64 setores** à mão no editor
      (precisa de jogo, não de código).
- [ ] Coerência visual: Kenney e Quaternius têm estilos diferentes — usar por
      zona, não intercalar.

### M22 — Balanceamento (precisa de PLAYTEST teu)
- [ ] Rever dano/cadência/regen das 2 classes **e das variantes** após jogar.
- [ ] Afinar a curva do diretor de horda (intervalo 75 s, lotes, limite simultâneo).
      `HARD_ENEMY_CAP` = 140 **já não é o constrangimento** com Forward+.
- [ ] Decidir se o disparo manual permanece.

### M25 — Base de volta (feature grande, pedida)
- [ ] Repor reabastecimento, depósito de Scrap e upgrades como estruturas
      pintadas (o código continua todo no repositório).
- [ ] Modo de construção (grelha, preview fantasma, gasta Scrap).
- [ ] Persistência do layout da base no save.
- [ ] **Base evolui visualmente** conforme os upgrades comprados.

### M23 — Polimento e conteúdo extra (backlog)
- [ ] Mais objetivos de mastery e recompensas.
- [ ] Save de partida a meio (continuar uma run).
- [ ] Modificadores de arena (mutators) — variedade entre partidas (inspiração RoR2).
- [ ] Evolução de armas por condições (inspiração YAZS).
- [ ] Labels 3D `[F]` a mostrar a tecla real (após rebind).
- [ ] Fundir marcadores coincidentes no mapa tático.
- [ ] **`ESC` no menu de definições** (já funciona nos outros ecrãs).

### Bloqueado (precisa de ti / assets)
- Novos packs de arte = **download teu**; Mixamo **parqueado** (Quaternius cobre tudo);
  armas com modelo externo só com `BoneAttachment3D`.

---

## 7. Decisões e restrições que NÃO se revertem

1. **Armas visíveis = malhas embutidas nos rigs Quaternius** (nunca ancorar ao
   `WeaponPivot` estático; pack de armas externo foi testado e revertido).
2. **Mixamo parqueado** (`assets/models/mixamo/` existe mas não se usa).
3. **Navegação = grelha runtime** (`arena_navigation.gd`); não migrar para navmesh
   de editor. As peças de GridMap entram nessa grelha via `gridmap_obstacles.gd`.
4. **Inimigos perseguem só o jogador**; nada mais é alvo nem condição de derrota.
5. **Loot renova a cada partida**; persiste no save: seed, setores visitados,
   progressão e compras.
6. **Mapa autorado, não gerado**: o `sector_generator.gd` coloca só conteúdo.
   Não voltar a pôr geometria procedural — colide com o que está pintado.
7. **Renderer Forward+**: a mudança deu 8,7× de desempenho. Reverter para GL
   Compatibility traz de volta o problema de FPS com hordas grandes.
8. **O pintor decide onde cabe uma peça, não a grelha**: `tools/paint_world.gd`
   mede cada peça pelo alcance a partir da origem da malha e reserva as células
   que ela ocupa mesmo. Colocar às cegas célula a célula foi o que pôs edifícios
   dentro uns dos outros durante toda a fase anterior.
9. **POIs são pintados, não construídos**: as cenas em `scenes/world/poi_*.tscn`
   não têm geometria nenhuma — só gatilho, marcadores e recompensa. O graybox
   antigo (`exploration_pois.tscn`) fica no repositório mas está morto.
10. **SSIL fica desligado** até alguém voltar a medir (`ENABLE_SSIL` em
    `tools/apply_skyboxes.gd`). Não voltar a ligá-lo "porque agora dá".
11. Não descarregar assets externos sem autorização; comunicação em PT-PT, código
    em inglês.

---

## 8. Assets & licenças

- **Quaternius Zombie Apocalypse Kit** (CC0) — personagens, inimigos, armas embutidas, props.
- **Quaternius Downtown City MegaKit** (CC0, versão FREE) — edifícios e estradas
  (`city_test_model`, só glTF; ~91 MB após remover formatos redundantes).
- **Rajdhani** (SIL OFL 1.1) — fonte da UI.
- Sons sintetizados em runtime (sem ficheiros de áudio externos).

---

## 9. Referências de design (`INSPIRATIONS.md`)

WWZ Aftermath (pressão de horda, classes), Killing Floor 2 (perks numéricos, boss),
**Deep Rock Galactic: Survivor** (o nosso espelho: progressão dupla, desbloqueios por
nível, mastery→variante), Risk of Rain 2 (escalada temporal, mutators), Yet Another
Zombie Survivors (auto-fire, mastery, evolução de armas). **5 dos 6 passos sugeridos
já cumpridos**; défices face às referências: variedade entre partidas (mutators) e
arsenal por classe (parcialmente resolvido pelo ARMORY).
