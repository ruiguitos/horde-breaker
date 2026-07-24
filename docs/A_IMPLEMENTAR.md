# A_IMPLEMENTAR.md
# Horde Breaker — Plano de Implementação M24 + M25
# Gerado em: 2026-07-24

---

## Índice

1. [M24 — Cidade a sério (continuação)](#m24--cidade-a-sério-continuação)
   - 24.1 [Tiles de estrada alinhadas (Opcional)](#241-tiles-de-estrada-alinhadas-opcional)
   - 24.2 [Mais props e densidade](#242-mais-props-e-densidade)
   - 24.3 [Fachadas reais nos POIs](#243-fachadas-reais-nos-pois)
   - 24.4 [Atmosfera — Luz/nevoeiro/hora dourada](#244-atmosfera--luznevoeirohora-dourada)
2. [M25 — Construção livre da base](#m25--construção-livre-da-base)
   - 25.1 [Arquitetura geral](#251-arquitetura-geral)
   - 25.2 [Data layer — Recursos de estrutura](#252-data-layer--recursos-de-estrutura)
   - 25.3 [Cenas de estruturas](#253-cenas-de-estruturas)
   - 25.4 [Sistema de grelha e snapping](#254-sistema-de-grelha-e-snapping)
   - 25.5 [Camp Builder — modo de construção](#255-camp-builder--modo-de-construção)
   - 25.6 [UI do catálogo de construção](#256-ui-do-catálogo-de-construção)
   - 25.7 [Persistência do layout da base](#257-persistência-do-layout-da-base)
   - 25.8 [Base evolui visualmente com upgrades](#258-base-evolui-visualmente-com-upgrades)
   - 25.9 [Input rebindable — novas ações](#259-input-rebindable--novas-ações)
3. [Resumo de ficheiros a criar (checklist)](#resumo-de-ficheiros-a-criar-checklist)
4. [Ordem de implementação sugerida](#ordem-de-implementação-sugerida)

---

## Estado da implementação — 2026-07-24

- **M24 protótipo funcional:** props, fachadas e atmosfera estão operacionais, mas a cidade, as estradas e os caminhos serão substituídos por uma geração baseada num grafo contínuo entre setores. Ver `docs/CITY_REBUILD_PLAN.md`.
- **M25 funcional concluído:** cinco estruturas, grelha de 2 m, catálogo, preview válido/inválido, rotação, movimento durante a construção, custo em Scrap armazenado, reparação, navegação dinâmica, persistência do layout e visuais de upgrades.
- **Cancelado:** estrada contínua/world-space UV no gerador atual — superado pelo `docs/CITY_REBUILD_PLAN.md`, que substitui a geração de estradas por completo.
- **Polish pendente:** balanceamento em playtest. A zona de interação já suporta reparação e demolição com reembolso (ação `structure_demolish`, 50% do custo em Scrap), e a destruição por dano liberta a grelha e atualiza o save.

---

## M24 — Cidade a sério (continuação)

**Objetivo:** Transformar os setores gerados de "blocos funcionais" para "ambiente credível" sem quebrar performance ou a geração por seed.

---

### 24.1 Tiles de estrada alinhadas (Opcional — baixa prioridade)

**Decisão:** Se as estradas atuais já têm textura e funcionam, **deixa isto para o fim** do M24. Só vale a pena se quiseres remover o "tileado" visível.

| Ação | Ficheiro/Pasta |
|---|---|
| Criar material de estrada contínua | `assets/materials/road_continuous.tres` (ShaderMaterial com UV world-space) |
| Modificar `sector_generator.gd` | `scripts/systems/sector_generator.gd` — função `_place_road_segment()` |
| Criar cena de estrada segmentada | `scenes/world/road_segment_straight.tscn`, `road_segment_intersection.tscn`, `road_segment_corner.tscn` |

**Lógica:** Em vez de tiles 8×8m repetidos, gerar segmentos de estrada maiores (16×2m) que se encaixam nos pontos de interseção calculados. O UV do material usa `world_position.xz` para evitar seams.

```gdscript
# Em sector_generator.gd, na função de estradas:
# Substituir loop de tileado por:
# 1. Calcular grafo de estradas (pontos + arestas)
# 2. Por cada aresta, instanciar segmento reto com scale.x = distância
# 3. Por cada ponto com >2 arestas, instanciar interseção
# 4. Rotação = look_at entre pontos
```

---

### 24.2 Mais props e densidade

**A criar:**

| Ficheiro | Tipo | Nota |
|---|---|---|
| `scenes/world/props/ac_unit.tscn` | StaticBody3D + malha | Para fachadas |
| `scenes/world/props/drain_pipe.tscn` | StaticBody3D | Encosta em edifícios |
| `scenes/world/props/abandoned_car.tscn` | StaticBody3D + colisão | Obstáculo de navegação |
| `scenes/world/props/trash_pile.tscn` | Area3D (sem colisão sólida) | Só visual |
| `data/prop_placement_rules.tres` | Resource | Pesos, densidade máxima por setor |

**Modificar:**

| Ficheiro | O que alterar |
|---|---|
| `scripts/systems/sector_generator.gd` | Nova função `_place_props(building_transforms: Array[Transform3D])` |
| `scripts/systems/arena_navigation.gd` | Adicionar props como `navigation_blocker` se tiverem colisão sólida |

**Regras de colocação (script):**

```gdscript
# sector_generator.gd
func _place_props(buildings: Array[Node3D], sector_seed: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = sector_seed + 999  # offset para não coincidir com edifícios

    for building in buildings:
        # AC units: 30% de chance, no topo (y + altura do edifício)
        if rng.randf() < 0.3:
            var ac = preload("res://scenes/world/props/ac_unit.tscn").instantiate()
            ac.position = building.position + Vector3(rng.randf_range(-2,2), building.height, rng.randf_range(-2,2))
            add_child(ac)

        # Carros abandonados: 1-2 por setor, nas estradas
        # Drenos: 1 por edifício, encostado à face

    # Props de chão (trash, barricadas quebradas): densidade baseada em threat level
```

**Densidade:** Máximo 15 props colisionáveis por setor (para não afetar a navegação runtime). Props puramente visuais (trash) podem ir até 40.

---

### 24.3 Fachadas reais nos POIs

**A criar:**

| Ficheiro | Tipo |
|---|---|
| `scenes/world/poi_facades/` | Pasta nova |
| `scenes/world/poi_facades/police_station_facade.tscn` | Node3D com malha exterior |
| `scenes/world/poi_facades/hospital_facade.tscn` | Node3D com malha exterior |
| `scenes/world/poi_facades/supermarket_facade.tscn` | Node3D com malha exterior |
| `data/poi_registry.tres` | Resource que mapeia tipo de POI → cena de fachada + cena interior |

**Modificar:**

| Ficheiro | O que alterar |
|---|---|
| `scripts/systems/sector_generator.gd` | Em `_generate_poi()`, substituir ou envolver o edifício genérico pela fachada específica |
| `scripts/systems/*_encounter.gd` (os existentes) | Garantir que o loot/interior spawna dentro da fachada, não fora |

**Arquitetura:**

```
POI no setor:
├── Facade (visual exterior, colisão, navigation_blocker)
│   └── Porta/entrada marcada (Marker3D "poi_entrance")
└── Interior (instanciado como child, ou em posição offset y=-50 para não renderizar exterior)
    └── Loot, inimigos, spawns
```

A fachada é uma malha real (do pack Downtown ou modelada simples). O interior continua a ser o mesmo sistema de encontro atual, mas posicionado relativo à porta.

```gdscript
# sector_generator.gd
func _generate_poi(poi_type: String, position: Vector3) -> Node3D:
    var registry := preload("res://data/poi_registry.tres")
    var entry: POIEntry = registry.get_entry(poi_type)

    var facade = entry.facade_scene.instantiate()
    facade.position = position
    add_child(facade)

    var interior = entry.interior_scene.instantiate()
    # Interior spawna na mesma posição, mas o encounter script posiciona loot relativo ao marker
    interior.position = position
    add_child(interior)

    return facade
```

---

### 24.4 Atmosfera — Luz/nevoeiro/hora dourada

**A criar:**

| Ficheiro | Tipo |
|---|---|
| `scenes/world/world_environment.tscn` | WorldEnvironment (se ainda não existir) |
| `scripts/systems/atmosphere_controller.gd` | Autoload ou singleton da cena world |
| `shaders/fog_volume.gdshader` | Shader de nevoeiro volumétrico simples (raymarching barato) |
| `resources/atmosphere_presets/` | Pasta com Environment presets (.tres) |

**Modificar:**

| Ficheiro | O que alterar |
|---|---|
| `scenes/world/test_arena.tscn` | Adicionar WorldEnvironment node |
| `scripts/systems/world_streamer.gd` | Chamar `atmosphere_controller.apply_preset(current_threat_level)` |

**Sistema de atmosfera:**

```gdscript
# scripts/systems/atmosphere_controller.gd
class_name AtmosphereController extends Node

@export var world_env: WorldEnvironment
@export var directional_light: DirectionalLight3D

var presets: Dictionary = {
    "calm": preload("res://resources/atmosphere_presets/calm.tres"),
    "threat_5": preload("res://resources/atmosphere_presets/threat_5.tres"),
    "threat_10": preload("res://resources/atmosphere_presets/threat_10.tres"),
    "nightmare": preload("res://resources/atmosphere_presets/nightmare.tres")
}

func apply_preset(threat_level: int) -> void:
    var preset_name := "calm"
    if threat_level >= 15: preset_name = "nightmare"
    elif threat_level >= 10: preset_name = "threat_10"
    elif threat_level >= 5: preset_name = "threat_5"

    var env: Environment = presets[preset_name]
    world_env.environment = env

    # Luz: rotação suave para "hora dourada" em threat alto
    var target_rotation := Vector3(deg_to_rad(-15 if threat_level < 5 else -45), 0, 0)
    # Tween suave (não instantâneo)
```

**Presets (Environment .tres):**

| Preset | Características |
|---|---|
| `calm` | Ambient light #8a9ab0, fog depth begin 80m, end 200m, cor #b0c4de, sun elevation -20° |
| `threat_5` | Ambient mais quente #a08060, fog mais denso, begin 60m, cor #c4a882 |
| `threat_10` | Luz alaranjada forte, fog begin 40m, cor #d4a050, sky contribution baixo |
| `nightmare` | Luz vermelha/ambar, fog begin 25m, cor #8b0000, exposure ajustado para escurecer |

**Nota:** Como usas GL Compatibility renderer, **não tens volumetric fog nativo**. Usa:
- `Environment.fog_enabled = true` (depth fog)
- Ou o shader `fog_volume.gdshader` em um MeshInstance3D (quad grande) na frente da câmara se quiser efeito mais dramático.

---

## M25 — Construção livre da base

**Objetivo:** Modo de construção no acampamento com grelha, preview fantasma, catálogo de estruturas e persistência. A base evolui visualmente com os upgrades.

---

### 25.1 Arquitetura geral

```
Campo (camp_core.tscn) já existe. Vamos adicionar:

camp_core.tscn
├── ... (o que já existe)
├── CampBuildGrid (Node3D)  # área de construção
│   └── BuildGhost (MeshInstance3D, transparente) # preview
├── BuiltStructures (Node3D)  # container de estruturas colocadas
└── CampBuilder (Node/Area3D) # lógica de input

scripts/systems/camp_builder.gd  (NOVO - controla o modo construção)
scripts/systems/build_grid.gd    (NOVO - grelha e snapping)
scripts/data/structure_data.gd   (NOVO - Resource para cada estrutura)
data/structures/                 (NOVO - .tres de cada estrutura)
scenes/structures/               (NOVO - cenas de cada estrutura)
```

---

### 25.2 Data layer — Recursos de estrutura

**A criar:**

| Ficheiro | Tipo |
|---|---|
| `scripts/data/structure_data.gd` | `class_name StructureData extends Resource` |
| `data/structures/barricade.tres` | StructureData |
| `data/structures/watch_tower.tres` | StructureData |
| `data/structures/scrap_wall.tres` | StructureData |
| `data/structures/generator.tres` | StructureData |
| `data/structures/spotlight.tres` | StructureData |

**`scripts/data/structure_data.gd`:**

```gdscript
class_name StructureData extends Resource

@export var id: StringName
@export var display_name: String
@export var description: String
@export var scrap_cost: int
@export var scene: PackedScene
@export var grid_size: Vector2i = Vector2i(1, 1)  # em células de 2m
@export var build_time: float = 0.0  # 0 = instantâneo
@export var max_health: int = 100
@export var requires_upgrade: StringName = &""  # ex: "resupply_range_2"
@export var icon: Texture2D
@export var category: StringName = &"defense"  # defense / utility / decoration
```

---

### 25.3 Cenas de estruturas

**A criar em `scenes/structures/`:**

| Ficheiro | Conteúdo |
|---|---|
| `barricade.tscn` | StaticBody3D + malha do pack Quaternius (barricada quebrada ou similar) + collision |
| `watch_tower.tscn` | StaticBody3D + plataforma elevada + collision + SpotLight3D (se tiver energia) |
| `scrap_wall.tscn` | StaticBody3D + malha de metal amassado + collision alta |
| `generator.tscn` | StaticBody3D + malha + OmniLight3D + área de "energizado" |
| `spotlight.tscn` | StaticBody3D + SpotLight3D + collision pequena |

Todas herdam de uma cena base:

**`scenes/structures/structure_base.tscn`:**

```
StructureBase (StaticBody3D)
├── MeshInstance3D
├── CollisionShape3D
├── HealthComponent (script reutilizado dos inimigos se existir, ou novo)
└── InteractionZone (Area3D - para reparar/demolir)
```

**`scripts/structures/structure_base.gd`:**

```gdscript
class_name StructureBase extends StaticBody3D

@export var data: StructureData
var current_health: int
var is_ghost: bool = false  # true durante preview

func _ready() -> void:
    current_health = data.max_health
    collision_layer = 1  # World
    if is_ghost:
        collision_layer = 0
        collision_mask = 0
        # Material transparente
        _apply_ghost_material()

func take_damage(amount: int) -> void:
    current_health -= amount
    if current_health <= 0:
        destroy()

func destroy() -> void:
    # Efeito de partículas
    queue_free()

func repair(amount: int) -> void:
    current_health = mini(current_health + amount, data.max_health)
```

---

### 25.4 Sistema de grelha e snapping

**A criar:**

| Ficheiro | Tipo |
|---|---|
| `scripts/systems/build_grid.gd` | `class_name BuildGrid extends Node3D` |

```gdscript
class_name BuildGrid extends Node3D

@export var grid_origin: Vector3  # centro do acampamento
@export var grid_size: Vector2i = Vector2i(10, 10)  # 20m × 20m
@export var cell_size: float = 2.0

var occupied_cells: Dictionary = {}  # Vector2i → StructureBase

func world_to_grid(world_pos: Vector3) -> Vector2i:
    var local := world_pos - grid_origin
    return Vector2i(
        floori(local.x / cell_size),
        floori(local.z / cell_size)
    )

func grid_to_world(grid_pos: Vector2i) -> Vector3:
    return grid_origin + Vector3(
        grid_pos.x * cell_size + cell_size * 0.5,
        0.0,
        grid_pos.y * cell_size + cell_size * 0.5
    )

func is_cell_free(grid_pos: Vector2i, size: Vector2i = Vector2i(1,1)) -> bool:
    for dx in range(size.x):
        for dy in range(size.y):
            var check := Vector2i(grid_pos.x + dx, grid_pos.y + dy)
            if occupied_cells.has(check):
                return false
            if not _is_within_bounds(check):
                return false
    return true

func occupy_cells(grid_pos: Vector2i, size: Vector2i, structure: StructureBase) -> void:
    for dx in range(size.x):
        for dy in range(size.y):
            occupied_cells[Vector2i(grid_pos.x + dx, grid_pos.y + dy)] = structure

func _is_within_bounds(pos: Vector2i) -> bool:
    return pos.x >= -grid_size.x/2 and pos.x < grid_size.x/2 and \
           pos.y >= -grid_size.y/2 and pos.y < grid_size.y/2
```

---

### 25.5 Camp Builder — modo de construção

**A criar:**

| Ficheiro | Tipo |
|---|---|
| `scripts/systems/camp_builder.gd` | `class_name CampBuilder extends Node` (autoload ou no camp_core) |

Este é o **cérebro** do M25. Controla estados: IDLE → BUILD_MODE → PLACING → CONFIRM.

```gdscript
class_name CampBuilder extends Node

enum State { IDLE, BUILD_MODE, PLACING, CONFIRM }

@export var player: CharacterBody3D
@export var build_grid: BuildGrid
@export var ghost_container: Node3D  # onde o preview spawna
@export var built_container: Node3D  # onde estruturas reais ficam
@export var camera: Camera3D  # para raycast do mouse

var current_state: State = State.IDLE
var selected_structure: StructureData
var ghost_instance: StructureBase
var current_grid_pos: Vector2i

# Referências a sistemas existentes
@onready var economy: CampEconomy = CampEconomy  # ou get_node
@onready var input_handler: InputHandler  # o teu sistema de input rebindable

func _ready() -> void:
    input_handler.action_pressed.connect(_on_action_pressed)

func enter_build_mode() -> void:
    current_state = State.BUILD_MODE
    # Mostrar UI do catálogo
    # Desacelerar/pausar jogo? Ou time scale normal? (sugiro: normal, mas player não ataca)
    player.set_process_input(false)  # ou flag custom

func select_structure(data: StructureData) -> void:
    selected_structure = data
    current_state = State.PLACING
    _spawn_ghost(data)

func _spawn_ghost(data: StructureData) -> void:
    if ghost_instance:
        ghost_instance.queue_free()

    ghost_instance = data.scene.instantiate() as StructureBase
    ghost_instance.data = data
    ghost_instance.is_ghost = true
    ghost_container.add_child(ghost_instance)

func _physics_process(delta: float) -> void:
    if current_state != State.PLACING and current_state != State.CONFIRM:
        return

    # Raycast do centro do ecrã (ou do mouse, se usares cursor livre)
    var ray_origin := camera.project_ray_origin(get_viewport().get_mouse_position())
    var ray_dir := camera.project_ray_normal(get_viewport().get_mouse_position())

    # Intersecção com plano y=0 (chão do acampamento)
    var t := -ray_origin.y / ray_dir.y
    if t < 0:
        return  # ray aponta para cima

    var world_pos := ray_origin + ray_dir * t
    var grid_pos := build_grid.world_to_grid(world_pos)
    var snapped_pos := build_grid.grid_to_world(grid_pos)

    current_grid_pos = grid_pos

    if ghost_instance:
        ghost_instance.position = snapped_pos
        ghost_instance.visible = build_grid.is_cell_free(grid_pos, selected_structure.grid_size)

        # Cor do ghost: verde se válido, vermelho se inválido
        _update_ghost_color(ghost_instance.visible)

func _update_ghost_color(valid: bool) -> void:
    var color := Color.GREEN if valid else Color.RED
    color.a = 0.5
    # Aplicar ao material override do mesh

func _on_action_pressed(action: StringName) -> void:
    match action:
        &"build_mode_toggle":
            if current_state == State.IDLE:
                enter_build_mode()
            else:
                exit_build_mode()
        &"interact":  # ou "build_confirm"
            if current_state == State.PLACING and ghost_instance.visible:
                _confirm_build()
        &"build_rotate":
            _rotate_ghost()
        &"build_cancel":
            if current_state == State.PLACING:
                _deselect_structure()
            else:
                exit_build_mode()

func _confirm_build() -> void:
    if not economy.can_afford(selected_structure.scrap_cost):
        # Feedback: som "não pode", número vermelho
        return

    economy.spend_scrap(selected_structure.scrap_cost)

    var real := selected_structure.scene.instantiate() as StructureBase
    real.data = selected_structure
    real.position = build_grid.grid_to_world(current_grid_pos)
    built_container.add_child(real)

    build_grid.occupy_cells(current_grid_pos, selected_structure.grid_size, real)

    # Efeito: partículas de construção, som
    _play_build_effect(real.position)

    # Persistir imediatamente
    _save_structure_placement(real)

    # Continuar colocando ou sair?
    # Sugiro: continuar com a mesma estrutura (modo "pincel")
    _spawn_ghost(selected_structure)

func exit_build_mode() -> void:
    current_state = State.IDLE
    if ghost_instance:
        ghost_instance.queue_free()
        ghost_instance = null
    player.set_process_input(true)
    # Esconder UI catálogo
```

---

### 25.6 UI do catálogo de construção

**A criar:**

| Ficheiro | Tipo |
|---|---|
| `scenes/ui/build_catalog.tscn` | Control (painel flutuante) |
| `scripts/ui/build_catalog.gd` | Script do painel |
| `scenes/ui/build_catalog_item.tscn` | Botão de item individual |
| `scripts/ui/build_catalog_item.gd` | Script do item |

**`scenes/ui/build_catalog.tscn`:**

```
BuildCatalog (Control, anchor_right=1, anchor_bottom=1, mouse_filter=PASS)
└── PanelContainer (center screen, 800×500)
    └── VBoxContainer
        ├── Label "CONSTRUCTION"
        ├── TabContainer (3 tabs: Defense / Utility / Decoration)
        │   └── GridContainer (4 colunas)
        │       └── BuildCatalogItem (instâncias)
        └── HBoxContainer
            ├── Label "Scrap available: X"
            └── Button "Close"
```

**`scripts/ui/build_catalog_item.gd`:**

```gdscript
class_name BuildCatalogItem extends Button

@export var structure_data: StructureData

@onready var icon_texture: TextureRect = $Icon
@onready var name_label: Label = $Name
@onready var cost_label: Label = $Cost
@onready var lock_overlay: ColorRect = $LockOverlay

func _ready() -> void:
    icon_texture.texture = structure_data.icon
    name_label.text = structure_data.display_name
    cost_label.text = str(structure_data.scrap_cost)

    # Verificar se desbloqueado (via upgrades de base)
    var unlocked := _check_unlocked()
    lock_overlay.visible = not unlocked
    disabled = not unlocked

func _check_unlocked() -> bool:
    if structure_data.requires_upgrade.is_empty():
        return true
    return SaveManager.has_upgrade(structure_data.requires_upgrade)  # ou CampEconomy
```

**Integração com `camp_builder.gd`:**

```gdscript
# Em camp_builder.gd
@export var build_catalog: BuildCatalog

func enter_build_mode() -> void:
    build_catalog.open()
    build_catalog.structure_selected.connect(_on_structure_selected)

func _on_structure_selected(data: StructureData) -> void:
    select_structure(data)
```

---

### 25.7 Persistência do layout da base

**Modificar:**

| Ficheiro | O que alterar |
|---|---|
| `scripts/systems/save_manager.gd` (ou o que tens) | Nova secção `[base_layout]` |
| `scripts/systems/camp_builder.gd` | Funções `_save_structure_placement()` e `_load_base_layout()` |

**Formato no ConfigFile:**

```ini
[base_layout]
structures_count = 3
structure_0_id = "barricade"
structure_0_x = -2
structure_0_z = 1
structure_0_rotation = 0
structure_0_health = 80
structure_1_id = "watch_tower"
...
```

**`camp_builder.gd` — Save:**

```gdscript
func _save_structure_placement(structure: StructureBase) -> void:
    # Ou salvar tudo de uma vez
    pass

func save_all_structures() -> void:
    var save := ConfigFile.new()
    # Carregar existente
    save.load(SaveManager.SAVE_PATH)

    save.set_value("base_layout", "structures_count", built_container.get_child_count())

    for i in built_container.get_child_count():
        var s := built_container.get_child(i) as StructureBase
        var prefix := "structure_%d" % i
        save.set_value("base_layout", prefix + "_id", s.data.id)
        save.set_value("base_layout", prefix + "_grid_x", build_grid.world_to_grid(s.position).x)
        save.set_value("base_layout", prefix + "_grid_y", build_grid.world_to_grid(s.position).y)
        save.set_value("base_layout", prefix + "_rotation", s.rotation_degrees.y)
        save.set_value("base_layout", prefix + "_health", s.current_health)

    save.save(SaveManager.SAVE_PATH)

func load_base_layout() -> void:
    var save := ConfigFile.new()
    if save.load(SaveManager.SAVE_PATH) != OK:
        return

    var count: int = save.get_value("base_layout", "structures_count", 0)

    for i in count:
        var prefix := "structure_%d" % i
        var id: String = save.get_value("base_layout", prefix + "_id", "")
        var data: StructureData = WeaponCatalog.get_structure(id)  # ou StructureCatalog

        if not data:
            continue

        var grid_x: int = save.get_value("base_layout", prefix + "_grid_x", 0)
        var grid_y: int = save.get_value("base_layout", prefix + "_grid_y", 0)
        var rot: float = save.get_value("base_layout", prefix + "_rotation", 0.0)
        var health: int = save.get_value("base_layout", prefix + "_health", data.max_health)

        var real := data.scene.instantiate() as StructureBase
        real.data = data
        real.position = build_grid.grid_to_world(Vector2i(grid_x, grid_y))
        real.rotation_degrees.y = rot
        real.current_health = health
        built_container.add_child(real)
        build_grid.occupy_cells(Vector2i(grid_x, grid_y), data.grid_size, real)
```

**Onde chamar `load_base_layout()`:** No `_ready()` do `camp_core.gd` ou quando o jogador entra no acampamento.

---

### 25.8 Base evolui visualmente com upgrades

Isto é **conexão entre economia e construção**. Os upgrades atuais (Resupply Rate/Range, Scavenging) devem desbloquear/desencadear mudanças visuais.

**A criar:**

| Ficheiro | Tipo |
|---|---|
| `scenes/structures/camp_upgrade_visuals/` | Pasta |
| `scenes/structures/camp_upgrade_visuals/resupply_station_lv2.tscn` | Malha melhorada |
| `scenes/structures/camp_upgrade_visuals/scavenging_depot.tscn` | Malha de depósito |

**Modificar:**

| Ficheiro | O que alterar |
|---|---|
| `scripts/systems/camp_upgrade_station.gd` | Emitir sinal `upgrade_purchased(upgrade_id)` |
| `scripts/systems/camp_core.gd` | Ouvir sinal e instalar visual correspondente |

```gdscript
# camp_core.gd
@onready var upgrade_visuals: Node3D = $UpgradeVisuals

func _on_upgrade_purchased(upgrade_id: StringName) -> void:
    match upgrade_id:
        &"resupply_rate_2":
            _install_visual("resupply_station_lv2", Vector3(2, 0, -3))
        &"scavenging_1":
            _install_visual("scavenging_depot", Vector3(-3, 0, 2))

func _install_visual(scene_name: String, pos: Vector3) -> void:
    var scene := load("res://scenes/structures/camp_upgrade_visuals/%s.tscn" % scene_name)
    if scene:
        var instance = scene.instantiate()
        instance.position = pos
        upgrade_visuals.add_child(instance)
```

---

### 25.9 Input rebindable — novas ações

**Modificar:**

| Ficheiro | O que alterar |
|---|---|
| `project.godot` (ou o teu loader de input) | Adicionar actions: `build_mode_toggle`, `build_confirm`, `build_cancel`, `build_rotate` |
| `scripts/ui/settings.gd` | Adicionar estas ações ao ecrã de keybindings |

```ini
# project.godot (ou via código no teu input manager)
[input]
build_mode_toggle={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":66,"key_label":0,"unicode":98,"echo":false,"script":null)
]
}
build_confirm={
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)
]
}
build_cancel={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194305,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
build_rotate={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":82,"key_label":0,"unicode":114,"echo":false,"script":null)
]
}
```

---

## Resumo de ficheiros a criar (checklist)

### M24
- [~] `assets/materials/road_continuous.tres` — **cancelado** por decisão do utilizador (2026-07-24): o gerador atual de estradas não deve receber mais polish, já que será substituído por completo pelo grafo contínuo do `docs/CITY_REBUILD_PLAN.md`, que já prevê UV world-space por design.
- [x] `scenes/world/props/ac_unit.tscn`
- [x] `scenes/world/props/drain_pipe.tscn`
- [x] `scenes/world/props/abandoned_car.tscn`
- [x] `scenes/world/props/trash_pile.tscn`
- [x] `data/prop_placement_rules.tres`
- [x] `scenes/world/poi_facades/police_station_facade.tscn`
- [x] `scenes/world/poi_facades/hospital_facade.tscn`
- [x] `scenes/world/poi_facades/supermarket_facade.tscn`
- [x] `data/poi_registry.tres` (+ scripts `scripts/data/poi_entry.gd` e `poi_registry.gd`)
- [x] `scenes/world/world_environment.tscn`
- [x] `scripts/systems/atmosphere_controller.gd`
- [x] `shaders/fog_volume.gdshader` (opcional)
- [x] `resources/atmosphere_presets/calm.tres`, `threat_5.tres`, `threat_10.tres`, `nightmare.tres`

### M25
- [x] `scripts/data/structure_data.gd`
- [x] `data/structures/barricade.tres`, `watch_tower.tres`, `scrap_wall.tres`, `generator.tres`, `spotlight.tres`
- [x] `scenes/structures/structure_base.tscn`
- [x] `scripts/structures/structure_base.gd`
- [x] `scenes/structures/barricade.tscn`, `watch_tower.tscn`, `scrap_wall.tscn`, `generator.tscn`, `spotlight.tscn`
- [x] `scripts/systems/build_grid.gd`
- [x] `scripts/systems/camp_builder.gd`
- [x] `scenes/ui/build_catalog.tscn`
- [x] `scripts/ui/build_catalog.gd`
- [x] `scenes/ui/build_catalog_item.tscn`
- [x] `scripts/ui/build_catalog_item.gd`
- [x] `scenes/structures/camp_upgrade_visuals/` (duas cenas)
- [x] Modificar `project.godot` / input map e `autoload/settings_manager.gd`
- [x] Modificar `autoload/save_manager.gd` (secção `base_layout`)

---

## Ordem de implementação sugerida

1. **M24 primeiro** — é mais "artístico" e não bloqueia nada. Começa pelos props (24.2) e atmosfera (24.4), que dão maior impacto visual imediato.
2. **M25 em paralelo** — mas só depois de teres a economia de Scrap estável (já tens). Começa pela data layer (25.2) e grelha (25.4), depois UI (25.6), e só no fim a persistência (25.7) e integração visual (25.8).

---

*Ficheiro gerado a partir da análise do OVERVIEW.md do projeto Horde Breaker.*
