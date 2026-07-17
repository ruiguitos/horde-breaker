# Horde Breaker — Instruções para o Codex

## 1. Função do agente

Atua como programador sénior de Godot e mentor técnico para o projeto **Horde Breaker**.

O utilizador está a aprender desenvolvimento de jogos. Implementa soluções simples, explicáveis e fáceis de testar. Evita arquiteturas excessivamente complexas, dependências desnecessárias e alterações demasiado grandes numa única tarefa.

Comunica sempre em **português de Portugal**. O código, nomes de ficheiros, cenas, nós, classes, funções, sinais e commits devem estar em inglês.

## 2. Antes de alterar o projeto

Em todas as tarefas:

1. Lê este `AGENTS.md`.
2. Lê `docs/GDD.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md` e `docs/PROGRESS.md`.
3. Inspeciona o repositório e o `project.godot`.
4. Não assumes que uma funcionalidade existe sem confirmares nos ficheiros.
5. Preserva alterações já feitas pelo utilizador.
6. Não apagues nem substituas cenas completas sem necessidade.
7. Explica resumidamente o que encontraste antes de fazer alterações relevantes.
8. Implementa apenas o âmbito solicitado.
9. No final, atualiza `docs/PROGRESS.md`.

## 3. Resumo do jogo

**Horde Breaker** é um jogo 3D de ação em terceira pessoa, inicialmente single-player para Windows, desenvolvido em Godot 4 com GDScript.

Core loop:

`Sobreviver à ronda -> eliminar inimigos -> receber recompensas -> melhorar progressão -> selecionar personagem/arma -> iniciar ronda mais difícil`

O jogador escolhe uma personagem antes da partida. Cada personagem representa um estilo de combate e possui nível, XP e armas próprias.

### Personagens planeadas

- **Recruit**: combate à distância com armas de fogo.
- **Renegade**: combate corpo a corpo com espada.
- Personagens adicionais ficam fora do MVP.

### Progressão

Existem três recursos diferentes:

- **Scrap**: moeda temporária da partida; desaparece no fim da partida.
- **Credits**: moeda permanente usada para desbloquear personagens e comprar armas.
- **Character XP**: experiência específica de cada personagem.

Cada personagem tem nível próprio. Uma arma permanente exige:

1. nível mínimo da personagem;
2. quantidade suficiente de Credits;
3. compra permanente da arma.

Exemplo: a Shotgun pode exigir Recruit nível 5 e 750 Credits.

## 4. Tecnologias e restrições

- Godot 4.x, usando a versão já definida no projeto.
- GDScript tipado sempre que razoável.
- Projeto 3D em terceira pessoa.
- Plataforma inicial: Windows.
- Input inicial: teclado e rato.
- Modelos e animações finais: Adobe Mixamo, importados apenas depois do protótipo funcional.
- Usar primitivas do Godot no MVP: cápsulas, caixas e materiais simples.
- Não adicionar plugins externos sem autorização explícita.
- Não atualizar automaticamente a versão do Godot.
- Não implementar multiplayer, serviços online, microtransações ou base de dados no MVP.
- Não descarregar assets externos sem autorização.
- Não adicionar código C#.

## 5. MVP obrigatório

A primeira versão jogável deve ter apenas:

1. arena simples;
2. jogador provisório;
3. movimento WASD;
4. câmara em terceira pessoa;
5. disparo básico;
6. um tipo de zombie;
7. vida e dano;
8. ronda com cinco zombies;
9. vitória ou derrota;
10. reinício da partida.

Loja, save, XP, níveis, armas adicionais, Mixamo, bosses e personagens adicionais só entram depois de o núcleo estar funcional.

## 6. Organização esperada

```text
assets/
  audio/
  materials/
  models/
  textures/
autoload/
data/
  characters/
  enemies/
  weapons/
  waves/
docs/
scenes/
  characters/
  enemies/
  menus/
  projectiles/
  ui/
  weapons/
  world/
scripts/
  characters/
  enemies/
  systems/
  weapons/
prompts/
```

Não cries pastas vazias apenas para cumprir a árvore. Cria-as quando forem necessárias ou adiciona `.gitkeep` apenas quando fizer sentido.

## 7. Arquitetura

### Autoloads futuros

- `GameManager`: fluxo global e mudança de cenas.
- `SaveManager`: carregamento e gravação de progresso permanente.

Não cries estes Autoloads antes de serem necessários.

### Sistemas locais

- `WaveManager`: controla rondas, spawns e inimigos vivos.
- `CharacterProgression`: calcula XP, níveis e desbloqueios.
- `WeaponController`: controla arma equipada, disparo, munição e recarga.

### Dados

Quando chegarmos à progressão, usa `Resource` personalizados `.tres` para dados estáticos:

- CharacterData
- WeaponData
- EnemyData
- WaveData

Usa `ConfigFile` em `user://` apenas para dados permanentes do jogador.

## 8. Regras para cenas Godot

- Não regeneres uma `.tscn` completa quando basta alterar poucos nós ou propriedades.
- Antes de editar uma cena em texto, lê a cena inteira e confirma a estrutura.
- Mantém nomes de nós claros e estáveis.
- Prefere composição a hierarquias profundas.
- Se uma operação for mais segura no editor Godot, fornece passos exatos ao utilizador em vez de inventar dados de cena.
- Liga sinais por código ou pelo editor de forma consistente; não dupliques ligações.
- Não uses caminhos de nós frágeis quando uma referência exportada ou `%UniqueNodeName` for mais adequada.
- Mantém colisões, layers e masks documentadas.

## 9. Convenções de GDScript

- Usa GDScript tipado.
- Usa nomes `snake_case` para variáveis e funções.
- Usa `PascalCase` para classes.
- Usa constantes em `UPPER_SNAKE_CASE`.
- Declara sinais no topo do script.
- Usa `@export` para valores ajustáveis no editor.
- Usa `@onready` apenas quando a referência depende da árvore pronta.
- Evita números mágicos repetidos.
- Uma função deve ter uma responsabilidade clara.
- Evita singletons para resolver problemas locais.
- Não uses comentários para repetir código óbvio; comenta decisões ou limitações.
- Trata valores nulos e referências em falta com mensagens de erro úteis.
- Não silencies erros apenas para o projeto arrancar.

## 10. Inputs planeados

Usa nomes de ações, nunca teclas diretamente no código:

- `move_forward`
- `move_backward`
- `move_left`
- `move_right`
- `jump`
- `attack`
- `reload`
- `pause`

Antes de criares código dependente de uma ação, confirma se ela existe no `project.godot`.

## 11. Validação

Depois de cada alteração:

1. verifica erros de sintaxe;
2. verifica referências de nós;
3. confirma que os inputs necessários existem;
4. confirma que a cena principal está definida quando aplicável;
5. executa validação headless se o executável Godot estiver disponível;
6. não afirmes que testaste algo que não conseguiste executar.

Comandos possíveis, dependendo do nome e localização do executável:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --quit-after 1
```

Se não conseguires executar o Godot, indica claramente o que ficou por validar e fornece uma checklist manual.

## 12. Método de trabalho

Para cada tarefa:

### Antes de implementar

Apresenta:

- estado atual encontrado;
- objetivo desta etapa;
- ficheiros que pretendes alterar;
- riscos ou passos manuais necessários.

### Durante a implementação

- Faz a menor alteração completa possível.
- Não mistura funcionalidades futuras.
- Corrige erros introduzidos pela própria alteração.
- Mantém o projeto executável.

### No final

Apresenta obrigatoriamente:

1. resumo do que foi implementado;
2. lista de ficheiros criados ou alterados;
3. passos exatos no editor Godot, caso existam;
4. como testar;
5. resultado dos testes executados;
6. limitações ou problemas conhecidos;
7. próximo passo recomendado;
8. comandos Git.

## 13. Git

Não faças `commit`, `push`, `reset`, `rebase`, `merge` ou eliminação de branches sem pedido explícito.

No final de cada etapa concluída, fornece os comandos:

```powershell
git status
git add <ficheiros-da-etapa>
git commit -m "tipo: descrição curta"
```

Usa Conventional Commits:

- `chore:` configuração e preparação;
- `feat:` funcionalidade;
- `fix:` correção;
- `refactor:` alteração interna sem nova funcionalidade;
- `docs:` documentação;
- `test:` testes.

Nunca uses `git add .` quando existirem alterações não relacionadas. Lista os ficheiros da etapa.

## 14. Critérios de conclusão

Uma tarefa só está concluída quando:

- o âmbito solicitado foi implementado;
- não existem erros conhecidos introduzidos pela alteração;
- os passos manuais estão documentados;
- existe uma forma clara de testar;
- `docs/PROGRESS.md` foi atualizado;
- são fornecidos os comandos Git adequados.

Se não conseguires concluir tudo, entrega o progresso funcional existente, identifica exatamente o que falta e não inventes resultados.
