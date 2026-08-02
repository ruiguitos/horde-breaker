# Horde Breaker — Plano de gameplay do arquipélago

Estado: direção de design aprovada para prototipagem em 2026-08-02. Este
documento define o objetivo de cada ilha antes de aumentar a dimensão total do
mapa. Os valores de duração e distância são alvos de playtest, não regras finais.

## Estrutura da expedição

Uma run visita três ilhas, mantendo uma escolha real no hub:

```text
                         Shallow Reef
                  ┌────────────────────► Shadow Forest
                  │                              │
            Dawn Beach                    Rope Bridge
          CAMP / START HUB                       │
                  │                              ▼
                  │                        Volcano Peak
                  │                         BOSS / EXIT
                  │                              ▲
                  │                       Ancient Ruins
                  │                              │
                  └────────────────────► High Cliffs
                           Sea Cave
```

O jogador percorre Dawn Beach, escolhe Shadow Forest **ou** High Cliffs e
converge em Volcano Peak. A rota não escolhida oferece variedade numa run
seguinte sem obrigar cada expedição a atravessar as quatro ilhas.

## Regras comuns

- Cada ilha tem uma identidade de combate, um objetivo principal, pelo menos
  três landmarks e duas rotas de fuga nos encontros importantes.
- O percurso direto entre entrada e saída deve demorar 60–90 segundos; fazer
  objetivos e explorar deve ocupar 5–10 minutos por ilha.
- O alvo para uma expedição de três ilhas é 20–30 minutos. A pressão vem do
  diretor de ameaça e não de espaços vazios ou de um relógio demasiado curto.
- Só a ilha ativa mantém IA, colisão detalhada e encontros completos. Ilhas
  distantes usam apenas terreno, silhueta e dressing leve.
- O orçamento global continua limitado a 90 inimigos ativos, com a guarda
  absoluta de 120, fila máxima de 12 e duas instanciações por frame de física.
- Nenhuma rota destrutível pode criar um soft-lock. Deve existir reparação,
  reativação ou uma alternativa claramente acessível.

## Dawn Beach — hub de partida

### Papel

Introduzir a expedição, permitir preparação e apresentar uma escolha de rota
visível. É o único acampamento completo do arquipélago.

### Conteúdo

- núcleo de energia e depósito de Scrap;
- cura e reabastecimento;
- estações de Resupply Rate, Resupply Range e Scavenging;
- pontos defensivos no exterior do perímetro;
- torre de sinalização, cais e painel do arquipélago;
- duas saídas reconhecíveis: Shallow Reef e Sea Cave;
- caches e componentes distribuídos pela praia para incentivar exploração.

### Objetivo e escolha

O jogador recupera células de energia espalhadas pela ilha e regressa ao
acampamento. Com energia suficiente pode ativar uma das duas rotas:

- **Route A — Shallow Reef:** reparar o Tide Beacon e abrir o banco de areia;
- **Route B — Sea Cave:** alimentar as bombas e tornar a passagem utilizável.

A primeira versão permite apenas uma escolha por sessão. A outra rota fica
visivelmente bloqueada, mas tudo reinicia quando o protótipo volta a arrancar.

## Shadow Forest — controlo e sobrevivência

### Identidade

Baixa visibilidade, pântano, vegetação densa, Spitters e emboscadas curtas.

### Conteúdo e objetivo

- acampamento de guardas abandonado;
- cripta parcialmente submersa;
- estação de bombagem;
- três ninhos de zombies;
- caminhos secundários e caches escondidas.

O jogador elimina os ninhos, recupera componentes do guincho e repara a Rope
Bridge. A ponte recebe dano, mas pode sempre ser reparada para evitar soft-lock.

## High Cliffs — mobilidade e precisão

### Identidade

Verticalidade, vento, visibilidade longa e encontros onde o posicionamento tem
mais importância do que a densidade de inimigos.

### Conteúdo e objetivo

- torre de vigia;
- comboio militar acidentado;
- pedreira e gruta lateral;
- três relés em elevações diferentes;
- atalhos desbloqueáveis e futuras tirolesas.

O jogador ativa os relés, defende-os e abre a entrada das Ancient Ruins.

## Volcano Peak — boss e extração

Não existe um acampamento completo, apenas uma zona de preparação antes da
arena. A sequência final é:

1. desativar três selos ou condutas vulcânicas;
2. abrir a arena;
3. derrotar o boss;
4. impedir o diretor de criar novos inimigos;
5. eliminar todos os zombies ainda ativos;
6. ativar o ponto de extração numa localização específica;
7. chegar ao ponto para concluir a run.

O relógio e a morte do boss, isoladamente, nunca concluem a run.

## Acampamentos avançados

Shadow Forest e High Cliffs podem conter um **Field Outpost**. Depois de limpar
a zona, o jogador escolhe apenas um módulo por run:

- **Resupply Module:** cura e munição;
- **Recon Module:** revela objetivos, caches e elites;
- **Defense Module:** instala uma torre automática.

As melhorias do acampamento principal também melhoram estes postos. Não é
criada uma nova moeda nem uma quarta árvore de bónus.

## Progressão e recompensas

- XP da run continua a oferecer cartas temporárias;
- Scrap compra acampamento, outposts, reparações e passagens;
- Credits, skill tree, classes e ARMORY continuam permanentes;
- a primeira conclusão de uma ilha pode desbloquear um blueprint temático.

Recompensas candidatas, ainda não aprovadas para implementação:

- Shadow Forest: Carbine ou resistência a ácido;
- High Cliffs: DMR e progressão do Recon Scout;
- Volcano Peak: Grenade Launcher ou progressão do Demolitionist.

## Noclip de desenvolvimento

Ferramenta apenas para builds de desenvolvimento:

- `Mouse 4` ativa/desativa;
- `WASD` move relativamente à câmara;
- `Space` sobe, `Ctrl` desce e `Shift` acelera;
- colisão, gravidade, armas e interação ficam desativadas;
- o HUD apresenta `NOCLIP // DEBUG`;
- ao sair, o jogador regressa à última posição física segura se estiver dentro
  de geometria ou fora de terreno navegável;
- nunca é guardado no save nem disponibilizado numa build final.

## Ordem de implementação

1. [x] noclip de desenvolvimento e indicador no HUD;
2. [x] vertical slice de Dawn Beach com recolha, acampamento e escolha A/B;
3. [ ] playtest de distâncias, leitura e tempo de exploração;
4. [x] Shadow Forest — três ninhos abatíveis, peças de guincho e reparação da
   Rope Bridge (`shadow_forest_hub.gd`, `shadow_forest_nest.gd`);
5. [ ] High Cliffs — três relés, defesa e abertura das Ancient Ruins;
6. [ ] Volcano Peak, fase finita e extração. A fase finita e a extração já
   existem em `run_objective.gd`, mas são disparadas pelo relógio; o plano
   quer que sejam os selos e o boss a dispará-las, e que o relógio nunca
   conclua a run sozinho;
7. [ ] só depois aumentar o oceano e as dimensões finais das ilhas.

### Notas de implementação

- **Ninhos são abatidos, não interagidos.** A identidade da ilha é emboscada e
  baixa visibilidade, e um objetivo que se *limpa* assenta nisso melhor do que um
  a que se chega e se carrega em F. A ponte ao lado já usa o mesmo caminho de
  dano, portanto os objetos de mundo aqui partilham o contrato.
- **A regra do soft-lock apanhou um bug real.** O `_collapse()` da ponte
  desativava a colisão com `set_deferred` e o `reset_bridge()` reativava-a de
  imediato: destruir e reparar dentro do mesmo frame deixava a ponte de pé, com
  bom aspeto e sem nada onde pisar. Corrigido pondo as duas a diferir.
