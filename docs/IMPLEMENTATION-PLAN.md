> ## ⚠️ ERRATAS — ler antes de agir sobre este plano
>
> Verificadas contra o código em 2026-07-27. O plano descreve o projeto como
> estava algumas sessões antes e tem uma sugestão que introduziria um bug.
> Os itens já triados estão em `TODO.md`.
>
> | Ponto | O que está errado |
> |---|---|
> | **Tarefa 3** — baixar `load_distance` para 48 | **Não fazer.** Os centros dos setores estão a 64 m; 72 m existe para os apanhar. Com 48, um setor vizinho só carregaria quando o jogador já estivesse quase dentro dele — buracos visíveis à frente. Se o arranque está lento, medir primeiro. |
> | **Tarefa 6** — integrar Mixamo | O Mixamo foi **apagado do repositório**; não há nada a aguardar autorização. |
> | **Tarefa 7** — ESC nas definições | Correto: **já funciona** (`settings_menu.gd`, `_input`). Nada a fazer. |
> | **Tarefa 5** — editar os presets à mão | Os `.tres` de atmosfera são reescritos por `tools/apply_skyboxes.gd`. A alteração tem de ser feita na ferramenta, senão perde-se. |
> | **Tarefa 9** — "as três classes" | São **duas**. O Medic está parqueado via `is_selectable`. |
> | **Tarefa 1** — `camp_builder.gd` "implementado" | O script existe, mas o **nó foi removido da arena**; terá de ser religado. |
> | Estimativas | Otimistas nas duas primeiras. "Percorrer todos os setores manualmente" em 8h dá 7 minutos por setor, para 64 setores. |

🧟 Horde Breaker – Plano de Implementação

Data: 27 de julho de 2026
Versão do projeto: Horde Breaker (survival zombie / open world 8x8)
Estado atual: Código base maduro; faltam tarefas de integração, balanceamento e polimento.
📌 Análise Geral

O projeto Horde Breaker está num estado muito avançado. Os sistemas principais – progressão permanente, combate, streaming do mundo, construção de base, economia, árvore de skills, armory e UI – estão implementados e funcionais. A arquitetura é sólida, com uso adequado de autoloads, sinais, grupos e worker threads.

O que falta agora são tarefas de integração, correção de bugs conhecidos, balanceamento e polimento final para que o jogo fique jogável do início ao fim.
🟥 Tarefas Críticas (Impedem o jogo de ser jogável)
1. Restaurar a Base (Camp) no Mundo 8×8

Estado atual:
O camp_core.gd, camp_economy.gd, camp_builder.gd e build_grid.gd estão implementados, mas o acampamento foi removido do mundo durante a migração para o mapa 8x8. Atualmente, o setor (0,0) está vazio.

O que falta:

    Garantir que o setor (0,0) contenha a cena do acampamento (com CampCore, BuildGrid, CampEconomy, UpgradeStations e FortificationSites).

    Verificar que o PlayerSpawner coloca o jogador na posição correta do acampamento.

    Validar que o CampBuilder carrega o layout salvo (SaveManager.get_base_layout()) e instancia as estruturas no built_container.

    Assegurar que a interação [F] no CampCoreInteraction funciona (depósito de scrap e reparação).

Solução proposta:

    Criar uma cena camp_sector.tscn que contenha:

        CampCore (com CampCoreInteraction, HealthLabel, CoreLight)

        BuildGrid (com GridVisual)

        CampEconomy (se não for autoload)

        UpgradeStations para as três melhorias

        FortificationSites pré-colocados

        PickupRandomizer para loot do acampamento

    No world_streamer.gd, adicionar uma função para carregar esta cena no setor CAMP_COORDS:

gdscript

func _load_camp_sector() -> void:
    var camp_scene := load("res://scenes/world/camp_sector.tscn")
    if camp_scene == null:
        push_error("Camp scene not found.")
        return
    var camp := camp_scene.instantiate() as Node3D
    if camp == null:
        return
    camp.position = Vector3.ZERO
    add_child(camp)
    _instances[&"camp_sector"] = camp
    sector_loaded.emit(&"camp_sector")

    Chamar _load_camp_sector() no _ready() do world_streamer, após a construção da grelha.

    No camp_builder.gd, verificar que load_base_layout() é chamado após a cena estar na árvore.

2. Corrigir Inconsistências do Mapa 8×8

Estado atual:
A documentação (MAP_DESIGN.md) menciona inconsistências encontradas no playtest com o novo mapa de 8×8.

O que falta:

    Catalogar e corrigir:

        Colisões de edifícios/paredes com o terreno.

        Navegação (NavMesh) em áreas com objetos pintados no GridMap.

        Posicionamento de POIs, spawns e loot para não ficarem dentro de paredes.

        Transições entre setores (continuidade visual e de navegação).

Solução:

    Percorrer todos os setores manualmente no editor e ajustar:

        A pintura do GridMap (blocos de construção, estradas, vegetação).

        Os NavigationRegion3D (regenerar navmesh após alterações).

        Os marcadores (Marker3D) de spawn, loot e POIs.

    Utilizar o GridMapObstacles para garantir que as células pintadas bloqueiam a navegação corretamente.

    Ajustar MINIMUM_BLOCKING_HEIGHT (0.5) se necessário.

3. Otimizar Arranque da Arena (Modo Headless)

Estado atual:
O arranque com o mapa 8×8 ficou lento, especialmente em modo headless (servidor dedicado).

O que falta:

    Reduzir a quantidade de setores carregados no início.

    Melhorar a eficiência da geração em threads.

    Evitar pedidos de carga redundantes.

Solução:

No world_streamer.gd:

    Reduzir load_distance para 48 (em vez de 72).

    Reduzir unload_distance para 64 (em vez de 96).

    Na _physics_process, adicionar uma verificação para evitar pedir carga de setores já em processo.

gdscript

func _is_sector_loading_or_loaded(sector_id: StringName) -> bool:
    return (
        _instances.has(sector_id)
        or _request_started_ticks.has(sector_id)
        or _generation_tasks.has(sector_id)
    )

E no _physics_process:
gdscript

if distance <= load_distance and not _is_sector_loading_or_loaded(sector_id):
    request_sector_load(sector_id)

🟨 Tarefas Importantes (Melhoram a experiência de jogo)
4. Spawns em Marker3D (em vez de procedural)

Estado atual:
O SectorGenerator coloca Marker3D de spawn de forma aleatória dentro do setor.

O que falta:
Permitir que os spawns sejam colocados à mão no editor, para um design de níveis mais controlado.

Solução:

    Criar um recurso SectorData.tres por setor, contendo listas de posições para:

        Spawns de inimigos (normais, runners, etc.)

        Loot (scrap, ammo, health, weapons)

        POIs (hospitais, armazéns, postos militares)

    Modificar o SectorGenerator.add_content_stage() para ler estas posições em vez de gerar aleatoriamente.

    Para setores sem dados manuais, manter a geração procedural como fallback.

Código exemplo:

No sector_generator.gd, modificar _add_caches, _add_ammo_box, _add_weapon_crate e _add_spawn_markers para aceitarem listas de posições do config.
5. Configurar Efeitos Gráficos (Forward+)

Estado atual:
O AtmosphereController já troca o Environment conforme o nível de ameaça, mas os efeitos de pós-processamento (SSAO, SSIL, nevoeiro volumétrico) podem estar desativados nos presets.

O que falta:

    Ativar ssao_enabled, ssil_enabled e ajustar o nevoeiro volumétrico nos recursos de ambiente.

    Ajustar os Environment presets (calm.tres, threat_5.tres, threat_10.tres, nightmare.tres) para incluírem estas configurações.

Solução:

    Abrir cada .tres no editor e ativar:

        Ambient Light (definir como Sky ou Color).

        SSAO (ativar e ajustar intensidade).

        SSIL (ativar).

        Volumetric Fog (ativar e ajustar densidade).

    Testar o desempenho em diferentes setores.

6. Integrar Animações Mixamo

Estado atual:
O imported_model_animation.gd já suporta animações, mas os modelos atuais são placeholders.

O que falta:
Substituir os placeholders pelos modelos finais do Mixamo (aguarda autorização).

Solução:

    Quando os modelos estiverem disponíveis, substituir os ficheiros .gltf em assets/models/.

    Verificar se os nomes das animações coincidem com os usados no script (Idle, Run, Attack, etc.).

    Ajustar EMBEDDED_WEAPON_NAMES se os nomes das armas embutidas forem diferentes.

7. Menu de Definições – Tecla ESC

Estado atual: Já funcional. O settings_menu.gd lida com ESC para fechar. Nada a fazer.
8. Afinar os 64 Setores (Balanceamento)

O que falta:

    Distribuição de loot (scrap, munição, saúde, armas) por setor.

    Quantidade e tipo de inimigos em emboscadas.

    Localização de POIs (hospital, armazém, posto militar, estação) para criar rotas interessantes.

    Ajustar a densidade de obstáculos e cobertura para o combate.

Solução:

    Criar um recurso SectorConfig.tres por setor, com parâmetros como:

        loot_density (0-1)

        enemy_density (0-1)

        poi_type (hospital, warehouse, military, fuel_station, etc.)

        spawn_count_normal, spawn_count_runner, etc.

    Ajustar manualmente no editor, utilizando a visão de cima.

9. Revisão do Balanço de Combate

O que falta:

    Testar com as três classes e ajustar dano, cadência, alcance automático, regeneração, etc.

    Verificar se o sistema de knockback e headshot está equilibrado.

    Ajustar a progressão da ameaça (níveis de onda) para que a dificuldade aumente de forma gradual.

Solução:

    Realizar playtests com diferentes classes e anotar o tempo de sobrevivência e kills.

    Ajustar valores nos recursos:

        WeaponData (damage, fire_rate, magazine_size, reload_duration)

        CharacterData (base_health, regeneration_rate)

        WaveManager (base_max_alive, max_alive_per_level, level_up_interval)

    Utilizar a ferramenta de debug (FPS overlay) para monitorizar o desempenho.

🟩 Tarefas Opcionais (Polimento e Conteúdo)
10. Evoluir o Graybox para Mapa Final

    Substituir os modelos de graybox por modelos finais de ambiente (edifícios, estradas, vegetação).

    Adicionar decoração, iluminação, partículas (fogo, fumo, etc.).

11. Sistema de Som e Música

    Adicionar sons para armas, passos, ambiente, música dinâmica.

    Expandir o HitSoundLibrary para outros eventos.

12. Sistema de Partículas para Efeitos

    Sangue, explosões, fogo, poeira, etc. (usando o sistema de partículas do Godot).

13. Melhorias na UI

    Animações mais refinadas, feedback tátil (vibration), tooltips detalhados.

    Indicadores visuais para direção do dano, alertas de munição baixa, etc.

14. Suporte para Controlador (Gamepad)

    Mapeamento de inputs para gamepad (já existe InputMap com ações, mas é preciso testar e ajustar).

15. Localização (i18n)

    Preparar o jogo para múltiplos idiomas (inglês já está, português pode ser adicionado).

📊 Resumo das Tarefas por Prioridade
Prioridade	Tarefa	Descrição	Estimativa
🟥 Crítica	1. Restaurar Base	Reintegrar o acampamento no mundo 8×8.	4h
🟥 Crítica	2. Inconsistências do Mapa	Corrigir colisões, navegação, posicionamento.	8h
🟥 Crítica	3. Otimizar Arranque	Reduzir distâncias de carga e melhorar a inicialização.	2h
🟨 Importante	4. Spawns em Marker3D	Permitir posicionamento manual de spawns.	3h
🟨 Importante	5. Efeitos Gráficos	Ativar SSAO, SSIL, nevoeiro volumétrico.	1h
🟨 Importante	6. Animações Mixamo	Integrar modelos finais.	2h
🟨 Importante	8. Afinar Setores	Balancear loot, inimigos, POIs por setor.	6h
🟨 Importante	9. Balanço de Combate	Ajustar valores de armas, inimigos, classes.	4h
🟩 Opcional	10. Mapa Final	Substituir graybox por arte final.	20h
🟩 Opcional	11. Som e Música	Adicionar áudio.	8h
🟩 Opcional	12. Partículas	Efeitos visuais.	6h
🟩 Opcional	13. UI	Melhorias de feedback.	4h
🟩 Opcional	14. Gamepad	Suporte a controladores.	3h
🟩 Opcional	15. Localização	Traduções.	2h
🔧 Sugestões de Código para Tarefas Críticas
1. Restaurar a Base – Código adicional

No world_streamer.gd:
gdscript

func _ready() -> void:
    # ... código existente ...
    _load_camp_sector()

func _load_camp_sector() -> void:
    var camp_scene := load("res://scenes/world/camp_sector.tscn")
    if camp_scene == null:
        push_error("Camp scene not found.")
        return
    var camp := camp_scene.instantiate() as Node3D
    if camp == null:
        return
    camp.position = Vector3.ZERO
    add_child(camp)
    _instances[&"camp_sector"] = camp
    sector_loaded.emit(&"camp_sector")

3. Otimizar Arranque – Código adicional

No world_streamer.gd:
gdscript

@export_range(8.0, 200.0, 1.0) var load_distance: float = 48.0
@export_range(8.0, 240.0, 1.0) var unload_distance: float = 64.0

func _physics_process(_delta: float) -> void:
    # ... código existente ...
    for sector_id in _definitions_by_id:
        var definition: Dictionary = _definitions_by_id[sector_id]
        var distance := _player.global_position.distance_to(
            Vector3(definition["position"])
        )
        if distance <= load_distance:
            if not _is_sector_loading_or_loaded(sector_id):
                request_sector_load(sector_id)
        elif distance >= unload_distance:
            unload_sector(sector_id)

func _is_sector_loading_or_loaded(sector_id: StringName) -> bool:
    return (
        _instances.has(sector_id)
        or _request_started_ticks.has(sector_id)
        or _generation_tasks.has(sector_id)
    )

🧪 Plano de Testes

Após cada tarefa crítica, realizar:

    Teste de arranque: O jogo inicia sem erros e o acampamento aparece.

    Teste de navegação: Os inimigos conseguem percorrer o mapa e chegar ao jogador.

    Teste de loot: Scrap, munição e armas aparecem nos locais esperados.

    Teste de desempenho: FPS mantém-se acima de 30 em zonas com 100+ inimigos.

    Teste de progressão: XP, créditos, skills e mastery são guardados corretamente.

🏁 Conclusão

Com a conclusão das tarefas críticas, o jogo ficará jogável do início ao fim, com o core loop funcional (explorar → combater → recolher loot → melhorar base e personagem → extrair). As tarefas importantes e opcionais podem ser realizadas posteriormente para polir e expandir a experiência.