# Horde Breaker — Proposta de mundo aberto

## Estado da decisão

Proposta técnica e de design aprovada em 2026-07-18. O primeiro slice da Fase 2
está implementado com um setor leste graybox; a expansão para 16 setores continua
dependente dos resultados deste protótipo.

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
-> sobreviver às hordas que perseguem o jogador
-> decidir quanto risco aceitar e quanto transportar
-> regressar ao acampamento quando for vantajoso
-> construir e melhorar a base
```

O acampamento continua a ser a âncora da partida. O mapa aberto serve o ciclo de
explorar, transportar recursos e melhorar a base; não deve tornar-se espaço vazio
sem decisões.

### Direção aprovada para os inimigos

- Os inimigos perseguem o jogador através dos setores carregados.
- O núcleo, o acampamento e as fortificações não são alvos diretos.
- Uma horda pode acompanhar o jogador até à zona do acampamento, mas a pressão e
  a condição de derrota permanecem centradas no jogador.
- Os avisos futuros anunciam a chegada de uma horda ao jogador; não obrigam a
  regressar à base para a defender.

Esta decisão substitui a escolha anterior de ataques agendados ao acampamento
descrita abaixo. O protótipo atual ainda implementa jogador, núcleo e barricada
como alvos possíveis, pelo que a alteração funcional permanece pendente.

## Decisão anterior sobre ataques ao acampamento

Antes da decisão de centrar os inimigos no jogador, foram consideradas estas
regras para compatibilizar o intervalo atual de 45 segundos com o mapa aberto:

1. **Ataques agendados com aviso longo — recomendado:** exploração livre durante
   vários minutos, seguida de um aviso claro e tempo suficiente para regressar.
2. **Expedições separadas:** o ataque ao acampamento só avança quando o jogador
   regressa de uma zona de exploração.
3. **Acampamento atacável à distância:** mantém o tempo contínuo, mas exige mapa,
   alertas, defesas autónomas e uma forma justa de regressar rapidamente.

A primeira opção chegou a ser escolhida, mas foi posteriormente substituída pela
regra de perseguição do jogador registada acima. O aviso de horda ainda não está
implementado.

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

O primeiro slice usa temporariamente um `PackedScene` já carregado porque o setor
graybox é pequeno. Esta simplificação permite validar a transição e o estado antes
de introduzir carregamento em background.

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

- Só existem inimigos simulados perto do jogador ou de um encontro ativo.
- Inimigos distantes são representados por estado simples, não por nós com física.
- As hordas usam spawns dos setores próximos do jogador e perseguem-no entre setores carregados.
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

- [x] validar hospital e posto militar;
- [x] abrir a estação de combustível;
- confirmar densidade, rotas e duração da exploração a pé.

### Fase 2 — protótipo de dois setores

- [ ] extrair o mapa atual para uma cena de setor inicial independente;
- [x] criar um segundo setor graybox ligado por uma estrada;
- [x] manter jogador e acampamento ao carregar e descarregar o segundo setor;
- [ ] medir a pausa da transição e adotar background loading; a ausência de duplicação e o estado do farol já foram validados.

### Fase 3 — mundo compacto 4 × 4

- criar 16 setores de 64 × 64 metros;
- carregar apenas a vizinhança necessária;
- introduzir descoberta de POIs e estado de sessão;
- medir memória, tempo de carregamento, draw calls, física e navegação.

### Fase 4 — persistência e construção

- guardar alterações dos setores;
- permitir mais estruturas em redor do acampamento;
- adicionar mapa, marcadores e avisos de chegada de hordas;
- afinar o intervalo entre exploração e pressão sobre o jogador.

## Critérios para avançar

O protótipo de mundo aberto só deve começar quando:

- [x] os quatro POIs atuais forem jogáveis;
- o posto militar e o hospital tiverem sido testados com as três classes;
- [x] existir uma decisão sobre ataques enquanto o jogador está longe;
- a arena atual mantiver desempenho estável com as hordas previstas;
- [x] estiver definido o primeiro objetivo de uma expedição além de recolher Scrap.

## Riscos conhecidos

- mapa maior sem conteúdo suficiente pode tornar a exploração vazia;
- navegação mal alinhada pode impedir zombies de atravessar setores;
- descarregar setores sem guardar estado pode duplicar loot e encontros;
- ataques demasiado frequentes podem impedir o jogador de explorar;
- construção livre aumenta bastante a complexidade do save e da navegação;
- produzir arte para um mapa grande pode custar mais tempo do que os sistemas de jogo.

## Recomendação atual

Validar manualmente o setor leste, o farol e o disparo automático com as três
classes. Depois, extrair o setor inicial e substituir o carregamento síncrono por
background loading. Só se esta transição continuar fiável deve o mapa avançar
para os 16 setores do protótipo de 256 × 256 metros.
