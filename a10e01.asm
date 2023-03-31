; Aula 10 - Subprogramas
; arquivo: a10e01.asm
; objetivo: demonstrar chamada de procedimento
; nasm -f elf64 a10e01.asm ; ld a10e01.o -o a10e01.x

%define _exit  60
%define _write 1

section .data
    strOla  : db "You can't take the sky from me", 10, 0
    strOlaL : equ $-strOla

section .text
    global _start

_start:                 ; addr = 0x401000
                        ; RSP = 0x7fffffffe330
                        ; PUSH fim        
                        ; RIP = x401000
    call iboserenity    ; ADDR = ?
                        ; RSP = ?

fim:                 ; addr =  0x401005
    mov rax, _exit   
    mov rdi, 0
    syscall        

; imprimeBalladofSerenity()
iboserenity:            ; addr = 0x401011
    mov rax, _write 
    mov rdi, 1          ;RSP = 0x7fffffffe328
    lea rsi, [strOla]
    mov rdx, strOlaL
    syscall
lret:   
   ; POP 
    ret
