# Horde Breaker — Arquitetura Técnica

## Princípios

- Construir verticalmente: uma pequena experiência completa antes de expandir.
- Separar dados estáticos de estado em execução.
- Usar sinais para eventos importantes.
- Evitar dependências globais desnecessárias.
- Manter cenas pequenas e reutilizáveis.
- Não otimizar prematuramente.

## Sistemas globais e locais

- `SaveManager` é o único Autoload atual e persiste progresso com `ConfigFile`.
- `GameManager` permanece futuro até existirem menus e mudanças de cena globais.
- `WaveManager` controla localmente rondas, spawns e inimigos vivos.
- `CharacterProgression` atribui recompensas da sessão ao Recruit através do `SaveManager`.

## Cenas planeadas

```text
scenes/
  world/
    test_arena.tscn
    arena.tscn
    spawn_point.tscn
  characters/
    player_base.tscn
    recruit.tscn
    renegade.tscn
  enemies/
    enemy_base.tscn
    normal_zombie.tscn
    runner_zombie.tscn
  weapons/
    assault_rifle.tscn
    shotgun.tscn
    sword.tscn
  projectiles/
    bullet.tscn
  ui/
    game_hud.tscn
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
  Visual (MeshInstance3D)
  CameraPivot (Node3D)
    SpringArm3D
      Camera3D
  WeaponPivot (Marker3D ou Node3D)
```

O script do jogador deve tratar inicialmente:

- movimento;
- gravidade;
- rotação;
- estado de vida.

O combate deve ficar num componente ou controlador próprio quando começar a crescer.

## Combate provisório

- Um ponto de mira fixo no centro do HUD define a direção visual do disparo.
- O primeiro raycast parte da câmara e encontra o ponto visado; o segundo parte do cano até esse ponto.
- O segundo raycast impede que a arma dispare através de uma parede entre o cano e o alvo.
- O raycast deteta a layer 1 (`World`) e a layer 3 (`Enemies`).
- Um alvo que implemente `take_damage(amount)` recebe o dano configurado na arma.
- A arma orienta-se para o ponto visado e o tracer parte do cano até ao impacto real.
- A Assault Rifle usa um carregador local, emite alterações de munição e recarrega através da ação `reload`.

## Cena de inimigo provisória

```text
NormalZombie (CharacterBody3D)
  CollisionShape3D
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

## Arena

```text
TestArena (Node3D)
  Environment
  DirectionalLight3D
  Floor
  Walls
  NavigationRegion3D
  PlayerSpawn
  EnemySpawns
  Gameplay
```

A arena de teste cria uma navmesh retangular em runtime através de
`arena_navigation.gd`. Esta solução é específica para a geometria plana do
protótipo e deverá ser substituída por uma navmesh feita no editor quando a
arena tiver obstáculos ou formas mais complexas.

## Game over provisório

- O jogador mantém a sua vida em execução e emite `health_changed` e `died`.
- O painel local de game over escuta o sinal `died`, liberta o rato e pausa a árvore.
- O botão de reinício repõe a pausa e recarrega a cena atual.
- Este fluxo permanece local à arena; ainda não requer um `GameManager` global.

## Ronda provisória

- O `WaveManager` local lê uma lista tipada de recursos `WaveData` e cria os inimigos nos marcadores da arena.
- O gestor mantém a contagem de inimigos vivos e recebe o sinal `died` de cada instância.
- `wave_completed` inicia um intervalo configurável e `all_waves_completed` ativa a vitória após a última ronda.
- O painel de vitória pausa a árvore e permite reiniciar a cena atual.
- O Runner herda a cena do Normal Zombie e altera apenas atributos e material provisório.

## HUD provisório

- O HUD local descobre jogador, arma e `WaveManager` através de grupos estáveis.
- Sinais atualizam vida, munição, ronda e inimigos restantes sem polling por frame.
- A barra de vida e os contadores não controlam gameplay; apenas apresentam o estado.

## Layers de física propostas

| Layer | Utilização |
|---:|---|
| 1 | World |
| 2 | Player |
| 3 | Enemies |
| 4 | Player projectiles |
| 5 | Enemy attacks |
| 6 | Pickups |

Só configurar as layers quando forem necessárias e manter esta tabela atualizada.

## Sinais planeados

```gdscript
signal health_changed(current_health: float, maximum_health: float)
signal died
signal enemy_died(enemy: Node)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal xp_gained(amount: int)
signal level_up(new_level: int)
```

## Dados futuros

### CharacterData

Campos possíveis:

- id;
- display_name;
- scene;
- unlock_cost;
- base_health;
- move_speed;
- starting_weapon_id.

### WeaponData

Campos possíveis:

- id;
- display_name;
- weapon_type;
- required_character_id;
- required_level;
- credit_cost;
- damage;
- fire_rate;
- magazine_size;
- reload_time.

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
level=1
xp=0
selected_weapon="assault_rifle"
purchased_weapons=["assault_rifle"]
```

O `SaveManager` cria valores em falta, guarda XP imediatamente e persiste Credits,
nível, XP, armas compradas e arma selecionada. A estrutura será expandida quando
o Renegade e os menus forem implementados.
