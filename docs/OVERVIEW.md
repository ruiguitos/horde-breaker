# Horde Breaker — Overview Completo do Projeto

Ficheiro-mestre único e **ponto de entrada para qualquer sessão nova** (substitui
o antigo HANDOFF): o que é o jogo, como está organizado, o que está feito e o que
falta. Última atualização: 2026-07-24. Detalhe histórico em `PROGRESS.md`;
plano por milestone em `ROADMAP.md`.

---

## 1. O que é

Horde shooter 3D em **terceira pessoa**, single-player, Windows, feito em
**Godot 4.7 (mono, renderer GL Compatibility)**, GDScript tipado, **sem C#**.

O jogador explora um **mundo aberto compacto** (grelha 4×4 de setores, 256×256 m)
enquanto uma **horda contínua** nasce à volta e escala com o tempo. O acampamento
central é o porto seguro (reabastecimento, depósito de Scrap, melhorias). Texto
do jogo em **inglês**; documentação em **português**.

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
  world/          test_arena, camp_core, camp_upgrade_station, fortification_site,
                  city_road_grid, exploration_pois, sectors/east_sector
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
    city_test_model/               Quaternius Downtown MegaKit (CC0) — edifícios/estradas
    mixamo/                        PARQUEADO (não usado)
  shaders/, themes/  tema partilhado da UI e shaders procedurais
tools/            generate_ui_icons.gd (regenera ícones/retratos)
docs/             este overview + GDD, ARCHITECTURE, ROADMAP, PROGRESS, TODO, INSPIRATIONS
prompts/          prompts para agentes
```

Números atuais: ~59 scripts `.gd`, ~41 cenas `.tscn`, 13 `.tres` de dados.

---

## 4. Sistemas principais (`scripts/systems/`)

| Sistema | Função |
|---|---|
| `wave_manager.gd` | **Diretor de horda contínuo**: threat level sobe **por tempo** (75 s/nível), spawns em lotes nos 6 pontos mais próximos (≥12 m), pesos por tipo, boss a cada 5 níveis, `cycle_completed` a cada 3. |
| `world_streamer.gd` | Grelha 4×4; setores gerados em **worker threads**; carga 72 m / descarga 96 m; estado por setor; seed/visitados/farol persistidos no save. |
| `sector_generator.gd` | Constrói o setor por seed: estradas, **edifícios CC0 reais** (com lote), props, caches, munições, caixa de arma (~⅓), **POI explorável** (~½), spawns, navegação. |
| `arena_navigation.gd` | Grelha de navegação em runtime que exclui `navigation_blocker`. Decisão: navmesh de editor não se aplica (setores gerados em runtime). |
| `camp_economy.gd` | Scrap transportado/armazenado, multiplicadores, **melhorias da base** (Resupply Rate/Range, Scavenging), progresso de mastery de Scrap. |
| `camp_core.gd` / `camp_upgrade_station.gd` | Núcleo, **zona de reabastecimento** (raio/valores crescem com upgrades), 3 pedestais de upgrade. |
| `fortification_site.gd` | 3 pontos de barricada construíveis/reparáveis. |
| `character_progression.gd` | XP por kill/nível/ciclo, Credits por ciclo, **mastery** (kills/threat). |
| `skill_tree.gd` / `character_skills.gd` | Árvore permanente (3 ramos × 5 tiers, níveis mín. 2/5/9/14/20) e aplicação dos bónus. |
| `character_mastery.gd` | Objetivos de mastery (EXTERMINATOR/STORM RIDER/SCAVENGER). |
| `character_variants.gd` | **Variantes de classe** (capstone da mastery): VETERAN/BERSERKER/COMBAT MEDIC. |
| `weapon_catalog.gd` | Catálogo único das armas jogáveis (usado pelo controller e pelo ARMORY). |
| `*_encounter.gd`, `sector_beacon.gd`, `pickup_randomizer.gd`, `hit_sound_library.gd` | Encontros dos POIs à mão, farol, randomização de loot do acampamento, sons sintetizados. |

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
- 3 classes (Recruit/Renegade/Medic) com passivos e loadout 1/2.
- **7 armas:** AR, Pistol, Shotgun, **SMG**, Worn Sword, Spear, **Fire Axe** — visuais
  são **malhas embutidas nos rigs** (decisão firme; nada ancorado ao pivot estático).
- **ARMORY:** comprar armas com Credits (nível+custo), escolher slots 1/2 (persistente).
- **Skill tree** permanente por classe; **mastery** (3 objetivos → Credits + variante).
- **Variantes de classe** desbloqueadas ao completar a mastery.
- Munição do chão **escala com o nível de ameaça**.

### Survivors-like (M26 Fase 1)
- **Cartas de upgrade** por nível de run (3 de 10, só duram a run) com painel próprio.
- **Orbes de XP** largadas por todos os inimigos, com íman até ao jogador.
- **Barra de XP + `LV n`** no HUD; auto-fire alargado e câmara recuada; auto-reload
  assim que o carregador esvazia.

### Mundo aberto
- Grelha 4×4 por seed em worker threads, streaming, navegação contínua.
- Seed **fixo por perfil**, setores visitados e farol **persistidos no save**.
- **Cidade a sério (M24):** layout urbano com **cruz de ruas de 16 m** e quatro
  **quarteirões de 24×24 m**; os **edifícios CC0 reais** (Quaternius Downtown) só
  são colocados dentro dos quarteirões, com lote próprio; props de cidade. O chão
  em tiles repetidos foi removido do acampamento e do setor este. POIs exploráveis + emboscadas
  por ciclo. Colisão dos edifícios **alinhada** com o visual (bug corrigido).

### Acampamento
- Zona de reabastecimento, depósito de Scrap, **3 upgrades** compráveis, 3 barricadas.

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

### M22 — Balanceamento (precisa de PLAYTEST teu)
- [ ] Rever dano/cadência/regen das 3 classes **e das variantes** após jogar.
- [ ] Afinar a curva do diretor de horda (intervalo 75 s, lotes, limite simultâneo).
- [ ] Decidir se o disparo manual permanece.

### M24 — Cidade a sério (continuação)
- [ ] Tiles de estrada Downtown alinhadas (opcional — estradas atuais já texturadas).
- [ ] Mais props (AC nas fachadas, drenos, veículos) e afinar densidade.
- [ ] Fachadas reais nos POIs (manter interior+loot).
- [ ] Atmosfera do mundo (luz/nevoeiro/hora dourada) alinhada com os assets.

### M25 — Construção livre da base (feature grande, pedida)
- [ ] Modo de construção no acampamento (grelha, preview fantasma, gasta Scrap).
- [ ] Catálogo de estruturas (barricada, torre, parede, gerador…).
- [ ] Persistência do layout da base no save.
- [ ] **Base evolui visualmente** conforme os upgrades comprados.

### M23 — Polimento e conteúdo extra (backlog)
- [ ] Mais objetivos de mastery e recompensas.
- [ ] Save de partida a meio (continuar uma run).
- [ ] Modificadores de arena (mutators) — variedade entre partidas (inspiração RoR2).
- [ ] Evolução de armas por condições (inspiração YAZS).
- [ ] Labels 3D `[F]` a mostrar a tecla real (após rebind).
- [ ] Fundir marcadores coincidentes no mapa tático.
- [ ] Mini-hitch do `add_child` dos setores (encaixar malhas por frames) — **em espera**.

### Bloqueado (precisa de ti / assets)
- Novos packs de arte = **download teu**; Mixamo **parqueado** (Quaternius cobre tudo);
  armas com modelo externo só com `BoneAttachment3D`.

---

## 7. Decisões e restrições que NÃO se revertem

1. **Armas visíveis = malhas embutidas nos rigs Quaternius** (nunca ancorar ao
   `WeaponPivot` estático; pack de armas externo foi testado e revertido).
2. **Mixamo parqueado** (`assets/models/mixamo/` existe mas não se usa).
3. **Navegação = grelha runtime** (`arena_navigation.gd`); não migrar para navmesh de editor.
4. **Inimigos perseguem só o jogador**; núcleo/base não são alvo nem condição de derrota.
5. **Loot renova a cada partida**; persiste no save: seed, setores visitados, farol,
   progressão e compras.
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
