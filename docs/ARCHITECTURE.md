# Horde Breaker — Arquitetura Técnica

## Princípios

- Construir verticalmente: uma pequena experiência completa antes de expandir.
- Separar dados estáticos de estado em execução.
- Usar sinais para eventos importantes.
- Evitar dependências globais desnecessárias.
- Manter cenas pequenas e reutilizáveis.
- Não otimizar prematuramente.

## Sistemas globais e locais

- `SaveManager` persiste progresso, desbloqueios e seleções com `ConfigFile`.
- `GameManager` centraliza as mudanças entre menu principal, seleção e arena.
- `WaveManager` controla localmente ataques contínuos, spawns, ciclos e inimigos vivos.
- `CampEconomy` mantém o Scrap transportado e armazenado durante a partida e emite alterações para o HUD.
- `CharacterProgression` atribui recompensas à personagem selecionada através do `SaveManager`.
- `WeaponController` cria os dois slots da classe, ativa apenas uma arma e trata a troca com `1`/`2`.

## Cenas planeadas

```text
scenes/
  world/
    test_arena.tscn
    camp_core.tscn
    fortification_site.tscn
    city_road_grid.tscn
    exploration_pois.tscn
    arena.tscn
    spawn_point.tscn
  characters/
    player_base.tscn
    recruit.tscn
    renegade.tscn
    medic.tscn
  enemies/
    enemy_base.tscn
    normal_zombie.tscn
    runner_zombie.tscn
  weapons/
    assault_rifle.tscn
    pistol.tscn
    shotgun.tscn
    sword.tscn
  projectiles/
    bullet.tscn
  ui/
    game_hud.tscn
    pause_menu.tscn
    wave_complete_panel.tscn
    game_over_panel.tscn
  menus/
    main_menu.tscn
    character_selection.tscn
```

A árvore será criada progressivamente. Não criar todas as cenas no arranque.

## Cena de jogador provisória

Estrutura prevista:

```text
Player (CharacterBody3D)
  CollisionShape3D
  InteractionArea (Area3D)
  VisualRoot (Node3D)
    Visual (MeshInstance3D)
    WeaponPivot (Marker3D + WeaponController)
      PrimaryWeapon (runtime)
      SecondaryWeapon (runtime, opcional)
  CameraPivot (Node3D)
    ShoulderOffset (Node3D)
      SpringArm3D
        Camera3D
```

O script do jogador deve tratar inicialmente:

- movimento;
- gravidade;
- rotação;
- andar, corrida, salto e agachamento;
- interação com objetos próximos;
- estado de vida.

O combate deve ficar num componente ou controlador próprio quando começar a crescer.

## Combate provisório

- Um ponto de mira fixo no centro do HUD define a direção visual do disparo.
- O primeiro raycast parte da câmara e encontra o ponto visado; o segundo parte do cano até esse ponto.
- O segundo raycast impede que a arma dispare através de uma parede entre o cano e o alvo.
- O raycast deteta a layer 1 (`World`) e as `DamageHitbox` da layer 3.
- `BodyHitbox` usa multiplicador `1.0` e `HeadHitbox` usa provisoriamente `2.0`; ambas delegam o dano no zombie que implementa `take_damage(amount)`.
- `DamageNumber3D` apresenta o dano realmente aplicado no ponto atingido; impactos no corpo usam texto claro e headshots usam texto dourado.
- A arma orienta-se para o ponto visado e o tracer parte do cano até ao impacto real.
- Cada arma de fogo mantém carregador e reserva próprios, emite alterações dos dois valores e transfere apenas a munição disponível durante `reload`.
- Assault Rifle, Pistol e Shotgun começam respetivamente com reservas de 90, 48 e 32 munições.
- A Pistol reutiliza o hitscan, mas dispara apenas uma vez por clique e usa um carregador de 12 munições.
- A Shotgun dispara oito raycasts com dispersão, consome uma munição por ataque e é semiautomática.
- O `WeaponController` instancia o loadout indicado por `CharacterData`, desativa a arma guardada e troca os slots através de `weapon_primary` e `weapon_secondary`.
- O multiplicador de recarga da classe é aplicado a todas as armas de fogo criadas pelo controlador.
- `ShoulderOffset` desloca a câmara 0,9 m para a direita para o jogador não tapar a mira; o raycast continua a partir do centro ótico da câmara.
- O botão direito do rato aproxima a câmara para uma mira sobre o ombro, reduzindo suavemente o FOV e o comprimento do `SpringArm3D`.
- Manter `C` premido coloca temporariamente a câmara em frente da personagem e libertar a tecla repõe a órbita anterior.
- A Worn Sword consulta um volume frontal na layer 3, aplica 50 de dano base a cada inimigo válido e usa cooldown de 0,6 segundos.
- Um raycast curto a partir do centro da câmara identifica se a cabeça do alvo principal está sob a mira e aplica também à espada o multiplicador da `HeadHitbox`.
- Corpo e cabeça são deduplicados por zombie para que o mesmo golpe nunca aplique dano duas vezes ao mesmo inimigo.
- O volume frontal é uma aproximação retangular simples de um golpe em arco e usa uma consulta direta ao servidor de física no instante do ataque.
- Antes de aplicar dano melee, um raycast na layer 1 (`World`) confirma que não existe uma cobertura entre a espada e o alvo.

## Movimento e interação

- A velocidade base corresponde a andar; `Shift` ativa a corrida enquanto existir direção de movimento.
- `Space` salta apenas quando a personagem está no chão e não está agachada.
- `Ctrl` reduz a altura da cápsula, baixa a câmara e limita a velocidade. A personagem só volta a levantar-se quando existe espaço livre por cima.
- `F` procura o `Area3D` interagível mais próximo dentro de `InteractionArea` e chama o método `interact(player)`.
- O pickup de teste acrescenta munições à reserva de uma arma de fogo do loadout, mesmo quando a personagem tem uma arma melee ativa.
- O `WeaponController` tenta primeiro a arma ativa e depois o outro slot; o pickup só desaparece quando alguma reserva recebe pelo menos uma munição.
- `ScrapPickup` acrescenta 25 unidades ao Scrap transportado e só desaparece após uma recolha válida.
- `HealthPickup` chama `heal` no jogador, recupera até 40 pontos de vida e só fica indisponível após uma cura real. Escuta `cycle_completed` para voltar a mostrar o visual e reativar a colisão.
- A área de interação do `CampCore` deposita primeiro todo o Scrap transportado; sem Scrap transportado, tenta reparar o núcleo durante a exploração.
- `FortificationInteraction` delega a ação do volume interagível no `FortificationSite`, que constrói ou repara conforme o seu estado.

## Cena de inimigo provisória

```text
NormalZombie (CharacterBody3D)
  CollisionShape3D
  BodyHitbox (Area3D)
  HeadHitbox (Area3D)
  Visual (MeshInstance3D)
  NavigationAgent3D
  AttackArea (Area3D)
```

Responsabilidades:

- encontrar o jogador;
- pedir caminho;
- mover-se;
- atacar dentro do alcance;
- receber dano;
- emitir sinal de morte.

A cápsula do `CharacterBody3D` permanece responsável apenas pelo movimento e usa
`collision_layer = 0`. `BodyHitbox` e `HeadHitbox` ocupam a layer 3 para separar
colisão física de deteção de dano. O Runner herda as duas zonas da cena base.

## Arena

```text
TestArena (Node3D)
  Environment
  DirectionalLight3D
  RoadNorthWest
  RoadNorthEast
  RoadSouthWest
  RoadSouthEast
  ExplorationPOIs
  Floor
  Walls
  Obstacles
  NavigationRegion3D
  PlayerSpawn
  CampCore
  FortificationSite
  Pickups
  EnemySpawns
  Gameplay
```

A arena mede 64 × 64 metros e instancia quatro cópias rodadas de
`city_road_grid.tscn`, que contém apenas os 16 módulos CC0 de estrada. A antiga
`city_test_map.tscn` fica preservada como referência, mas já não é instanciada na
arena. O piso graybox continua a fornecer a colisão, mas a sua malha está oculta.

`exploration_pois.tscn` reúne quatro zonas identificadas pelo grupo
`point_of_interest`: `HospitalPOI`, `WarehousePOI`, `MilitaryOutpostPOI` e
`FuelStationPOI`. Cada uma possui uma silhueta, cor, etiqueta e um `AccessPoint`
no grupo `poi_access_point`. Os contentores, camião e torre de água importados são
reutilizados uma única vez como elementos específicos destas zonas.

O `WarehousePOI` é o primeiro edifício explorável. O antigo volume fechado foi
substituído por paredes segmentadas, teto e uma entrada central de cinco metros.
As paredes continuam no grupo `navigation_blocker`, enquanto o ponto navegável
interior pertence a `poi_interior_point`. `WarehouseEncounter` observa apenas a
layer 2 (`Player`), ativa dois Normal Zombies durante a exploração e mantém a
emboscada disponível uma vez por ciclo. O mesmo componente instancia as cenas
existentes de `ScrapPickup` e `AmmoPickup` e repõe apenas pickups já recolhidos
quando recebe `cycle_completed`.

O `HospitalPOI` reutiliza a mesma construção por paredes segmentadas e possui um
segundo `InteriorPoint` no grupo `poi_interior_point`. Não tem encontro hostil
nesta etapa: contém duas camas graybox e uma instância única de `HealthPickup` na
layer 4, alcançável pela interação do jogador. A reposição altera a mesma instância
em vez de criar pickups adicionais.

O `MilitaryOutpostPOI` é o terceiro interior. `MilitaryOutpostEncounter` chama
`spawn_exploration_enemies` separadamente para dois Normal Zombies e um Runner,
mas acompanha os três como um único encontro disponível uma vez por ciclo. As duas
instâncias de `AmmoPickup` são criadas nos marcadores locais, repostas apenas quando
estão ausentes e nunca alteram `alive_enemy_count`.

As quatro paredes graybox deixaram de ter representação visual. As colisões de
segurança permanecem temporariamente em ±32,5 metros para impedir que o jogador
caia para fora da arena enquanto o mapa não possuir limites definitivos. As
barreiras internas duplicadas dos módulos estão ocultas.

Os edifícios graybox, contentores, camião e torre de água mantêm coberturas
estáticas na layer 1 (`World`). As três colisões graybox anteriores foram
desativadas, mas os nós foram preservados. Os obstáculos que devem bloquear caminhos pertencem ao grupo
`navigation_blocker` e usam um `CollisionShape3D` com `BoxShape3D` chamado
`Collision`.

`arena_navigation.gd` cria em runtime uma grelha navegável de 1 metro até 31,5
metros do centro e exclui as células ocupadas pelas coberturas ativas, incluindo
uma margem de segurança. O cálculo projeta também os volumes rodados de cada
bairro na grelha. Esta solução mantém o protótipo simples e deverá ser substituída por uma navmesh feita
no editor quando a geometria deixar de ser composta por caixas alinhadas aos eixos.

Esta grelha global fica limitada ao mapa atual. A proposta de mundo aberto em
`docs/OPEN_WORLD_PLAN.md` substitui-a por uma `NavigationRegion3D` por setor e
carregamento assíncrono de cenas; nenhum streaming foi implementado neste milestone.

`FortificationSite` também pertence a `navigation_blocker`, mas começa com a
colisão desativada. Construir ou destruir a barricada volta a gerar a grelha para
adicionar ou remover as células bloqueadas.

`PlayerSpawn` usa `player_spawner.gd` para instanciar a cena indicada pelo
`CharacterData` da personagem selecionada e configura vida, regeneração, recarga e
loadout antes de adicionar o jogador à árvore. Recruit, Renegade e Medic continuam
a usar cápsulas provisórias com materiais distintos.

## Survival e game over provisório

- O jogador mantém a sua vida em execução e emite `health_changed` e `died`.
- `CampCore` é um `StaticBody3D` com 500 pontos de vida, sinais `health_changed` e `destroyed` e um volume físico legível na arena.
- Jogador, núcleo e barricada construída pertencem ao grupo `enemy_target`; cada zombie escolhe por distância o alvo vivo mais próximo.
- O núcleo recebe `take_enemy_damage` dos zombies; continua a bloquear tiros como geometria de mundo, mas não aceita dano das armas do jogador.
- Ao morrer, o jogador sai do grupo de alvos; ao chegar a zero, o núcleo faz o mesmo e emite `destroyed`.
- O painel local de game over escuta `died` e `destroyed`, apresenta a causa, liberta o rato e pausa a árvore.
- O botão de reinício repõe a pausa e recarrega a cena atual.
- O painel de derrota também permite regressar ao menu através do `GameManager`.
- `CampEconomy` começa com zero Scrap transportado e armazenado; ambos são estado apenas da partida atual.
- Existem oito `ScrapPickup` estáticos nas zonas exteriores e um no armazém, reposto após cada ciclo se tiver sido recolhido.
- Existe um `HealthPickup` no hospital; cura imediatamente até 40 pontos e é reposto no fim de cada ciclo se tiver sido utilizado.
- Existem dois `AmmoPickup` no posto militar, repostos no fim de cada ciclo apenas quando já foram recolhidos.
- `CampCoreInteraction` converte 1 Scrap armazenado em 5 pontos de vida, até 50 por interação, apenas durante a exploração.
- `FortificationSite` começa vazio, custa 30 Scrap, tem 200 pontos de vida quando construído e reutiliza a mesma taxa de reparação do núcleo.
- A barricada é um `StaticBody3D` na layer 1/2, pelo que bloqueia jogador, disparos e zombies e é detetada pelas áreas de ataque inimigas.
- Aos zero pontos de vida, remove-se de `enemy_target`, desativa a colisão e regressa ao estado de ponto de construção.

## Pausa

- `pause_menu.tscn` processa sempre a ação `pause`, mesmo quando a árvore está pausada.
- `Esc` apresenta o painel, pausa a árvore, liberta o rato e volta ao jogo quando premido novamente.
- Os botões permitem continuar, regressar ao menu principal ou sair.
- O painel não abre sobre os estados de vitória ou derrota, que já pausam a árvore.

## Ataques contínuos provisórios

- O `WaveManager` local lê uma lista tipada de recursos `WaveData` e cria os inimigos nos marcadores da arena.
- O gestor mantém a contagem de inimigos vivos e recebe o sinal `died` de cada instância.
- A partida começa com 30 segundos de exploração e `wave_completed` inicia um intervalo configurável de 45 segundos.
- Os temporizadores de preparação respeitam a pausa da árvore; terminado o intervalo, o índice seguinte reutiliza ciclicamente os três `WaveData` existentes.
- Cada ciclo acrescenta dois Normal Zombies a todas as composições e emite `cycle_completed` após o terceiro ataque.
- `CharacterProgression` atribui 100 Credits em cada `cycle_completed`; já não existe vitória automática após três ataques.
- `WaveManager.spawn_exploration_enemies` coloca ameaças locais no contentor comum e emite a recompensa de XP quando morrem, sem alterar `alive_enemy_count` ou a conclusão da vaga.
- O Runner herda a cena do Normal Zombie e altera apenas atributos e material provisório.

## HUD provisório

- O HUD local descobre jogador, núcleo, `CampEconomy`, arma opcional e `WaveManager` através de grupos estáveis.
- Sinais atualizam vida do jogador, vida do núcleo, munição, ataque, inimigos restantes, contagem da exploração e Scrap sem polling por frame.
- A barra de vida e os contadores não controlam gameplay; apenas apresentam o estado.
- O HUD mostra a arma ativa, os dois slots e as teclas `1`/`2`.
- A mira é apresentada com armas de fogo e com a Worn Sword, permitindo apontar ataques melee à cabeça.
- Um painel de recursos distingue Scrap transportado de Scrap na base e mensagens curtas confirmam recolha, depósito e reparação.

## Menus e seleção

- `main_menu.tscn` apresenta Credits, classe, passivo, loadout e progresso atual.
- `character_selection.tscn` permite desbloquear e selecionar Recruit, Renegade ou Medic.
- Os loadouts atuais são fixos por classe; o segundo slot do Medic fica vazio até ser definida uma opção adequada.
- A compra de personagens e armas passa sempre pelo `SaveManager`.
- `WeaponData.is_playable` impede equipar uma arma que ainda só exista como dado estático.
- A cena principal é o menu; `GameManager` abre a seleção, inicia a arena ou regressa ao menu.

## Layers de física propostas

| Layer | Utilização |
|---:|---|
| 1 | World |
| 2 | Player e alvos atacáveis do acampamento |
| 3 | Enemy damage hitboxes |
| 4 | Pickups |
| 5 | Enemy attacks (futuro) |
| 6 | Player projectiles (futuro) |

Só configurar as layers quando forem necessárias e manter esta tabela atualizada.

## Sinais planeados

```gdscript
signal health_changed(current_health: float, maximum_health: float)
signal died
signal enemy_died(enemy: Node)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal intermission_started(next_wave: int, duration: float)
signal preparation_time_changed(seconds_remaining: int)
signal cycle_completed(cycle_number: int)
signal scrap_changed(carried_scrap: int, stored_scrap: int)
signal built
signal destroyed
signal xp_gained(amount: int)
signal level_up(new_level: int)
```

## Dados

### CharacterData

Campos atuais:

- id;
- display_name;
- character_scene;
- unlock_cost;
- maximum_level;
- base_health;
- primary_weapon_id;
- secondary_weapon_id;
- reload_duration_multiplier;
- health_regeneration_rate;
- health_regeneration_delay;
- class_description.

### WeaponData

Campos atuais:

- id;
- display_name;
- required_character_id;
- required_level;
- credit_cost;
- is_playable;
- weapon_scene.

### EnemyData

Campos possíveis:

- id;
- maximum_health;
- move_speed;
- damage;
- attack_range;
- attack_cooldown;
- xp_reward;
- scrap_reward.

### WaveData

Campos atuais:

- normal_zombie_count;
- runner_zombie_count.

## Save permanente

Local:

```text
user://horde_breaker_save.cfg
```

Estrutura atual:

```ini
[profile]
credits=0
selected_character="recruit"

[recruit]
unlocked=true
level=1
xp=0
selected_primary_weapon="assault_rifle"
selected_secondary_weapon="pistol"
purchased_weapons=["assault_rifle", "pistol"]

[renegade]
unlocked=false
level=1
xp=0
selected_primary_weapon="shotgun"
selected_secondary_weapon="worn_sword"
purchased_weapons=["shotgun", "worn_sword"]

[medic]
unlocked=false
level=1
xp=0
selected_primary_weapon="pistol"
selected_secondary_weapon=""
purchased_weapons=["pistol"]
```

O `SaveManager` cria valores em falta, guarda XP imediatamente e persiste Credits,
nível, XP, personagens desbloqueadas, armas compradas e seleções. Saves anteriores
são migrados pela adição dos valores em falta, sem apagar progresso existente.
