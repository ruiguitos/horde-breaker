# Horde Breaker — Plano de Trabalho

O que falta implementar, por ordem de dependência, com o detalhe necessário para
começar sem redescobrir o contexto. Escrito em 2026-07-27 a partir de uma
análise do código, não das notas antigas.

Complementa: `OVERVIEW.md` (estado geral) · `MAP_DESIGN.md` (mapa) ·
`TODO.md` (lista curta) · `IMPLEMENTATION-PLAN.md` (plano do utilizador, com
erratas no topo).

---

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

## Etapa 2 — Catalogar as inconsistências do mapa

**Porquê agora:** foram vistas em playtest e nunca escritas. Corrigir sem lista é
adivinhar, e o mapa tem 64 setores.

**Método:** uma passagem de jogo com um ficheiro aberto ao lado, a registar
*sítio + sintoma*. Suspeitos, por ordem de probabilidade:

| Suspeita | Como confirmar |
|---|---|
| Edifícios sobrepostos entre si | vista de topo ortogonal; procurar geometria a interpenetrar |
| Loot ou spawns dentro de paredes | `_find_free_position` não conhece as células pintadas |
| Navegação a atravessar peças | `GridMapObstacles` ignora formas < 0,5 m (`MINIMUM_BLOCKING_HEIGHT`) |
| Costuras entre setores | as estradas alinham, mas os props nas bordas podem colidir |

**Provável correção estrutural:** o gerador de conteúdo coloca loot com
`_find_free_position`, que só evita as áreas que ele próprio reservou — **não vê
o GridMap**. Passar-lhe os obstáculos pintados resolve a família toda:

```gdscript
# sector_generator.gd — o config já transporta painted_obstacles para a navegação;
# usá-los também como blocked_areas ao colocar conteúdo.
for obstacle in config.get("painted_obstacles", []):
    var centre: Vector3 = obstacle["center"]
    blocked_areas.append(Rect2(
        Vector2(centre.x - obstacle["half_x"], centre.z - obstacle["half_z"]),
        Vector2(obstacle["half_x"] * 2.0, obstacle["half_z"] * 2.0)
    ))
```

---

## Etapa 3 — Medir o arranque lento em headless

**Sintoma:** com 8×8, abrir a arena em headless passou a demorar tanto que fez
uma validação exceder 600 s. Com 4×4 era imediato.

⚠️ **Não** baixar `load_distance` para 48 (sugestão do `IMPLEMENTATION-PLAN.md`):
os centros dos setores estão a 64 m e os 72 m existem para os apanhar a tempo.
48 abriria buracos à frente do jogador.

**Medir primeiro.** Hipóteses, por ordem:

1. `paint_world` escreve 4096 células por camada; o `.tscn` cresceu e o *parse*
   da cena é que ficou caro. Medir com `Time.get_ticks_msec()` à volta do
   `change_scene_to_file`.
2. O bake de navegação corre por setor carregado — com mais setores dentro do
   raio, é mais bake no arranque.
3. Um teste que nunca sai (o `--quit-after` não dispara). Confirmar com um
   `print` no `_ready` da arena.

Só depois de saber qual é, mexer.

---

## Etapa 4 — Repor os POIs

Saíram com o graybox. `scenes/world/exploration_pois.tscn` e os três scripts de
encontro (`warehouse_`, `military_outpost_`, `fuel_station_encounter.gd`)
continuam no repositório.

**Abordagem:** os POIs passam a ser **pintados** com peças reais em vez de
grayboxes — `ind_building_*` (armazém), `grav_crypt_*` (cripta), `fac_*`
(industrial). A cena de encontros liga-se por `Area3D` colocada sobre a peça
pintada, em vez de construir as paredes ela própria.

Cada POI devolve o que o gerador perdeu ao deixar de os criar: uma cache de
recompensa (eram 50 de Scrap) e um encontro por ciclo.

---

## Etapa 5 — Atmosfera Forward+

Passou a ser possível com a mudança de renderer e continua por fazer.

⚠️ **Editar os `.tres` à mão perde-se**: `tools/apply_skyboxes.gd` reescreve os
quatro presets. A alteração tem de ser feita *nessa ferramenta*.

```gdscript
# tools/apply_skyboxes.gd — dentro do ciclo, antes de gravar:
environment.ssao_enabled = true
environment.ssao_intensity = 1.5
environment.ssil_enabled = true          # caro; medir antes de manter
environment.volumetric_fog_enabled = true
environment.volumetric_fog_density = 0.02
environment.volumetric_fog_albedo = Color(0.75, 0.78, 0.8)
```

Subir a densidade do nevoeiro com o nível de ameaça é o que faz o mapa fechar-se
à volta do jogador à medida que a run aperta.

**Medir com `tests/bench_horde.gd` depois de ativar** — SSIL e nevoeiro
volumétrico são dos efeitos mais caros que há, e há 143 FPS de margem para gastar.

---

## Etapa 6 — Spawns e loot colocados à mão

Hoje o gerador espalha tudo aleatoriamente. Para design de níveis a sério, as
posições têm de ser autoráveis.

**Abordagem:** um `SectorData.tres` por setor com listas de posições
(spawns, loot, POI), lido em `add_content_stage()`; setores sem ficheiro mantêm
a geração procedural como fallback. Assim pode-se autorar setor a setor sem
partir os outros.

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

## Etapa 8 — Balanceamento

Só faz sentido **depois da etapa 1**: sem base, a economia de Scrap não fecha.

Precisa de sessões de jogo, não de código. Valores a rever:
`WeaponData` (dano, cadência, carregador, recarga) · `CharacterData` (vida,
regeneração) · `wave_manager` (`base_max_alive`, `max_alive_per_level`,
`level_up_interval`, `HARD_ENEMY_CAP` — que já não é o constrangimento que era).

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

Os 11 testes em ``tests/`` somam **329 verificações** e cobrem extração, armas,
melee, skill tree, navegação do GridMap, solo do mundo, desempenho da horda,
ligação de nós da arena, minimapa e o painel de pausa. **Correr todos antes de commitar** — foi assim que se
apanharam o script perdido do `world_streamer` e o desalinhamento das peças.
