# Horde Breaker — Arquitetura Técnica

## Princípios

- Construir verticalmente: uma pequena experiência completa antes de expandir.
- Separar dados estáticos de estado em execução.
- Usar sinais para eventos importantes.
- Evitar dependências globais desnecessárias.
- Manter cenas pequenas e reutilizáveis.
- Não otimizar prematuramente.

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

- O disparo básico do Recruit usa hitscan a partir do centro da câmara ativa.
- O raycast deteta a layer 1 (`World`) e a layer 3 (`Enemies`).
- Um alvo que implemente `take_damage(amount)` recebe o dano configurado na arma.
- O clarão do cano e um tracer temporário fornecem feedback visual.
- Munição e recarga ficam fora do Milestone 4.

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

## Save futuro

Local:

```text
user://horde_breaker_save.cfg
```

Estrutura conceptual:

```ini
[profile]
credits=0
selected_character="recruit"

[recruit]
unlocked=true
level=1
xp=0
selected_weapon="assault_rifle"
purchased_weapons=["assault_rifle"]

[renegade]
unlocked=false
level=1
xp=0
selected_weapon="worn_sword"
purchased_weapons=["worn_sword"]

[records]
highest_wave=0
total_enemies_defeated=0
```

O SaveManager só será criado na fase de progressão.
