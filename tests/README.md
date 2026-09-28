# Testes de regressão

Na raiz do repositório:

```sh
python -m unittest discover -s tests -v
```

Valida hints truncados, limites de dados, palavras incompletas e referências
relativas para fora da ROM. A verificação completa do firmware continua em
`disasm/verify.sh` (requer asm6809).

Depois de montar o cartucho com `cartridge/demo/build.sh` ou `build.ps1`:

```sh
python tests/run_mame.py /caminho/para/mame
```

O teste executa o código 6809 montado no MAME (verificado com 0.289), sem janela,
e confere 515 casos: os três dígitos do HUD nas 256 fases, colisões com tijolos
nas duas paredes, o placar durante FASE COMPLETA e os 256 estados das barras
contra a função Python usada pela prévia. O teste isola as rotinas; na transição
de fase, substitui a espera e o salto para a próxima tela apenas na memória do
emulador. Não altera o cartucho. ROM temporária e configurações ficam em `build/`.

Use `--cart` e `--symbols` para testar outro build, sempre com o arquivo de símbolos
correspondente (gerado pelo asm6809 com `-s`). Falhas Lua, timeout ou ausência da
mensagem final de sucesso fazem o runner retornar erro.
