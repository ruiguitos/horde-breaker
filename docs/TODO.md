# Horde Breaker — TODO

## Pendentes confirmados

- [x] Implementar pausa real com `Esc`, incluindo pausa da árvore, libertação do rato e painel próprio.
- [ ] Integrar modelos e animações do Adobe Mixamo no Milestone 12, depois de o protótipo de combate estar funcional. Não descarregar assets sem autorização explícita. **Bloqueado: aguarda autorização para descarregar assets.**
- [x] Integrar modelos CC0 de teste para as três classes, dois tipos de zombie e as três armas de fogo, preservando colisões e mecânicas.
- [x] Criar a primeira expansão graybox da arena com três obstáculos, navegação que os contorna e seis pontos de spawn validados.
- [ ] Evoluir o graybox para um mapa totalmente jogável, afinando rotas, zonas de combate, coberturas e spawns através de playtests com Recruit, Renegade e Medic. **Nota: será substituído pela geração de mapa open world planeada.**
- [x] Substituir os quatro bairros repetidos pelo primeiro graybox de hospital, armazém, posto militar e estação de combustível.
- [x] Tornar o armazém no primeiro edifício explorável, com entrada, interior graybox e loot funcional de teste.
- [x] Adicionar ao armazém uma emboscada por ciclo e reposição controlada de Scrap e munições.
- [x] Abrir o hospital como segundo interior explorável e adicionar um medkit de 40 pontos reposto por ciclo.
- [x] Abrir o posto militar com duas caixas de munições e um encontro de dois Normal Zombies mais um Runner.
- [x] Abrir a estação de combustível com duas caches de Scrap e um encontro de três Runners por ciclo.
- [x] Escolher ataques agendados com aviso longo e aprovar o protótipo de dois setores descrito em `docs/OPEN_WORLD_PLAN.md`.
- [x] Criar o primeiro setor leste carregável, com navegação ligada e estado do farol preservado em memória.
- [x] Implementar carregamento em background dos setores com `ResourceLoader.load_threaded_request` e medição do tempo de carga.
- [x] Grelha 4 × 4 de setores implementada com geração procedural por seed, estado de caches por setor e navegação contínua; a extração do setor inicial foi substituída pela decisão de manter o acampamento persistente.
- [x] Adicionar encontros (emboscada única por setor), spawns próprios, caixa de munições com estado e geração distribuída por vários frames aos setores gerados.
- [x] Fazer as hordas nascerem nos pontos de spawn mais próximos do jogador, incluindo os marcadores dos setores carregados.
- [ ] Adicionar POIs com interiores exploráveis aos setores gerados e repor emboscadas por ciclo em vez de uma única por partida.
- [x] Implementar classes com loadout principal/secundário, passivos do Recruit, Renegade e Medic, e troca de arma com `1`/`2`.
- [x] Adicionar andar, corrida com `Shift`, salto com `Space`, agachamento com `Ctrl`, interação com `F`, vista frontal com `C` e mira com o botão direito do rato.
- [x] Criar um pickup de munições de teste e corrigir o visual suspenso da Worn Sword no Renegade.
- [x] Adicionar munição de reserva, recarga com consumo real e recolha de munições mesmo com uma arma melee ativa.
- [x] Criar a primeira composição urbana com modelos ambientais CC0 e remover as paredes graybox visíveis.
- [x] Implementar dano por zonas com corpo a `1 ×` e cabeça a `2 ×` para armas de fogo e armas brancas.
- [x] Adicionar números de dano pequenos, com cor distinta para impacto no corpo e headshot.
- [x] Adicionar disparo automático das armas de fogo contra inimigos com linha de visão até 3 metros.
- [ ] Afinar entre 2 e 3 metros e decidir se o disparo manual permanece depois do playtest das três classes. **Bloqueado: decisão do playtest.**
- [x] Alterar a IA para perseguir apenas o jogador e remover núcleo, acampamento e fortificações da seleção de alvos e das condições de derrota.
- [x] Adicionar feedback visual no próprio inimigo e feedback sonoro distinto para impacto no corpo e headshot.
- [ ] Definir uma arma ou ferramenta secundária própria para o Medic após playtest da Pistol e da regeneração. **Bloqueado: decisão do playtest.**
- [x] Implementar a primeira escolha de melhoria entre rondas, inspirada nos jogos analisados em `docs/INSPIRATIONS.md`.
- [x] Adotar survival contínuo com núcleo, exploração, Scrap e construção progressiva do acampamento.
- [x] Criar o primeiro ponto fixo para construir, reparar e reconstruir uma barricada com Scrap.
- [x] Corrigir as definições para guardar o modo de janela, mostrar a resolução
  real do monitor em fullscreen e aplicar a resolução selecionada em modo janela.
- [x] Adicionar um mapa tático em `Tab` com grelha de setores e marcadores do
  jogador, acampamento, POIs e inimigos ativos.
- [x] Remover as rondas e adotar um diretor de horda contínuo que faz nascer
  inimigos à volta do jogador durante a exploração, com escalada por nível de
  ameaça e mais zombies em simultâneo.
- [x] Aumentar o alcance do disparo automático de 3 para 6 metros.
- [x] Randomizar as posições do Scrap e das munições do acampamento a cada partida.
- [x] Melhorar o mapa tático: setor atual destacado, marcadores de Scrap, munição
  e medkit, e chip de acento no estilo do HUD.
- [x] Converter todo o texto do jogo (menus, HUD, mundo, dados) para inglês.
- [x] Enriquecer os setores gerados com torre de água, camião destroçado e postes
  de iluminação além dos marcos e contentores.
- [x] Transformar o acampamento numa zona de reabastecimento (cura e munições ao
  ficar perto do núcleo), inspirado no hub das referências.
- [x] Remover as etiquetas 3D por cima das caches de Scrap e das caixas de munições.
- [x] Auto-pickup de Scrap e munições ao passar por cima, sem premir `F`.
- [x] Remover o delay/pop-in ao carregar setores, gerando-os antes de estarem à vista.
- [x] Melhorar o mapa tático: bússola Norte, setor atual destacado, setores
  visitados, marcadores de armas e de objetivos, e legenda alargada.
- [x] Reduzir o HUD in-game ao essencial (vida, munição, ameaça compacta, Scrap
  pequeno), removendo a placa do núcleo, a placa grande de recursos e a barra de atalhos.
- [x] Adicionar armas encontráveis pela exploração: caixas de arma nos setores
  gerados que substituem a arma secundária durante a partida, com estado por setor.
- [x] Adicionar variedade de inimigos: Brute (tanque com knockback), Spitter
  (ataque à distância) e o boss The Breaker (invoca minions), ligados à
  escalada do diretor de horda.
- [x] Baixar a resolução por defeito para janela 1152 × 648 e adicionar um
  contador de FPS (autoload, alternável com `F3`) para testes.
- [ ] **Em espera:** ainda existe um mini-hitch no instante em que um setor
  gerado aparece (o `add_child` regista ~64 malhas de uma vez). Próximo passo
  possível: encaixar as peças do setor em 2-3 frames em vez de todas de uma vez.
- [x] Remover o limite de níveis das personagens e adicionar uma árvore de
  habilidades permanente por personagem (skill tree), com pontos ganhos por nível.
- [x] Remover o "Field Upgrade" (melhorias entre rondas), substituído pela skill tree.
- [x] Ao apanhar uma arma do chão, largar a arma substituída no chão para poder
  voltar a apanhá-la.

## Regra

Estes itens não alteram o âmbito do milestone atual. Quando forem concluídos, atualizar também `docs/PROGRESS.md`.
