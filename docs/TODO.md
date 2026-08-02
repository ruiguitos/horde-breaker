# Horde Breaker — TODO

## Pendentes confirmados

- [x] Limitar todos os spawns ao orçamento global de 90 zombies, com fila máxima
  de 12 e instanciação de apenas 2 inimigos por frame de física.
- [x] Retirar armas melee do jogo ativo e migrar loadouts/saves antigos para
  armas de fogo sem apagar estatísticas históricas.
- [ ] Implementar novas classes, armas e módulos de skills pela matriz de
  papéis de `docs/CONTENT_EXPANSION_PLAN.md`, uma vertical slice de cada vez.
- [x] Implementar pausa real com `Esc`, incluindo pausa da árvore, libertação do rato e painel próprio.
- [ ] Integrar modelos e animações do Adobe Mixamo no Milestone 12, depois de o protótipo de combate estar funcional. Não descarregar assets sem autorização explícita. **Bloqueado: aguarda autorização para descarregar assets.**
- [x] Integrar modelos CC0 de teste para as três classes, dois tipos de zombie e as três armas de fogo, preservando colisões e mecânicas.
- [x] Criar a primeira expansão graybox da arena com três obstáculos, navegação que os contorna e seis pontos de spawn validados.
- [ ] Evoluir o graybox para um mapa totalmente jogável, afinando rotas, zonas de combate, coberturas e spawns através de playtests com Recruit, Renegade e Medic. **Nota: será substituído pela geração de mapa open world planeada.**
- [x] Substituir os quatro bairros repetidos pelo primeiro graybox de hospital, armazém, posto militar e estação de combustível.
- [x] Tornar o armazém no primeiro edifício explorável, com entrada, interior graybox e loot funcional de teste.
- [x] Adicionar ao armazém uma emboscada por ciclo e reposição controlada de Scrap e munições.
- [x] Abrir o hospital como segundo interior explorável e adicionar um medkit de 40 pontos reposto por ciclo.
- [x] Abrir o posto militar com duas caixas de munições e um encontro de dois Normal Zombies mais um Runner.
- [x] Abrir a estação de combustível com duas caches de Scrap e um encontro de três Runners por ciclo.
- [x] Escolher ataques agendados com aviso longo e aprovar o protótipo de dois setores descrito em `docs/OPEN_WORLD_PLAN.md`.
- [x] Criar o primeiro setor leste carregável, com navegação ligada e estado do farol preservado em memória.
- [x] Implementar carregamento em background dos setores com `ResourceLoader.load_threaded_request` e medição do tempo de carga.
- [x] Grelha 4 × 4 de setores implementada com geração procedural por seed, estado de caches por setor e navegação contínua; a extração do setor inicial foi substituída pela decisão de manter o acampamento persistente.
- [x] Adicionar encontros (emboscada única por setor), spawns próprios, caixa de munições com estado e geração distribuída por vários frames aos setores gerados.
- [x] Fazer as hordas nascerem nos pontos de spawn mais próximos do jogador, incluindo os marcadores dos setores carregados.
- [x] Adicionar POIs com interiores exploráveis aos setores gerados (edifício graybox com muros, uma porta, chão interior e cache de recompensa lá dentro; marcador no mapa tático).
- [x] Repor emboscadas por ciclo em vez de uma única por partida: o `WorldStreamer` liga-se ao `cycle_completed` do diretor de horda e re-arma as emboscadas dos setores a cada ciclo (~3 níveis de ameaça), com guarda que impede duplicar enquanto os inimigos anteriores estiverem vivos.
- [x] Implementar classes com loadout principal/secundário, passivos do Recruit, Renegade e Medic, e troca de arma com `1`/`2`.
- [x] Adicionar andar, corrida com `Shift`, salto com `Space`, agachamento com `Ctrl`, interação com `F`, vista frontal com `C` e mira com o botão direito do rato.
- [x] Criar um pickup de munições de teste e corrigir o visual suspenso da Worn Sword no Renegade.
- [x] Adicionar munição de reserva, recarga com consumo real e recolha de munições mesmo com uma arma melee ativa.
- [x] Criar a primeira composição urbana com modelos ambientais CC0 e remover as paredes graybox visíveis.
- [x] Implementar dano por zonas com corpo a `1 ×` e cabeça a `2 ×` para armas de fogo e armas brancas.
- [x] Adicionar números de dano pequenos, com cor distinta para impacto no corpo e headshot.
- [x] Adicionar disparo automático das armas de fogo contra inimigos com linha de visão até 3 metros.
- [ ] Afinar entre 2 e 3 metros e decidir se o disparo manual permanece depois do playtest das três classes. **Bloqueado: decisão do playtest.**
- [x] Alterar a IA para perseguir apenas o jogador e remover núcleo, acampamento e fortificações da seleção de alvos e das condições de derrota.
- [x] Adicionar feedback visual no próprio inimigo e feedback sonoro distinto para impacto no corpo e headshot.
- [x] Definir a Spear como arma secundária do Medic, usando a malha embutida e a animação `Stab`.
- [x] Implementar a primeira escolha de melhoria entre rondas, inspirada nos jogos analisados em `docs/INSPIRATIONS.md`.
- [x] Adotar survival contínuo com núcleo, exploração, Scrap e construção progressiva do acampamento.
- [x] Criar o primeiro ponto fixo para construir, reparar e reconstruir uma barricada com Scrap.
- [x] Corrigir as definições para guardar o modo de janela, mostrar a resolução
  real do monitor em fullscreen e aplicar a resolução selecionada em modo janela.
- [x] Adicionar um mapa tático em `Tab` com grelha de setores e marcadores do
  jogador, acampamento, POIs e inimigos ativos.
- [x] Remover as rondas e adotar um diretor de horda contínuo que faz nascer
  inimigos à volta do jogador durante a exploração, com escalada por nível de
  ameaça e mais zombies em simultâneo.
- [x] Aumentar o alcance do disparo automático de 3 para 6 metros.
- [x] Randomizar as posições do Scrap e das munições do acampamento a cada partida.
- [x] Melhorar o mapa tático: setor atual destacado, marcadores de Scrap, munição
  e medkit, e chip de acento no estilo do HUD.
- [x] Converter todo o texto do jogo (menus, HUD, mundo, dados) para inglês.
- [x] Enriquecer os setores gerados com torre de água, camião destroçado e postes
  de iluminação além dos marcos e contentores.
- [x] Transformar o acampamento numa zona de reabastecimento (cura e munições ao
  ficar perto do núcleo), inspirado no hub das referências.
- [x] Remover as etiquetas 3D por cima das caches de Scrap e das caixas de munições.
- [x] Auto-pickup de Scrap e munições ao passar por cima, sem premir `F`.
- [x] Remover o delay/pop-in ao carregar setores, gerando-os antes de estarem à vista.
- [x] Melhorar o mapa tático: bússola Norte, setor atual destacado, setores
  visitados, marcadores de armas e de objetivos, e legenda alargada.
- [x] Reduzir o HUD in-game ao essencial (vida, munição, ameaça compacta, Scrap
  pequeno), removendo a placa do núcleo, a placa grande de recursos e a barra de atalhos.
- [x] Adicionar armas encontráveis pela exploração: caixas de arma nos setores
  gerados que substituem a arma secundária durante a partida, com estado por setor.
- [x] Adicionar variedade de inimigos: Brute (tanque com knockback), Spitter
  (ataque à distância) e o boss The Breaker (invoca minions), ligados à
  escalada do diretor de horda.
- [x] Baixar a resolução por defeito para janela 1152 × 648 e adicionar um
  contador de FPS (autoload, alternável com `F3`) para testes.
- [ ] **Em espera:** ainda existe um mini-hitch no instante em que um setor
  gerado aparece (o `add_child` regista ~64 malhas de uma vez). Próximo passo
  possível: encaixar as peças do setor em 2-3 frames em vez de todas de uma vez.
- [x] Remover o limite de níveis das personagens e adicionar uma árvore de
  habilidades permanente por personagem (skill tree), com um ponto a cada dois
  níveis e requisitos de nível 2/5/9/14/20 por tier.
- [x] Remover o "Field Upgrade" (melhorias entre rondas), substituído pela skill tree.
- [x] Ao apanhar uma arma do chão, largar a arma substituída no chão para poder
  voltar a apanhá-la.
- [x] Animar o ataque dos inimigos com o clip `Idle_Attack` já existente nos
  modelos Quaternius, disparado pelo sinal `attacked`.
- [x] Persistir o estado do mundo no save: seed fixo por perfil, setores
  visitados e farol este (loot continua por partida, por decisão de design).
- [x] Melhorias da base com Scrap armazenado: pedestais de Resupply Rate,
  Resupply Range e Scavenging junto ao núcleo, 3 níveis cada.
- [x] `HitReact` e animação de morte (`Death`) nos inimigos, com cadáver breve
  sem colisão nem hitboxes.
- [x] Dois pontos de fortificação extra à volta do acampamento (total 3).
- [x] Objetivos de mastery por personagem com recompensa em Credits, visíveis
  na seleção de classes.
- [x] Orçamento de IA para inimigos distantes (repath e steering reduzidos
  além de 40 m).
- [x] Métricas de streaming no overlay de FPS (`F3`).
- [x] Painel de vitória antigo removido; sinal morto `all_waves_completed`
  retirado.
- [x] Decisão do navmesh registada: manter a grelha runtime (setores gerados
  em runtime não podem usar navmesh de editor).
- [x] `GDD.md`, `ARCHITECTURE.md` e `ROADMAP.md` sincronizados com o jogo real.
- [x] Facelift visual Tier 1 dos menus: backdrop 3D leve no menu principal,
  pré-visualização animada da classe selecionada, interação dos botões,
  transições internas, Credits animados e painéis com profundidade procedural.
- [x] **Experiência do pack "Animated Guns" revertida por decisão de playtest:**
  o visual da arma na cena (ancorado ao `WeaponPivot` estático) nunca assenta
  bem nas mãos — as malhas embutidas nos personagens (animadas pelo próprio
  esqueleto) continuam a ser o padrão. Aprendizagem: futuros modelos de armas
  só funcionam presos ao osso da mão (`BoneAttachment3D`) ou embutidos no rig.
  As armas novas (Hunting/Marksman/Revolver) foram removidas junto com o pack;
  o design (stats/custos) fica no histórico git para quando houver modelos.
- [x] Ecrã de compra de armas (`ARMORY` na seleção de classes): lista com estado
  possuída/comprável/bloqueada, compra com Credits e escolha persistente do slot.
- [x] SMG implementada com a malha embutida. Fire Axe e Spear foram prototipadas
  nesta etapa histórica e depois retiradas do catálogo jogável.

- [x] Adicionar drop de Scrap por tipo de inimigo ao morrer, com quantidades
  configuráveis, despawn após 25 segundos e limite de 40 pickups ativos.

- [x] UI Tier 2: tipografia Rajdhani OFL, retratos das classes, ícones das cinco
  armas jogáveis no ARMORY/HUD e sons discretos de interação.
- [x] UI Tier 3: polimento final do HUD, skill tree, pausa/derrota, ARMORY,
  definições e mapa tático, com validação visual por ecrã.
- [ ] Melhorar a separação ou agregação de marcadores coincidentes no mapa
  tático quando vários pickups ocupam a mesma zona. Melhoria futura; não
  bloqueia o Tier 3.

- [x] Menu de definições reorganizado em separadores **DISPLAY / CONTROLS /
  AUDIO**, com **keybindings rebindable**: captura de tecla/rato ao clicar,
  swap automático em conflito, reset a defaults, persistência na secção
  `[input]` das settings e aplicação real ao `InputMap` no arranque (`pause`
  fica fixo em Esc por segurança).
- [ ] Os textos 3D do mundo ("[F] BUILD", "[F] UPGRADE", "[F] DEPOSIT") mostram
  a tecla fixa — ler o binding real de `interact` via
  `SettingsManager.get_action_binding_text` nos labels dinâmicos.

- [x] Munição do chão escala com o nível de ameaça (base + 4 por nível, teto
  4×) com feedback "+N AMMO" no HUD.
- [x] **Variantes de classe** desbloqueadas ao completar as 3 masteries da
  classe (capstone): VETERAN (Recruit, −recarga rápida/+15% cadência),
  BERSERKER (Renegade, 110 HP/+20% dano de armas de fogo), COMBAT MEDIC (Medic, regen
  fraca + 5 HP por abate). Toggle persistido na seleção de classes, aplicação
  no arranque via `character_skills.gd`, tint subtil no modelo.
- [ ] Rever os números das variantes após playtest (dano do Berserker, heal-on-kill,
  cadência) e considerar variantes com loadouts próprios no futuro.
- [x] SMG e Fire Axe chegaram a estar compráveis no ARMORY; a Fire Axe foi
  posteriormente retirada. Auto-fire por arma afinado (SMG 7 m).
- [ ] **Playtest e balanceamento (M22):** rever dano/cadência/regen das 3 classes
  e das variantes, e a curva do diretor de horda (intervalo, lotes, limite) —
  precisa de sessão de jogo real; não é implementável às cegas.

## Do plano de implementação (2026-07-27)

Triados a partir de `IMPLEMENTATION-PLAN.md`. As erratas estão no cabeçalho
desse ficheiro; abaixo ficam só os itens verificados contra o código.

### Críticos

- [ ] **Restaurar a base no mundo 8×8.** Sem ela não há depósito de Scrap nem
  upgrades, e o core loop fica truncado. Abordagem: cena `camp_sector.tscn` com
  `CampCore`, `BuildGrid`, estações de upgrade e pontos de fortificação,
  carregada no setor (0,0). Nota: `camp_builder.gd` existe mas o nó foi removido
  da arena — voltará a precisar de ser ligado. Confirmar também se
  `SaveManager.get_base_layout()` é definição ou chamada órfã.
- [ ] **Catalogar as inconsistências do mapa** notadas no playtest. Suspeitos
  segundo o plano: colisões contra o terreno, navegação em células pintadas,
  loot/spawns dentro de paredes, continuidade entre setores.

### Importantes

- [ ] **Medir** por que ficou lento o arranque da arena em headless com 8×8.
  ⚠️ **Não** baixar `load_distance` para 48 como o plano sugere: os centros dos
  setores estão a 64 m, e 72 m existe precisamente para os apanhar. 48 abriria
  buracos à frente do jogador.
- [ ] **`SectorData.tres` por setor** com posições à mão para spawns, loot e
  POIs, mantendo a geração procedural como fallback. Cobre o pedido dos spawns
  em `Marker3D`.
- [ ] **Efeitos Forward+** nos presets de atmosfera (SSAO, SSIL, nevoeiro
  volumétrico). ⚠️ Editar os `.tres` à mão perde-se ao correr
  `tools/apply_skyboxes.gd` — a alteração tem de ser feita nessa ferramenta.
- [ ] **Afinar os 64 setores**: densidade de loot, inimigos, POIs, coberturas.
- [ ] **Balanceamento de combate** com as **2** classes atuais (o plano diz 3).

### Opcionais registados

- [ ] Som e música; partículas (sangue, fogo, poeira); feedback de UI
  (direção do dano, aviso de munição baixa); suporte a gamepad; localização.

## Pedidos por detalhar (2026-07-27)

Registados pelo utilizador como "todo", sem especificação. Antes de arrancar,
perguntar o que incomoda em cada um — melhorar sem saber o alvo é adivinhar.

- [ ] **Melhorar o menu principal.** O que existe: fundo 3D
  (`menu_backdrop.tscn`), tipografia Rajdhani, botões animados. Por esclarecer:
  é o aspeto, a estrutura (o que está lá e o que falta), ou a sensação de
  arranque do jogo?
- [ ] **Melhorar o mapa.** Sobrepõe-se ao trabalho já em curso em
  `MAP_DESIGN.md` secção 8 — inclui as inconsistências notadas no playtest de
  2026-07-26, que continuam por catalogar.
- [ ] **Melhorar o minimapa.** Ambíguo: hoje existe o **mapa tático** em ecrã
  cheio (`tactical_map.gd`, tecla `Tab`), mas **não existe minimapa permanente**
  no HUD. Confirmar se o pedido é melhorar o mapa tático ou criar um minimapa
  de canto.

## Resolução e responsividade (2026-08-02) — parqueado a pedido

Investigado e medido; a correção fica pendente.

- [x] **Redimensionar a janela partia a interface.** `SettingsManager` fixava o
  `content_scale_size` e nada o atualizava quando a janela mudava de tamanho por
  outra via (arrastar um canto, a janela embebida do editor). Corrigido ligando
  o `size_changed` da janela.
- [ ] **A página de seleção de classes não cabe na resolução por omissão.**
  Medido: com um viewport de 1152×648, a página precisa de **1205×757**. Não é
  escalar mal, é não caber — e é daí que vem a barra `CLASS LOADOUT` desenhada
  por cima das cartas. Duas tentativas de correção (reordenar contentores;
  reconstruir antes de ordenar) **não resolveram**; a barra fica presa em
  y≈615 seja qual for a resolução. A correção é estrutural: as cartas encolherem
  (conteúdo com scroll) ou a página adaptar-se (largar o painel de
  pré-visualização em ecrãs pequenos, ou pôr as cartas em duas linhas).
- [ ] **Fullscreen só oferece uma resolução.** O dropdown está *desativado* em
  fullscreen (`resolution_option.disabled = fullscreen`). Proposta: mantê-lo
  ativo como **resolução de render** — baixar o `content_scale_size` abaixo do
  monitor, que é o que os jogos modernos fazem e dá desempenho sem mudar o modo
  de vídeo.
- [ ] **Windowed parece aceitar só uma resolução.** A lista é fixa
  (`1152×648 … 2560×1440`) e ignora o monitor. Num ecrã de 1920×1080 as duas
  maiores não cabem como janela e o Windows corta-as para o mesmo sítio.
  Proposta: construir a lista a partir de `DisplayServer.screen_get_size()` do
  ecrã atual, filtrando as que cabem.
- Contexto medido: dois monitores — 1920×1080 a 144 Hz e 1280×1024 a 60 Hz.

## Regra

Estes itens não alteram o âmbito do milestone atual. Quando forem concluídos, atualizar também `docs/PROGRESS.md`.
