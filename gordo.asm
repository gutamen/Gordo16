; Leitor de imagem FAT16
; arquivo: gordo.asm
; objetivo: Processar Arquivos organizados em FAT16
;           e exibir CAT dos mesmos
; nasm -f elf64 gordo.asm ; ld gordo.o -o gordo.x

%define _exit   60
%define _write  1
%define _open   2
%define _read   0

section .data
    
    strOla  : db "Testi", 10, 0
    strOlaL : equ $-strOla


section .bss


section .text
    global _start

_start:
  
  mov rax,  _open


  mov rax,  _write
  mov rdi,  1
  lea rsi,  [strOla]
  mov rdx,  strOlaL
  syscall

_end:
  mov rax,  _exit
  mov rdi,  0
  syscall
