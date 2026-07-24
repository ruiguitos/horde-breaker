# Horde Breaker — Roadmap

Sincronizado a 2026-07-22. Os milestones 0–19 estão concluídos; o detalhe de
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
  fortificação, POIs com interiores (hospital, armazém, posto militar, estação),
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
- [x] Spear do Medic baseada na malha embutida, com alcance melee e animação `Stab`.
- [x] Primeiro passe de identidade das classes: Recruit 100 HP/recarga rápida,
  Renegade 150 HP, Medic 100 HP/regeneração 3 HP/s após 4 s.
- [x] Variantes de classe como capstone da mastery (VETERAN/BERSERKER/COMBAT
  MEDIC), alternáveis na seleção e aplicadas no arranque da partida.
- [x] Munição do chão a escalar com o nível de ameaça (base + 4/nível, teto 4×).
- [ ] Rever dano, cadência, alcance automático e regeneração após playtest das
  três classes (incluindo os números das variantes).
- [x] SMG (automática, cadência 11/dano 16, carregador 35; nível 3 · 400 cr) e
  Fire Axe (melee, dano 70/cooldown 0,9 s; nível 4 · 500 cr) compráveis no
  ARMORY, com as malhas embutidas SMG/Axe e ícones gerados.
- [x] Alcance de auto-fire por arma (AR 6 m, Pistol 5,5 m, Shotgun 4,5 m, SMG 7 m).

## Milestone 24 — Cidade a sério (atual)

Objetivo: substituir o graybox dos setores gerados por uma cidade CC0 real
(Quaternius Downtown MegaKit), mantendo a geração procedural e a navegação.

- [x] Pack CC0 importado (`assets/models/city_test_model`, glTF); fonte/licença
  documentadas em `SOURCE.md`.
- [x] Edifícios completos (Small/Medium/Large) substituem os cubos graybox como
  `navigation_blocker`, colocados pela geração por seed (2–3 por setor); planters
  de passeio adicionados. Navegação e worker-thread intactos.
- [x] Mais props de cidade: bollards e tampas de esgoto (decoração sem colisão)
  + mais planters, para encher os quarteirões.
- [ ] Tiles de estrada reais do Downtown (opcional): as estradas atuais já são
  tiles Quaternius texturados com marcações; swap é polish de baixa prioridade.
- [ ] Mais props ainda (AC nas fachadas, drenos, veículos) e afinar densidade.
- [ ] POIs exploráveis com fachadas reais (interior + loot mantidos).
- [ ] Atmosfera do mundo (luz/nevoeiro/hora do dia) alinhada com os novos assets.

## Milestone 21 — Ambiente e POIs finais (absorvido pelo M24)

- [x] Escolher e integrar um pack CC0 de edifícios (Quaternius Downtown MegaKit).
- [ ] Substituir os POIs graybox dos setores gerados por edifícios reais.
- [ ] Variedade de POIs gerados (2–3 plantas diferentes).

## Milestone 22 — Balanceamento e sensação de jogo

- [ ] Curva do diretor de horda (intervalo de subida, lotes, limite simultâneo).
- [ ] Decisões de playtest pendentes: alcance do auto-fire por arma e manter
  disparo manual.
- [ ] Mini-hitch do `add_child` dos setores (encaixar malhas por frames) — em
  espera a pedido do utilizador.

## Milestone 23 — Polimento e conteúdo extra (backlog)

- [ ] Mais objetivos de mastery e recompensas.
- [ ] Construção livre / mais estruturas da base.
- [ ] Salvamento de partida a meio (continuar uma run).
- [ ] Persistência opcional de loot entre partidas (se o playtest o pedir).
- [ ] Mixamo (parqueado): só se for precisa uma animação que o Quaternius não tem.
