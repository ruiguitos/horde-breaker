# Horde Breaker — Referência do projeto

Retrato do jogo e do código a **2026-08-03**, derivado do repositório e não da
documentação anterior. Todos os números foram medidos nesta passagem: contagens
de ficheiros e linhas vêm de `git ls-files`, e o total de verificações vem de
correr a suite completa em headless.

Este documento responde a três perguntas: **o que é o jogo**, **o que ele já tem
de jogabilidade** e **o que existe em termos de código**. Para detalhe de
decisões e histórico, ver os documentos indexados no fim.

---

## 1. O que é o jogo

**Horde Breaker** é um *horde shooter* 3D em terceira pessoa, single-player,
para Windows. O jogador escolhe uma classe, entra num mundo compacto e sobrevive
a uma horda contínua que escala com o tempo, enquanto recolhe recursos, melhora
o acampamento e sobe uma progressão que persiste entre partidas.

Não há rondas discretas nem vitória por pontos. Uma partida (*run*) tem um
relógio, mas o relógio **não termina a run** — decide quando o fim começa.

### Ciclo principal

```text
escolher classe e loadout
      ↓
explorar → combater a horda → recolher Scrap, munições e armas
      ↓
depositar no acampamento → comprar melhorias da base e torres
      ↓
subir de nível na run (cartas temporárias) e ganhar XP permanente
      ↓
LAST STAND → limpar a horda finita → extração
      ↓
recomeçar com skill tree, mastery, Credits e arsenal permanentes
```

### As cinco fases de uma run

Implementadas em [run_objective.gd](scripts/systems/run_objective.gd) como um
`enum Phase` de quatro estados mais a extensão opcional:

1. **SURVIVING** — o relógio corre (600 s por omissão) e o diretor de horda faz
   nascer inimigos.
2. **Surto final** — nos últimos 60 s a horda intensifica-se.
3. **LAST_STAND** — a torneira fecha: nada mais nasce e o que está no mapa passa
   a ser um número finito que tem de chegar a zero.
4. **EXTRACTING** — mapa limpo; a zona de extração fica ativa e a run acaba
   quando o jogador lá chega.
5. **Extensão** — em vez de extrair, o jogador pode prolongar 300 s por um
   multiplicador de recompensa de 2×.

### Onde o jogo se joga hoje

O menu Play abre **`destiny_archipelago_prototype.tscn`** — um arquipélago de
512 × 512 m com quatro ilhas sobre Terrain3D. A arena antiga
(`test_arena.tscn`, mundo aberto 8 × 8 com streaming de setores) continua no
projeto e é o que vários testes carregam, mas já não é a run.

---

## 2. Jogabilidade

### Jogador e controlos

`CharacterBody3D` em terceira pessoa com câmara sobre o ombro em `SpringArm3D`.

| Ação | Tecla | Notas |
|---|---|---|
| Mover | `WASD` | 4 m/s |
| Correr | `Shift` | 7 m/s |
| Agachar | `Ctrl` | 2,5 m/s, câmara desce 0,35 m |
| Saltar | `Space` | |
| Disparar | Botão esquerdo | há também disparo automático por proximidade |
| Mirar | Botão direito | |
| Recarregar | `R` | |
| Interagir | `F` | |
| Armas 1/2 | `1` / `2` | |
| Mapa tático | `Tab` | |
| Construir | `B`, `R` roda, `X` demole | |
| Pausa | `Esc` | |
| FPS overlay | `F3` | |
| Noclip (dev) | `Mouse 4` | só em builds de desenvolvimento |

### Classes

Definidas em `data/characters/*.tres` como `CharacterData`.

| Classe | Loadout | Passivo | Desbloqueio |
|---|---|---|---|
| **Recruit** | Assault Rifle + Pistol | recarga 30% mais rápida | inicial |
| **Renegade** | Shotgun + SMG | 150 HP | 500 Credits |
| **Medic** | Pistol + SMG | regenera 3 HP/s após 4 s sem dano | 750 Credits |

Cada classe tem uma **variante** desbloqueada ao completar as três mastery:
VETERAN, BERSERKER e COMBAT MEDIC. Não são personagens novas — partilham XP,
skills e arsenal com a base.

### Armas

Existem 13 ficheiros `WeaponData` em `data/weapons/`, mas o catálogo
(`WeaponCatalog.ALL_WEAPONS`) só carrega **nove armas de fogo**, em quatro
categorias:

- **assault** — Assault Rifle, Hornet, SMG, Storm Rifle
- **close_range** — Shotgun, Siege Breaker
- **heavy** — Machine Gun, Minigun
- **sidearm** — Pistol

As quatro melee (Cleaver, Fire Axe, Spear, Worn Sword) foram **retiradas**: não
estão em `ALL_WEAPONS`, `melee` não consta das categorias da ARMORY, e perfis
antigos que tivessem uma equipada saem a segurar uma arma de fogo. Os `.tres`
continuam no disco com `is_playable = true`, que aí já não tem efeito. Ver
`test_melee_retirement.gd`.

Combate hitscan com dano por zonas (corpo 1×, cabeça 2×) e disparo automático
contra o inimigo visível mais próximo até 6 m.

### Inimigos e diretor de horda

| Inimigo | Vida | Velocidade | Dano | Papel |
|---|---|---|---|---|
| Normal Zombie | 100 | 2,5 m/s | 10 | base |
| Runner | 60 | 4,5 m/s | 7 | rápido |
| Brute | 320 | 1,8 m/s | 26 | tanque, knockback 12 |
| Spitter | 70 | 2,9 m/s | 11 | à distância, mantém-se a 9 m |
| The Breaker (boss) | 1200 | 2,2 m/s | 34 | knockback 16, invoca minions |

O diretor ([wave_manager.gd](scripts/systems/wave_manager.gd)) é contínuo, não
por rondas:

- primeiro surto aos **45 s**; nível de ameaça sobe a cada **75 s**;
- spawns em lote nos 6 pontos mais próximos do jogador, sempre a **≥ 12 m**;
- pesos por tipo conforme o nível (Runners cedo, Brutes do nível 2, Spitters do 3);
- **boss a cada 5 níveis**; um "ciclo" são 3 níveis e paga 100 Credits;
- orçamento global de **90 inimigos ativos**, barreira absoluta de **120**, fila
  máxima de **12** e apenas **2 instanciações por frame de física**;
- inimigos distantes correm em LOD de simulação (menos repaths, e acima de 60 m
  simulam 1 frame em 3).

### Economia e progressão

**Dentro da run**
- **Scrap** — moeda temporária; transportado até ser depositado no núcleo (`F`).
- **Nível da run** — XP de orbes largados por inimigos; cada nível oferece 3
  cartas temporárias com raridade e até 5 níveis cada.
- **Melhorias da base** — Resupply Rate, Resupply Range e Scavenging, 3 níveis.
- **Torres defensivas** — 3 níveis ligados ao nível da run (45 Scrap no nível 1,
  90 no 5, 150 no 10); recebem dano, reparam-se e nunca terminam a run.

**Permanente** (em `user://horde_breaker_save.cfg` via `SaveManager`)
- **Credits** — desbloqueiam classes e armas.
- **Character XP** — por classe, sem teto; 1 ponto de habilidade a cada 2 níveis.
- **Skill tree** — 3 classes × 3 categorias × 6 nós = **54 nós**, em 5 tiers com
  níveis mínimos 2 / 5 / 9 / 14 / 20. Cada categoria tem a mesma forma: tronco,
  tronco, bifurcação, reencontro, remate.
- **Mastery** — EXTERMINATOR (100 abates), STORM RIDER (ameaça 5 numa partida),
  SCAVENGER (500 Scrap). As três desbloqueiam a variante da classe.
- **ARMORY** — compra e equipa armas nos slots 1/2.

### Mundos

| Cena | Dimensão | Estado |
|---|---|---|
| `destiny_archipelago_prototype.tscn` | 512 × 512 m, 4 regiões Terrain3D | **a run atual** |
| `test_arena.tscn` | 8 × 8 setores, 512 × 512 m, streaming | mundo antigo, ainda usado por testes |
| `shipwreck_rocks_prototype.tscn` | 256 × 256 m | micro-ilha de validação, com ferry |
| `terrain3d_prototype.tscn` / `terrain3d_world.tscn` | — | protótipos de terreno |

**Arquipélago:** Dawn Beach (hub) → Shallow Reef ou Sea Cave → Shadow Forest ou
High Cliffs → Rope Bridge ou Ancient Ruins → Volcano Peak (boss). Dawn Beach tem
um loop jogável: recuperar três células de energia, voltar ao acampamento e
ativar **apenas uma** das duas rotas.

### Interface

Menu principal, seleção de classes, ARMORY, skill tree, definições, pausa e
derrota. Em jogo: HUD minimalista (vida, munição, faixa de ameaça, Scrap, feed
de mensagens), **minimapa circular** rodado com o jogador (raio 70 m),
**mapa tático** no `Tab` e overlay de FPS.

---

## 3. Código

### Motor e linguagem

- **Godot 4.7 stable (mono)**, renderer **Forward+**.
- **GDScript tipado**, 100% — **zero ficheiros C#** apesar da build mono.
- Um único addon: **Terrain3D 1.0.2**.
- 121 commits; janela por omissão 1152 × 648.

### Dimensão do código

| Área | Ficheiros `.gd` | Linhas |
|---|---:|---:|
| `scripts/systems/` | 54 | 10 431 |
| `tests/` | 27 | 5 234 |
| `scripts/ui/` | 20 | 4 546 |
| `tools/` | 15 | 3 467 |
| `autoload/` | 4 | 1 288 |
| `scripts/weapons/` | 3 | 922 |
| `scripts/characters/` | 4 | 895 |
| `scripts/enemies/` | 4 | 803 |
| `scripts/pickups/` | 6 | 413 |
| `scripts/data/` | 11 | 224 |
| `scripts/structures/` | 2 | 150 |
| **Total** | **150** | **28 373** |

Restante conteúdo versionado: **71 cenas** `.tscn`, **39 recursos** `.tres`,
**7 shaders** próprios, **456 modelos** `.glb`/`.gltf` e 29 documentos.

### Autoloads

| Autoload | Linhas | Responsabilidade |
|---|---:|---|
| `SettingsManager` | 386 | janela, resolução, VSync, sensibilidade, volume, rebinds; `user://horde_breaker_settings.cfg` |
| `SaveManager` | 740 | Credits, XP e nível por classe, skills, mastery, variantes, armas compradas, seed do mundo, setores visitados, layout da base |
| `GameManager` | 87 | transições de cena com fade; define qual é a cena da run |
| `FpsOverlay` | 75 | contador de FPS (`F3`) com cor por faixa e métricas de streaming |

### Sistemas principais

Os maiores ficheiros, que são também onde vive a maior parte da lógica:

| Ficheiro | Linhas | O que faz |
|---|---:|---|
| `destiny_archipelago_prototype.gd` | 761 | monta o arquipélago inteiro: terreno, rotas, hubs, dressing, spawns |
| `normal_zombie.gd` | 683 | classe base de **todos** os inimigos, incluindo boss e ranged |
| `tactical_map.gd` | 652 | mapa do `Tab` desenhado em `_draw()` |
| `wave_manager.gd` | 594 | diretor de horda e orçamento global |
| `world_streamer.gd` | 558 | grelha 8 × 8 com geração em `WorkerThreadPool` |
| `sector_generator.gd` | 520 | conteúdo de um setor por seed |
| `game_hud.gd` | 513 | HUD in-game |
| `dawn_beach_hub.gd` | 506 | acampamento, células de energia e escolha de rota |

### Padrões e convenções

- **Dados estáticos em `Resource .tres`** (`CharacterData`, `WeaponData`,
  `IslandData`, `IslandRouteData`, `ArchipelagoData`, `StructureData`,
  `SectorData`), separados do estado em execução.
- **Sinais para eventos, grupos para descoberta.** Os grupos mais usados são
  `player`, `enemy`, `enemy_target`, `camp_economy`, `wave_manager`,
  `run_progression`, `run_objective`, `terrain3d_world`.
- **Herança única para inimigos:** Runner, Brute, Spitter e o boss são cenas que
  reconfiguram `normal_zombie.gd` por `@export`, não subclasses.
- **Terreno gerado por código**, não esculpido: `create_height_map()` e
  `create_control_map()` nos ficheiros `*_design.gd`, assados em regiões pelos
  scripts de `tools/`.
- **Nomes de ações, nunca teclas** — 23 ações em `project.godot`.
- Código, nós, classes e commits em inglês; documentação em português.

### Testes

**25 ficheiros de teste + 2 benchmarks**, todos `SceneTree` corridos em
headless. Medido nesta passagem: **901 verificações, 0 falhas**.

```bash
"C:\Users\Rui\Downloads\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64_console.exe" --headless --path . --script res://tests/test_destiny_archipelago.gd
```

Os maiores: `test_skill_tree` (222), `test_destiny_archipelago` (184),
`test_camp_layout` (59), `test_balance_and_weapons` (53).

Nota sobre autoloads em testes: um script corrido com `--script` compila **antes**
de os autoloads existirem, por isso só as **constantes** de um autoload resolvem
por identificador. Para ler ou escrever propriedades é preciso
`root.get_node("/root/GameManager")`.

### Ferramentas

Quinze scripts em `tools/` que geram conteúdo versionado em vez de o construir
em runtime: dados de terreno das três cenas Terrain3D, o acampamento, as cenas
de POI, a biblioteca de tiles, os skyboxes, os ícones da UI e capturas de ecrã
da interface.

### Arte

456 modelos CC0 low-poly: Kenney (factory, graveyard, car, city commercial,
city industrial, mini forest — 372), KayKit city bits (41) e Quaternius zombie
apocalypse (43, os personagens e armas). Céu procedural, nevoeiro volumétrico e
SSAO que engrossam com o nível de ameaça.

### Desempenho

Forward+ foi adotado depois de medir 140 inimigos a **16,5 FPS** em GL
Compatibility contra **143,9 FPS** em Forward+. As decisões de orçamento da
horda (LOD de simulação, teto de 90 ativos, 2 spawns por frame, geração de
setores em worker threads) vêm de medições, não de estimativas.

---

## 4. Divergências entre documentação e código

Detetadas ao comparar os documentos com o repositório nesta passagem. Valem uma
correção quando houver oportunidade:

1. **`GDD.md` diz que o arquipélago está "fora da run principal".** Já não está:
   `GameManager.RUN_SCENE` aponta para `destiny_archipelago_prototype.tscn`.
   O GDD descreve o mundo 8 × 8 como a run atual.
2. **`GDD.md` descreve a skill tree como "36 nós em 7 tiers" com níveis mínimos
   2/4/7/10/14/18/24.** O código tem **54 nós em 5 tiers** com 2/5/9/14/20.
3. **`OVERVIEW.md` está datado de 2026-07-30** e descreve o mundo pintado à mão
   como o estado atual, antes de o arquipélago passar a ser a run.

---

## 5. Dívida técnica conhecida

- **Não existe navegação assada em lado nenhum do arquipélago.** Os inimigos
  andam a direito para o alvo, atravessando o que deviam contornar, e encalham
  em barreiras. Uma `NavigationRegion3D` sobre as ilhas Terrain3D continua em
  dívida. Há um teste que fixa o comportamento atual
  (`a zombie inside the navmesh band closes on the player`).
- **O mapa tático desenha o mundo antigo.** `tactical_map.gd` lê
  `world_streamer` e `terrain3d_world_design` e tem limites `[-224, 288]`; no
  arquipélago o jogador está fora desses limites, o marcador cai fora do painel
  e o rodapé mostra um setor inexistente.
- **Volcano Peak não fecha a run.** A fase finita e a extração existem, mas são
  disparadas pelo relógio; o plano quer que sejam os selos e o boss.
- **Duas regras de grounding em paralelo:** no mundo antigo os inimigos são
  colados por consulta de altura (`_snap_to_terrain`), no arquipélago usam
  colisão real do Terrain3D.
- **O aviso de depreciação do Terrain3D** (`instance_reset_physics_interpolation`)
  aparece em todos os arranques.

---

## 6. Índice da documentação

| Documento | Para quê |
|---|---|
| `AGENTS.md` | regras de trabalho, convenções e método |
| `GDD.md` | design do jogo |
| `ARCHITECTURE.md` | arquitetura técnica detalhada |
| `ARCHIPELAGO_GAMEPLAY_PLAN.md` | direção aprovada do arquipélago e ordem de implementação |
| `PROGRESS.md` | histórico cronológico do que foi feito |
| `ROADMAP.md` / `PLANO-DE-TRABALHO.md` / `TODO.md` | o que falta |
| `MAP_DESIGN.md` / `TERRAIN_MAP_OPTIONS.md` | mapa e alternativas de terreno |
| `CONTENT_EXPANSION_PLAN.md` | classes e conteúdo futuros |
| `OVERVIEW.md` | ponto de entrada anterior (parcialmente desatualizado) |
