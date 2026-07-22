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

## Milestone 20 — Arsenal e arte de armas (atual)

Objetivo: substituir os modelos estáticos das armas pelo pack CC0
**Quaternius Animated Guns** e alargar o arsenal.

- [ ] Integrar o pack (download do utilizador): Pistol, Shotgun, AR/P90.
- [ ] Ligar animações de disparo/recarga aos eventos do `WeaponController`.
- [ ] Avaliar SMG (P90) e Marksman (sniper) como armas novas compráveis.
- [ ] Rever balanceamento do arsenal após playtest.

## Milestone 21 — Ambiente e POIs finais

- [ ] Escolher e integrar um pack CC0 de edifícios (Quaternius/Kenney).
- [ ] Substituir os POIs graybox dos setores gerados por edifícios reais.
- [ ] Variedade de POIs gerados (2–3 plantas diferentes).

## Milestone 22 — Balanceamento e sensação de jogo

- [ ] Curva do diretor de horda (intervalo de subida, lotes, limite simultâneo).
- [ ] Decisões de playtest pendentes: alcance do auto-fire (2–3 m vs 6 m),
  manter disparo manual, 2ª arma do Medic.
- [ ] Mini-hitch do `add_child` dos setores (encaixar malhas por frames) — em
  espera a pedido do utilizador.

## Milestone 23 — Polimento e conteúdo extra (backlog)

- [ ] Mais objetivos de mastery e recompensas.
- [ ] Construção livre / mais estruturas da base.
- [ ] Salvamento de partida a meio (continuar uma run).
- [ ] Persistência opcional de loot entre partidas (se o playtest o pedir).
- [ ] Mixamo (parqueado): só se for precisa uma animação que o Quaternius não tem.
