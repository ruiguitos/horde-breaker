# Reconstrução da cidade e dos caminhos

## Progresso

- **Fase 1 (linhas de debug do grafo) e Fase 2 (validação de continuidade)
  implementadas em 2026-07-24.** `scripts/world/sector_edge_contract.gd`
  calcula os quatro conectores de aresta por setor de forma determinística
  (seed global + coordenadas), `scripts/world/road_graph.gd` guarda o grafo
  resultante e valida-o (sem dead-ends não intencionais, sem segmentos
  curtos, sem cruzamentos impossíveis), e
  `scripts/world/city_layout_generator.gd` orquestra a construção do grafo
  para as 16 células da grelha, o visual de debug (reutilizando a técnica
  `ImmediateMesh` de `build_grid.gd`) e as verificações de continuidade nas
  24 fronteiras internas e de determinismo com seeds repetidas. O overlay
  `scripts/world/city_graph_debug_overlay.gd` está ligado a
  `scenes/world/test_arena.tscn` e corre automaticamente ao arrancar,
  reportando falhas via `push_warning`. Há também uma ferramenta de editor
  (`scripts/world/tools/validate_city_graph.gd`, `@tool extends
  EditorScript`, corre via File → Run) que testa várias seeds fixas de uma
  vez. Este trabalho é inteiramente aditivo — não altera
  `sector_generator.gd`, `city_road_grid.tscn` nem `east_sector.tscn`.
  **Falta ainda a validação manual no editor** (não há binário Godot nem
  suite de testes neste ambiente para a confirmar automaticamente).
- **Fases 3–7 (geometria real, quarteirões/lotes, reintegração de
  edifícios/POIs/props/navegação) ainda por implementar.**

## Estado

A cidade procedural atual é um protótipo funcional. Os edifícios, fachadas,
props e presets de atmosfera podem ser reutilizados, mas o layout por quatro
quadrantes de estrada não deve ser expandido. A próxima versão substitui a
geometria de circulação e só depois recompõe os quarteirões.

## Objetivo

Gerar uma cidade legível e contínua em que estradas, passeios, caminhos,
entradas de edifícios, lotes e navegação nascem da mesma estrutura de dados.
As ligações entre setores têm de ser determinísticas para nunca existirem
estradas cortadas na fronteira do streaming.

## Arquitetura proposta

1. **Contrato das fronteiras do setor**
   - Cada setor calcula quatro `edge connectors` a partir da seed global e das
     coordenadas da aresta partilhada.
   - Dois setores vizinhos obtêm exatamente a mesma posição, largura e tipo de
     ligação sem precisarem de comunicar entre si.

2. **Grafo de circulação**
   - Nós representam interseções, entradas de POI, becos e ligações de fronteira.
   - Arestas representam estrada, passeio ou caminho pedonal.
   - O grafo é validado antes de criar qualquer malha: sem pontas mortas
     involuntárias, cruzamentos impossíveis ou segmentos demasiado curtos.

3. **Geometria de estradas e caminhos**
   - Instanciar segmentos retos, curvas e interseções a partir das arestas.
   - Usar material com UV em world-space para remover costuras.
   - Passeios e lancis são derivados das margens da estrada, não colocados como
     props independentes.

4. **Quarteirões e lotes**
   - As áreas fechadas pelo grafo tornam-se quarteirões.
   - Cada quarteirão é dividido em lotes com setback mínimo para passeio,
     estrada, cruzamentos e POIs.
   - A entrada principal de cada edifício fica orientada para o passeio mais
     próximo e nunca para o interior de outro lote.

5. **POIs e caminhos secundários**
   - POIs reservam primeiro o footprint e adicionam um nó de entrada ao grafo.
   - Becos, parques, atalhos pedonais e acessos de serviço são arestas próprias,
     permitindo controlar navegação e encontros separadamente das estradas.

6. **Navegação e streaming**
   - Colisões e `navigation_blocker` são gerados apenas depois do layout final.
   - As bordas navegáveis usam o mesmo contrato dos conectores do setor.
   - A geração continua faseada: grafo, estradas, lotes, edifícios, props e nav.

## Ficheiros previstos

- `scripts/world/city_layout_generator.gd`
- `scripts/world/road_graph.gd`
- `scripts/world/sector_edge_contract.gd`
- `scripts/world/city_block_builder.gd`
- `data/city_layout_rules.tres`
- `scenes/world/roads/road_straight.tscn`
- `scenes/world/roads/road_curve.tscn`
- `scenes/world/roads/road_intersection.tscn`
- `scenes/world/roads/pedestrian_path.tscn`

## Ordem de implementação

1. Desenhar apenas linhas de debug do grafo em 4×4 setores.
2. Validar continuidade nas 24 fronteiras internas e nas seeds repetidas.
3. Substituir linhas por estradas/passeios sem edifícios.
4. Gerar quarteirões e lotes.
5. Reintegrar edifícios e POIs existentes.
6. Reintegrar props, atmosfera, loot e navegação.
7. Medir custo por fase e ajustar pooling/streaming.

## Critérios de aceitação

- Todas as estradas e caminhos terminam numa ligação válida, entrada ou destino.
- Setores vizinhos encaixam em qualquer ordem de carregamento.
- Nenhum edifício invade estrada, passeio, passadeira ou outro lote.
- Entradas de edifícios e POIs são alcançáveis pelo jogador e pela navegação.
- A mesma seed produz exatamente o mesmo grafo e composição.
- A geração não introduz um hitch superior ao orçamento já definido para o
  streaming faseado.
