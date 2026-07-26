# Horde Breaker — Overview Completo do Projeto

Ficheiro-mestre único e **ponto de entrada para qualquer sessão nova** (substitui
o antigo HANDOFF): o que é o jogo, como está organizado, o que está feito e o que
falta. Última atualização: 2026-07-26. Detalhe histórico em `PROGRESS.md`;
plano por milestone em `ROADMAP.md`; o mapa novo em `MAP_DESIGN.md`.

---

## 0. ESTADO ATUAL (2026-07-26) — LER PRIMEIRO

Árvore limpa, nada por commitar.

### O que mudou de fundo

| Área | Antes | Agora |
|---|---|---|
| **Renderer** | GL Compatibility | **Forward+** — 140 inimigos: 16,5 → **143,9 FPS** |
| **Mundo** | 4×4 setores (256 m), chão por setor | **8×8 setores (512 m)** sobre **solo único** |
| **Mapa** | gerado por código | **pintado à mão** em 3 camadas de GridMap |
| **Gerador de setor** | 894 linhas, construía geometria | **339 linhas**, só conteúdo |
| **Assets** | Quaternius + Downtown | **+448 modelos CC0** (Kenney, KayKit, Quaternius) |
| **Classes** | 3 | **2** (Medic parqueado, recuperável) |
| **Skill tree** | 3 colunas × 5 nós | **3 árvores com bifurcação, 36 nós** |

### Removido a pedido do utilizador

O **acampamento** (núcleo, construção, fortificações), o **beacon** e o setor
este feito à mão, os **grayboxes** (paredes, obstáculos, POIs) e o `CampBuilder`.

Consequência a ter presente: a **zona de extração passou a ser a origem (0,0,0)**,
porque `run_objective` procura o núcleo do campo e, não o encontrando, usa o
centro. As 5 fases continuam a funcionar, mas **não há reabastecimento nem
depósito de Scrap** até a base voltar como estruturas pintadas.

### ⚠️ Por confirmar

- **A suite completa não correu até ao fim** desde o mundo passar a 8×8.
  Confirmados: `test_arena_wiring` 9/9, `test_world_ground` 9/9, arena sem erros.
- **Arranque da arena em headless ficou lento** com 8×8 — fez a validação
  exceder o tempo. Pode ser só volume de células, pode ser algo que não fecha.
- **Inconsistências no mapa** notadas em playtest, ainda por catalogar
  (`MAP_DESIGN.md` secção 8).

### Backlog pedido e ainda não feito

1. **`ESC` no menu de definições** (já funciona na seleção, armory e skill tree).
2. **Base funcional de volta** — reabastecimento, depósito de Scrap, upgrades,
   agora como estruturas pintadas.
3. **Atmosfera Forward+** — nevoeiro volumétrico, SSAO e SSIL passaram a estar
   disponíveis e continuam por configurar.
4. **Spawns em `Marker3D`** colocados à mão (atrás de coberturas, becos).
5. **Afinar os 64 setores** e resolver as inconsistências do playtest.

---

## 1. O que é

Horde shooter 3D em **terceira pessoa**, single-player, Windows, feito em
**Godot 4.7 (mono, renderer Forward+)**, GDScript tipado, **sem C#**.

O jogador explora um **mundo aberto** (grelha 8×8 de setores, 512×512 m, sobre um
solo contínuo) enquanto uma **horda contínua** nasce à volta e escala com o tempo.
O centro do mapa é a zona de extração. Texto do jogo em **inglês**; documentação
em **português**.

> O acampamento foi removido em 2026-07-26; volta como estruturas pintadas.

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
<godot> --headless --path . --import                          # parsing
<godot> --headless --path . <cena.tscn> --quit-after N        # procurar SCRIPT ERROR
<godot> --headless --path . --script res://teste.gd           # extends SceneTree, prints TEST:/TEST FAIL:
<godot> --path . --rendering-driver opengl3 --script ...      # capturas OpenGL (get_viewport().get_texture())
```
Nota: autoloads só entram na árvore após o 1º `process_frame` num script `--script`.

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
scenes/
  characters/     player, renegade, medic + mixamo_recruit (parqueado)
  enemies/        normal/runner/brute/spitter/boss + spit_projectile
  menus/          main_menu, character_selection, armory_screen, settings, skill_tree
  pickups/        scrap/ammo/health/weapon
  ui/             hud, tactical_map, damage_number, painéis
  weapons/        cenas das 7 armas (lógica + malhas invisíveis; visual = embutido no rig)
  world/          test_arena (o mapa vive nas 3 camadas de GridMap desta cena)
scripts/
  characters/     player, third_person_camera, imported_model_animation
  enemies/        normal_zombie (base), boss_breaker, damage_hitbox, spit_projectile
  weapons/        weapon_controller, hitscan_weapon, melee_weapon
  systems/        (ver secção 4 — o coração do jogo)
  ui/             ecrãs e helpers (armory, selection, hud, mapa, animações)
  pickups/        scrap/ammo/health/weapon
  data/           CharacterData, WeaponData, WaveData (Resources tipados)
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
                  paint_world.gd           pinta todos os setores
                  apply_skyboxes.gd        liga os céus aos presets de atmosfera
                  capture_ui_screen.gd     capturas
tests/            10 scripts headless (extends SceneTree, prints TEST:/TEST FAIL:)
docs/             este overview + GDD, ARCHITECTURE, ROADMAP, PROGRESS, TODO, INSPIRATIONS
prompts/          prompts para agentes
```

Números atuais: 78 scripts `.gd`, 65 cenas `.tscn`, 26 `.tres` de dados, 10 testes.

---

## 4. Sistemas principais (`scripts/systems/`)

| Sistema | Função |
|---|---|
| `wave_manager.gd` | **Diretor de horda contínuo**: threat level sobe **por tempo** (75 s/nível), spawns em lotes nos 6 pontos mais próximos (≥12 m), pesos por tipo, boss a cada 5 níveis, `cycle_completed` a cada 3. |
| `world_streamer.gd` | Grelha 8×8 (512 m); setores gerados em **worker threads**; carga 72 m / descarga 96 m; estado por setor; seed e setores visitados persistidos no save. |
| `sector_generator.gd` | **Só conteúdo, nunca geometria**: caches, munições, caixa de arma (~⅓), marcadores de spawn, paredes de limite e o bake de navegação. O mapa é pintado à mão. |
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
- **Cartas de upgrade** por nível de run (3 de 10, só duram a run) com painel próprio.
- **Orbes de XP** largadas por todos os inimigos, com íman até ao jogador.
- **Barra de XP + `LV n`** no HUD; auto-fire alargado e câmara recuada; auto-reload
  assim que o carregador esvazia.

### Mundo aberto — ver `MAP_DESIGN.md`
- **8×8 setores (512 m)** sobre um **solo único**, streaming em worker threads.
- **Mapa autorado à mão** em 3 camadas de GridMap (`MapRoads`, `MapStructures`,
  `MapProps`), célula 8×4×8 m, a partir de **448 peças CC0** medidas e escaladas
  (os packs Kenney/KayKit vêm em miniatura e são ampliados ×1,8 a ×6).
- **Navegação lê as peças pintadas** (`gridmap_obstacles.gd`), pelas formas de
  cada peça — o armazém continua praticável por dentro.
- Gerador de setor reduzido a **conteúdo**: caches, munições, arma, spawns.
- Seed **fixo por perfil**, setores visitados persistidos no save.
- **Céu por nível de ameaça** (5 panoramas Kenney nos presets de atmosfera).

### Acampamento — REMOVIDO (2026-07-26)
O núcleo, as estações de upgrade e as fortificações foram apagados a pedido.
O código (`camp_core.gd`, `camp_economy.gd`, `camp_upgrade_station.gd`,
`fortification_site.gd`) continua no repositório e pode voltar como estruturas
pintadas. **A extração passou a ser na origem (0,0,0).**

### UI / UX (facelift completo — Tier 1/2/3)
- Menu principal com fundo 3D, seleção de classes com modelo 3D + mastery + variante,
  ARMORY, skill tree (ligações/cores), pausa/derrota com blur, HUD polido.
- Tipografia **Rajdhani**, ícones gerados dos modelos, som de UI, animações/juice.
- **Definições em separadores** Display/Controls/Audio com **keybindings rebindable**
  (captura, swap de conflito, reset, persistência no save).

### Técnico
- Save robusto com migrações, definições persistidas, overlay F3 com métricas de
  streaming, testes headless sistemáticos, docs sincronizados.

---

## 6. O QUE FALTA ❌ (por milestone)

### M27 — Mapa autorado (em curso)
- [ ] **Catalogar as inconsistências** vistas no playtest de 2026-07-26.
- [ ] Afinar densidade e composição dos 64 setores à mão no editor.
- [ ] **Atmosfera Forward+**: nevoeiro volumétrico, SSAO, SSIL (agora possíveis).
- [ ] **Spawns em `Marker3D`** colocados à mão (atrás de coberturas, becos).
- [ ] POIs pintados (a peça `ind_building_*` é a indicada) a repor as recompensas
      que saíram com o POI procedural.
- [ ] Coerência visual: Kenney e Quaternius têm estilos diferentes — usar por
      zona, não intercalar.
- [ ] Investigar o **arranque lento da arena em headless** com 8×8.

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
6. Não descarregar assets externos sem autorização; comunicação em PT-PT, código em inglês.

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
