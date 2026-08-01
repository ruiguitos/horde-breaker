# Horde Breaker — Game Design Document

## Estado

Sincronizado com o jogo real a 2026-08-01. Substitui a versão antiga baseada em
rondas; o histórico detalhado vive em `docs/PROGRESS.md`.

## Visão do jogo

Horde shooter 3D na terceira pessoa, single-player, para Windows. O jogador
explora um **mundo aberto compacto** (8 × 8 setores, 512 × 512 m) enquanto uma
**horda contínua** nasce à sua volta e escala com o tempo. O acampamento central
é o porto seguro: zona de reabastecimento, depósito de Scrap e melhorias da
base. Todo o texto do jogo está em **inglês**; a documentação em português.

## Core loop

`Explorar setores → combater a horda contínua → recolher Scrap/munições/armas →
reabastecer e melhorar a base no acampamento → subir de nível e desbloquear
skills/mastery → aguentar níveis de ameaça cada vez mais altos → morrer →
recomeçar com progressão permanente.`

Não há rondas nem vitória formal: a partida termina com a morte do jogador. A
progressão permanente (XP, skill tree, mastery, Credits) transita entre partidas.

## Personagens

Três classes com loadout primário/secundário (`1`/`2`) e passivos:

- **Recruit** (Assault): Assault Rifle + Pistol; recarrega 30% mais rápido.
- **Renegade** (Vanguard): Shotgun + SMG; 150 de vida. Desbloqueio: 500 Credits.
- **Medic** (Support): Pistol + SMG; regenera 3 HP/s após 4 s sem dano.
  Desbloqueio: 750 Credits.

Movimento: andar 4 m/s, correr 7 m/s (`Shift`), salto (`Space`), agachar
(`Ctrl`), interação (`F`), vista frontal (`C`), mira sobre o ombro (botão
direito), mapa tático (`Tab`).

## Combate

- **Hitscan** com dano por zonas: corpo 1×, cabeça 2×.
- **Disparo automático por proximidade**: armas de fogo disparam sozinhas contra
  o inimigo visível mais próximo até **6 m**; disparo manual continua disponível.
- O arsenal jogável é exclusivamente de armas de fogo; as armas melee foram
  retiradas do catálogo, pickups, evoluções e loadouts.
- Feedback: números de dano, flash no inimigo, HitReact, sons sintetizados,
  hit-marker, knockback ao jogador (Brute/Boss).

## Inimigos

Perseguem o alvo ativo mais próximo: o jogador está sempre disponível e as
torres defensivas entram temporariamente no grupo de alvos quando são
construídas. Núcleo, muralhas e restantes estruturas continuam ignorados; a
destruição de uma torre não termina a run.

| Inimigo | Papel | Notas |
|---|---|---|
| Normal Zombie | base | 100 HP |
| Runner | rápido | 60 HP, 4,5 m/s |
| Brute | tanque | 320 HP, knockback forte |
| Spitter | à distância | mantém distância, projétil de ácido |
| The Breaker (boss) | clímax | 1200 HP, knockback, invoca minions |

**Diretor de horda contínuo**: spawns em lotes nos pontos mais próximos do
jogador (≥ 12 m), nível de ameaça sobe a cada 75 s (mais inimigos, tipos mais
pesados, intervalos mais curtos), boss a cada 5 níveis. O orçamento global é de
90 inimigos ativos, partilhado por horda, boss, emboscadas e POIs, com uma
barreira absoluta de 120. A fila reserva no máximo 12 spawns e instancia apenas
2 por frame de física; acima do teto, a dificuldade cresce pela composição e
não pela quantidade. Um "ciclo" = 3 níveis de ameaça (recompensa 100 Credits,
reposição de loot dos POIs, re-arme das emboscadas). Ao morrer, o inimigo toca
a animação de morte e o cadáver desaparece pouco depois.

## Mundo aberto

- Grelha 8 × 8 de setores 64 × 64 m sobre um Terrain3D contínuo. O acampamento
  persistente ocupa `(-1,-1)`; os restantes setores carregam conteúdo por seed
  em worker threads.
- O protótipo atual assume uma ilha grande: costa irregular, água a `Y = -3 m`,
  fundo marinho a `Y = -6 m`, um anel interior, um anel costeiro e três ligações
  entre ambos. Twin Ridge, Red Plateau, West Rise e South Cape funcionam como
  landmarks terrain-native. Spawns, loot e navegação são excluídos das zonas
  submersas. As alternativas e critérios estão em `docs/TERRAIN_MAP_OPTIONS.md`.
- Uma barreira física invisível e persistente segue a forma da ilha **24 m para
  dentro do mar**. A praia e o início da água ficam livres; a parede só funciona
  como último backstop antes do fim dos dados Terrain3D e estende-se abaixo do
  fundo marinho. Substitui as antigas paredes quadradas geradas por setor.
- **O seed do mundo é fixo por perfil** (guardado no save): o layout mantém-se
  entre partidas. Loot volta a cada partida — decisão de design: mundo familiar,
  exploração sempre recompensada.
- Nesta passagem o exterior do acampamento mostra **apenas terreno e água**,
  incluindo caminhos de terra, praia com espuma e variação de relva, floresta,
  zona seca e rocha. Casas, estradas, props e POIs autorados continuam retirados;
  caches, munições, caixas de arma e spawns permanecem ativos.
- **Emboscadas por setor** ao aproximar, re-armadas a cada ciclo.
- Setores **visitados persistem no save** (memória do mapa tático).
- Os POIs antigos (hospital, armazém, posto militar, combustível e variantes)
  estão temporariamente fora da arena até existir um passe terrain-native.
- **Expansão futura aprovada em conceito:** um arquipélago modular com ilhas de
  dimensões, silhuetas, biomas e conteúdo exclusivos. Ilhas próximas podem ser
  navegáveis na mesma zona marítima; zonas distantes carregam separadamente para
  manter IA, colisão e render apenas na área ativa. Os modelos Kenney/Quaternius
  já existentes podem regressar por tema, sem voltar a encher a ilha principal.

## Acampamento

- **Zona de reabastecimento**: perto do núcleo cura e repõe munição por segundo.
- **Depósito**: `F` no núcleo guarda o Scrap transportado; Scrap armazenado
  compra reparações e melhorias.
- **Melhorias da base** (por partida, compradas nos pedestais junto ao núcleo):
  Resupply Rate, Resupply Range e Scavenging (+% Scrap), 3 níveis cada.
- **3 torres defensivas exteriores**, junto aos acessos norte, oeste e este.
  São opcionais, disparam automaticamente e podem receber dano, ser reparadas
  ou reconstruídas com Scrap armazenado.
- Os quatro acessos têm estrada danificada e sinalização própria. Norte, oeste
  e este incluem cobertura lateral sem fechar o corredor central; torre de
  água, camião blindado, sinal urbano e bandeiras distinguem as direções.
- Cada torre tem 3 níveis ligados à progressão da run: LV1 custa 45 Scrap no
  nível 1 da run; LV2 custa 90 no nível 5; LV3 custa 150 no nível 10. Vida,
  dano, alcance e cadência sobem em cada nível.

## Progressão

- **Scrap**: moeda da partida (desaparece no fim).
- **Credits**: moeda permanente (ciclos e mastery) — desbloqueia classes e armas.
- **Character XP**: por classe, **sem teto de nível**; 1 skill point a cada 2 níveis.
- **Skill tree permanente** por classe: 3 ramos (Offense/Survival/Expedition),
  36 nós em 7 tiers com pré-requisitos e níveis mínimos 2/4/7/10/14/18/24 (dano, cadência,
  recarga, vida, regen, redução de dano, velocidade, reserva de munição,
  +Scrap, +XP).
- **Arsenal permanente**: o ecrã `ARMORY` permite comprar armas elegíveis com
  Credits e equipá-las nos slots 1/2; nível, compatibilidade e compra ficam no save.
- **Mastery por classe** (persistente, recompensa em Credits):
  EXTERMINATOR (100 abates), STORM RIDER (nível de ameaça 5 numa partida),
  SCAVENGER (500 Scrap recolhido). Completar as três desbloqueia a **variante**
  da classe.
- **Variantes de classe** (capstone da mastery, alternáveis na seleção; não são
  personagens novos — XP/skills/mastery/armory continuam da classe base):
  **VETERAN** (Recruit: troca a recarga rápida por +15% cadência),
  **BERSERKER** (Renegade: 110 HP, todas as armas de fogo causam +20% de dano),
  **COMBAT MEDIC** (Medic: regen 1,5 HP/s após 5 s, cada abate cura 5 HP).
  Com a variante ativa o modelo ganha um brilho subtil na cor da variante.
- **Armas encontráveis**: caixas de arma nos setores substituem o slot
  secundário durante a partida; a arma trocada cai no chão e pode ser reapanhada.
- **Expansão de conteúdo**: classes novas só entram quando tiverem papel,
  passivo, combinação de loadout e skills específicas que não repitam as atuais.
  A matriz aprovada e a ordem proposta vivem em `docs/CONTENT_EXPANSION_PLAN.md`.

## Direção visual

Low-poly CC0 (Quaternius, Kenney e KayKit) + Terrain3D. Fora do acampamento, a
passagem atual mostra relevo, caminhos, biomas e costa, ainda sem cidade nem
dressing. O acampamento reutiliza cercas, contentores, paletes, máquinas, tenda,
ambulância, armas e props destes kits em vez de volumes graybox visíveis.
Céu procedural de entardecer, nevoeiro subtil. **Decisão:** manter
Quaternius para modelos e animações (cobre todos os movimentos necessários);
Mixamo parqueado. As armas visíveis continuam a ser as malhas embutidas nos
modelos; armas externas só serão reconsideradas com `BoneAttachment3D`. O
próximo passo de arte é reintroduzir POIs e dressing por pequenos lotes medidos,
sem transformar novamente a ilha num bloco monolítico de cidade.

## Interface

Menu principal, seleção de classes (com mastery), `ARMORY`, skill tree, definições
(janela/resolução/VSync/sensibilidade/som), pausa, derrota. HUD minimalista:
vida, munição + arma, faixa de ameaça, Scrap, feed de mensagens. Mapa tático
(`Tab`): costa e mar, caminhos, landmarks, setores terrestres recortados,
visitados, loot, POIs, inimigos e bússola. FPS overlay (`F3`) com métricas de
streaming.

## Princípios de design

1. A horda pressiona sempre; o descanso é uma escolha tática (voltar à base).
2. Exploração recompensada: loot, armas, POIs e emboscadas dão razões para sair.
3. Progressão dupla: dentro da partida (Scrap/upgrades) e permanente (XP/skills/mastery).
4. Simplicidade técnica primeiro: primitivas e CC0 até o gameplay estar fechado.
