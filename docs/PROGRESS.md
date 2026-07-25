# Horde Breaker — Progresso

## Estado atual

Fase: survivors-like no combate (cartas de upgrade, orbes de XP) sobre um
mundo aberto 4x4 com cidade procedural, base construível e progressão
permanente. Última atualização: 2026-07-24.

> Histórico anterior ao Milestone 19 (rondas, protótipos iniciais, primeira
> arte) foi podado para manter este ficheiro legível — vive no histórico git.

## Concluído (do Milestone 19 em diante)

- [x] Rondas removidas e substituídas por um diretor de horda contínuo: os inimigos nascem em lotes à volta do jogador durante a viagem, com o nível de ameaça a subir a cada 75 s (mais zombies, mais Runners e intervalos de spawn mais curtos), limite simultâneo escalável e HUD com "THREAT LEVEL", "HOSTILES" e contagem para a próxima subida.
- [x] Spawns garantidos a pelo menos 12 m do jogador para dar tempo de reação, mantendo os seis pontos mais próximos e o desvio aleatório.
- [x] Alcance do disparo automático das armas de fogo aumentado de 3 para 6 metros.
- [x] Posições do Scrap e das munições do acampamento randomizadas a cada partida por `PickupRandomizer`, evitando marcos e o centro e sem sobreposição.
- [x] Setores gerados enriquecidos com torre de água e camião destroçado (com colisão e como `navigation_blocker`) e quatro postes de iluminação decorativos.
- [x] Acampamento transformado em zona de reabastecimento: ficar a menos de 12 m do núcleo cura o jogador e repõe munição de reserva por segundo, com aviso no HUD.
- [x] Mapa tático melhorado: setor atual destacado com moldura de acento, marcadores em losango para Scrap, munição e medkit, chip de acento no estilo do HUD e legenda alargada.
- [x] Todo o texto do jogo convertido para inglês: menus, HUD, painéis, etiquetas do mundo, feedback e descrições das classes.
- [x] Etiquetas 3D removidas das caches de Scrap e das caixas de munições; ambas passam a ser recolhidas automaticamente ao passar por cima (deteção do corpo do jogador na layer 2).
- [x] Delay de carregamento eliminado aumentando o raio de streaming para 95 m (descarga a 120 m), gerando os setores antes de entrarem no campo de visão.
- [x] Mapa tático melhorado: bússola Norte, moldura de acento no setor atual, tonalidade própria para setores já visitados, triângulos para caixas de arma, anéis para objetivos e legenda alargada.
- [x] HUD in-game reduzido ao essencial: vida compacta em baixo à esquerda, munição grande em baixo à direita com o nome da arma ativa, faixa de ameaça discreta no topo e contador de Scrap pequeno; removidas a placa do núcleo, a placa grande de recursos, o loadout `[1]/[2]` e a barra de atalhos.
- [x] Armas encontráveis pela exploração: caixas de arma geradas em cerca de um terço dos setores por seed, recolhidas com `F`, que substituem a arma secundária durante a partida e ficam com estado por setor.
- [x] `WeaponController.equip_field_weapon` adicionado para trocar o slot secundário em runtime; `AmmoPickup` e `ScrapPickup` emitem `collected` e suportam auto-recolha.
- [x] Variedade de inimigos alargada: **Brute** (tanque lento, 320 de vida, ataque forte com knockback), **Spitter** (mantém distância e dispara projéteis de ácido) e o boss **The Breaker** (1200 de vida, knockback e invocação periódica de minions).
- [x] Base `normal_zombie.gd` estendida com knockback configurável e modo de ataque à distância (aproximar/recuar/disparar) reutilizável; projétil `spit_projectile` criado.
- [x] Knockback do jogador implementado como impulso que decai por cima do input, aplicado por Brute e Boss.
- [x] Diretor de horda passou a escolher o tipo de inimigo por peso conforme o nível de ameaça (Runners cedo, Brutes a partir do nível 2, Spitters do nível 3) e a invocar um Boss a cada cinco níveis, com aviso no HUD.
- [x] Resolução por defeito baixada para janela 1152 × 648 (projeto e `SettingsManager`) para facilitar os testes; fullscreen e resoluções maiores continuam opcionais e persistidos.
- [x] Contador de FPS global adicionado como autoload `FpsOverlay`, sempre visível, com cor por faixa (verde/amarelo/vermelho) e alternável com `F3`.
- [x] Primeira ronda de otimização de desempenho: aquisição de alvo do disparo automático passou a fazer os raycasts por inimigo só algumas vezes por segundo (cache entre varreduras), corrigindo também um erro de objeto libertado; repath dos inimigos throttlado e escalonado (0,35 s) com cache do alvo do jogador; setores carregados em simultâneo reduzidos de ~9 para ~5 baixando o raio de streaming (72 m / descarga 96 m) para cortar draw calls no renderer GL Compatibility.
- [x] Geração de setores movida para threads de trabalho (`WorkerThreadPool`): a construção da subárvore (estradas, adereços, navegação) deixou de correr na thread principal, eliminando o "break" de ~230 ms ao entrar numa zona nova; o setor pronto é apenas adicionado à cena na thread principal, com o resultado descartado em segurança se o jogador se afastar entretanto.
- [x] Limite de níveis removido: as personagens sobem de nível sem teto e ganham um ponto de habilidade a cada dois níveis.
- [x] Árvore de habilidades permanente por personagem (`SkillTree`): três ramos (Ofensiva, Sobrevivência, Expedição) de cinco níveis, com pré-requisitos e níveis mínimos 2/5/9/14/20 por tier, guardada no save e aplicada a cada partida (dano, cadência, recarga, vida, regeneração, redução de dano, velocidade, reserva de munição, e multiplicadores de Scrap e XP).
- [x] Ecrã de skill tree acessível por um botão na seleção de personagens, que constrói os cartões dinamicamente com estados desbloqueado/disponível/bloqueado e pontos disponíveis.
- [x] "Field Upgrade" (painel de melhorias entre rondas) removido por completo, substituído pela skill tree permanente.
- [x] Ao equipar uma arma encontrada, a arma substituída é largada no chão como pickup, podendo ser reapanhada com `F`.
- [x] POIs com interiores exploráveis nos setores gerados: cerca de metade dos
  setores recebe um edifício graybox de 11 × 11 m (`SectorGenerator._add_poi_building`)
  com três muros sólidos e uma frente partida à volta de uma porta de 4 m. Os
  muros são `navigation_blocker`, por isso a porta é a única abertura que a grelha
  de navegação em runtime deixa livre — o jogador entra para recolher a cache de
  recompensa (50 de Scrap) e os inimigos perseguem-no para dentro pela mesma porta.
- [x] Cache interior do POI reutiliza o estado por setor sob um índice reservado
  (`POI_CACHE_INDEX`), não reaparecendo depois de recolhida durante a partida.
- [x] Cada POI ganhou um marcador no grupo `point_of_interest` (visível no mapa
  tático em `Tab`) e uma etiqueta 3D (OUTPOST/DEPOT/BUNKER/RUINS).
- [x] Ataques dos inimigos animados: novo `attack_animation` no componente
  `imported_model_animation.gd`, ligado ao sinal `attacked` que os zombies já
  emitem; Normal, Runner, Brute, Spitter (herdado) e Boss tocam `Idle_Attack`
  (1,67 s, sem loop) ao atacar, voltando à locomoção quando o clip termina. O
  jogador não é afetado (ataques continuam a vir dos sinais das armas).
- [x] Decisão de assets: manter Quaternius para todos os movimentos (Mixamo
  parqueado); todos os clips necessários já existem nos modelos atuais.
- [x] Emboscadas dos setores repostas por ciclo em vez de uma única por partida:
  o `WorldStreamer` liga-se ao sinal `cycle_completed` do diretor de horda e, a
  cada ciclo (~3 níveis de ameaça), re-arma a emboscada de todos os setores; uma
  guarda de inimigos vivos (`_ambush_enemies_cleared`) impede que uma nova vaga
  se sobreponha à anterior enquanto ainda está a ser combatida.

- [x] Estado do mundo persistido no save: seed fixo por perfil (o layout dos
  setores mantém-se entre partidas; loot volta a cada partida por decisão de
  design), setores visitados (memória do mapa tático) e farol este; secção
  `[world]` no `SaveManager`.
- [x] Melhorias da base compradas com Scrap armazenado: três pedestais junto ao
  núcleo (`camp_upgrade_station`) — Resupply Rate (+cura/+munição por segundo),
  Resupply Range (+raio) e Scavenging (+% Scrap), 3 níveis com custos crescentes,
  estado e efeitos no `CampEconomy`, raio/valores efetivos no `CampCore`.
- [x] `HitReact` nos inimigos ao levar dano (via `health_changed`, cooldown de
  0,9 s, nunca interrompe o ataque) e animação de morte `Death`: o inimigo emite
  `died` como antes e fica como cadáver 2,5 s sem colisão, grupos ou hitboxes
  (os tiros atravessam para os inimigos vivos atrás).
- [x] Dois pontos de fortificação extra (oeste e este do núcleo), reutilizando a
  cena existente — total de 3 barricadas construíveis.
- [x] Objetivos de mastery por personagem (`character_mastery.gd` + API no
  `SaveManager`): EXTERMINATOR (100 abates), STORM RIDER (nível de ameaça 5 numa
  partida, guarda o máximo), SCAVENGER (500 Scrap); recompensa em Credits paga
  uma única vez, progresso persistido, resumo nos cartões da seleção de classes
  e detalhe no painel de loadout, feedback no HUD ao completar.
- [x] Orçamento de IA para inimigos distantes: a mais de 40 m o repath passa de
  0,35 s para 1,2 s e o steering (query de caminho por frame) é cacheado e
  refrescado a 0,3 s; comportamento de perto inalterado.
- [x] Métricas de streaming no overlay de FPS (`F3`): setores carregados e
  duração do último build de setor.
- [x] Painel de vitória antigo removido (`wave_complete_panel` cena+script) e o
  sinal morto `all_waves_completed` retirado do diretor de horda.
- [x] Decisão registada: navmesh de editor não se aplica (setores gerados em
  runtime); mantém-se a grelha de navegação construída na worker thread.
- [x] `GDD.md`, `ARCHITECTURE.md` e `ROADMAP.md` reescritos e sincronizados com
  o jogo real (horda contínua, mundo aberto, inglês, skill tree, mastery).
- [x] Facelift visual Tier 1 dos menus: backdrop 3D leve no menu principal com
  estrada urbana, props existentes, núcleo apenas visual, céu/nevoeiro de
  entardecer e órbita lenta; pré-visualização animada da classe selecionada com
  os GLTF Quaternius diretos; hover/press reutilizáveis, entrada com fade+slide
  e contagem animada de Credits; painéis com sombra, acento âmbar, gradiente,
  ruído e scanlines procedurais subtis, sem assets externos nem gameplay.

- [x] **Pack "Animated Guns" experimentado e revertido** (decisão de playtest):
  os visuais animados nas cenas das armas, ancorados ao `WeaponPivot` estático,
  nunca assentaram bem nas mãos do personagem — mesmo após recentrar o pivot, a
  arma "flutua" porque as mãos mexem com as animações do rig e o pivot não.
  Rollback completo: malhas embutidas restauradas, pivot original, armas novas
  (Hunting/Marksman/Revolver) removidas com limpeza de save, assets apagados.
  Aprendizagem registada: modelos de armas futuros exigem `BoneAttachment3D` ao
  osso da mão ou vir embutidos no rig do personagem.

- [x] Progressão da skill tree abrandada: um ponto a cada dois níveis, tiers
  bloqueados até aos níveis 2/5/9/14/20 e migração conservadora que nunca remove
  skills já desbloqueadas nem mostra pontos negativos em saves antigos.
- [x] `ARMORY` funcional adicionado à seleção de classes: catálogo por classe,
  requisitos de nível/Créditos, compra permanente e equipamento persistente nos
  slots `[1]`/`[2]`, incluindo troca automática quando a mesma arma muda de slot.
- [x] Medic concluído com Pistol + Spear, malha `Spear` embutida no rig, golpe
  melee de 42 de dano, alcance superior e animação `Stab`.
- [x] Primeiro passe de equilíbrio das classes: Recruit mantém 100 HP, 1 HP/s
  após 6 s e recarga 30% mais rápida; Renegade passa a 150 HP; Medic mantém
  100 HP e regenera 3 HP/s após 4 s. Alcances automáticos iniciais: AR 6 m,
  Pistol 5,5 m e Shotgun 4,5 m.
- [x] Overlay do flash de dano dos inimigos corrigido para usar transparência
  alfa explícita no renderer Compatibility, preservando as cores originais dos
  modelos quando não estão a receber dano.


- [x] Menu de definições reorganizado em três separadores (DISPLAY / CONTROLS /
  AUDIO) com botões-tab no estilo do tema, mantendo o visual do facelift.
- [x] **Keybindings rebindable**: lista das 16 ações de jogo no separador
  CONTROLS (o `pause` fica fixo em Esc por segurança), captura da próxima tecla
  ou botão do rato ao clicar, **swap automático quando a tecla já está em uso**,
  botão de reset a defaults, persistência na secção `[input]` de
  `user://horde_breaker_settings.cfg` (keycodes físicos — WASD mantém a posição
  em qualquer layout de teclado) e aplicação ao `InputMap` no arranque pelo
  `SettingsManager`; como todo o jogo usa ações, os rebinds funcionam em todo o
  lado de imediato. `load_settings(path)` adicionado como hook de teste isolado.

- [x] Munição do chão escala com o nível de ameaça: cada caixa vale
  `base + 4 × (nível − 1)`, com teto em 4× a base (12 → 48), e a recolha mostra
  "+N AMMO" no feed do HUD. Sem wave manager (menus/testes) mantém a base.

- [x] **Variantes de classe** (`character_variants.gd` + API no SaveManager +
  aplicação em `character_skills.gd`): desbloqueadas ao completar as 3 masteries
  da classe, alternáveis por um toggle persistido na seleção de classes (linha
  própria no painel de loadout com estados locked/on/off). VETERAN troca a
  recarga rápida do Recruit por +15% de cadência; BERSERKER baixa o Renegade
  para 110 HP mas o melee rouba 2 HP por golpe; COMBAT MEDIC enfraquece a regen
  (1,5 HP/s após 5 s) mas cada abate cura 5 HP. Overrides base aplicados antes
  dos bónus da skill tree; hooks de runtime (lifesteal via `attack_performed`,
  cura via `enemy_defeated`) ligados no arranque; tint aditivo subtil no modelo
  (com transparência alfa, seguindo a lição do hit-flash).

- [x] **SMG** e **Fire Axe** compráveis no ARMORY (Milestone 20): SMG hitscan
  automática (dano 16, cadência 11, carregador 35, auto-fire 7 m; nível 3 · 400
  Credits) com a malha embutida `SMG`; Fire Axe melee (dano 70, cooldown 0,9 s,
  swing `Slash`; nível 4 · 500 Credits) com a malha embutida `Axe`. Registadas
  no `WeaponCatalog`, com stance correta (SMG = gun, Axe = melee), nomes na UI e
  ícones gerados pela ferramenta (`weapon_smg.png`/`weapon_fire_axe.png`).
- [x] Auto-fire por arma confirmado/afinado (AR 6, Pistol 5,5, Shotgun 4,5,
  SMG 7 m) — item do Milestone 22 que dependia de implementação.

- [x] **Milestone 24 — cidade a sério (1ª fatia):** os setores gerados deixaram
  de usar cubos graybox como landmarks. `SectorGenerator._add_city_buildings`
  coloca agora **edifícios CC0 reais** do Quaternius Downtown MegaKit
  (Building_Small/Medium/Large, 1 mesh cada, ~12–20 m de footprint) como
  `navigation_blocker` com colisão por footprint e rotação por quarto de volta;
  `_add_city_props` espalha planters (com colisão), bollards e tampas de
  esgoto (decoração pura) pelos quarteirões. A geração continua por seed em
  worker threads e a navegação em runtime mantém-se (2842 polígonos com um
  edifício na cena). As estradas atuais já são tiles Quaternius texturados, por
  isso o swap para as Downtown ficou como polish opcional. Pack CC0 aligeirado
  de 247 MB → 91 MB (Textures/FBX redundantes removidas; a pasta glTF é
  auto-suficiente). Fonte/licença em `assets/models/city_test_model/SOURCE.md`.

- [x] **Fix:** as malhas dos edifícios Quaternius não estão centradas na origem
  (footprint deslocado até ~8 m em z), o que deixava a caixa de colisão ao lado
  do prédio visível — paredes invisíveis no vazio e atravessar o edifício. O
  visual passa a ser deslocado por `-center` para o footprint coincidir com a
  origem/colisão; teste confirmou 28 edifícios com colisão a <1,5 m do visível
  (antes 5–8 m).

- [x] **Cidade mais densa + passadeiras corrigidas:** mais edifícios por setor
  (3–6, média 4 vs 2,6), cada um com um **lote de betão** por baixo que esconde
  as marcações/passadeiras da rua sob o prédio (assim os edifícios assentam num
  lote em vez de flutuarem sobre a rua). O lote não tem colisão (a navegação
  continua a usar só o nó `Collision`); a área do lote é reservada para os
  edifícios manterem distância. Navegação saudável (min 2426 polígonos em 8
  setores).

- [x] **Layout urbano refeito (quarteirões e ruas):** o setor deixou de ser uma
  grelha uniforme de 64 tiles de estrada (que punha passadeiras por todo o lado
  e edifícios em cima delas). Passou a ser uma malha de 8×8 células de 8 m onde
  as células do eixo central formam uma **cruz de ruas de 16 m** (com tiles
  retos e cruzamento 4-way) e os quatro cantos são **quarteirões de 24×24 m**
  pavimentados com passeio. Os **edifícios só são colocados dentro dos
  quarteirões** (`_find_free_position_in_block`), pelo que nunca mais assentam
  sobre marcações ou passadeiras. Os quarteirões são lajes planas (sem degrau,
  movimento inalterado); as constantes mortas do antigo `city_road_grid` foram
  removidas.

- [x] **Fase 1 da inspiração "Yet Another Zombie Survivors"** (survivors-like no
  combate, mantendo o mundo aberto):
  - **Cartas de upgrade por nível de run** (`run_upgrades.gd` +
    `run_progression.gd` + `upgrade_choice_panel`): a run tem nível próprio
    (10 XP para o nível 2, +6 por nível), e cada subida pausa o jogo e oferece
    **3 cartas distintas** de um catálogo de 10 (dano, cadência, vida, velocidade,
    recarga, carregador, reserva, raio de recolha, XP, regeneração). Duram só a
    run; a progressão permanente (skill tree/mastery/armory) fica intacta.
    Subidas simultâneas ficam em fila.
  - **Orbes de XP** (`xp_orb`): todos os inimigos largam uma orbe ao morrer (valor
    derivado do `xp_reward`), que **voa para o jogador** dentro do raio de íman
    (escalado pela carta MAGNETIC FIELD), com teto de 120 orbes e expiração a 30 s.
  - **Feel survivors:** câmara recuada (spring 5 → 7,5) e auto-fire alargado
    (AR 12 m, SMG 13 m, Pistol 10 m, Shotgun 8 m) — o jogador posiciona-se, a
    arma trata do resto.
  - **Barra de XP no HUD:** barra fina na borda superior do ecrã + etiqueta
    `LV n` no canto, ligadas a `run_xp_changed`/`run_level_gained`, com flash ao
    subir de nível. Esconde-se em cenas sem `run_progression`.
- [x] **Esc consistente para recuar:** fecha o catálogo de construção
  (`build_catalog`) em vez de abrir a pausa, e sai do ecrã de definições
  (tratado em `_input` para nenhum controlo com foco o engolir primeiro).

- [x] **M26 Fase 2 — estrutura de run:** `run_objective.gd` dá um fim à partida:
  sobreviver 10 minutos até à **extração**, com relógio no HUD (fica âmbar no
  último minuto), avisos no feed aos 5 min/2 min/60 s/30 s/10 s e, ao chegar ao
  fim, painel de fim de run com "EXTRACTION COMPLETE" e **+300 Credits**. Morrer
  continua a terminar a run como derrota.
- [x] **Correções:** auto-reload assim que o carregador esvazia (sem esperar por
  input de disparo) e a etiqueta `LV n` saiu de debaixo do overlay de FPS (passou
  para cima da barra de vida).
- [x] **Tiles removidos também do setor este** (`east_sector.tscn`), que ainda
  usava as quatro grelhas `city_road_grid`; ficou com o chão liso como o
  acampamento.
- [x] **Documentação consolidada:** 12 → 7 ficheiros. Apagados `A_IMPLEMENTAR`,
  `CITY_REBUILD_PLAN`, `M24_M25_TEST_CHECKLIST` e `OPEN_WORLD_PLAN` (planos já
  executados); `HANDOFF` fundido no `OVERVIEW` (ponto de entrada único); histórico
  do `PROGRESS` podado ao Milestone 19 em diante (962 → 666 linhas).

- [x] **M26 — evolução de armas** (`weapon_evolution.gd`): matar com uma arma
  acumula abates por personagem no save e, ao chegar ao limiar, **desbloqueia
  permanentemente a versão evoluída** no ARMORY (sem custo em Credits). Quatro
  evoluções: Assault Rifle → **Storm Rifle** (300), Shotgun → **Siege Breaker**
  (250), SMG → **Hornet** (350), Worn Sword → **Cleaver** (200). Os abates são
  atribuídos à arma ativa no momento (`character_progression`), as evoluídas não
  voltam a acumular, o ARMORY mostra a barra de progresso ("EVOLVES INTO X ·
  n/N KILLS" e "EVOLVED FROM Y") e há aviso no HUD ao evoluir. As armas evoluídas
  reutilizam as malhas embutidas das originais.

- [x] **M26 Fase 3 — hordas massivas:** teto de inimigos vivos subiu de **30 para
  140** (base 20 + 12/nível, lotes de 5+2/nível, intervalo 4,5 s → mín. 1,2 s),
  suportado por **LOD de simulação em três níveis** no `normal_zombie.gd`:
  perto (<28 m) usa navmesh completo, médio usa **steering direto sem qualquer
  query ao NavigationServer**, e além de 60 m o passo de física corre 1 frame em
  3 com delta escalado. O `imported_model_animation.gd` ganhou **LOD de
  animação**: modelos a mais de 42 m do jogador desligam o `AnimationPlayer`
  (o modelo do próprio jogador nunca suspende). Os inimigos já não colidiam
  entre si, por isso a física não foi um estrangulamento.
  **Medições (1152×648, renderer OpenGL):** base 136 fps · 10 inimigos 109 fps ·
  **120 inimigos a combater à volta do jogador = 58 fps (17,2 ms)**. Em headless
  (só CPU) 120 inimigos custam +1,3 ms/frame, o que confirma que o peso está no
  skinning e não na IA.

- [x] **Economia de munição ajustada à horda:** com o teto a 140 inimigos a
  munição acabava depressa demais. Duas medidas: **reservas das armas cerca do
  dobro** (AR 90/180 → 180/360, Pistol 96/240, Shotgun 64/128, SMG 200/400, e as
  evoluídas em proporção) e **os inimigos passam a largar munição** ao morrer —
  Normal 14% / 8, Runner 16% / 8, Spitter 30% / 14, Brute 50% / 20, Boss 100% /
  60. As caixas largadas usam o `ammo_pickup` normal, por isso **escalam com o
  nível de ameaça** e são apanhadas ao passar por cima; há teto de 30 drops
  ativos e expiram em 25 s para não encherem a cena.

## Milestone atual

**Milestone 20 — Arsenal e progressão controlada**

## Próxima tarefa

Fazer um playtest curto das três classes: ritmo de pontos/requisitos da skill
tree, compra e troca de slots no `ARMORY`, alcance/dano das armas, regeneração
do Medic e golpe da Spear. O facelift adicional dos menus fica adiado a pedido
do utilizador; Mixamo e armas externas continuam parqueados.

## Validação

- Godot disponível: `4.7.stable.mono.official.5b4e0cb0f`.
- Cidade: teste headless confirmou 21 edifícios em 8 setores, todos como
  `navigation_blocker` com colisão e mesh, e navegação a construir com 2842
  polígonos com um edifício presente; arena real 400 frames (geração em worker
  threads) sem erros; captura OpenGL de um setor com edifícios de tijolo,
  janelas, cornijas e estradas com marcações.
- SMG/Fire Axe: teste headless (9 asserts) — presença no catálogo e ícones,
  SMG automática com carregador 35, Fire Axe melee com swing Slash, e compra no
  ARMORY bloqueada abaixo do nível 3 / permitida ao nível 3 com Credits; captura
  OpenGL do ARMORY confirmou as duas armas com ícones e custos.
- Variantes: teste headless ponta-a-ponta com save isolado (13 asserts) —
  bloqueio até à mastery completa, toggle persistente, e em arena real: Veteran
  com cadência 6,9 e recarga de classe removida; Berserker com 110 HP e +4 HP
  por golpe duplo de melee; Combat Medic com regen 1,5/5 s e +5 HP por abate.
  Seleção de personagens validada em headless e captura OpenGL (linha da
  variante com estado LOCKED).
- Munição escalável: teste headless (5 asserts) — base 12 sem diretor, 36 ao
  nível 7, teto 48, e entrega escalada ao jogador (28 ao nível 5).
- Keybindings: teste headless com settings isoladas confirmou rebind (Space→K),
  texto do binding, swap em conflito (crouch→K trocou com jump, que recebeu
  Ctrl), binding de rato (MOUSE MIDDLE), reaplicação após reload e reset a
  defaults (9 asserts); menu de definições headless 60 frames sem erros e
  capturas OpenGL dos três separadores validadas visualmente.
- Milestone 20: importação headless sem erros; `armory_screen`,
  `character_selection`, `skill_tree_screen`, `spear`, `medic` e `test_arena`
  executados isoladamente durante 60 frames sem `SCRIPT ERROR`.
- Teste integrado com save isolado confirmou 33 verificações: níveis mínimos,
  pontos a cada dois níveis, preservação de skills antigas, migração do loadout
  do Medic, catálogo, compra da Pistol pelo Renegade, persistência/troca dos
  slots e Spear ativa com malha embutida e animação `Stab`.
- Capturas OpenGL a 1152 × 648 confirmaram o novo `ARMORY` e o botão na seleção
  de classes sem cortes nem sobreposições.
- Facelift Tier 1: importação headless concluída sem erros; `main_menu.tscn` e
  `character_selection.tscn` executados isoladamente durante 60 frames sem
  `SCRIPT ERROR`.
- Facelift Tier 1: teste headless alternou Recruit, Renegade e Medic no mesmo
  `SubViewport`, confirmando uma única instância, `Idle_Gun` em reprodução e as
  malhas embutidas Rifle, Shotgun e Pistol visíveis, respetivamente.
- Facelift Tier 1: capturas OpenGL a 1152 × 648 confirmaram o backdrop 3D, a
  vinheta, o modelo animado do Recruit, os cartões/mastery e o loadout sem
  cortes nem sobreposições; o overlay F3 foi ocultado apenas durante a captura.
- Emboscadas por ciclo: teste headless (`SceneTree`) confirmou que um inimigo
  vivo impede o re-arme, que uma lista limpa conta como pronta, que
  `_on_cycle_completed` repõe `ambush_triggered` em todos os setores e que o
  `WorldStreamer` se liga ao sinal `cycle_completed` de um wave manager fictício
  e re-arma ao recebê-lo.
- Emboscadas por ciclo: `test_arena` em headless durante 300 frames correu sem
  erros com a ligação ao diretor de horda real ativa.
- Ataques animados: teste com renderer OpenGL confirmou que os cinco inimigos
  tocam `Idle_Attack` (sem loop) ao emitir `attacked`, com captura visual do
  pose de ataque; `test_arena` em headless durante 240 frames sem erros.
- Persistência do mundo: teste headless com save isolado confirmou seed estável
  entre chamadas e reloads, deduplicação de setores visitados, farol persistido
  e o `WorldStreamer` a usar o seed do save (9 asserts).
- Upgrades da base: teste headless confirmou custos 40→80→120, recusa quando
  maxado ou sem Scrap, bónus (+12 cura/s, +6 munição/s no nível 3), Scavenging
  a converter 100→115, compra pela estação com etiqueta atualizada, 3 estações
  nomeadas no núcleo e raio efetivo 12→16 (14 asserts).
- HitReact/Death: teste headless confirmou HitReact ao dano com cooldown sem
  restart, prioridade do ataque, `died` emitido uma vez, cadáver com `Death`,
  sem colisão/grupo/hitboxes, imune a dano e libertado após 2,5 s (9 asserts).
- Mastery: teste headless com save isolado confirmou acumulação, modo máximo,
  clamp no objetivo, recompensa paga uma única vez, persistência após reload e
  captura OpenGL da seleção de classes com resumo e detalhe legíveis (7 asserts).
- Arena completa: 3 fortificações e 3 estações verificadas por script; run
  headless de 1700 frames (~28 s com horda ativa) sem erros com o orçamento de
  IA e as métricas de streaming ativos.
- Armas animadas: teste confirmou o clip de Fire a tocar em `shot_fired` e o de
  Reload à velocidade certa (0,54×) em `reload_started`; orientações das três
  armas validadas por capturas de perfil com guias de muzzle; arena com o
  renderer OpenGL sem erros (os avisos de material em headless são ruído do
  renderer dummy com FBX skinned).
- POIs: teste headless (`SceneTree`) sobre 60 seeds confirmou POIs em 33/60
  setores (55%), os cinco muros no grupo `navigation_blocker` com `Collision`, o
  marcador em `point_of_interest`, a cache interior de 50 de Scrap e — via malha
  de navegação em runtime — a célula caminhável mais próxima do centro interior a
  0,56 m e da porta a 0,42 m (interior alcançável pela porta, não murado).
- POIs: `test_arena` em headless durante 240 frames carregou dois setores gerados
  (com POIs) em worker threads sem erros de navegação ou de colisão.
- POIs: captura OpenGL a 1152 × 648 confirmou os muros, a porta, o chão interior
  e a cache de recompensa dentro do edifício, entre os marcos existentes.
- Importação do projeto em modo headless concluída com código de saída 0.
- Cena principal executada em modo headless durante dois frames com código de saída 0.
- Cena executada com o renderer OpenGL e gravada durante dois frames com código de saída 0.
- Inspeção visual confirmou o enquadramento completo da arena, materiais e iluminação.
- Cena do jogador e script GDScript importados sem erros.
- Teste automatizado confirmou as quatro direções WASD e a normalização do movimento diagonal.
- Teste automatizado confirmou o spawn em `(0, 1, 0)`, contacto com o chão e bloqueio na parede norte em `z = -11.49984`.
- Inspeção visual confirmou a cápsula provisória dentro da arena.
- Teste automatizado confirmou rotação horizontal, limites verticais e captura/libertação do rato.
- Teste automatizado confirmou movimento relativo à câmara e orientação correta do visual.
- Teste automatizado confirmou que o `SpringArm3D` encurta de 5 para `2.83203125` junto a uma parede.
- Teste automatizado confirmou o jogador 12,9% à esquerda do centro com a câmara sobre o ombro.
- Teste automatizado confirmou que o disparo mantém erro de projeção de `0 px` e aplica 25 de dano após o deslocamento da câmara.
- Cena e script da Assault Rifle importados sem erros.
- Teste automatizado confirmou 6 disparos por segundo com cadência configurada para 6.
- Alvo temporário na layer `Enemies` recebeu 25 de dano por tiro e 150 de dano total.
- Teste automatizado confirmou criação e limpeza do clarão e do tracer.
- Inspeção visual confirmou arma e clarão legíveis na vista em terceira pessoa.
- Cena e script do Normal Zombie importados sem erros.
- Teste automatizado confirmou perseguição através da navegação, reduzindo a distância ao jogador de `7.75000095367432` para `5.25001049041748` num segundo.
- Teste automatizado confirmou três ataques em 2,5 segundos com cooldown de um segundo e payload de 10 de dano.
- Teste automatizado confirmou dois eventos de vida e morte após dois disparos de 25 de dano.
- Inspeção visual confirmou o zombie na arena, a aproximação ao jogador e o contacto correto com o chão.
- Cena e script do painel de game over importados sem erros.
- Teste automatizado confirmou que um ataque real do zombie reduz a vida do jogador de 100 para 90.
- Teste automatizado confirmou morte aos zero pontos, uma única emissão de `died`, interrupção do movimento e rejeição de dano posterior.
- Teste automatizado confirmou apresentação do painel, pausa da árvore e libertação do rato.
- Teste automatizado acionou o botão de reinício e confirmou uma nova arena sem pausa, painel oculto e jogador novamente com 100 pontos de vida.
- Inspeção visual confirmou o fundo escurecido, a mensagem de derrota e o botão de reinício centrados.
- Teste automatizado confirmou a criação de exatamente cinco Normal Zombies em cinco pontos de spawn.
- Teste automatizado confirmou a sequência de inimigos vivos `[4, 3, 2, 1, 0]`.
- Teste automatizado confirmou uma única conclusão de ronda e apresentação do painel de vitória apenas aos zero inimigos.
- Teste automatizado confirmou que reiniciar a vitória repõe os cinco inimigos.
- Teste automatizado confirmou os valores iniciais do HUD: vida `100/100`, munição `30/30`, ronda 1 e cinco inimigos.
- Teste automatizado confirmou atualização da vida para `90/100` após dano.
- Teste automatizado confirmou consumo de munição `30 → 29`, estado de recarga e reposição `29 → 30` após 1,5 segundos.
- Inspeção visual confirmou os painéis do HUD legíveis nos cantos superiores sem ocultar o centro da arena.
- Teste automatizado percorreu as composições de 5, 10 e 17 inimigos pela ordem prevista.
- Teste automatizado confirmou dois intervalos e vitória apenas após a terceira ronda.
- Teste automatizado confirmou exatamente dois Runners na terceira ronda através da velocidade configurada.
- Inspeção visual confirmou que o Runner usa material laranja e se distingue dos Normal Zombies verdes.
- Importação confirmou o registo das classes `CharacterData`, `WeaponData` e `WaveData` sem erros.
- Teste com Autoload real e save isolado confirmou os valores iniciais do Recruit e da Assault Rifle.
- Teste automatizado confirmou progressão de nível 1 para nível 5 com 700 XP.
- Teste integrado das três rondas confirmou 286 XP de sessão, nível 3 com 36 XP restante e 100 Credits.
- Teste automatizado confirmou persistência das recompensas após novo carregamento do save.
- Teste automatizado rodou a câmara 90 graus e confirmou alinhamento do jogador e da arma com a mira.
- Teste automatizado confirmou impacto exatamente no centro do ecrã, com erro de projeção de `0 px`.
- Alvo colocado sob a mira recebeu 25 de dano, a munição passou de 30 para 29 e o tracer nasceu no cano.
- Inspeção visual confirmou o ponto de mira centrado e legível sobre a arena.
- Cena principal de menu executada em modo headless durante dois frames com código de saída 0.
- Teste automatizado confirmou desbloqueio do Renegade por 500 Credits e persistência da seleção.
- Teste automatizado instanciou a arena com Recruit e Renegade e confirmou personagem, arma e visibilidade da mira esperadas.
- Menus renderizados com OpenGL a 1152 × 648 sem texto cortado, sobreposição ou botões fora do ecrã.
- Teste melee com o driver Windows confirmou dois alvos frontais atingidos pelo mesmo golpe e um alvo traseiro intacto.
- Teste automatizado confirmou 35 de dano por ataque, rejeição de ataques durante o cooldown e novo ataque após o intervalo.
- Normal Zombie real morreu após dois ataques acionados através da ação `attack` e emitiu o sinal `died` esperado.
- Arena instanciada com o Renegade confirmou Worn Sword ativa, Assault Rifle oculta e HUD `Arma: Worn Sword`; a mira passou posteriormente a permanecer visível para permitir headshots melee.
- Inspeção visual OpenGL confirmou a espada provisória visível na vista sobre o ombro.
- Primeiro arranque criou `horde_breaker_test.cfg` com 2000 Credits, Recruit nível 5 e progressão normal das duas personagens.
- Segundo arranque manteve o hash do perfil de teste, confirmando que os valores iniciais não são adicionados novamente.
- Hash do save normal permaneceu inalterado durante os dois arranques com o perfil de teste.
- Teste integrado confirmou 846 polígonos navegáveis, exclusão das três coberturas e caminhos válidos dos seis spawns até ao jogador.
- Teste integrado confirmou exatamente cinco zombies na primeira ronda e movimento normal antes e depois da pausa.
- Teste integrado confirmou que os zombies não mudam de posição enquanto a árvore está pausada.
- Teste integrado confirmou mira com 6 × 6 píxeis e centro com 2 × 2 píxeis.
- Teste de física confirmou que a Worn Sword tem linha direta para um alvo livre e fica bloqueada pela barricada central.
- Inspeção visual OpenGL confirmou as três coberturas, espaço de circulação, mira reduzida e painel de pausa legível.
- Teste com save legado isolado preservou 1234 Credits, Recruit nível 5 com 42 XP e Renegade nível 2 com 17 XP.
- A migração acrescentou Pistol ao Recruit, Shotgun ao Renegade e valores iniciais do Medic sem remover compras existentes.
- Teste automatizado confirmou Assault Rifle/Pistol no Recruit, Shotgun/Worn Sword no Renegade e Pistol/slot vazio no Medic.
- Teste automatizado confirmou recargas do Recruit reduzidas de 1,5 para 1,05 segundos e de 1,3 para 0,91 segundos.
- Teste automatizado confirmou 140 de vida no Renegade e regeneração de 4 pontos por segundo no Medic contra 1 ponto no Recruit.
- Teste de física confirmou dano de múltiplos pellets da Shotgun sem ultrapassar o máximo de oito pellets.
- Teste automatizado confirmou as ações `weapon_primary` e `weapon_secondary` e a rejeição segura do slot secundário vazio do Medic.
- Menu de classes e arena com Shotgun renderizados em OpenGL a 1152 × 648 sem texto cortado ou sobreposição.
- Oito ficheiros glTF do Quaternius foram importados pelo Godot 4.7 em modo headless com código de saída 0.
- Cenas do Recruit, Renegade, Medic, Assault Rifle, Pistol e Shotgun executadas isoladamente em modo headless sem erros.
- Arena de teste executada durante 30 frames em modo headless com o Recruit e os zombies importados sem erros de carregamento ou de animação.
- Teste automatizado confirmou a arma visual ativa em cada loadout: Rifle/Pistol no Recruit, Shotgun no Renegade e Pistol no Medic.
- Captura OpenGL a 1152 × 648 confirmou o Recruit no chão, orientado para a mira, sem as armas internas não equipadas visíveis.
- Teste automatizado confirmou as ações `jump`, `sprint`, `crouch`, `interact`, `camera_front` e `aim` no `InputMap`.
- Teste de física confirmou andar a 4 m/s, corrida a 7 m/s, salto ascendente e agachamento a 2,5 m/s com cápsula reduzida de 2 para 1,2 metros.
- Teste de física confirmou que uma cobertura superior impede a personagem de se levantar e que a altura normal é reposta depois de libertar o espaço.
- Teste integrado confirmou que `F` transfere munições para a reserva e remove o pickup apenas quando a transferência é válida.
- Teste automatizado confirmou que o botão direito reduz o FOV de 70 para 55 e o comprimento do braço de 5 para 3,2 metros.
- Teste automatizado confirmou que manter `C` roda a câmara aproximadamente 180 graus e que libertar a tecla repõe a órbita anterior.
- Teste integrado confirmou que selecionar a Worn Sword mostra a lâmina integrada, mantém a primitiva antiga oculta e reproduz `Slash` ao atacar.
- Capturas OpenGL confirmaram a espada na mão do Renegade em idle e ataque, a postura agachada, a mira aproximada e a vista frontal sem o objeto suspenso.
- Oito modelos ambientais e de veículo foram importados em modo headless sem erros.
- Teste automatizado confirmou Assault Rifle com `30 / 90`, recolha de 12 munições com o carregador cheio e reserva resultante de 102.
- Teste automatizado confirmou que uma recarga com cinco munições de reserva transfere apenas essas cinco e deixa a reserva a zero.
- Teste integrado confirmou que o Renegade recolhe munições para a Shotgun enquanto a Worn Sword está ativa, aumentando a reserva de 32 para 44.
- Teste integrado confirmou 16 módulos de estrada, piso e quatro paredes visuais ocultos e navegação ainda disponível.
- Captura OpenGL a 1152 × 648 confirmou o mapa urbano completo, contentores, camião, torre, barreiras e ausência das paredes graybox.
- Teste direto confirmou 10 de dano no corpo e 20 de dano na cabeça através das `DamageHitbox`.
- Teste com raycast real confirmou 25 de dano no corpo e 50 de dano na cabeça com a Assault Rifle.
- Teste com a Worn Sword confirmou 35 de dano no corpo e 70 de dano na cabeça, aplicado uma única vez apesar da sobreposição das duas hitboxes.
- Teste de herança confirmou `BodyHitbox`, `HeadHitbox` e multiplicador `2.0` no Runner.
- Inspeção OpenGL com volumes de depuração confirmou a esfera de cabeça alinhada com a cabeça visível do Normal Zombie e a cápsula do corpo até ao pescoço.
- Tema partilhado, seis cenas de UI e scripts associados importados pelo Godot 4.7 sem erros.
- Menu principal e seleção de personagens executados isoladamente em modo headless com código de saída 0.
- Arena de teste executada durante 60 frames em modo headless com o HUD revisto e código de saída 0.
- Capturas OpenGL a 1152 × 648 confirmaram menu principal, seleção, HUD, pausa, derrota e vitória sem texto cortado ou painéis sobrepostos.
- Teste automatizado confirmou números `10` no corpo e `20` na cabeça com dano base 10, incluindo a cor dourada exclusiva do headshot.
- Teste automatizado confirmou que os oito pellets da Shotgun produzem um único número agregado no mesmo inimigo.
- Teste automatizado confirmou um único número por alvo atingido pela Worn Sword e remoção automática de todos os indicadores após 0,65 segundos.
- Captura OpenGL a 1152 × 648 confirmou o número de headshot pequeno, legível e sem interferir com o HUD.
- Teste automatizado carregou as cenas reais e confirmou 100/60 de vida no Normal Zombie/Runner e multiplicador de cabeça `2 ×`.
- Teste automatizado confirmou dano corpo/cabeça de `30/60` na Assault Rifle, `35/70` na Pistol, `12/24` por pellet na Shotgun e `50/100` na Worn Sword.
- Teste integrado com raycasts reais confirmou números `30/60` da Assault Rifle no corpo/cabeça, `35` da Pistol, `96` para oito pellets da Shotgun e `50` da Worn Sword.
- Arena executada durante 60 frames em modo headless após o balanceamento sem erros de carregamento ou execução.
- Importação headless após o Milestone 15 concluída sem erros de parsing ou de recursos.
- Cena principal executada durante 120 frames em modo headless sem erros.
- Teste integrado percorreu os ataques `1–4` com `5`, `10`, `17` e `7` inimigos, confirmando repetição contínua e aumento de dois Normal Zombies no novo ciclo.
- Teste integrado confirmou uma única emissão de `cycle_completed` após três ataques e ausência do painel de vitória na arena.
- Teste integrado confirmou zombies a escolher tanto jogador como núcleo, dano real causado ao núcleo e remoção do núcleo do grupo de alvos aos zero pontos de vida.
- Teste integrado confirmou que o núcleo aceita dano real dos zombies, mas não expõe o método usado pelas armas do jogador.
- Teste integrado confirmou mensagem específica de destruição do núcleo, apresentação do painel de derrota e pausa da árvore.
- Captura OpenGL a 1152 × 648 confirmou o núcleo legível no mapa e o novo painel de vida sem sobreposição com ataque, ameaças ou retículo.
- Importação headless após o primeiro slice do Milestone 16 concluída sem erros de parsing ou de recursos.
- Arena expandida executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou arena de 64 × 64 metros, quatro bairros e malha de navegação com 3344 polígonos.
- Teste integrado confirmou caminhos dos seis spawns inimigos até ao núcleo e oito caches de Scrap presentes.
- Teste integrado confirmou recolha de 25 Scrap, depósito, reparação de 50 pontos por 10 Scrap e bloqueio da reparação durante um ataque.
- Teste integrado confirmou o início do primeiro ataque após a fase de preparação.
- Captura OpenGL a 1152 × 648 confirmou o centro desimpedido, maior distância visual, contagem de exploração e painéis de Scrap sem sobreposição.
- Importação headless após a fortificação concluída sem erros de parsing ou de recursos.
- Arena com a fortificação executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou construção por 30 Scrap, 200 pontos de vida e reparação de 50 pontos por 10 Scrap.
- Teste integrado confirmou bloqueio da construção durante ataques e reconstrução durante a exploração.
- Teste integrado confirmou atualização da navegação de `3344` para `3332` polígonos ao construir e reposição para `3344` ao destruir.
- Teste integrado confirmou que um Normal Zombie real escolhe a barricada próxima e lhe causa dano.
- Captura OpenGL a 1152 × 648 confirmou marcador, barricada construída, etiqueta no mundo e feedback sem sobreposição crítica com o HUD.
- Importação headless do primeiro slice do Milestone 17 concluída sem erros de parsing ou de recursos.
- Arena com os quatro POIs executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou quatro grelhas de estrada, quatro POIs e ausência das antigas instâncias repetidas na arena.
- Teste integrado confirmou 3424 polígonos navegáveis, caminhos dos seis spawns ao núcleo e caminhos do acampamento aos quatro acessos.
- Teste integrado confirmou os oito caches preservados, alcançáveis e com uma cache a menos de 10 metros de cada POI.
- Captura OpenGL frontal confirmou hospital e armazém legíveis a partir do acampamento sem bloquear a área central.
- Captura OpenGL aérea confirmou as quatro silhuetas distintas, distribuição por quadrantes e rotas abertas entre zonas.
- Importação headless após a abertura do armazém concluída sem erros de parsing ou de recursos.
- Arena com o interior do armazém executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou 3468 polígonos navegáveis, caminho do acampamento até ao interior, quatro acessos e seis rotas de spawn preservadas.
- Teste integrado confirmou nove caches de Scrap e recolha funcional do loot interior: 25 Scrap e 12 munições.
- Capturas OpenGL a 1152 × 648 confirmaram a entrada aberta, o interior iluminado, a prateleira e os dois pickups legíveis.
- Importação headless após a emboscada do armazém concluída sem erros de parsing ou de recursos.
- Arena com `WarehouseEncounter` executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou dois Normal Zombies por ativação, 10 XP total e `alive_enemy_count` inalterado em zero.
- Teste integrado confirmou uma ativação por ciclo, reposição de Scrap e munições após `cycle_completed` e ausência de duplicação quando o loot permanece por recolher.
- Captura OpenGL a 1152 × 648 confirmou os dois zombies separados, no chão e legíveis em redor do loot interior.
- Importação headless após a abertura do hospital concluída sem erros de parsing ou de recursos.
- Arena com o hospital explorável executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou 3498 polígonos navegáveis, percurso de 29 pontos do acampamento ao interior e os quatro acessos dos POIs preservados.
- Teste integrado confirmou uma única instância do medkit, rejeição com vida cheia, cura de 40 pontos, limite na vida máxima e reposição após `cycle_completed`.
- Capturas OpenGL a 1152 × 648 confirmaram a entrada aberta, sinalização, duas camas, iluminação fria e medkit legível no interior.
- Importação headless após a abertura do posto militar concluída sem erros de parsing ou de recursos.
- Arena com o posto militar explorável executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou 3516 polígonos navegáveis, percurso de 25 pontos do acampamento ao interior e os quatro acessos preservados.
- Teste integrado confirmou dois Normal Zombies, um Runner, 18 XP total e `alive_enemy_count` inalterado em zero.
- Teste integrado confirmou duas caixas de munições, reposição após `cycle_completed` e ausência de duplicação quando o loot permanece por recolher.
- Capturas OpenGL a 1152 × 648 confirmaram a entrada aberta, bunker iluminado, duas caixas e elementos militares legíveis.
- Importação headless após a abertura da estação de combustível concluída sem erros de parsing ou de recursos.
- Arena com a estação de combustível explorável executada diretamente durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou 3522 polígonos navegáveis, percurso de 26 pontos do acampamento ao interior e os quatro acessos preservados.
- Teste integrado confirmou três Runners, 24 XP total, `alive_enemy_count` inalterado em zero e reposição seletiva das duas caches sem duplicação.
- Capturas OpenGL a 1152 × 648 confirmaram a loja aberta, iluminação quente, duas caches legíveis e Runners separados na zona das bombas.
- Importação headless do primeiro slice do Milestone 18 concluída sem erros de parsing ou recursos.
- Menu principal e arena do primeiro slice executados durante 120 frames em modo headless com código de saída 0.
- Teste integrado confirmou ausência de disparo a 4 metros e através de uma parede, seguida de dano automático real a 2,5 metros.
- Teste integrado confirmou configuração comum na Pistol e Shotgun, herança do grupo `enemy` no Runner e exclusão da Worn Sword.
- Teste integrado confirmou duas regiões de navegação e um percurso contínuo de 33 pontos até ao farol do setor leste.
- Teste integrado confirmou carregamento, descarregamento e novo carregamento com uma única instância do setor.
- Teste integrado confirmou preservação das instâncias do jogador e do acampamento e do estado ativado do farol.
- Capturas OpenGL a 1152 × 648 confirmaram os dois setores alinhados, estrada contínua e farol visualmente destacado no graybox leste.
- Não foram encontrados erros de parsing ou de carregamento.
- Importação headless após as melhorias de UI concluída sem erros e com registo da classe `UiAnimations`.
- Menu principal, menu de definições, seleção de personagens, menu de pausa e arena executados em modo headless com código de saída 0.
- Capturas OpenGL a 1152 × 648 confirmaram o menu principal com o botão de definições, o painel de definições completo sem cortes e o banner de exploração do HUD legível sem sobreposição com os painéis existentes.
- O pulso da vinheta de dano, o hit-marker e a barra de recarga ainda não foram exercitados num playtest manual com combate real.
- Importação headless após o redesign visual concluída sem erros de parsing ou de recursos.
- Menu principal, seleção de personagens, definições, pausa e arena executados em modo headless com código de saída 0 após o redesign.
- Capturas OpenGL a 1152 × 648 confirmaram o menu principal com botões enviesados, a seleção de classes com emblemas e cartões centrados, o menu de definições com o novo tema e o HUD modular sem sobreposição de elementos.
- O painel de vitória (`wave_complete_panel.tscn`) continua fora de uso e mantém o estilo antigo; será atualizado se voltar a ser necessário.
- Importação headless e cena de definições executadas sem erros após remover a secção de gráficos.
- Teste integrado do streamer confirmou: zero setores no arranque, carregamento em background do setor leste em 15 ms (3 frames físicos após o gatilho), descarregamento ao afastar e recarregamento em 9 ms sem duplicação.
- Captura OpenGL a 1920 × 1080 confirmou o céu de entardecer, o nevoeiro no horizonte e o HUD corretamente escalado com o novo stretch.
- Teste com janela real confirmou o ciclo completo: arranque em ecrã completo 1920 × 1080, mudança para janela 1600 × 900 centrada, regresso a ecrã completo e nova mudança para janela, tudo com o modo e o tamanho corretos.
- Diagnóstico frame a frame confirmou a causa original: pedir modo janela com o jogo arrancado em fullscreen nativo deixava a janela presa em exclusive fullscreen e a ignorar redimensionamentos.
- Teste integrado confirmou o núcleo fora do grupo de alvos, o painel de melhorias aberto durante a preparação inicial e um zombie a 10 metros a perseguir o jogador até aos 3,17 metros, onde o disparo automático o abateu, com a vida do núcleo intacta.
- Teste integrado confirmou o flash de dano ativo após `take_damage`, os dois sons sintetizados com dados válidos e as cinco melhorias a aplicar os efeitos numéricos exatos (dano ×1,2, +25 vida, velocidade ×1,1, recarga ×0,8 e cura total).
- Captura OpenGL confirmou o painel de três vantagens legível sobre o HUD durante a exploração.
- Teste integrado do mundo aberto confirmou: zero setores no acampamento, geração do setor norte com três caches e muro exterior, caminho de navegação contínuo de 51 pontos do acampamento até ao interior do setor gerado, layout determinístico após descarregar e recarregar, cache recolhida sem reaparecer e dois setores vizinhos carregados num canto.
- Geração de um setor medida em 134–144 ms (dominada pela instanciação das estradas) e carregamento do setor leste em background em 12–20 ms.
- Capturas com janela real confirmaram ruas contínuas, marcos, contentores e caches legíveis nos setores gerados sob o céu de entardecer.
- Teste integrado do mapa tático confirmou o pior cenário real: com o botão do painel de melhorias focado, o Tab abre e fecha o mapa na mesma.
- Captura com janela real confirmou o mapa tático com a grelha 4 × 4, a base destacada, os setores carregados, o marcador do jogador com direção e os POIs.
- Teste integrado da vida dos setores confirmou: geração faseada completa (4 quadrantes + navegação) em ~180–220 ms totais espalhados por 7 frames, marcadores de spawn e caixa de munições presentes, emboscada de 3 inimigos disparada uma única vez, munições recolhidas sem reaparecer e vaga a nascer dentro do setor do jogador.
- Regressão completa dos testes do mundo aberto, streamer e funcionalidades anteriores sem falhas após a geração faseada.
- Teste integrado com save isolado confirmou o pool de vantagens a crescer com o nível (3 no nível 1, 6 no nível 7, 7 no nível 9) e os efeitos exatos das novas vantagens (carregador 30 → 38 e cadência ×1,15).
- Teste integrado com registo das posições de nascimento confirmou spawns aleatórios: inimigos dentro de 2,6 m de um marcador válido, com desvio visível e vaga a nascer dentro do setor do jogador (3 em 5).
- Captura em jogo real confirmou o painel com Carregadores Alargados no pool e o rodapé "Vantagens desbloqueadas 6 / 7".
- Teste integrado confirmou auto-recolha de Scrap e munições ao sobrepor o corpo do jogador, e que a caixa de arma exige `F` (não é auto-recolhida) e troca a arma secundária para Shotgun, tornando-a ativa.
- Teste do mundo aberto atualizado para o streaming antecipado (raio 95 m) confirmou setor distante não carregado no acampamento, geração ao entrar, layout determinístico, cache recolhida persistente e cinco setores vizinhos num canto.
- Capturas em jogo real confirmaram o HUD minimalista sem as placas antigas e o mapa tático com bússola, setor atual, triângulos de arma, anel de objetivo e legenda alargada.
- Teste integrado dos inimigos confirmou: o Brute dá dano e empurra o jogador, o Spitter dispara um projétil à distância, o Boss invoca minions ao longo do tempo e o diretor gera um Boss no nível configurado.
- Cenas de Brute, Spitter e Boss executadas isoladamente e a arena durante 90 frames sem erros.
- Teste automatizado confirmou que o modo guardado é apresentado corretamente,
  que uma janela muda realmente para `1280 × 720` e que o estado anterior é reposto.
- Teste automatizado confirmou a ação `toggle_map`, o mapa inicialmente oculto e
  a abertura através de `Tab` na arena real.
- Captura OpenGL a `1152 × 648` confirmou o mapa legível e centrado sobre o HUD,
  com grelha, setor da base, orientação do jogador e marcadores de POI.
- Importação e execução headless de menu e arena sem erros após o diretor de horda contínuo, o reabastecimento, os setores enriquecidos e a localização em inglês.
- Testes integrados atualizados para o diretor contínuo confirmaram geração faseada, emboscadas por setor com estado, munições com estado, spawns aleatórios à volta do jogador e o pool de vantagens por nível (3 → 6 → 7).
- Regressão dos testes de mundo aberto, mapa tático e funcionalidades anteriores sem falhas.
- Pesquisa por caracteres acentuados confirmou zero strings em português nos scripts, cenas e dados do jogo.
- Capturas com janela real a `1152 × 648` confirmaram o menu principal em inglês, o mapa tático com setor atual destacado e marcadores de Scrap/munição, e um setor gerado com postes de iluminação, camião e a zona de reabastecimento ativa.

- [x] Inimigos passaram a poder largar um único pickup de Scrap ao morrer:
  Normal 15% (1–2), Runner 20% (1–2), Spitter 30% (2–3), Brute 60% (4–6)
  e Boss 100% (15–20). Os drops desaparecem ao fim de 25 segundos e ficam
  limitados aos 40 mais recentes, sem alterar as caches e POIs existentes.
- Teste headless determinístico confirmou uma taxa Normal de 14,5% em 2000
  mortes, quantidades e overrides corretos, máximo de um pickup por inimigo,
  despawn e limite de 40. Importação headless e arena durante 240 frames
  terminaram sem SCRIPT ERROR.

- [x] UI Tier 2 concluído: Rajdhani Regular/SemiBold/Bold integrada no tema,
  títulos e números com pesos próprios, mapa tático/FPS/dano 3D atualizados,
  oito retratos/ícones transparentes gerados a partir dos modelos Quaternius e
  usados na seleção, ARMORY e HUD, e sons subtis de hover/clique sintetizados
  em runtime. A fonte veio do Google Fonts sob SIL OFL 1.1 e a origem/licença
  ficaram guardadas em `assets/fonts/`.
- Validação Tier 2: importação headless sem erros, gerador OpenGL produziu os
  oito PNGs, inspeção visual confirmou retratos e armas centrados, e main menu,
  seleção, ARMORY, skill tree, definições e arena correram 60 frames headless
  sem `SCRIPT ERROR`.

- [x] UI Tier 3 concluído: vida do HUD interpolada, pulso discreto de munição
  baixa e ameaça, skill tree com ligações e cores por ramo, pausa e derrota com
  profundidade em dois níveis, estados mais claros no ARMORY, controlos das
  definições alinhados com o tema e mapa tático com grelha/legenda refinadas.
- O menu principal passou a mostrar o loadout persistente escolhido no ARMORY,
  incluindo a Spear; os ícones das armas receberam maior contraste e suporte
  visual sem alterar compras, saves ou equipamento.
- Foi acrescentada `tools/capture_ui_screen.gd` para regenerar capturas dos nove
  ecrãs. A inspeção final OpenGL confirmou todos os ecrãs sem texto cortado a
  1152 × 648 e 1920 × 1080; o overlay técnico de FPS é ocultado apenas durante
  esta validação.
- Validação Tier 3: importação headless sem erros; main menu, seleção, ARMORY,
  skill tree e definições executados isoladamente; arena executada durante 240
  frames; capturas finais de HUD, pausa, derrota e mapa tático inspecionadas nas
  duas resoluções sem regressões do fluxo funcional.


## M24/M25 — cidade e construção livre

- [x] Setores procedurais enriquecidos com AC de cobertura, drenos, carros
  abandonados e lixo; a colocação usa `sector_seed + 999`, respeita os limites
  de 15 props com colisão e 40 visuais e reserva corretamente veículos rodados.
- [x] POIs gerados passaram a escolher deterministicamente entre fachadas de
  esquadra, hospital e supermercado através de `POIRegistry`, mantendo o piso,
  entrada, marcador e cache de loot existentes.
- [x] Ambiente mundial isolado em cena própria e quatro presets de céu, luz e
  nevoeiro ligados aos níveis de ameaça 0, 5, 10 e 15+.
- [x] Construção livre integrada na arena: catálogo com cinco estruturas,
  grelha de 2 m, reserva em torno do núcleo, snapping, rotação, ghost
  verde/vermelho, custo em Scrap armazenado e bloqueios por upgrades.
- [x] Estruturas colocadas atualizam a navegação, podem receber dano e ser
  reparadas por interação; destruição liberta células e posição, rotação e vida
  ficam persistidas na secção `base_layout` do save.
- [x] Ações `build_mode_toggle`, `build_confirm`, `build_cancel` e
  `build_rotate` adicionadas ao Input Map e ao sistema de keybindings.
- [x] O modo de construção deixou de bloquear o `CharacterBody3D`: o jogador
  pode deslocar-se com o catálogo aberto e mantém movimento completo, salto e
  controlo da câmara durante o preview; armas e interação normal ficam
  desativadas até sair do modo.
- [x] O acampamento instala visuais adicionais ao atingir Resupply Rate nível 2
  e Scavenging nível 1.
- Validação estática concluída em 52 ficheiros e 157 referências de recursos,
  sem caminhos em falta, IDs por resolver ou erros estruturais detetados.
- A cidade/fachadas/props atuais ficam preservados apenas como protótipo. A
  próxima iteração substitui também as estradas e caminhos por um grafo contínuo
  entre setores, conforme `docs/CITY_REBUILD_PLAN.md`.

## CITY_REBUILD_PLAN — fase 1+2 (grafo de debug e continuidade)

- [x] `SectorEdgeContract` calcula os quatro conectores de aresta de cada
  setor (posição, largura, tipo) a partir só da seed global e das
  coordenadas — dois setores vizinhos chegam ao mesmo ponto sem comunicarem
  entre si, canonicalizando pela coordenada menor no eixo partilhado.
- [x] `RoadGraph` guarda o grafo resultante (nós/arestas idempotentes) e
  valida sem dead-ends não intencionais, segmentos demasiado curtos ou
  cruzamentos impossíveis.
- [x] `CityLayoutGenerator` constrói o grafo para as 16 células da grelha,
  desenha um visual de debug (reutilizando a técnica `ImmediateMesh` de
  `build_grid.gd`) e expõe verificações de continuidade nas 24 fronteiras
  internas e de determinismo com seeds repetidas.
- [x] Overlay `CityGraphDebugOverlay` ligado a `test_arena.tscn`, corre ao
  arrancar e reporta falhas via `push_warning`; ferramenta de editor
  `validate_city_graph.gd` (`@tool extends EditorScript`) testa várias seeds
  fixas de uma vez, fora do Play mode.
- Trabalho inteiramente aditivo: não altera `sector_generator.gd`,
  `city_road_grid.tscn` nem `east_sector.tscn`. Falta validação manual no
  editor (sem binário Godot nem suite de testes neste ambiente) e as fases
  3–7 (geometria real, quarteirões/lotes, reintegração de edifícios/POIs/
  props/navegação).

## Decisões pendentes

- resolução inicial;
- layout definitivo de controlos.
- afinação final da Spear como secundária do Medic.
- afinação final dos 30/45 segundos, custo de 30 Scrap, 200 pontos de vida e limites da reparação/construção no modo survival contínuo.
- alcance final do disparo automático entre 2 e 3 metros e permanência do controlo manual.
- aprovação da expansão do protótipo de dois setores para 16 setores e 256 × 256 metros.

## Problemas conhecidos

- Os ataques contínuos reutilizam apenas três composições e escalam a quantidade de Normal Zombies; Brute, Spitter, boss e progressão por variedade ficam para etapas posteriores.
- Os oito caches exteriores são estáticos; o Scrap do armazém e da estação reaparece por ciclo, ainda sem loot aleatório ou inventário.
- A construção livre está funcional e permite movimento durante a colocação, mas custos, alcance, colisões, leitura do ghost e limites da grelha ainda precisam de playtest. A demolição/reembolso já tem comando próprio (`structure_demolish`, tecla X por omissão): fora do modo construção, junto de uma estrutura, devolve 50% do custo em Scrap armazenado.
- O ataque da Worn Sword usa um volume retangular frontal como aproximação de um arco; alcance, dano e apresentação ainda precisam de playtest.
- A Spear do Medic é funcional, mas dano, alcance e cadência ainda precisam de playtest.
- Os modelos CC0 atuais são provisórios; Mixamo e a escolha de arte final continuam pendentes para o Milestone 12.
- A postura agachada usa uma pose fixa retirada da animação `Duck`; necessita de afinação ou de uma animação final adequada.
- A reserva de munições ainda usa um pickup genérico; o do armazém reaparece por ciclo, mas tipos de munição e regras próprias por arma ainda não existem.
- As colisões das paredes permanecem invisíveis como limite de segurança temporário; devem ser substituídas por limites naturais totalmente legíveis depois do playtest do mapa.
- Os quatro POIs têm interiores próprios, mas continuam a usar geometria graybox e loot fixo.
- O medkit do hospital aplica cura imediata fixa até 40 pontos; ainda não existem inventário, transporte de consumíveis ou tipos diferentes de medicamentos.
- As duas caixas do posto militar usam o pickup genérico de munições; ainda não existem tipos separados por arma nem loot aleatório.
- As duas caches da estação usam o pickup genérico de Scrap; ainda não existem recursos de combustível nem uma tabela de loot própria.
- O setor persistente ainda faz parte de `test_arena.tscn`; apenas o setor leste está isolado numa cena própria.
- O setor leste já usa background loading medido (9–15 ms no graybox); falta repetir a medição com setores de geometria real.
- A geração faseada elimina a pausa única, mas cada quadrante de estradas ainda custa ~35–45 ms no seu frame; dividir por peça de estrada ou usar um pool fica para depois de medir em jogo real.
- Os setores gerados têm POIs com fachada temática, entrada e interior simples, mas ainda não têm interiores detalhados; a emboscada é única por partida em vez de reposta por ciclo.
- O estado por setor cobre caches, munições e emboscada; estruturas locais e descoberta de POIs ainda não têm estado.
- Apenas o estado do farol é preservado ao descarregar; loot, encontros, inimigos e estruturas locais ainda não possuem estado de setor.
- O disparo automático pesquisa o grupo `enemy` a cada frame de física e usa provisoriamente 3 metros; desempenho e sensação precisam de playtest com hordas maiores.
- Com a perseguição exclusiva do jogador, a vida do núcleo e as estruturas
  construídas têm utilidade defensiva limitada; o bloqueio de navegação funciona,
  mas o seu papel no combate precisa de playtest e objetivos próprios.
- Ameaças de exploração não contam para a vaga e podem continuar vivas quando o ataque seguinte começa se forem ativadas perto do fim da exploração.
- As hitboxes de corpo e cabeça acompanham a raiz do zombie, mas ainda não seguem ossos individuais durante as animações.
- O flash de dano e os sons sintetizados são provisórios; arte de reação (animações de hit) e áudio final ficam para milestones de arte.
- Ataque melee, salto e movimento já controlam animações provisórias; recarga, dano e morte ainda não possuem animações próprias.
- O mapa tático ainda não possui fog of war, nomes próprios para todos os POIs,
  filtros de marcadores, zoom ou navegação por cursor.
