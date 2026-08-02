# Opções de terreno e mapa

Estado a 2026-08-01. Este documento regista alternativas para não ficarmos
presos à primeira solução visual. Não autoriza downloads nem importações.

## Decisão do protótipo atual

Foi escolhida uma **ilha grande e contínua** para a primeira passagem do mapa
principal. Mantém os 64 setores de gameplay, mas usa a costa para dar um limite
visual natural ao mundo em vez de parecer uma arena quadrada.

- área lógica: 8 × 8 setores, 512 × 512 m;
- armazenamento: nove regiões Terrain3D, 768 × 768 m com margem de amostragem;
- centro da ilha: `(32, 32)`; acampamento: setor `(-1, -1)`;
- água: `Y = -3 m`; fundo marinho: `Y = -6 m`;
- relevo: costa irregular, cordilheira norte, planalto leste e elevação oeste;
- percursos: anel interior, anel costeiro e três ligações terrain-native;
- landmarks: Twin Ridge, Red Plateau, West Rise e South Cape;
- materiais: praia, relva, floresta, zona seca, rocha e caminho de terra;
- limite: parede invisível persistente 24 m offshore, ainda dentro dos dados
  Terrain3D e com a praia/início da água livres;
- conteúdo: só pode nascer em terreno acima da linha costeira navegável;
- navegação: células submersas não recebem polígonos;
- arte: continuam fora da arena casas, estradas, vegetação e POIs antigos.

A página indicada na investigação, asset `3134`, é o próprio plugin Terrain3D
1.0.0 e não um mapa nem um pack de ilhas. O projeto já inclui Terrain3D 1.0.2;
não é necessário instalar esse asset novamente.

## Formas possíveis para o mapa

| Opção | Vantagens | Riscos | Adequação ao Horde Breaker |
|---|---|---|---|
| **Ilha grande** — atual | limite natural, silhueta clara, costa útil para extração, fácil dividir em biomas | a barreira resolve a queda, mas ainda não existe gameplay de natação | **Alta**: mantém exploração e horda contínua sem parecer uma caixa |
| **Península** | uma ligação terrestre pode ser objetivo, gargalo ou evacuação | o limite interior continua a precisar de montanha/muralha | Alta para uma campanha orientada; média para sandbox |
| **Vale fechado / cratera** | montanhas explicam o limite e criam leitura vertical forte | horizonte repetitivo; zombies podem sofrer em declives extremos | Alta para uma arena mais tensa e controlada |
| **Arquipélago** | zonas muito distintas, recompensas exclusivas e reutilização temática dos modelos existentes | barcos fragmentam navegação/hordas e exigem streaming por zona | **Alta como expansão**, depois de validar uma ilha piloto e o transporte |
| **Massa continental aberta** | máxima liberdade para estradas e cidade | o bordo quadrado volta a ser visível; exige limites artificiais | Média, se a cidade densa for novamente a prioridade |
| **Terreno real por DEM** | formas naturais credíveis e rápidas de obter | escala, ruído, licença da fonte e legibilidade de gameplay | Média como matéria-prima; não deve ser usado sem edição |

## Métodos para criar o relevo

| Pipeline | Quando usar | O que validar |
|---|---|---|
| **Geração determinística em GDScript** — atual | protótipos repetíveis, testes automáticos e alterações macro rápidas | monotonia, declives, tempo de regeneração e diferença entre fórmula e dados guardados |
| **Escultura no editor Terrain3D** | afinar costa, caminhos, plataformas e landmarks após aprovar o macro-layout | guardar regiões, não destruir o acampamento, testar colisão/nav após cada lote |
| **Heightmap EXR ou R16** | importar uma ilha feita em Blender, Gaea, World Machine ou ferramenta semelhante | resolução, gama de alturas, orientação, bordos, licença e escala de 1 m |
| **Mapa de controlo/cor** | pintar areia, relva, rocha, trilhos e biomas de forma persistente | transições, repetição de texturas, custo de materiais e consistência com a costa |
| **Modelo 3D completo em GLB** | apenas para falésias, grutas ou landmarks que não funcionem como heightmap | colisão, LOD, oclusão e integração com Terrain3D; não usar como chão integral |
| **Mapa/heightmap existente** | acelerar um protótipo quando a licença for clara | licença comercial, atribuição, tamanho, qualidade, autoria e custo de adaptação |

Three.js pode gerar ou visualizar geometria e exportar glTF/GLB, mas não resolve
por si só o design do mapa, a colisão, a navegação, os LODs ou a edição no Godot.
Para o chão contínuo, Terrain3D com heightmap é a base mais apropriada; Three.js
fica útil para ferramentas específicas ou protótipos, não como editor principal.

## Expansão recomendada: arquipélago modular

A melhor solução não é aumentar já o Terrain3D atual para um oceano gigante.
Recomenda-se uma arquitetura híbrida:

- cada **zona marítima** contém 2–4 ilhas próximas, visíveis e navegáveis sem
  loading durante o percurso curto;
- viagens maiores ligam zonas separadas, carregando o próximo conjunto enquanto
  o barco atravessa um corredor de mar ou uma transição curta;
- só a ilha onde o jogador está mantém zombies, navegação, colisão detalhada,
  loot e interiores ativos; ilhas distantes usam silhuetas/LOD muito leves;
- o diretor de horda pausa no oceano e retoma com uma composição própria ao
  desembarcar, sempre dentro do teto global de 90 inimigos;
- a primeira versão do barco deve ser um `CharacterBody3D` simples, estável e
  previsível. Ondas e física naval avançada ficam para depois do loop funcionar.

### Catálogo inicial de ilhas

| Ilha | Dimensão indicativa | Forma | Modelos já disponíveis | Conteúdo exclusivo possível |
|---|---:|---|---|---|
| Home Island | atual, ~440 m de diâmetro | grande e irregular | acampamento + terreno atual | base, upgrades e extração principal |
| Ironworks | 160 × 110 m | comprida, porto numa ponta | Kenney Factory/City Industrial, armazém e fuel station | blueprints Heavy, muito Scrap, Brutes |
| Quarantine Key | 120 × 90 m | crescente com baía interior | hospital/police facades e City Commercial | skills de suporte, medkits raros, Spitters |
| Fort Breaker | 90 × 70 m | compacta e elevada | Military Outpost, Quaternius/Kenney props | armas e munição exclusiva, encontro de elite |
| Mourning Isle | 80 × 60 m | assimétrica, floresta densa | Graveyard Kit + Mini Forest | variante rara, boss/noturno, mastery |
| Shipwreck Rocks | 25–50 m | micro-ilhas/rochedos | carros, caixas, cercas e destroços existentes | caches, beacon, eventos curtos |

As dimensões são alvos de protótipo, não uma grelha obrigatória. Cada ilha deve
ter costa própria, dois pontos de desembarque no máximo, uma silhueta reconhecível
e uma razão concreta para ser visitada.

### Dados do arquipélago

O protótipo já usa `IslandData` para `island_id`, nome, terreno, dificuldade,
descrição, posição 3D, posição no diagrama e destinos. `IslandRouteData` guarda
origem, destino, nome e mecânica; `ArchipelagoData` valida o grafo completo.
Continuam por acrescentar bounds detalhados, cena/pasta própria, tabela de loot,
pesos de inimigos, requisito de desbloqueio e recompensa exclusiva. Descoberta,
loot único e bosses derrotados só serão persistidos quando o sistema entrar na
run principal.

### Topologia jogável do protótipo Destiny Archipelago

```text
                         Route A: Shallow Reef
                   ┌────────────────────────────► Shadow Forest
                   │                                     │
                   │                            Route C: Rope Bridge
                   │                                     │
            Dawn Beach                                    ▼
            STARTING HUB                             Volcano Peak
                   │                                 FINAL / BOSS
                   │                                     ▲
                   │                           Route D: Ancient Ruins
                   │                                     │
                   └────────────────────────────► High Cliffs
                          Route B: Sea Cave
```

- Route A é um caminho Terrain3D contínuo com bancos de areia em `MultiMesh`;
  a maré fica baixa e estática nesta versão.
- Route B usa uma transição interativa entre duas bocas de gruta.
- Route C é uma ponte física de corda com 400 HP e alternativa pela Route D se
  for destruída.
- Route D tem 32 degraus físicos e pilares; o encontro de guardas ainda é um
  marcador de design.

### Ordem de implementação

1. [x] manter a ilha principal e validar a nova barreira offshore;
2. [x] criar **Shipwreck Rocks** como ilha piloto sem zombies e sem barco livre;
3. [x] adicionar um transporte automático entre dois cais;
4. [x] validar `IslandData` e um grafo visual isolado com quatro ilhas;
5. [ ] adaptar o mapa tático principal e save à descoberta da ilha;
6. [ ] criar **Ironworks** com um único lote do Factory Kit e um encontro exclusivo;
7. [ ] só depois tornar o barco controlável e acrescentar novas zonas marítimas.

## Layout recomendado para a ilha

```text
                 NORTE
       falésias ─ cordilheira ─ miradouro
          │          │              │
   costa oeste ─ corredor natural ─ planalto leste
          │          │              │
      pântano ─ ACAMPAMENTO ─ zona industrial/porto
          │          │              │
       praias ─ rota costeira ─ EXTRAÇÃO
                  SUL/ESTE
```

Princípios:

1. duas rotas macro em anel, uma interior e outra costeira;
2. pelo menos três ligações entre os anéis para evitar becos sem saída;
3. o acampamento fica fora do centro para tornar a viagem até à extração real;
4. colinas quebram a linha de visão sem criarem corredores estreitos permanentes;
5. cada quadrante recebe um landmark visível antes de receber dressing denso;
6. praias são zonas de risco abertas; cumes oferecem orientação, não segurança;
7. o ponto de extração deve poder alternar entre dois ou três locais costeiros.

## Critérios antes de adicionar modelos

- percorrer a costa inteira sem ficar preso nem cair através do terreno;
- jogador e todos os inimigos mantêm os pés no solo em repouso e movimento;
- nenhum spawn, cache ou caixa aparece abaixo da água;
- os zombies não tentam atravessar o mar;
- caminhos principais permitem circulação de uma horda larga;
- de qualquer zona jogável existe um landmark reconhecível;
- o acampamento continua nivelado e ligado a pelo menos duas rotas;
- benchmark de 90 zombies não sofre uma regressão material face à baseline;
- o mapa tático passa a representar costa, água e setores parcialmente terrestres.

## Estado dos critérios e próximas decisões

- [x] Costa livre; barreira persistente 24 m offshore, contínua acima da água e
  abaixo do fundo marinho, sem paredes quadradas depois do mar.
- [x] Dois anéis e três ligações largos, secos e com declive amostrado até 0,415.
- [x] Cinco tipos de inimigo com os ossos dos pés a 0,00 m do terreno nos testes.
- [x] Quatro landmarks de relevo e cinco zonas de material sem modelos externos.
- [x] Mapa tático com costa, água, caminhos e setores parcialmente terrestres.
- [x] Playtest automatizado em doze pontos dos caminhos e grelha de declives a 4 m.
- [ ] Fazer o playtest humano prolongado da ilha e ajustar ritmo, visibilidade e
  rotas de fuga segundo a sensação real de jogo.
- [ ] Reintroduzir modelos apenas por lotes pequenos com orçamento de render.
- [ ] Decidir se no futuro a barreira dá lugar a natação, dano ou retorno à margem.
- [x] Implementar Shipwreck Rocks como primeira ilha piloto do arquipélago, numa
  cena isolada com uma região persistente, dois cais e ferry automático.

## Referências técnicas

- Terrain3D no Asset Library: <https://godotengine.org/asset-library/asset/3134>
- Repositório oficial: <https://github.com/TokisanGames/Terrain3D>
- Importação e exportação: <https://terrain3d.readthedocs.io/en/stable/docs/import_export.html>
- Preparação de heightmaps: <https://terrain3d.readthedocs.io/en/latest/docs/heightmaps.html>
- Navegação sobre Terrain3D: <https://terrain3d.readthedocs.io/en/stable/docs/navigation.html>
- Preparação de texturas: <https://terrain3d.readthedocs.io/en/stable/docs/texture_prep.html>
