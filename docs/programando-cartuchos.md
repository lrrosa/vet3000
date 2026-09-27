# Programando cartuchos para o VET 3000

O firmware v2.1 aceita dois tipos de cartucho na janela `$4000-$7FFF` do conector CN1. O
[cartucho de demonstração](../cartridge/demo/) segue todas as regras abaixo e serve de exemplo
completo.

## 1. Cartucho de programa ("OBJECT")

### Cabeçalho

O firmware compara 6 bytes e executa:

```asm
        ldx  [$4006]      ; indireto estendido: X = palavra no endereço contido em $4006
        jsr  $4000,X
```

O `[$4006]` lê **duas vezes**: `$4006` contém um **ponteiro** e o deslocamento da entrada está na
palavra apontada. O cabeçalho mínimo correto é:

```asm
        org  $4000
        fcc  "OBJECT"          ; $4000: assinatura
        fdb  vetor             ; $4006: ponteiro...
vetor   fdb  entrada-$4000     ; $4008: ...para o deslocamento da entrada
entrada ...
```

Se `"OBJECT"` não estiver em `$4000`, o firmware tenta `$6000` (com `[$6006]` e `JSR $6000,X`). Um
cartucho de 16 KB pode, portanto, ter um programa na metade de cima, e dá para montar cartuchos de
8 KB (uma 2764 respondendo em `$4000-$5FFF` ou `$6000-$7FFF`).

### Estado na entrada

- **Pilha:** perto de `$01FE`, com o endereço de retorno para a ROM.
- **Interrupções:** IRQ e FIRQ mascaradas (estado do reset) e **DP = `$00`**.
- **VDP:** Graphics II, R1 = `$82` (imagem desligada, sem interrupção). A VRAM está zerada, com
  nomes 0..255 ×3, lista de sprites vazia e padrões de sprite em `$1800`.
- **RAM:** variáveis do firmware já inicializadas, e os ponteiros de fonte apontam para a ROM. Os
  cartuchos `"FONT"` ainda **não** foram procurados.

### Voltar ou assumir a máquina

- **`RTS`**: o firmware continua o boot normalmente (fontes, "POWER", abertura, editor). Serve para
  cartuchos que só acrescentam coisas, por exemplo trocando entradas da tabela de comandos em
  `$0040-$007F` ou instalando um vetor de IRQ.
- **Não voltar**: o programa assume a máquina. Para devolver o controle ao titulador depois, a demo
  grava uma marca em RAM e salta para o vetor de reset. Na nova entrada, o cartucho vê a marca e
  faz `RTS`:

```asm
EXIT_MAGIC equ $0080            ; RAM que o firmware não usa
entrada ldd  EXIT_MAGIC
        cmpd #"EX"
        bne  roda
        ldd  EXIT_MAGIC+2
        cmpd #"IT"
        bne  roda
        clr  EXIT_MAGIC
        rts                     ; segue para o titulador
roda    ...
sair    ldd  #"EX"
        std  EXIT_MAGIC
        ldd  #"IT"
        std  EXIT_MAGIC+2
        jmp  [$FFFE]            ; reset
```

Boa prática: se uma tecla estiver apertada no boot (a demo usa EXT MODE), faça `RTS` na hora.
Assim o usuário usa o titulador sem tirar o cartucho.

### Voltar do titulador para o cartucho

O firmware só chama o cartucho no boot, mas a tabela de comandos fica em RAM e é recriada antes
dessa chamada. Antes do `RTS`, o cartucho pode trocar uma entrada por uma rotina sua. O editor do
titulador a chama com `JSR` quando a tecla correspondente é apertada. A demo usa o código `$15`
(SHIFT+EXT MODE), que no firmware só repetia o EXT MODE:

```asm
CMD_TABLE equ $0040             ; 32 ponteiros, um por código de tecla
        ldd  #volta
        std  CMD_TABLE+2*$15    ; SHIFT+EXT MODE
        rts                     ; segue para o titulador
volta   ...                     ; espera EXT MODE ser solta e faz jmp [$FFFE]
```

O código `$15` é aceito com o cursor desligado e com a imagem desligada (BORDER BLK). Na tela de
abertura do titulador ("Pressione qualquer tecla") a ROM trata EXT MODE sem passar pela tabela, então
o atalho só vale depois de entrar no editor. Espere a tecla ser solta antes do reset: a demo pula o
cartucho se EXT MODE estiver apertada no boot.

### RAM: não apague os títulos do usuário

A RAM tem bateria e guarda até 30 páginas de títulos. Áreas **livres** para o cartucho:

| Faixa | Situação |
|---|---|
| `$0000-$002F` | Variáveis do firmware, recriadas no boot |
| `$0035-$007F` | Ponteiros, vetores e tabela de comandos, recriados no boot |
| `$0080-$009F` | Não usada pelo firmware |
| `$0190-$01FF` | Área da pilha |

**Não toque em:** `$0030-$0034` ("POWER"; sem ela o firmware apaga tudo), `$00A0-$018F` (atributos)
e `$0200-$1FFF` (textos). Se o programa precisar de mais memória, a VRAM tem espaço sobrando
conforme o modo de vídeo usado.

## 2. Cartucho de fonte ("FONT")

Depois do teste de `"OBJECT"`, o firmware procura `"FONT"`:

| Posição | `$4000` (fonte A, substitui a da ROM) | `$6000` (fonte B, caracteres com bit 7 = 1) |
|---|---|---|
| +`$0000` | `"FONT"` | `"FONT"` |
| +`$0004` | byte de identificação | byte de identificação (ver abaixo) |
| +`$0010` | fonte grande 16×24: 104 glifos × 48 bytes | idem |
| +`$1390` | fonte normal 8×24: 104 glifos × 24 bytes (+ 4 glifos `$7B-$7E`) | idem |

O formato dos glifos é o mesmo das fontes da ROM (ver [firmware.md](firmware.md#fontes)).
A fonte B só é instalada se o byte de identificação em `$6004` for diferente do de `$4004`, ou
diferente de 0 quando não há fonte em `$4000`.

No editor, **o modo do cursor escolhe a fonte**: com o cursor em bloco os caracteres saem da fonte A,
e com o cursor sublinhado eles são gravados com o bit 7 ligado e saem da fonte B. Sem cartucho, as
duas apontam para a ROM. Um cartucho de 16 KB com duas fontes dá ao titulador dois estilos de letra
alternados pela tecla CURSOR.

## 3. VDP: regras de temporização

- **Portas:** `$8000` = dados (VRAM), `$8001` = controle/status.
- **Endereço de escrita:** byte baixo, depois byte alto OR `$40`, ambos em `$8001`.
- **Registrador:** valor, depois `$80 | número`, em `$8001`.
- **Intervalo mínimo** entre acessos à porta de dados durante a imagem ativa: **8 µs, ou 8 ciclos
  do 6809**. Exemplos:
  - `LDA ,X+` / `STA $8000` = 11 ciclos: seguro;
  - `STA $8000` / `STB $8000` seguidos = 5 ciclos: **pode perder bytes** fora do apagamento vertical;
  - `LDA n,X` / `ORA n,Y` / `STA $8000` = 15 ciclos (o scroller da demo).
- Nos **~4,3 ms após a interrupção** de quadro (cerca de 3.800 ciclos), ou com a imagem desligada,
  qualquer velocidade funciona.

### Sobreposição ao vídeo externo

Com o bit EXTVID (R0 bit 0) ligado, o vídeo da entrada só aparece onde a cor do pixel é **0
(transparente)**, e o backdrop (R7) também tem de ser 0. Um fundo preto (cor 1) esconde o vídeo.
Use a cor 0 nos fundos e deixe R7 = 1 no uso normal: a tela fica preta igual. Para sobrepor, ligue
o EXTVID e ponha R7 = 0, como faz a tecla V da demo. O MAME mostra a cor 0 como preto.

## 4. Sincronismo com o quadro sem vetores

Ligue o bit IE (R1 bit 5) e mantenha a IRQ **mascarada** na CPU. A instrução `SYNC` do 6809 espera a
linha IRQ ser ativada e segue em frente sem desviar para o vetor. A leitura do status apaga a INT:

```asm
wait_frame
        sync                ; espera o /INT do VDP (fim da área ativa)
        lda  $8001          ; lê o status: apaga a INT, bit 5 = 5o sprite, bit 7 = F
        rts
```

Isso evita a corrida conhecida da leitura do status em laço e não precisa de `$0039`. Se preferir
interrupções de verdade, grave o endereço da rotina em `$0039` antes de executar `ANDCC #$EF`.

## 5. Orçamento de processamento

A cerca de 60 Hz e 0,895 MHz, um quadro tem **~14.930 ciclos**. Custos de algumas tarefas da demo:

| Tarefa | Ciclos | Origem |
|---|---|---|
| Escrever 1 byte na VRAM num laço simples | 11-19 | contagem de ciclos |
| Atualizar 32 sprites (128 bytes) | ~2.000 | estimado |
| Tabela de nomes inteira (768 bytes) | ~9.000 | estimado (use o apagamento vertical ou divida entre quadros) |
| Scroller suave de 32 colunas (256 bytes calculados) | ~5.300 | contagem de ciclos |
| Trocar a cor de uma linha de pixel em 23 colunas (endereço refeito a cada byte) | ~900 | contagem de ciclos |
| Abertura completa da demo | ~12.000 | **medido** (build DEBUG) |
| Jogo QUEBRA-TIJOLO | ~1.600 com 3 passos de lógica | **medido** no MAME |

O driver do MAME 0.289 roda o VDP a 20 Hz (ver [mame.md](mame.md)), o que dá **3 vezes mais
ciclos por quadro** que o aparelho. A demo mede os ciclos por quadro no início (laço de 13 ciclos
até o próximo fim de quadro) e ajusta quantos passos de lógica roda por quadro. Assim a velocidade
do jogo é a mesma nos dois casos.

## 6. Testando no MAME sem recompilar

[tools/mame/vet3000_cart.lua](../tools/mame/vet3000_cart.lua) instala um *read tap* em
`$4000-$7FFF` e devolve os bytes do arquivo indicado em `VET_CART`. A ROM original encontra o
cartucho como no aparelho. O script também digita teclas, tira snapshots e grava trace (ver
[mame.md](mame.md)).

## 7. Ferramentas

- **Montador:** [asm6809](https://www.6809.org.uk/asm6809/) (`asm6809 -B -o cart.bin fonte.asm`).
  Use `setdp 0` para o modo direto automático.
- **Tamanho:** complete a imagem com `$FF` até 16 KB (27C128) com `cartridge/demo/pad.py`.
