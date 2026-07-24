# M24/M25 — Checklist de teste manual

## Preparação

1. Abrir a pasta do projeto no Godot 4.7 com o renderer GL Compatibility.
2. Aguardar o fim da importação dos `.gltf` e confirmar que o painel **Output**
   não apresenta erros de parsing ou recursos em falta.
3. Abrir `scenes/world/test_arena.tscn` e executá-la com **F6**; também deve ser
   possível executar o projeto com **F5**, porque esta continua a ser a cena
   principal.
4. Não é necessário ligar nós ou sinais manualmente: a arena já inclui
   `Environment`, `AtmosphereController`, `CampConstruction`, `CampBuilder` e
   `BuildCatalogLayer`.

## M24 — cidade e atmosfera

- Percorrer vários setores gerados e confirmar que a mesma seed produz a mesma
  distribuição de edifícios, AC, drenos, carros e lixo entre execuções.
- Confirmar que os carros não atravessam edifícios ou outros bloqueios quando
  aparecem rodados 90°/270°.
- Confirmar que os props sólidos alteram a navegação e que os props visuais não
  bloqueiam o jogador.
- Encontrar vários POIs gerados e confirmar as três fachadas possíveis:
  **Police Station**, **Hospital** e **Supermarket**. A entrada deve permanecer
  transitável e a cache deve continuar no interior.
- Para acelerar o teste da atmosfera, selecionar `Gameplay/WaveManager` no
  **Remote Scene Tree** e reduzir temporariamente `level_up_interval` para
  `2.0`. Confirmar as transições nos níveis 5, 10 e 15 e repor depois o valor.

## M25 — construção livre

1. Recolher Scrap e depositá-lo no núcleo com a ação de interação. Para um teste
   rápido, também se pode alterar temporariamente `stored_scrap` em
   `Gameplay/CampEconomy` através do **Remote Inspector**.
2. Permanecer perto do acampamento e premir **B**. O jogador deve parar de se
   mover/disparar e o catálogo deve abrir com o cursor visível.
3. Confirmar que o catálogo mostra Barricade, Scrap Wall, Watch Tower,
   Generator e Spotlight, separando Defense e Utility.
4. Confirmar os bloqueios por upgrade:
   - Generator: Resupply Rate nível 1;
   - Spotlight: Scavenging nível 1;
   - Watch Tower: Resupply Range nível 2.
5. Selecionar uma estrutura. O cursor volta a ficar capturado e aparece um
   preview na grelha de 2 m.
6. Apontar para uma célula livre: preview verde. Apontar para a zona reservada
   do núcleo, para fora da grelha ou sobre outra estrutura: preview vermelho.
7. Premir **R** e confirmar que footprints 2×1 passam para 1×2.
8. Premir o botão esquerdo do rato numa posição válida. Confirmar desconto do
   Scrap armazenado, colisão, atualização da navegação e continuidade do modo
   de colocação com a mesma estrutura.
9. Premir **Esc** durante a colocação para voltar ao catálogo; premir **Esc** ou
   **B** no catálogo para sair do modo de construção.
10. Afastar-se mais de 18 m do centro da grelha e premir **B**. Deve surgir o
    feedback `RETURN TO CAMP TO BUILD`.

## Persistência e reparação

- Colocar pelo menos duas estruturas com rotações diferentes, sair do jogo e
  voltar a abrir a arena. As estruturas devem reaparecer nas mesmas células.
- No **Remote Inspector**, reduzir `current_health` de uma estrutura e sair do
  jogo. Ao reabrir, a vida reduzida deve ser restaurada.
- Aproximar-se da estrutura danificada e interagir. Devem ser consumidos 10
  Scrap armazenados e reparados até 50 pontos de vida.
- No **Remote Inspector**, chamar `take_damage()` até destruir uma estrutura ou
  reduzir `current_health` e voltar a aplicar dano em jogo através de um teste
  auxiliar. A célula deve ficar livre e a estrutura não deve regressar no save.

## Upgrades visuais do acampamento

- Comprar **Resupply Rate** até ao nível 2: deve surgir a estação visual do lado
  oeste/noroeste do núcleo.
- Comprar **Scavenging** nível 1: deve surgir o depósito visual do lado leste.
- Sair e voltar a entrar na cena durante a mesma execução e confirmar que os
  visuais não são duplicados.

## Regressões essenciais

- **Esc** continua a abrir a pausa fora do modo de construção.
- **Esc** cancela primeiro o modo de construção sem abrir simultaneamente a
  pausa.
- O ataque e a recarga não disparam durante a colocação, apesar de partilharem
  LMB/R com as ações de construção.
- Inimigos continuam a perseguir o jogador através da navegação reconstruída.
- Depositar Scrap, comprar upgrades, loot de POI, HUD e mapa tático continuam a
  funcionar.

## Movimento durante a construção

- [ ] Entrar no modo com `B` e confirmar que `WASD` continua a mover o jogador com o catálogo aberto.
- [ ] Selecionar uma estrutura e confirmar movimento, sprint, agachamento, salto e controlo da câmara durante o preview.
- [ ] Confirmar que disparo/recarga e interação normal não são executados enquanto o modo está ativo.
- [ ] Afastar-se da posição do ghost e confirmar que o preview fica inválido para além do alcance máximo.
- [ ] Sair com `B` ou `Esc` e confirmar que armas e interação normal voltam a funcionar.
