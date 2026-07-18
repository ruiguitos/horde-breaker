# Horde Breaker — Roadmap

## Regras

- Uma etapa deve estar funcional antes da seguinte.
- Cada etapa termina com teste, atualização de `PROGRESS.md` e comandos Git.
- Não adicionar arte Mixamo antes do protótipo de combate estar funcional.

## Milestone 0 — Bootstrap

Objetivo:

- confirmar projeto Godot;
- preparar documentação e Git;
- criar estrutura mínima necessária;
- configurar uma cena de arranque vazia ou de teste.

Critérios:

- o projeto abre;
- não existem erros de parsing;
- a cena principal executa;
- documentação está no repositório.

## Milestone 1 — Test Arena

Objetivo:

- criar chão;
- paredes;
- luz;
- ambiente;
- ponto de spawn do jogador.

Critérios:

- a arena é visível;
- há colisão no chão e paredes;
- não existem assets externos.

## Milestone 2 — Player Movement

Objetivo:

- criar `CharacterBody3D`;
- movimento WASD;
- gravidade;
- rotação básica;
- inputs configurados.

Critérios:

- o jogador anda sem atravessar o chão;
- movimento é independente do framerate;
- valores principais são exportados.

## Milestone 3 — Third-Person Camera

Objetivo:

- pivot;
- SpringArm3D;
- controlo com rato;
- limite vertical;
- captura e libertação do rato.

Critérios:

- a câmara segue o jogador;
- não atravessa paredes facilmente;
- o jogador orienta-se corretamente.

## Milestone 4 — Basic Shooting

Objetivo:

- arma provisória;
- ação `attack`;
- projétil ou hitscan escolhido de forma explícita;
- dano básico;
- cadência.

Critérios:

- disparar produz resultado visível;
- não dispara acima da cadência;
- sistema não depende de um modelo Mixamo.

## Milestone 5 — Normal Zombie

Objetivo:

- inimigo com vida;
- NavigationAgent3D;
- perseguição;
- ataque;
- morte.

Critérios:

- encontra e persegue o jogador;
- não causa dano continuamente sem cooldown;
- morre ao receber dano suficiente.

## Milestone 6 — Health and Game Over

Objetivo:

- vida do jogador;
- dano;
- morte;
- painel de game over;
- reiniciar.

## Milestone 7 — Wave 1

Objetivo:

- pontos de spawn;
- cinco zombies;
- contador de vivos;
- vitória quando todos morrem.

## Milestone 8 — HUD

Objetivo:

- vida;
- munição;
- ronda;
- inimigos restantes.

## Milestone 9 — Multiple Waves

Objetivo:

- configuração de rondas;
- pausa entre rondas;
- aumento progressivo;
- Runner.

## Milestone 10 — Permanent Progression

Objetivo:

- Credits;
- XP por personagem;
- níveis;
- requisitos de armas;
- SaveManager com ConfigFile.

## Milestone 11 — Menu and Character Selection

Objetivo:

- menu principal;
- seleção Recruit/Renegade/Medic;
- compra;
- seleção de armas.

## Milestone 12 — Mixamo

Objetivo:

- importar personagem;
- configurar Skeleton3D;
- animações principais;
- substituir modelos provisórios sem alterar mecânicas.

## Milestone 13 — Renegade Combat

Estado: protótipo base concluído antecipadamente; apresentação e afinação permanecem futuras.

Objetivo:

- espada;
- ataque em arco;
- múltiplos alvos;
- cooldown ou combo;
- dash posterior.

## Milestone 14 — Classes and Loadouts

Estado: primeira versão funcional concluída.

Objetivo:

- dois slots de arma por classe, com segundo slot opcional;
- troca entre arma principal e secundária;
- Recruit com recarga mais rápida;
- Renegade com mais vida;
- Medic com regeneração superior;
- menu e HUD adaptados aos loadouts.

Critérios:

- `1` e `2` trocam entre slots disponíveis;
- apenas a arma ativa processa input;
- saves antigos recebem os novos campos sem perder progresso;
- as vantagens das três classes podem ser medidas em teste.

## Milestone 15 — Survival Foundation

Estado: primeiro vertical slice funcional concluído.

Objetivo:

- substituir a vitória após três rondas por ataques contínuos;
- repetir as composições existentes com aumento progressivo da quantidade;
- adicionar um núcleo do acampamento com vida própria;
- permitir aos zombies atacar o jogador ou o núcleo;
- terminar a partida quando o jogador ou o núcleo forem destruídos;
- apresentar a vida do núcleo no HUD.

## Milestone 16 — Camp Resources and Repair

Estado: concluído.

Objetivo:

- introduzir Scrap obtido durante a partida;
- permitir reparar o núcleo entre ataques;
- apresentar decisões simples de gastar ou guardar recursos;
- preparar uma primeira fortificação colocável sem iniciar ainda construção livre.

Implementado neste slice:

- mapa de teste expandido para 64 × 64 metros com quatro bairros modulares;
- oito caches de Scrap, transporte e depósito no núcleo;
- reparação do núcleo apenas durante fases de exploração;
- preparação inicial de 30 segundos e exploração de 45 segundos entre ataques;
- HUD de recursos, contagem decrescente e feedback contextual.
- primeiro ponto fixo de defesa com construção, 200 pontos de vida, reparação e reconstrução;
- atualização dinâmica da navegação quando a barricada é construída ou destruída.

## Milestone 17 — Exploration Map and Points of Interest

Estado: primeiro vertical slice funcional concluído.

Objetivo:

- substituir a repetição dos quatro bairros por zonas com identidade própria;
- criar POIs maiores, como hospital, armazém, posto militar e estação de combustível;
- distribuir recursos e encontros por rotas de exploração legíveis;
- manter caminhos alternativos entre o exterior e o acampamento;
- medir o tamanho final do mapa e desempenho antes de importar mais modelos.

Implementado neste slice:

- estradas separadas dos adereços repetidos numa cena modular própria;
- hospital, armazém, posto militar e estação de combustível com silhuetas distintas;
- colisões e exclusão de navegação para os volumes principais de cada POI;
- um acesso navegável e uma cache de Scrap próxima por POI;
- composição validada sem descarregar novos modelos.

Pendente:

- tornar o primeiro edifício realmente explorável;
- definir loot e encontros específicos por zona;
- decidir se a arena deve crescer além dos 64 × 64 metros após playtest.
