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
- conteúdo: só pode nascer em terreno acima da linha costeira navegável;
- navegação: células submersas não recebem polígonos;
- arte: continuam fora da arena casas, estradas, vegetação e POIs antigos.

A página indicada na investigação, asset `3134`, é o próprio plugin Terrain3D
1.0.0 e não um mapa nem um pack de ilhas. O projeto já inclui Terrain3D 1.0.2;
não é necessário instalar esse asset novamente.

## Formas possíveis para o mapa

| Opção | Vantagens | Riscos | Adequação ao Horde Breaker |
|---|---|---|---|
| **Ilha grande** — atual | limite natural, silhueta clara, costa útil para extração, fácil dividir em biomas | água/natação e costa no mapa tático precisam de solução | **Alta**: mantém exploração e horda contínua sem parecer uma caixa |
| **Península** | uma ligação terrestre pode ser objetivo, gargalo ou evacuação | o limite interior continua a precisar de montanha/muralha | Alta para uma campanha orientada; média para sandbox |
| **Vale fechado / cratera** | montanhas explicam o limite e criam leitura vertical forte | horizonte repetitivo; zombies podem sofrer em declives extremos | Alta para uma arena mais tensa e controlada |
| **Arquipélago** | zonas muito distintas e forte identidade visual | pontes/barcos fragmentam a navegação e as hordas; streaming mais complexo | Baixa nesta fase; interessante para expansão futura |
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
- benchmark de 140 zombies não sofre uma regressão material face à baseline;
- o mapa tático passa a representar costa, água e setores parcialmente terrestres.

## Próximas decisões

1. Fazer playtest da ilha vazia e aprovar escala, declives e linha de costa.
2. Esculpir duas rotas terrain-native e três ligações entre elas.
3. Escolher quatro landmarks sem reutilizar edifícios antigos por defeito.
4. Definir biomas e texturas: praia, planície, floresta/serra e zona industrial.
5. Só depois reintroduzir modelos, por lotes pequenos e com orçamento de render.
6. Decidir natação, dano/retorno na água ou barreira costeira natural.

## Referências técnicas

- Terrain3D no Asset Library: <https://godotengine.org/asset-library/asset/3134>
- Repositório oficial: <https://github.com/TokisanGames/Terrain3D>
- Importação e exportação: <https://terrain3d.readthedocs.io/en/stable/docs/import_export.html>
- Preparação de heightmaps: <https://terrain3d.readthedocs.io/en/latest/docs/heightmaps.html>
- Navegação sobre Terrain3D: <https://terrain3d.readthedocs.io/en/stable/docs/navigation.html>
- Preparação de texturas: <https://terrain3d.readthedocs.io/en/stable/docs/texture_prep.html>

