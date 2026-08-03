# Horde Breaker — Roadmap

Sincronizado a 2026-08-01. Os milestones 0–19 estão concluídos; o detalhe de
cada um vive no histórico do `docs/PROGRESS.md`.

## Regras

- Uma etapa deve estar funcional antes da seguinte.
- Cada etapa termina com teste, atualização de `PROGRESS.md` e comandos Git.
- Assets externos só com autorização explícita (downloads são do utilizador).

## Concluído (resumo)

- **M0–M9 — Núcleo jogável:** bootstrap, arena, movimento, câmara 3ª pessoa,
  hitscan, Normal Zombie, vida/derrota, rondas iniciais, HUD, múltiplas vagas.
- **M10–M14 — Progressão e classes:** save permanente (XP/Credits/armas), menus,
  Renegade melee, três classes com loadouts e passivos, modelos CC0 Quaternius.
- **M15–M17 — Survival e exploração:** núcleo/acampamento, Scrap e reparação,
  torres defensivas exteriores, POIs com interiores (hospital, armazém, posto militar, estação),
  dano por zonas, feedback de combate, tema visual próprio.
- **M18 — Mundo aberto compacto:** grelha 4×4 por seed, streaming em worker
  threads, navegação contínua, céu procedural, mapa tático.
- **M19 — Open World Sandbox:** diretor de horda contínuo (sem rondas),
  acampamento como zona de reabastecimento, jogo todo em inglês, variedade de
  inimigos (Brute/Spitter/Boss), skill tree permanente sem teto de níveis,
  armas encontráveis, POIs gerados, emboscadas por ciclo, persistência do mundo
  no save, melhorias da base, mastery, animações de ataque/dano/morte,
  orçamento de IA e métricas de streaming.

## Milestone 20 — Arsenal e progressão controlada (atual)

Objetivo: tornar compras/loadouts utilizáveis e impedir que a skill tree seja
concluída demasiado cedo, mantendo as malhas embutidas nos rigs Quaternius.

- [x] Pontos de skill ganhos a cada dois níveis e tiers limitados aos níveis
  2/5/9/14/20, sem retirar skills de saves anteriores.
- [x] Ecrã `ARMORY` com estados comprado/comprável/bloqueado, compra com Credits
  e escolha persistente dos slots 1/2.
- [x] Spear do Medic baseada na malha embutida (implementação histórica,
  posteriormente retirada do catálogo jogável).
- [x] Primeiro passe de identidade das classes: Recruit 100 HP/recarga rápida,
  Renegade 150 HP, Medic 100 HP/regeneração 3 HP/s após 4 s.
- [x] Variantes de classe como capstone da mastery (VETERAN/BERSERKER/COMBAT
  MEDIC), alternáveis na seleção e aplicadas no arranque da partida.
- [x] Munição do chão a escalar com o nível de ameaça (base + 4/nível, teto 4×).
- [ ] Rever dano, cadência, alcance automático e regeneração após playtest das
  três classes (incluindo os números das variantes).
- [x] SMG automática (cadência 11/dano 16, carregador 35; nível 3 · 400 cr)
  comprável no ARMORY. A Fire Axe desta passagem foi depois retirada.
- [x] Armas melee retiradas do catálogo, ARMORY, pickups, loadouts, evoluções,
  HUD e animações ativas. Saves antigos migram para AR/Pistol, Shotgun/SMG e
  Pistol/SMG sem perder os contadores históricos.
- [x] Alcance de auto-fire por arma (AR 6 m, Pistol 5,5 m, Shotgun 4,5 m, SMG 7 m).

## Milestone 24 — Terrain3D e reconstrução do mapa (em curso)

O protótipo de cidade foi retirado da arena. A base atual é um Terrain3D
contínuo e limpo; casas, estradas, props e POIs só regressam depois de o relevo,
os percursos e o desempenho estarem validados.

- [x] Terrain3D 1.0.2 autorizado e integrado sem assets externos do demo.
- [x] Nove regiões persistentes cobrem os 512 × 512 m dos 64 setores.
- [x] Plataforma nivelada do acampamento, relevo ondulado e corredor natural.
- [x] Primeira ilha integral: costa irregular, plano de água, fundo marinho e
  massas de relevo macro; opções registadas em `docs/TERRAIN_MAP_OPTIONS.md`.
- [x] Spawns, loot e navegação excluídos do mar; zombies consultam a altura real
  dos recursos Terrain3D carregados em vez de repetirem a fórmula procedural.
- [x] `MapRoads`, `MapStructures` e `MapProps` esvaziados; POIs autorados removidos.
- [x] Forward+ restaurado e colisão otimizada para hordas: jogador usa colisão
  dinâmica, zombies usam consulta de altura.
- [x] Barreira física persistente deslocada 24 m para dentro do mar; costa e
  espuma ficam livres, paredes quadradas foram removidas e a continuidade foi
  validada à superfície e abaixo do fundo marinho.
- [x] Playtest técnico automatizado cobre os dois caminhos, doze aterragens do
  jogador, declives por amostragem e contacto dos cinco tipos de inimigo.
- [x] Dois caminhos terrain-native em anel e três ligações, espuma costeira,
  cinco zonas de material e quatro landmarks de relevo.
- [x] Mapa tático recortado pela costa, com mar, caminhos e landmarks; a grelha
  de setores fica apenas como referência sobre a parte terrestre.
- [ ] Fazer o playtest humano prolongado de visibilidade, sensação dos declives,
  rotas de fuga e leitura espacial.
- [ ] Reintroduzir POIs/dressing em pequenos lotes, com orçamento de render e
  navegação medido por etapa.
- [ ] Avaliar a criação de um minimapa dedicado.
  Estudar referências de outros jogos antes de decidir escala, orientação,
  fog of war, marcadores, filtros, zoom, objetivos e relação entre minimapa,
  bússola e mapa completo.

## Milestone 25 — Construção livre da base (implementado; requer playtest)

- [x] Data layer e catálogo para Barricade, Scrap Wall, Watch Tower, Generator e Spotlight.
- [x] Grelha de 2 m, snapping, rotação, reserva do núcleo e preview verde/vermelho.
- [x] Compra com Scrap armazenado, requisitos por upgrade e modo de construção rebindable.
- [x] Persistência de posição, rotação e vida; ocupação e navegação atualizadas após colocar/destruir.
- [x] Reparação por interação e visuais do acampamento para Resupply Rate 2 e Scavenging 1.
- [x] Movimento do jogador mantido durante o catálogo e a colocação; a câmara
  continua controlável durante o preview, e armas/interação normal ficam suspensas.
- [ ] Playtest de custos, alcance de construção, colisões e leitura visual.
- [x] UX explícita de demolição/reembolso: interação dedicada na `InteractionZone`
  da estrutura (fora do modo construção) devolve 50% do custo em Scrap armazenado.

## Milestone 26 — Survivors-like (inspiração YAZS)

Objetivo: adotar o *feel* do Yet Another Zombie Survivors no combate, mantendo o
mundo aberto, POIs e base como diferenciador.

- [x] **Fase 1:** cartas de upgrade por nível de run, orbes de XP largadas pelos
  inimigos (com íman) e feel survivors (câmara recuada + auto-fire alargado).
- [x] **Fase 2 — estrutura de run:** sobreviver 10 min até à extração, com
  relógio no HUD, avisos e recompensa de 300 Credits.
- [ ] Refazer o fim da run: quando o tempo terminar, entrar numa fase finita de
  limpeza dos zombies ativos; só depois de não restarem inimigos deve ficar
  disponível um ponto de extração numa localização específica do mapa. A run
  termina apenas quando o jogador chegar a esse ponto.
- [x] **Fase 3 — hordas massivas:** LOD de simulação (navmesh
  perto, steering direto ao médio, frames saltados ao longe) e LOD de animação
  (>42 m desliga o AnimationPlayer). O teto de gameplay é agora 90, partilhado
  por todas as origens de spawn, com guarda absoluta de 120, fila máxima de 12
  e apenas 2 novas instâncias por frame de física.
- [x] Evolução de armas por abates (4 evoluções desbloqueadas no ARMORY).
- [ ] Esquadrão de 3 personagens (controlas 1, IA segue) — o mais caro.

## Milestone 27 — Arquipélago modular (em curso)

Objetivo: transformar a ilha atual no ponto de partida de uma rede navegável de
ilhas com escalas, formas, biomas, encontros e recompensas próprias, reutilizando
os modelos CC0 que já existem no projeto.

- [x] Definir estratégia híbrida: 2–4 ilhas próximas por zona marítima e zonas
  distantes carregadas separadamente; apenas a ilha/zona ativa mantém IA,
  colisão e conteúdo completos.
- [x] Criar Shipwreck Rocks como ilha piloto pequena sem alterar a arena nem o
  save principal: uma região Terrain3D persistente, dois cais, destroços e cache
  exclusiva de demonstração.
- [x] Implementar transporte automático entre os dois cais com um ferry low-poly,
  antes de considerar controlo livre ou física naval.
- [x] Criar `IslandData`, `IslandRouteData` e `ArchipelagoData`, com validação do
  grafo e quatro ilhas ligadas num protótipo Terrain3D separado.
- [x] Validar duas escolhas no hub e convergência na ilha final: recife raso,
  gruta inundada, ponte destrutível e ruínas físicas.
- [x] Guardar o plano de gameplay por ilha e criar o vertical slice de Dawn
  Beach: três células de energia, acampamento de expedição, terminais A/B,
  bloqueio físico da rota não escolhida e noclip de desenvolvimento em Mouse 4.
- [ ] Implementar a expansão física do acampamento de Dawn Beach por tiers:
  começar apenas com o núcleo, ampliar perímetro e serviços com upgrades e
  terminar na fortaleza da referência visual, incluindo sockets para torres.
- [ ] Fechar as decisões do interior do acampamento — estações, segurança,
  destruição/reconstrução, NPCs, construção livre, UI e orçamento de render —
  antes de produzir todos os tiers.
- [ ] Adaptar mapa tático, persistência de descoberta e diretor de horda à ilha ativa.
- [ ] Reintroduzir um único kit visual na ilha piloto e medir FPS/draw calls.

## Milestone 21 — Ambiente e POIs finais (absorvido pelo M24)

- [x] Escolher e integrar um pack CC0 de edifícios (Quaternius Downtown MegaKit).
- [x] Substituir os POIs graybox dos setores gerados por fachadas temáticas.
- [x] Variedade de POIs gerados com três fachadas/planta visual.

## Milestone 22 — Balanceamento e sensação de jogo

- [x] Primeira proteção da curva do diretor: teto simultâneo global de 90,
  reservas em fila limitadas a 12 e instanciação limitada a 2 por frame.
- [ ] Afinar intervalo, composição e teto após playtest/profiling em Forward+.
- [ ] Otimização orientada por profiling: benchmark atual de 140 zombies ronda
  26 FPS no GL Compatibility; começar por skinning/animação e draw calls antes
  de reduzir conteúdo visual.
- [ ] Decisões de playtest pendentes: alcance do auto-fire por arma e manter
  disparo manual.
- [ ] Mini-hitch do `add_child` dos setores (encaixar malhas por frames) — em
  espera a pedido do utilizador.

## Milestone 23 — Polimento e conteúdo extra (backlog)

- [ ] Mais objetivos de mastery e recompensas.
- [x] Construção livre / mais estruturas da base (entregue no M25; falta playtest).
- [ ] Salvamento de partida a meio (continuar uma run).
- [ ] Persistência opcional de loot entre partidas (se o playtest o pedir).
- [ ] Mixamo (parqueado): só se for precisa uma animação que o Quaternius não tem.
- [x] Definir papéis e combinações não repetidas para a expansão de classes,
  armas e skills em `docs/CONTENT_EXPANSION_PLAN.md`.
- [ ] Implementar a expansão de conteúdo pela ordem aprovada, começando por uma
  classe/arma vertical slice e medindo desempenho antes da seguinte.
- [x] Remover armas melee e migrar Renegade, Medic, BERSERKER, ARMORY, pickups,
  evoluções, animações, HUD e saves antigos para alternativas de armas de fogo.
- [ ] Melhorar as animações e o encaixe das mãos nas armas: avaliar grips por
  arma, `BoneAttachment3D`, poses de mira, disparo e recarga compatíveis com o rig.
- [ ] Investigar o pipeline de arte final para personagens e mapa, comparando:
  geração procedural com Three.js e exportação para glTF/GLB; modelos existentes
  compatíveis com Godot; e criação/ajuste num modelador 3D. Avaliar licença,
  rig/animações, escala, materiais, colisões, tamanho e desempenho antes de
  autorizar qualquer download ou importação.
