# Horde Breaker — Plano de Trabalho

O que falta implementar, por ordem de dependência, com o detalhe necessário para
começar sem redescobrir o contexto. Escrito em 2026-07-27 a partir de uma
análise do código, não das notas antigas.

Complementa: `OVERVIEW.md` (estado geral) · `MAP_DESIGN.md` (mapa) ·
`TODO.md` (lista curta) · `IMPLEMENTATION-PLAN.md` (plano do utilizador, com
erratas no topo).

---

> **2026-07-30 — as etapas 1 a 7 estão fechadas.** O que resta neste ficheiro
> (etapa 8 e o backlog) precisa de sessões de jogo, não de código. Cada etapa
> abaixo diz o que se descobriu ao fazê-la, incluindo as duas que se revelaram
> ser outra coisa.

## 0. Onde estamos (2026-07-29)

**Funciona e está validado por testes:** combate e hitscan, melee com auto-ataque,
horda contínua com escalada temporal, 11 armas com evolução por abates, 2 classes,
skill tree de 36 nós, cartas de upgrade por run, orbes de XP, extração em 5 fases,
streaming 8×8 em worker threads, navegação a ler GridMap, save com migrações,
UI completa (menu, seleção, armory, skill tree, definições, HUD, mapa tático).

**Desempenho:** Forward+, 143 FPS com 140 inimigos. Margem para 200 a 105 FPS.

**Testes:** 10 ficheiros headless em `tests/`, ~290 verificações.

**O que se partiu ao refazer o mapa:** o acampamento e os POIs foram removidos
da arena. Os *scripts e cenas continuam todos lá* — só os nós saíram. É isso que
a etapa 1 repõe.

---

## Etapa 1 — Restaurar o acampamento ✅ **FEITO (2026-07-27)**

`scenes/world/camp_sector.tscn` empacota núcleo, 3 estações de upgrade,
3 pontos de fortificação e a grelha de construção. Colocado no setor **(-1,-1)**,
não no centro: ao centro todas as runs têm a mesma forma e nenhum lado do mapa
é mais perigoso que outro. A posição é uma constante em três ficheiros que têm
de concordar (`world_streamer.CAMP_COORDS`, `place_camp.CAMP_COORDS`,
`paint_world.CENTRE`).

Apareceram pelo caminho: o `CampBuilder` apontava para nós inexistentes, o
catálogo de construção e a sua `CanvasLayer` tinham desaparecido, e o jogador
nascia na antiga origem. Tudo religado. `test_arena_wiring` cobre-o.

<details>
<summary>Detalhe original da etapa</summary>

**Porquê primeiro:** sem base não há depósito de Scrap nem upgrades. O core loop
("explorar → combater → recolher → melhorar → extrair") está partido a meio, e
qualquer balanceamento feito antes disto é feito sobre um jogo incompleto.

**O que sobreviveu** (nada precisa de ser reescrito):

```
scenes/world/camp_core.tscn              núcleo + interação [F]
scenes/world/camp_upgrade_station.tscn   pedestal de upgrade
scenes/world/fortification_site.tscn     ponto de barricada
scripts/systems/camp_core.gd             zona de reabastecimento
scripts/systems/camp_economy.gd          Scrap transportado/armazenado  (JÁ na arena)
scripts/systems/camp_builder.gd          modo de construção
scripts/systems/build_grid.gd            grelha de colocação
scripts/systems/structure_catalog.gd     catálogo de estruturas
data/structures/*.tres                   barricade, generator, scrap_wall,
                                         spotlight, watch_tower
```

**Passos**

1. Criar `scenes/world/camp_sector.tscn` com raiz `Node3D`:

```
CampSector (Node3D)
├── CampCore              (instância de camp_core.tscn)
├── UpgradeStations (Node3D)
│   ├── ResupplyRate      (camp_upgrade_station.tscn)
│   ├── ResupplyRange     (camp_upgrade_station.tscn)
│   └── Scavenging        (camp_upgrade_station.tscn)
├── Fortifications (Node3D)
│   ├── North / West / East   (fortification_site.tscn)
└── CampConstruction (Node3D)
    ├── BuildGrid         (script build_grid.gd)
    ├── GhostContainer    (Node3D)
    └── BuiltStructures   (Node3D)
```

2. Instanciar na arena, centrada na origem — é onde o jogador nasce e onde a
   extração acontece. **Não** pintar GridMap por cima do setor (0,0): o
   `paint_world.gd` já o deixa aberto de propósito.

3. Religar o `CampBuilder` (`scripts/systems/camp_builder.gd`) em
   `Gameplay/CampBuilder` e apontar os seus `NodePath` para os três nós de
   `CampConstruction`. Foi este desencontro que produzia, antes da remoção:
   `Node not found: "../../CampConstruction/BuildGrid"`.

4. Confirmar que `SaveManager.get_base_layout()` é uma definição e não uma
   chamada órfã — aparece uma única vez no ficheiro.

**Validação**

- `tests/test_arena_wiring.gd` — acrescentar `camp_core` e `build_grid` à
  tabela `REQUIRED`, que é exatamente o teste que apanha nós sem script.
- Em jogo: depositar Scrap com `[F]`, comprar um upgrade, construir uma
  barricada, sair e voltar a entrar (o layout tem de persistir).

**Risco conhecido:** a zona de extração usa o grupo `camp_core`. Com o
acampamento de volta, deixa de cair no fallback `Vector3.ZERO` — se o núcleo não
ficar na origem, a extração muda de sítio sem aviso.

---

</details>

---

## Etapa 2 — Catalogar as inconsistências do mapa ✅ **FEITO (2026-07-30)**

Eram duas, e a segunda não estava na lista de suspeitos com a forma certa.

**Inconsistência 1 — loot e spawns dentro de paredes.** Confirmada e corrigida
como previsto: `begin_sector` semeia agora `blocked_areas` com os obstáculos
pintados que o config já transportava para a navegação. Medido antes e depois,
com 40 seeds sobre um setor de blocos e ruas: **105 de 266 colocações ficavam
dentro de edifícios; agora 0**. Pelo caminho apareceram mais duas:

- nada reservava o que acabara de ser colocado, por isso duas caches podiam
  partilhar o mesmo sítio — `_find_free_position` reserva agora o que devolve;
- quando as 20 tentativas falhavam todas, os spawns caíam em posições fixas
  escolhidas antes de o mapa existir, e essas podiam ser paredes — há agora um
  anel de recurso, verificado contra o mapa (`SPAWN_FALLBACK_POSITIONS`).

**Inconsistência 2 — edifícios a atravessarem-se.** A suspeita estava certa, a
causa não. Medidas as 20 peças que o pintor usa: **6 são maiores que a célula de
8 m** (`ind_building_a/b` 12,5 m, `ind_building_c` 11,3 × 12,6 m,
`ind_building_e` 10,1 m, `city_building_j` 12,5 m, `city_building_e` 9,8 m) e o
pintor colocava-as em células vizinhas. Mas medir só a largura **não chegava**:
as malhas industriais da Kenney não estão centradas na origem — `ind_building_h`
mede 7,9 m e estende-se **5,6 m para um dos lados**, por isso "cabe na célula"
era falso. O tamanho tem de vir do alcance a partir da origem
(`AABB.position`), não de `AABB.size`.

Correção: o pintor mantém um **mapa de ocupação do mundo inteiro**, semeado com
as ruas e passeios antes de qualquer estrutura (por isso as costuras entre
setores também fecham), e reserva as células que cada peça ocupa mesmo. De 16
sobreposições francas para **0**, verificado sobre a arena real em
`tests/test_painted_map.gd`.

⚠️ Efeito secundário: a rejeição cortava um terço das estruturas. As densidades
subiram de 0,3 / 0,5 / 0,4 para **0,4 / 0,65 / 0,55** para repor o número
(1262 peças sobrepostas → 1034 limpas). **Isto precisa de olhos.**

---

## Etapa 3 — Medir o arranque lento em headless ✅ **FEITO (2026-07-30)**

**Não existe.** `tests/bench_arena_startup.gd` mede-o por fases e dá **1,42 s até
jogável** com 8×8: 486 ms de arranque do motor, 588 ms de *parse* do `.tscn`
(a hipótese 1 estava certa quanto a ser o item dominante, mas são 0,6 s, não
minutos), 8 ms a instanciar, 53 ms de `_ready` e 289 ms até o streaming assentar
em 4 setores. O bake de navegação corre em worker threads, ~50 ms por setor,
fora do frame.

Era a **hipótese 3**: um teste que não saía. O `test_gridmap_navigation.gd` tinha
exatamente esse defeito (uma exceção saltava por cima do `quit()`) e já fora
corrigido — a suite inteira corre hoje em ~20 s, o teste mais lento em 2,6 s.

`load_distance` fica em 72. Apareceu ao medir, e foi corrigido, um ruído
antigo: cada peça de um `WeaponCrate` reanexada pelo streamer disparava um aviso
de `owner` inconsistente. A arena corre agora 400 frames sem um único aviso.

---

## Etapa 4 — Repor os POIs ✅ **FEITO (2026-07-30)**

São **6**: dois armazéns, dois postos militares, dois depósitos de combustível,
espalhados por `paint_world.POINTS_OF_INTEREST` de modo que nenhuma saída do
acampamento os apanhe todos.

Cada um é um **composto pintado**: fila de trás e uma lateral construídas com
peças reais, as duas faces viradas para o cruzamento abertas, e um **pátio de
24 m** ao meio. A cena (`scenes/world/poi_*.tscn`) não tem geometria nenhuma —
só o gatilho `Area3D` de 12 m, os marcadores de spawn e loot, o `AccessPoint`, a
etiqueta e uma **cache de 50 Scrap**. Os três scripts de encontro que estavam no
repositório entraram sem alterações.

⚠️ A ideia original de usar `ind_building_*` para o armazém **não sobreviveu à
medição**: são as peças descentradas da etapa 2 e punham as paredes do próprio
composto umas dentro das outras. O composto usa peças que cabem mesmo na célula
(`kay_building_*`, `city_building_*`, `ind_chimney_large`, `ind_detail_tank`,
`fac_hopper_*`).

Reconstruir: `build_poi_scenes.gd` (as cenas) e `place_pois.gd` (pô-las na
arena), sempre **depois** de `paint_world.gd` — o `place_pois` lê de lá onde
ficaram os pátios, para o gatilho e os edifícios não discordarem.

---

## Etapa 5 — Atmosfera Forward+ ✅ **FEITO (2026-07-30)**

Feito em `tools/apply_skyboxes.gd`, que passou a escrever os presets inteiros e
não só o céu. SSAO ligado nos quatro, nevoeiro volumétrico com a densidade a
subir **0,008 → 0,016 → 0,028 → 0,042** com o nível de ameaça, alcance de 80 m
(um setor mede 64) e dispersão para a frente para o sol continuar a ler-se como
uma direção.

**SSIL foi medido e ficou desligado.** `bench_horde.gd` com 140 inimigos, três
corridas de cada: **127 / 127 / 134 FPS sem**, **107 / 105 / 108 com** — cerca de
1,6 ms por frame, um sexto da taxa de frames, por luz indirecta que este nevoeiro
esconde. A flag `ENABLE_SSIL` fica para quem quiser voltar a medir. Nevoeiro e
SSAO juntos não custam nada que se veja acima da variação entre corridas.

`tests/test_arena_wiring.gd` verifica agora que os quatro presets têm SSAO e
nevoeiro e que a densidade cresce — é o que apanha um `.tres` editado à mão e
depois reescrito pela ferramenta.

---

## Etapa 6 — Spawns e loot colocados à mão ✅ **FEITO (2026-07-30)**

`SectorData` (`scripts/data/sector_data.gd`) com quatro listas de posições XZ
relativas ao centro do setor: `enemy_spawns`, `scrap_caches`,
`ammunition_boxes`, `weapon_crates`. O streamer procura
`res://data/sectors/sector_<x>_<y>.tres`, valida os limites do setor e entrega ao
worker **listas simples**, não o Resource — o worker constrói uma subárvore
desligada e não tem que tocar em recursos que o resto do jogo está a usar.

O fallback é **lista a lista**: autorar só os spawns deixa o loot disperso, por
isso um setor pode ser tomado aos poucos. Uma caixa de arma autorada aparece
sempre, em vez de depender do sorteio de 1 em 3.

Criar um: `<godot> --headless --path . --script res://tools/new_sector_data.gd -- <x> <y>`.
Escreve um layout de partida e **recusa-se a reescrever** um ficheiro existente.

⚠️ Depois de criar `scripts/data/sector_data.gd` foi preciso
`--headless --path . --import`: sem isso o `class_name` não existe e o
`world_streamer.gd` não compila. Está registado nas armadilhas do OVERVIEW.

---

## Etapa 7 — UI

**Feito (2026-07-29):**

- **Minimapa no HUD** (`scripts/ui/minimap.gd`) — dial no canto, roda com o
  jogador, base e extração agarradas à borda quando fora de alcance, teto de
  40 inimigos desenhados.
- **Mapa tático corrigido** — tinha cópias próprias das constantes do mundo e
  desenhava ainda um mundo 4×4 de 256 m com a base na origem.
- **Menu de pausa** — resumo da run (tempo, extração, abates, ameaça, nível,
  Scrap) e **lista das cartas escolhidas**, que o `RunUpgrades` aplicava e
  esquecia. Painel próprio à direita.
- **Menu principal** — cartão do operativo alinhado à direita (faltava-lhe
  `size_flags_horizontal`) e fim da faixa branca (o SubViewport do fundo estava
  fixo em 1152×648 e não acompanhava a janela).

**Falta:** "melhorar o menu principal" continua **sem alvo definido** — é o
aspeto, a estrutura, ou a sensação de arranque? Perguntar antes de mexer.

---

## Etapa 8 — Balanceamento ← **é aqui que a próxima sessão começa**

Só faz sentido **depois da etapa 1**: sem base, a economia de Scrap não fecha.
A base voltou a 2026-07-27, portanto está desbloqueada.

Precisa de sessões de jogo, não de código. Valores a rever:
`WeaponData` (dano, cadência, carregador, recarga) · `CharacterData` (vida,
regeneração) · `wave_manager` (`base_max_alive`, `max_alive_per_level`,
`level_up_interval`, `HARD_ENEMY_CAP` — que já não é o constrangimento que era).

**A juntar-lhe, do mesmo playtest:** o mapa mudou por baixo. As densidades novas
(0,4 / 0,65 / 0,55 em `paint_world.gd`) foram escolhidas para repor o número de
edifícios de antes da correção das sobreposições, não porque alguém as jogou. E
os 6 POIs nunca foram vistos em jogo — só verificados por teste.

---

## Backlog (sem ordem)

Som e música · partículas (sangue, fogo, poeira) · feedback de UI (direção do
dano, aviso de munição baixa) · gamepad · localização · save de partida a meio ·
mutators por run.

---

## Como validar qualquer etapa

```bash
<godot> --headless --path . --import                                  # parsing
<godot> --headless --path . res://scenes/world/test_arena.tscn --quit-after 300
<godot> --headless --path . --script res://tests/<teste>.gd           # TEST:/TEST FAIL:
```

Os 13 testes em ``tests/`` somam **383 verificações** e cobrem extração, armas,
melee, skill tree, navegação do GridMap, solo do mundo, desempenho da horda,
ligação de nós da arena, atmosfera, minimapa, painel de pausa, o mapa pintado
(sobreposições e POIs) e o conteúdo dos setores (loot em paredes, autoria).
**Correr todos antes de commitar** — foi assim que se apanharam o script perdido
do `world_streamer` e o desalinhamento das peças.

Todo o script `--script` tem de chamar `quit()` em **todos** os caminhos: um que
saia por uma exceção fica vivo para sempre, e foi isso que passou anos a parecer
"a arena arranca devagar". As duas medições que não passam/falham correm à parte:

```bash
<godot> --headless --path . --script res://tests/bench_arena_startup.gd   # arranque por fases
<godot> --path . --script res://tests/bench_horde.gd -- 140               # FPS (precisa de janela)
```
