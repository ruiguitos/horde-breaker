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
-> sobreviver à ronda
-> eliminar inimigos
-> receber Scrap, Credits e XP
-> escolher melhorias
-> iniciar ronda mais difícil
-> terminar a partida
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
- vulnerável quando é cercado.

Arma inicial:

- Assault Rifle.

Armas planeadas:

| Arma | Nível mínimo | Credits | Estado |
|---|---:|---:|---|
| Assault Rifle | 1 | 0 | Inicial |
| SMG | 3 | 400 | Planeada |
| Shotgun | 5 | 750 | Planeada |
| Marksman Rifle | 8 | 1500 | Planeada |

### Renegade

Personagem desbloqueável.

Preço provisório: 500 Credits.

Estilo: corpo a corpo com espada.

Características:

- dano elevado;
- ataque em arco;
- possibilidade de atingir vários inimigos;
- maior risco por proximidade.

Armas planeadas:

| Arma | Nível mínimo | Credits | Estado |
|---|---:|---:|---|
| Worn Sword | 1 | 0 | Inicial |
| Katana | 3 | 500 | Planeada |
| Heavy Blade | 5 | 900 | Planeada |
| Energy Blade | 8 | 1800 | Planeada |

## Progressão

### Character XP

Cada personagem tem:

- nível próprio;
- XP próprio;
- armas compradas próprias;
- arma selecionada própria.

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
| Completar ronda | 20 × ronda |
| Completar partida | 100 |

O XP obtido é mantido mesmo quando o jogador perde.

### Credits

Moeda permanente.

Serve para:

- desbloquear personagens;
- comprar armas cujo nível mínimo já foi atingido;
- futuramente comprar cosméticos ou arenas.

### Scrap

Moeda temporária por partida.

Serve para melhorias temporárias entre rondas:

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
- vida e dano médios;
- persegue o jogador;
- inimigo base.

### Runner

- rápido;
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

## Rondas provisórias

| Ronda | Composição |
|---:|---|
| 1 | 5 Normal Zombies |
| 2 | 10 Normal Zombies |
| 3 | 15 Normal Zombies + 2 Runners |
| 4 | 15 Normal Zombies + 5 Runners + 1 Brute |
| 5 | Zombies + Boss |

Estes valores são provisórios e devem ser ajustados após playtests.

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
- munição;
- ronda;
- inimigos restantes;
- Scrap da sessão;
- XP ganho na sessão.

Menu principal:

- saldo de Credits;
- personagem selecionada;
- nível e XP;
- armas disponíveis, bloqueadas e compradas;
- iniciar partida.

## Princípios de design

- A dificuldade deve aumentar por composição e comportamento, não apenas por quantidade.
- Cada personagem deve mudar a forma de jogar.
- Uma arma nova deve oferecer um estilo diferente, não apenas mais dano.
- O jogador deve receber progresso mesmo após perder.
- O combate deve funcionar antes de animações e arte final.
- Os números deste documento são hipóteses, não valores finais.
