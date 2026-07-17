# Utilizar o Codex no projeto Horde Breaker

## Preparação

1. Cria ou abre a pasta do projeto Godot.
2. Copia `AGENTS.md`, a pasta `docs` e a pasta `prompts` para a raiz do projeto.
3. Abre essa pasta no Codex App, na extensão Codex do editor ou no Codex CLI.
4. Inicia pela tarefa `prompts/01_bootstrap_project.md`.
5. Trabalha numa tarefa de cada vez.
6. Revê sempre o diff antes de aceitar alterações.
7. Abre o Godot e testa a funcionalidade antes do commit.

## Estrutura mínima

```text
horde-breaker/
  AGENTS.md
  README_CODEX.md
  docs/
  prompts/
  project.godot
```

## Primeira mensagem recomendada

```text
Lê primeiro o AGENTS.md e todos os ficheiros em docs/. Depois inspeciona o repositório e executa apenas a tarefa descrita em prompts/01_bootstrap_project.md. Não avances para a tarefa seguinte. Preserva todas as alterações existentes, explica os passos manuais necessários no Godot e termina com validação e comandos Git.
```

## Regra de utilização

Não peças ao Codex para “criar o jogo completo”. Usa tarefas pequenas:

- preparar o projeto;
- criar arena;
- criar jogador;
- adicionar movimento;
- adicionar câmara;
- adicionar disparo;
- adicionar zombie;
- adicionar ronda.

Quanto menor e mais verificável for a tarefa, mais fácil será localizar e corrigir erros.
