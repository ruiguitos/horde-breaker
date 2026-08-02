# Horde Breaker — Referências e ideias

Pesquisa iniciada em 2026-07-17 e atualizada em 2026-07-18. Estas referências servem para identificar
padrões de design; não autorizam copiar assets, código ou conteúdo protegido.

## Jogos próximos

### World War Z: Aftermath

A página oficial destaca grandes hordas, progressão de herói e oito classes com
perks próprios. É a referência mais próxima para pressão de zombies num shooter
em terceira pessoa.

Fonte: [World War Z: Aftermath — Focus Entertainment](https://www.focus-entmt.com/en/games/world-war-z)

Ideias úteis:

- identidade de classe imediatamente percetível;
- inimigos especiais que obrigam a mudar de posicionamento;
- progressão da classe sem depender apenas do dano da arma.

### Killing Floor 2

O jogo associa perks a habilidades, poderes e conjuntos de armas, usando rondas
que terminam num boss.

Fontes: [visão geral oficial](https://www.killingfloor2.com/overview/) e
[galeria oficial de armas](https://killingfloor2.com/overview/weapons.html).

Ideias úteis:

- cada classe deve ter uma vantagem numérica simples e verificável;
- introduzir tipos de inimigo por função, não apenas por quantidade;
- reservar uma ronda final para um boss com leitura clara.

### Deep Rock Galactic: Survivor

As classes começam com armas próprias, desbloqueiam novos equipamentos por nível
e combinam melhorias temporárias da missão com progressão permanente.

Fontes: [armas por classe](https://deeprockgalactic.wiki.gg/wiki/Survivor%3AWeapons),
[equipamento e melhorias](https://deeprockgalactic.wiki.gg/wiki/Survivor%3AEquipment)
e [milestones](https://deeprockgalactic.wiki.gg/wiki/Survivor%3AMilestones).

Ideias úteis:

- apresentar sempre os dois slots do loadout;
- desbloquear alternativas através do nível específico da classe;
- usar objetivos pequenos para desbloquear armas ou variantes.

### Risk of Rain 2

Survivors diferentes têm mecânicas e estilos próprios, enquanto itens encontrados
durante a partida criam combinações variáveis e a dificuldade aumenta ao longo da
sessão.

Fontes: [Survivors of the Void](https://www.gearboxpublishing.com/press_release/risk-of-rain-2s-first-ever-expansion-survivors-of-the-void-launches-today/)
e [Railgunner](https://www.gearboxpublishing.com/press_release/risk-of-rain-2-survivors-of-the-void-introduces-its-first-new-survivor-railgunner/).

Ideias úteis:

- melhorias temporárias que criem sinergias com o passivo da classe;
- variantes de habilidade em vez de aumentos lineares infinitos;
- modificadores de arena para variar partidas sem criar mapas completos novos.

### Yet Another Zombie Survivors

Combina personagens, armas, habilidades, árvore permanente e objetivos de
progressão num formato centrado em hordas de zombies.

Fontes: [página oficial na Steam](https://store.steampowered.com/app/2163330/Yet_Another_Zombie_Survivors/)
e [descrição oficial](https://yetanotherzombie.wiki.gg/wiki/Yet_Another_Zombie_Survivors).

Ideias úteis:

- objetivos de mastery por personagem;
- evolução de armas após cumprir condições claras;
- autoapontar e disparar para reduzir a carga de controlo, preservando provisoriamente uma opção manual;
- modos ou modificadores adicionais apenas depois do core loop estar afinado.

## Segunda ronda de pesquisa (2026-08-01) — classes, armas e árvores

Feita para responder a "mais classes, armas e skill trees". O padrão útil não foi
o que os jogos põem nas árvores, foi **como estruturam a escolha**.

### Killing Floor 2 — a árvore mais simples que funciona

Cada perk sobe até ao nível 25 e, **a cada cinco níveis, escolhe-se entre duas
habilidades**. Só uma fica equipada por patamar, e as escolhas podem ser trocadas
antes ou até a meio da partida.

Fonte: [Perks (Killing Floor 2)](http://www.wiki.killingfloor2.com/index.php?title=Perks_%28Killing_Floor_2%29)

Ideias úteis:

- cinco patamares de "isto **ou** aquilo" leem-se melhor do que 36 nós;
- poder trocar sem penalização transforma a árvore num **loadout**, não num
  compromisso permanente — e remove o medo de estragar a personagem;
- a última escolha é a que define a classe, não a que soma mais dano.

### Deep Rock Galactic: Survivor — progressão dupla

Overclocks escolhem-se aos níveis 6, 12 e 18 **da arma**, não da personagem. As
*milestones* desbloqueiam classes, subclasses e armas; as *meta upgrades* são
melhorias permanentes partilhadas por todas as classes.

Fontes: [Overclocks](https://deeprockgalactic.wiki.gg/wiki/Survivor:Overclocks) ·
[Class Mods](https://deeprockgalactic.wiki.gg/wiki/Survivor:Class_Mods) ·
[Meta Upgrades](https://deeprockgalactic.wiki.gg/wiki/Survivor:Meta_Upgrades)

Ideias úteis:

- separar o que é **da classe** do que é **partilhado** (temos as duas coisas
  misturadas numa árvore só);
- subclasses são conteúdo barato: o Tinkerer é "usa todas as armas e ganha mais
  XP", não um corpo novo;
- desbloquear por objetivo cumprido em vez de por moeda.

### Vermintide 2 — o padrão que o nosso orçamento de arte permite

Cinco personagens, até **19 carreiras**. Uma carreira muda passivo, habilidade e
conjunto de armas — **sobre o mesmo corpo**.

Ideias úteis:

- é o único padrão dos quatro que dá "mais classes" **sem modelos novos**;
- é o que já fazemos com as variantes de mastery (VETERAN/BERSERKER), por isso o
  sistema existe e está a metade do caminho.

### O que a pesquisa não resolve: só há três corpos e três armas

O que decide o que é possível aqui não é design, são os assets:

| Recurso | O que existe | Consequência |
|---|---|---|
| Rigs de personagem | **3** (Lis, Matt, Sam) | já usados por Recruit/Renegade/Medic — não há corpo para uma 4ª classe |
| Modelos de arma | **3** (Pistol, Rifle, Shotgun) + malhas embutidas | armas novas têm de reutilizar malhas, como as 13 atuais já fazem |
| Árvore de skills | 1 partilhada, 36 nós | o save **já guarda `skill_nodes` por personagem** — árvores por classe não precisam de arte nenhuma |

Conclusão: **as árvores por classe são o único dos três pedidos que não esbarra
em arte.** "Mais classes" só é possível como carreiras sobre os corpos que há (o
padrão Vermintide), e "mais armas" como variantes de comportamento sobre as
malhas que há (o padrão overclock).

## Ideias recomendadas para Horde Breaker

Ordem sugerida, mantendo etapas pequenas:

1. escolha de uma melhoria entre rondas;
2. um inimigo especial que force reposicionamento;
3. objetivo de mastery simples para cada classe;
4. primeira arma alternativa por slot;
5. quinta ronda com boss;
6. modificadores opcionais de arena.

Não é recomendado nesta fase aumentar muito o número de personagens, criar
multiplayer ou construir árvores de talentos extensas. Primeiro devem ser
playtestados os três passivos e os quatro tipos de arma atuais.
