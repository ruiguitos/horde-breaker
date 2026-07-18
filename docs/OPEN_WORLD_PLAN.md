# Horde Breaker — Proposta de mundo aberto

## Estado da decisão

Proposta técnica e de design criada em 2026-07-18. Ainda não altera o formato do
jogo nem autoriza a expansão imediata do mapa.

## Conclusão curta

É possível evoluir Horde Breaker para um mundo aberto. A opção recomendada é um
**mundo aberto compacto, dividido em setores**, e não um mapa gigantesco carregado
de uma só vez.

O primeiro alvo deve ser um protótipo de 256 × 256 metros, composto por 16 setores
de 64 × 64 metros. O sistema carrega o setor atual e os vizinhos necessários,
mantendo o acampamento e os sistemas globais fora dos setores descartáveis.

Esta dimensão não é um limite definitivo. Serve para provar exploração, densidade
de conteúdo, carregamento e regresso ao acampamento antes de produzir um mundo
maior.

## Experiência pretendida

```text
Preparar o acampamento
-> escolher uma direção de exploração
-> encontrar recursos, ameaças e POIs
-> decidir quanto risco aceitar e quanto transportar
-> regressar ao acampamento
-> construir, reparar e preparar defesas
-> resistir ao ataque seguinte
```

O acampamento continua a ser a âncora da partida. O mapa aberto serve o ciclo de
explorar, transportar recursos e melhorar a base; não deve tornar-se espaço vazio
sem decisões.

## Decisão de design mais importante

O intervalo atual de 45 segundos entre ataques funciona numa arena de 64 × 64 m,
mas não permite explorar um mapa aberto. Antes da expansão real é necessário
escolher uma destas regras:

1. **Ataques agendados com aviso longo — recomendado:** exploração livre durante
   vários minutos, seguida de um aviso claro e tempo suficiente para regressar.
2. **Expedições separadas:** o ataque ao acampamento só avança quando o jogador
   regressa de uma zona de exploração.
3. **Acampamento atacável à distância:** mantém o tempo contínuo, mas exige mapa,
   alertas, defesas autónomas e uma forma justa de regressar rapidamente.

A primeira opção preserva melhor a sensação de mundo contínuo e mantém o jogador
responsável pela preparação da base sem o punir com ataques impossíveis de alcançar.

## Arquitetura proposta

```text
OpenWorldRoot
  PersistentWorld
    Player
    Camp
    WaveManager / futuro AttackDirector
    WorldStreamer
  LoadedSectors
    Sector_x_y
      Environment
      PointsOfInterest
      NavigationRegion3D
      LocalSpawns
```

### Setores

- Cada setor é uma cena independente de 64 × 64 metros.
- O setor atual e os setores vizinhos são carregados conforme a posição do jogador.
- Setores distantes são removidos depois de guardar o seu estado de sessão.
- Estradas e limites devem alinhar-se através de pontos de ligação estáveis.
- O acampamento permanece carregado; inicialmente, a construção fica limitada ao
  setor do acampamento e às zonas próximas.

### Carregamento

- `ResourceLoader.load_threaded_request` prepara cenas sem bloquear o frame principal.
- A instanciação e remoção dos nós continuam a ocorrer na thread principal.
- O protótipo deve começar com apenas dois setores vizinhos antes de avançar para
  uma grelha 4 × 4.

Referência: [Background loading — Godot](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html).

### Navegação

- A grelha global gerada por `arena_navigation.gd` não deve crescer para 256 × 256 m.
- Cada setor recebe o seu próprio `NavigationRegion3D`.
- Regiões adjacentes alinham as margens e são combinadas pelo mapa de navegação.
- `NavigationLink3D` fica reservado para passagens especiais, como pontes ou portas.
- As pesquisas devem limitar regiões quando o número de setores crescer.

Referências: [Navigation regions](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationregions.html) e [path queries por região](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationpathqueryobjects.html).

### Estado dos setores

Cada setor precisa de um identificador e de estado separado da cena visual:

- loot recolhido;
- encontro concluído ou disponível;
- estruturas construídas;
- dano persistente em estruturas;
- POIs descobertos;
- momento da última reposição.

Na primeira experiência, este estado existe apenas durante a partida. A integração
com `SaveManager` deve ocorrer depois de carregar e descarregar setores funcionar
sem duplicar loot ou inimigos.

### IA e hordas

- Só existem inimigos simulados perto do jogador, do acampamento ou de um encontro ativo.
- Inimigos distantes são representados por estado simples, não por nós com física.
- Ataques ao acampamento usam spawns e navegação dos setores próximos da base.
- A quantidade de IA ativa deve ser limitada por um orçamento central.

### Apresentação e desempenho

- Objetos pequenos e etiquetas deixam de ser visíveis a grandes distâncias.
- Grupos de geometria podem usar HLOD ou representações simplificadas.
- Oclusão, LOD e `MultiMeshInstance3D` entram apenas depois de medir um mapa real.
- Não é necessário ativar large world coordinates para o protótipo compacto.

As recomendações oficiais indicam que large world coordinates não são normalmente
necessárias para zonas pedonais abaixo de 8192 × 8192 metros e têm custos de memória
e desempenho. Referências: [Large world coordinates](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html) e [Visibility ranges/HLOD](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html).

## Sequência recomendada

### Fase 1 — concluir o mapa atual

- validar hospital e posto militar;
- abrir a estação de combustível;
- confirmar densidade, rotas e duração da exploração a pé.

### Fase 2 — protótipo de dois setores

- transformar o mapa atual no setor inicial;
- criar um segundo setor graybox ligado por uma estrada;
- manter jogador e acampamento ao carregar e descarregar o segundo setor;
- provar uma transição sem pausa e sem duplicação de estado.

### Fase 3 — mundo compacto 4 × 4

- criar 16 setores de 64 × 64 metros;
- carregar apenas a vizinhança necessária;
- introduzir descoberta de POIs e estado de sessão;
- medir memória, tempo de carregamento, draw calls, física e navegação.

### Fase 4 — persistência e construção

- guardar alterações dos setores;
- permitir mais estruturas em redor do acampamento;
- adicionar mapa, marcadores e avisos de ataque;
- afinar o intervalo entre exploração e defesa.

## Critérios para avançar

O protótipo de mundo aberto só deve começar quando:

- os quatro POIs atuais forem jogáveis;
- o posto militar e o hospital tiverem sido testados com as três classes;
- existir uma decisão sobre ataques enquanto o jogador está longe;
- a arena atual mantiver desempenho estável com as hordas previstas;
- estiver definido o primeiro objetivo de uma expedição além de recolher Scrap.

## Riscos conhecidos

- mapa maior sem conteúdo suficiente pode tornar a exploração vazia;
- navegação mal alinhada pode impedir zombies de atravessar setores;
- descarregar setores sem guardar estado pode duplicar loot e encontros;
- ataques demasiado frequentes podem impedir o jogador de explorar;
- construção livre aumenta bastante a complexidade do save e da navegação;
- produzir arte para um mapa grande pode custar mais tempo do que os sistemas de jogo.

## Recomendação atual

Concluir o Milestone 17 no mapa de 64 × 64 metros e, depois, criar apenas um
segundo setor graybox. Se a transição, navegação e persistência de sessão forem
fiáveis, avançar para o mundo compacto de 256 × 256 metros.
