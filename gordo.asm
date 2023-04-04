; Leitor de imagem FAT16
; arquivo: gordo.asm
; objetivo: Processar Arquivos organizados em FAT16
;           e exibir CAT dos mesmos
; nasm -f elf64 gordo.asm ; ld gordo.o -o gordo.x

%define _exit     60
%define _write    1
%define _open     2
%define _read     0
%define _seek     8
%define _close    3
%define readOnly  0o    ; flag open()
%define writeOnly 1o    ; flag open()
%define readwrite 2o    ; flag open()
%define openrw    102o  ; flag open()
%define userWR    644o  ; Read+Write+Execute



section .data
    
    argErrorS : db "Erro: Quantidade de Parâmetros incorreta", 10, 0
    argErrorSL: equ $-argErrorS 

    arqErrorS : db "Erro: Arquivo não foi aberto", 10, 0
    arqErrorSL: equ $-arqErrorS

    strOla  : db "Testi", 10, 0
    strOlaL : equ $-strOla


section .bss
    
    arquivo : resq 1
    argv    : resq 1
    argc    : resq 1
    bytet   : resb 1

section .text

    global _start

_start:
  
  mov r8, [rsp]
  mov [argv], r8
  cmp QWORD[argv],  2        ; Verifica a quantidade de argumentos
  jne _argError
  
  mov r8, rsp
  add r8, 16
  mov r9, [r8]
  mov [argc], r9              ; Salvando endereço do argumento em variável


  mov rax,  _open
  mov rdi,  [argc]
  mov rsi,  readwrite
  mov rdx,  userWR
  syscall

  mov [arquivo], rax                   ; Salvar ponteiro do arquivo
  cmp rax, 0                           ; Verifica se o arquivo foi aberto
  jl _arqError

  mov rax,  _read
  mov rdi,  [arquivo]
  lea rsi,  [bytet]
  mov rdx,  1
  syscall

  tes:
  
  mov rax,  _read
  mov rdi,  [arquivo]
  lea rsi,  [bytet]
  mov rdx,  1
  syscall

  tes1:

  mov rax,  _seek
  mov rdi,  [arquivo]
  mov rsi,  0
  mov rdx,  0
  syscall

  mov rax,  _read
  mov rdi,  [arquivo]
  lea rsi,  [bytet]
  mov rdx,  1
  syscall

  tes2:

_stop:
  mov rax,  _close
  mov rdi,  [arquivo]
  syscall

_end:
  mov rax,  _exit
  mov rdi,  0
  syscall

_arqError:

  mov rax,  _write
  mov rdi,  1
  lea rsi,  [arqErrorS] 
  mov rdx,  arqErrorSL
  syscall
  jmp _end


_argError:
  
  mov rax,  _write
  mov rdi,  1
  lea rsi,  [argErrorS]
  mov rdx,  argErrorSL
  syscall
  jmp _end


