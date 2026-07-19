# Horde Breaker — Game Design Document

## Estado

Nome provisório: **Horde Breaker**

Género: ação 3D em terceira pessoa, arena survival e progressão permanente.

Plataforma inicial: Windows.

Modo inicial: single-player offline.

## Visão do jogo

O jogador entra numa arena, enfrenta vagas de zombies, recebe recompensas e desenvolve personagens com estilos de combate diferentes.

A experiência deve ser:

- fácil de compreender;
- rápida a iniciar;
- satisfatória a cada eliminação;
- progressivamente mais exigente;
- baseada em movimento, posicionamento e decisões de progressão.

## Core loop

```text
Selecionar personagem e arma
-> entrar na arena
-> explorar e melhorar o acampamento
-> enfrentar hordas que perseguem o operacional
-> eliminar inimigos
-> receber Scrap, Credits e XP
-> escolher melhorias
-> iniciar ataque mais difícil
-> sobreviver enquanto o operacional resistir
-> terminar a partida por queda do operacional
-> guardar progressão permanente
```

## Personagens

### Recruit

Personagem inicial e gratuita.

Estilo: armas de fogo e combate à distância.

Características:

- dano equilibrado;
- segurança à distância;
- munição e recarga;
- recarga 30% mais rápida do que as restantes classes;
- vulnerável quando é cercado.

Loadout inicial:

- principal: Assault Rifle;
- secundária: Pistol.

Armas planeadas:

| Arma | Nível mínimo | Credits | Estado |
|---|---:|---:|---|
| Assault Rifle | 1 | 0 | Inicial |
| Pistol | 1 | 0 | Inicial secundária |
| SMG | 3 | 400 | Planeada |
| Marksman Rifle | 8 | 1500 | Planeada |

### Renegade

Personagem desbloqueável.

Preço provisório: 500 Credits.

Estilo: combate agressivo a curta distância.

Características:

- dano elevado;
- ataque em arco;
- possibilidade de atingir vários inimigos;
- 140 pontos de vida, acima das restantes classes;
- Shotgun para abrir espaço antes do combate corpo a corpo;
- maior risco por proximidade.

Loadout inicial:

- principal: Shotgun;
- secundária: Worn Sword.

Armas planeadas:

| Arma | Nível mínimo | Credits | Estado |
|---|---:|---:|---|
| Worn Sword | 1 | 0 | Inicial |
| Shotgun | 1 | 0 | Inicial principal |
| Katana | 3 | 500 | Planeada |
| Heavy Blade | 5 | 900 | Planeada |
| Energy Blade | 8 | 1800 | Planeada |

### Medic

Personagem desbloqueável.

Preço provisório: 750 Credits.

Estilo: sobrevivência e recuperação sustentada.

Características:

- 100 pontos de vida;
- regenera 4 pontos de vida por segundo após 3 segundos sem sofrer dano;
- usa uma Pistol;
- menor poder imediato do que Recruit e Renegade.

Loadout inicial:

- principal: Pistol;
- secundária: vazia até ser definida uma arma ou ferramenta médica adequada.

## Dano por zonas

- Um impacto no corpo aplica o dano base da arma.
- Um impacto na cabeça aplica provisoriamente `2 ×` o dano base.
- A regra aplica-se a todas as armas de fogo e armas brancas do jogador.
- Nas armas melee, apenas o inimigo cuja cabeça esteja sob o centro da mira recebe o multiplicador; os restantes alvos do mesmo golpe recebem dano de corpo.
- O multiplicador é configurável por hitbox e deve ser afinado através de playtests.

Valores provisórios após o primeiro balanceamento conjunto de vida e dano:

| Arma | Corpo | Cabeça | Observação |
|---|---:|---:|---|
| Assault Rifle | 30 | 60 | Dano por bala; fogo automático. |
| Pistol | 35 | 70 | Dano por bala; fogo semiautomático. |
| Shotgun | 12 por pellet | 24 por pellet | Oito pellets; máximo teórico de 96 no corpo. |
| Worn Sword | 50 | 100 | Pode atingir vários inimigos no mesmo golpe. |

### Disparo automático por proximidade

- Assault Rifle, Pistol e Shotgun procuram o inimigo mais próximo até 3 metros.
- O disparo automático só acontece com linha de visão e continua a respeitar munição, recarga, cadência, dispersão e dano por zonas.
- O automático aponta ao corpo; premir o ataque dá prioridade à mira manual e permite procurar headshots.
- O disparo manual permanece disponível durante o protótipo para permitir comparar os dois estilos em playtest.
- A Worn Sword mantém ataque manual e o seu volume corpo a corpo próprio.

## Progressão

### Character XP

Cada personagem tem:

- nível próprio;
- XP próprio;
- armas compradas próprias;
- loadout principal/secundário próprio.

O XP ganho ao jogar com uma personagem só progride essa personagem.

Fórmula provisória:

```text
XP para o próximo nível = 100 + ((nível atual - 1) × 50)
```

Nível máximo inicial: 10.

Valores provisórios de XP:

| Ação | XP |
|---|---:|
| Zombie normal | 5 |
| Runner | 8 |
| Spitter | 12 |
| Brute | 15 |
| Boss | 100 |
| Completar ataque | 20 × ataque |

O XP obtido é mantido mesmo quando o jogador perde.

### Credits

Moeda permanente.

Serve para:

- desbloquear personagens;
- comprar armas cujo nível mínimo já foi atingido;
- futuramente comprar cosméticos ou arenas.

Completar cada ciclo de três ataques atribui provisoriamente 100 Credits.

### Scrap

Moeda temporária da expedição. O protótipo atual separa:

- **Scrap transportado**: encontrado em caches espalhados pelo mapa e ainda na posse do jogador;
- **Scrap na base**: depositado no núcleo do acampamento e disponível para utilização.

Existem provisoriamente onze caches de 25 Scrap em simultâneo: oito são estáticos
no exterior, um pertence ao armazém e dois pertencem à estação de combustível.
As três caches interiores são repostas após cada ciclo de três ataques apenas se
tiverem sido recolhidas. `F` recolhe uma cache próxima e, junto do núcleo, deposita
todo o Scrap transportado.

Durante uma fase de exploração, `F` junto do núcleo também permite reparar até
50 pontos de vida por interação. Cada unidade de Scrap repara 5 pontos de vida,
pelo que uma reparação completa custa no máximo 10 Scrap.

O primeiro ponto fixo de defesa permite construir uma barricada por 30 Scrap.
A barricada também usa a proporção de 5 pontos de vida por Scrap nas reparações.

Futuramente também poderá servir para melhorias temporárias entre ataques:

- dano;
- vida máxima;
- velocidade;
- cadência;
- recarga;
- tamanho de carregador;
- crítico;
- alcance corpo a corpo.

O Scrap é reiniciado no fim da partida.

## Inimigos planeados

### Normal Zombie

- lento;
- 100 pontos de vida;
- vida e dano médios;
- persegue o jogador e não escolhe o núcleo ou as fortificações como alvos;
- inimigo base.

### Runner

- rápido;
- 60 pontos de vida;
- pouca vida;
- força o jogador a reposicionar-se.

### Brute

- lento;
- muita vida;
- ataque forte;
- pode empurrar o jogador.

### Spitter

- ataque à distância;
- cria pressão de posicionamento.

### Boss: Breaker

Planeado para uma fase posterior.

- muita vida;
- investida;
- ataque de área;
- invoca inimigos;
- recompensa elevada.

## Núcleo do acampamento

- É a âncora da exploração, depósito de recursos e ponto de evolução do acampamento.
- Começa provisoriamente com 500 pontos de vida.
- Na direção aprovada, os zombies perseguem o jogador e não atacam diretamente o núcleo.
- A derrota deve resultar da morte do jogador, não da destruição do acampamento.
- Durante a exploração, aceita o depósito de Scrap e reparações de 5 pontos de vida por Scrap.
- Melhorias, construção livre e persistência da base ficam para etapas posteriores.
- O protótipo atual ainda permite dano no núcleo; a remoção desse comportamento fica pendente para uma alteração funcional própria.

## Fortificação provisória

- Existe um único ponto fixo de defesa junto do núcleo.
- Só pode ser construída ou reparada durante uma fase de exploração.
- A construção custa 30 Scrap armazenado e cria uma barricada com 200 pontos de vida.
- A reparação recupera até 50 pontos de vida por interação, à razão de 5 pontos por Scrap.
- Enquanto está construída, bloqueia movimento, mas não deve tornar-se um alvo escolhido pelos zombies.
- Quando é destruída, o ponto fica novamente disponível para reconstrução na exploração seguinte.
- Posicionamento livre, rotação, múltiplas estruturas e persistência ficam fora deste slice.

## Ataques provisórios

| Ataque do ciclo | Composição base |
|---:|---|
| 1 | 5 Normal Zombies |
| 2 | 10 Normal Zombies |
| 3 | 15 Normal Zombies + 2 Runners |

O ciclo repete-se continuamente e cada ciclo completo acrescenta provisoriamente
dois Normal Zombies a cada composição. Os valores e a variedade de inimigos
devem ser ajustados após playtests. Antes do primeiro ataque existem 30 segundos
de exploração; entre ataques existem provisoriamente 45 segundos para explorar,
recolher recursos e reparar o núcleo.

Para o futuro mapa aberto, as hordas devem surgir com aviso e perseguir o jogador
através dos setores carregados. O jogador não é obrigado a regressar para defender
o acampamento, porque a base não é um alvo direto. Os temporizadores atuais
permanecem inalterados até existir um sistema de aviso próprio.

## Exploração provisória

- O mapa de teste mede 64 × 64 metros e usa uma grelha modular de estradas.
- Os quatro bairros repetidos foram substituídos por silhuetas graybox próprias: hospital, armazém, posto militar e estação de combustível.
- Cada POI tem um acesso navegável e pelo menos uma cache de Scrap próxima.
- Os pontos de aparecimento dos inimigos continuam distribuídos nas zonas exteriores.
- As ruas mantêm caminhos contínuos até ao núcleo e permitem testar deslocações mais longas.
- O armazém é o primeiro interior explorável, com entrada aberta, iluminação graybox, uma cache de Scrap e um pickup de munições.
- Entrar no armazém durante uma fase de exploração ativa uma emboscada de dois Normal Zombies, uma vez por ciclo.
- Os zombies da emboscada concedem XP, mas não pertencem à contagem da vaga; o loot do armazém é reposto no ciclo seguinte sem duplicar pickups não recolhidos.
- O hospital é o segundo interior explorável e funciona como ponto de apoio, com entrada aberta, iluminação fria, duas camas e um medkit.
- `F` junto do medkit recupera até 40 pontos de vida. O pickup não é consumido com a vida cheia e reaparece após cada ciclo de três ataques.
- O posto militar é o terceiro interior explorável e representa uma zona de risco elevado, com duas caixas de 12 munições.
- Entrar no posto militar durante a exploração ativa dois Normal Zombies e um Runner, uma vez por ciclo. Os três concedem 18 XP total sem alterar a contagem da vaga.
- As munições do posto militar reaparecem no ciclo seguinte apenas quando foram recolhidas, sem duplicar caixas ainda presentes.
- A estação de combustível é o quarto interior explorável, com entrada aberta, iluminação quente, balcão e duas caches de 25 Scrap.
- Aproximar-se da estação durante a exploração ativa três Runners, uma vez por ciclo. Os três concedem 24 XP total sem alterar a contagem da vaga.
- As duas caches da estação reaparecem no ciclo seguinte apenas quando foram recolhidas, sem duplicar loot ainda presente.
- O tamanho final do mapa e a distribuição de futuros POIs ficam para etapas posteriores.

O primeiro protótipo de mundo aberto compacto acrescenta um setor leste graybox
de 64 × 64 metros. Este setor é carregado ao aproximar-se da fronteira e removido
depois do regresso ao acampamento, enquanto jogador, base e sistemas globais
permanecem na cena. Um farol de reconhecimento funciona como primeiro objetivo
de expedição e mantém o estado ativado durante a sessão mesmo após recarregar o
setor.

## Direção visual

Primeiro protótipo:

- primitivas 3D;
- materiais simples;
- arena cinzenta;
- iluminação funcional;
- efeitos mínimos.

Versão posterior:

- personagens e zombies humanoides do Adobe Mixamo;
- importação por Blender para glTF/GLB quando necessário;
- ambiente pós-apocalíptico;
- leitura visual clara entre tipos de inimigos.

## Interface planeada

Durante a partida:

- vida;
- vida do núcleo do acampamento;
- munição;
- ataque;
- inimigos restantes;
- Scrap da sessão;
- XP ganho na sessão.
- mapa tático aberto com `Tab`, mostrando setores, jogador, acampamento, POIs e
  inimigos ativos.

Menu principal:

- saldo de Credits;
- personagem selecionada;
- nível e XP;
- classe, passivo e loadout principal/secundário;
- armas disponíveis, bloqueadas e compradas quando existirem alternativas;
- iniciar partida.

Definições:

- o modo Janela ou Ecrã completo deve refletir e guardar o estado escolhido;
- em Ecrã completo, a resolução apresentada corresponde à resolução real do monitor;
- em Janela, a resolução selecionada redimensiona e centra imediatamente a janela.

## Princípios de design

- A dificuldade deve aumentar por composição e comportamento, não apenas por quantidade.
- Cada personagem deve mudar a forma de jogar.
- Uma arma nova deve oferecer um estilo diferente, não apenas mais dano.
- O jogador deve receber progresso mesmo após perder.
- O combate deve funcionar antes de animações e arte final.
- Os números deste documento são hipóteses, não valores finais.
