# Horde Breaker — Handoff / Estado do Projeto

Resumo para continuar o desenvolvimento noutro chat do Claude Code.
Última atualização: 2026-07-22.

## O que é

Horde shooter 3ª pessoa em **Godot 4.7 (mono, renderer GL Compatibility)**, com
protótipo de **mundo aberto compacto por setores**. Single-player, Windows.
Core loop: mover → combater → explorar o mapa → subir de nível/skill tree →
sobreviver à horda contínua. Assets: primitivas + kit CC0 Quaternius (sem
descarregar mais assets sem autorização — regra do `AGENTS.md`).

- **Cena principal:** `scenes/menus/main_menu.tscn`
- **Arena de jogo:** `scenes/world/test_arena.tscn`
- **Autoloads:** `SettingsManager`, `SaveManager`, `GameManager`, `FpsOverlay`
- **Arranque:** janela 1152×648 (baixo, para testes). `F3` alterna FPS. `Tab` abre o mapa tático.

## Como correr / testar

Executável Godot:
`C:\Users\Rui\Downloads\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64_console.exe`

```bash
# Importar (validar parsing/recursos)
<godot> --headless --path <proj> --import
# Correr uma cena headless N frames (procurar ERROR/SCRIPT ERROR na saída)
<godot> --headless --path <proj> "res://scenes/world/test_arena.tscn" --quit-after 120
# Captura visual (janela real OpenGL) via --script SceneTree que faz change_scene + get_viewport().get_texture()
```
Padrão de teste usado: scripts `extends SceneTree` em headless que instanciam a
arena, manipulam nós e imprimem `TEST: ...` / `TEST FAIL: ...`. (Ficaram na
scratchpad temporária, não no repo — recriar conforme necessário.)

**Save:** `user://horde_breaker_save.cfg` (export) e `user://horde_breaker_test.cfg`
(editor, semeado por `main_menu.gd`; atualmente 0 créditos / nível 1). Definições:
`user://horde_breaker_settings.cfg`. `user://` no Windows =
`%APPDATA%/Godot/app_userdata/Horde Breaker/`.

## Estado por área (✅ feito · 🟡 parcial · ❌ falta)

### Core & Combate — ✅ completo
Movimento (WASD, corrida, salto, agachamento), câmara 3ª pessoa + mira sobre
ombro, hitscan com dano por zonas (corpo 1× / cabeça 2×), disparo automático por
proximidade (6 m, com throttle de raycasts), melee (Worn Sword), feedback de
impacto (números, flash no inimigo, sons sintetizados), knockback ao jogador.

### Inimigos — ✅ variedade base
Normal Zombie, Runner, **Brute** (tanque + knockback), **Spitter** (à distância,
projétil), **Boss "The Breaker"** (invoca minions). Diretor de horda **contínuo**
(sem rondas): spawns aleatórios à volta do jogador, escalada por "threat level"
(a cada 75 s), boss a cada 5 níveis. Falta: ❌ simulação de inimigos distantes /
orçamento de IA (otimização).

### Personagens & Armas — 🟡
3 classes (Recruit/Renegade/Medic) com passivos e loadout 1/2. Armas de fogo
(AR/Pistol/Shotgun) + Worn Sword. **Armas encontráveis pela exploração** (caixas
nos setores; equipam no slot secundário e **largam a arma substituída no chão**).
Falta: ❌ 2ª arma do Medic, ❌ armas alternativas planeadas (SMG, Marksman, Katana…),
❌ Mixamo/arte final (bloqueado: assets).

### Progressão — ✅ grande salto
XP por personagem, **sem limite de níveis**, 1 ponto de skill por nível.
**Skill tree permanente por personagem** (`scripts/systems/skill_tree.gd`): 3 ramos
(Offense/Survival/Expedition) × 5 tiers com pré-requisitos, guardada no save,
aplicada a cada partida por `character_skills.gd` (dano, cadência, recarga, vida,
regen, redução de dano, velocidade, reserva de munição, +Scrap, +XP). UI:
`skill_tree_screen` (botão na seleção de personagens). O antigo "Field Upgrade"
entre rondas foi **removido**. Falta: ❌ objetivos de mastery por personagem.

### Mundo Aberto / Mapa — 🟡 (PRÓXIMO)
Grelha 4×4 (256×256 m) gerada por seed, streaming em **worker threads**
(`WorldStreamer` + `SectorGenerator`), navegação contínua entre setores, estado
por setor (loot/emboscada/arma, só sessão), céu procedural, props ambientais,
mapa tático melhorado (`Tab`). POIs com interiores existem só na arena feita à
mão. **Falta:** ❌ POIs/interiores nos setores gerados, ❌ emboscadas por ciclo (agora
1×/partida), ❌ persistência do estado dos setores no save, ❌ medição de desempenho.
**Bug conhecido em espera:** mini-hitch no instante em que um setor gerado é
adicionado à cena (`add_child` de ~64 malhas de uma vez). Próximo passo: encaixar
as peças do setor em 2-3 frames em vez de todas de uma vez.

### Acampamento / Economia — 🟡 (PRÓXIMO)
Núcleo com vida, depositar/reparar Scrap, **zona de reabastecimento** (cura +
munição perto do núcleo), caches de Scrap randomizadas por partida, 1 barricada
fixa. **Falta:** ❌ construção livre / várias estruturas, ❌ melhorias permanentes da
base.

### UI / UX — ✅
Menu principal, seleção de personagens, pausa, derrota, definições, skill tree,
HUD **minimalista** in-game, mapa tático, auto-pickup, transições fade, tudo em
**inglês**. 🟡 painel de vitória fora de uso (estilo antigo).

### Técnico / Docs — 🟡
Definições (janela/fullscreen, resolução, VSync, som). Contador de FPS (`F3`).
Primeira ronda de otimização (throttle de raycasts do auto-fire, repath dos
inimigos escalonado, geração em worker thread, streaming 72/96 m). **Falta:**
❌ navmesh de editor (em vez da grelha runtime), ❌ **sincronizar GDD/ARCHITECTURE/
ROADMAP** — descrevem ainda o jogo antigo (rondas, PT, 3 m, núcleo como alvo).
`PROGRESS.md` e `TODO.md` estão em dia.

## Arquitetura (mapa rápido de ficheiros)

- Autoloads: `autoload/{settings_manager,save_manager,game_manager,fps_overlay}.gd`
- Diretor de horda: `scripts/systems/wave_manager.gd` (spawns contínuos, threat level, boss)
- Mundo: `scripts/systems/{world_streamer,sector_generator,pickup_randomizer,arena_navigation}.gd`
- Progressão: `scripts/systems/{skill_tree,character_skills,character_progression}.gd`, `autoload/save_manager.gd`
- Economia/base: `scripts/systems/{camp_economy,camp_core,camp_core_interaction,fortification_site}.gd`
- Inimigos: `scripts/enemies/{normal_zombie,boss_breaker,spit_projectile}.gd` + cenas em `scenes/enemies/`
- Armas: `scripts/weapons/{weapon_controller,hitscan_weapon,melee_weapon}.gd`
- Pickups: `scripts/pickups/{scrap,ammo,health,weapon}_pickup.gd`
- UI: `scripts/ui/*` + `scenes/menus/*`, `scenes/ui/*`

Layers de física: 1=World, 2=Player, 3=Enemy hitboxes, 4/bit8=Pickups.
Grupos-chave: `player`, `enemy`, `enemy_target`, `enemy_spawn_point`,
`weapon_controller`, `wave_manager`, `camp_economy`, `world_streamer`,
`camp_core`, `point_of_interest`, `scrap_pickup`/`ammo_pickup`/`health_pickup`/`weapon_pickup`.

## Notas / decisões pendentes

- Otimização do mini-hitch da geração de setores: **em espera** (pedido do utilizador).
- Perf headless não é mensurável (física fixa a 60 Hz); medir em jogo com o contador de FPS.
- Inimigos só perseguem o jogador (núcleo/base/barricada não são alvos nem condição de derrota).
- Não descarregar assets externos sem autorização explícita.
- Ao testar, o jogo começa do zero (save reiniciado a 2026-07-22).

## Próximos passos sugeridos (novo chat)

1. **Mundo Aberto:** POIs com interiores nos setores gerados + emboscadas por
   ciclo; depois persistência do estado dos setores no save.
2. **Acampamento:** melhorias permanentes da base (comprar upgrades com Scrap
   armazenado) e/ou mais pontos de construção.
3. Sincronizar `GDD.md` / `ARCHITECTURE.md` / `ROADMAP.md` com o estado real.
4. (Quando pedido) resolver o mini-hitch da geração encaixando o setor por frames.
