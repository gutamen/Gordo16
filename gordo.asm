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
	
	jumpLine : db 10, 0 
	
	


section .bss
    
    arquivo : resq 1
    argv    : resq 1
    argc    : resq 1
  

    disassemble       : resb 3  ; offset 0
    OEMIdentifier     : resb 8  ; offset 3
    bytesPerSector    : resb 2  ; offset 11
    sectorsPerCluster : resb 1  ; offset 13
    reservedSectors   : resb 2  ; offset 14
    FATNumber         : resb 1  ; offset 16
    directoryEntries  : resb 2  ; offset 17
    totalSectors      : resb 2  ; offset 19
    mediaDescriptor   : resb 1  ; offset 21
    sectorsPerFAT     : resb 2  ; offset 22
    sectorsPerTrack   : resb 2  ; offset 24
    headsOfStorage    : resb 2  ; offset 26
    hiddenSectors     : resb 4  ; offset 28
    largeTotalSectors : resb 4  ; offset 32

    rootDirectoryInit : resq 1  ; posição no arquivo
    dataClustersInit  : resq 1  ; posição dos dados
    firstFATTable     : resq 1  ; posição da primeira FAT
    readNow	          : resq 1  ; qual arquivo está sendo lido
	stackPointerRead  : resq 1  ; salvar onde estava a pilha no começo da leitura do diretório
	totalEntrances	  : resq 1  ; entradas no diretório lido
	
	
	searcher		  : resb 128; leitor do terminal
	
section .text

    global _start

_start:
  
  mov r8, [rsp]
  mov [argv], r8
  cmp QWORD[argv], 2        ; Verifica a quantidade de argumentos
  jne _argError
  
  mov r8, rsp
  add r8, 16
  mov r9, [r8]
  mov [argc], r9              ; Salvando endereço do argumento em variável


  mov rax, _open
  mov rdi, [argc]
  mov rsi, readwrite
  mov rdx, userWR
  syscall

  mov [arquivo], rax                   ; Salvar ponteiro do arquivo
  cmp rax, 0                           ; Verifica se o arquivo foi aberto
  jl _arqError

  mov rax, _read
  mov rdi, [arquivo]
  lea rsi, [disassemble]
  mov rdx, 3
  syscall

  mov rax, _read
  mov rdi, [arquivo]
  lea rsi, [OEMIdentifier]
  mov rdx, 8
  syscall

  mov rax, _read
  mov rdi, [arquivo]
  lea rsi, [bytesPerSector]
  mov rdx, 2
  syscall 

  mov rax, _read
  mov rdi, [arquivo]
  lea rsi, [sectorsPerCluster]
  mov rdx, 1
  syscall
    
  mov rax, _read
  mov rdi, [arquivo]
  lea rsi, [reservedSectors]
  mov rdx, 2
  syscall

  mov rax, _read
  mov rdi, [arquivo]
  lea rsi, [FATNumber]
  mov rdx, 1
  syscall

  mov rax, _read
  mov rdi, [arquivo]
  lea rsi, [directoryEntries]
  mov rdx, 2
  syscall

  mov rax, _read
  mov rdi, [arquivo]
  lea rsi, [totalSectors]
  mov rdx, 2
  syscall

  mov rax, _read
  mov rdi, [arquivo]
  lea rsi, [mediaDescriptor]
  mov rdx, 1
  syscall

  mov rax, _read
  mov rdi, [arquivo]
  lea rsi, [sectorsPerFAT]
  mov rdx, 2
  syscall

  mov rax, _read
  mov rdi, [arquivo]
  lea rsi, [sectorsPerTrack]
  mov rdx, 2
  syscall

  mov rax, _read
  mov rdi, [arquivo]
  lea rsi, [headsOfStorage]
  mov rdx, 2
  syscall

  mov rax, _read
  mov rdi, [arquivo]
  lea rsi, [hiddenSectors]
  mov rdx, 4
  syscall

  mov rax, _read
  mov rdi, [arquivo]
  lea rsi, [largeTotalSectors]
  mov rdx, 4
  syscall


  xor rax, rax
  xor rbx, rbx
  mov ax, [bytesPerSector]
  mov bx, [reservedSectors]       ; reservados para boot record
  imul rbx, rax

  xor r8, r8
  xor r9, r9
  mov r8b, [FATNumber]
  mov r9w, [sectorsPerFAT]
  imul r8, r9                     ; reservados pela FAT
  imul r8, rax

  add r8, rbx
  mov [rootDirectoryInit], r8

  xor rdx, rdx
  xor rax, rax
  mov ax, [directoryEntries]
  imul rax, 32
  xor r15, r15
  mov r15w, [bytesPerSector]
  div r15
  xor r14, r14
  mov r14, rdx
  xor rax, rax
  mov ax, [directoryEntries]
  imul rax, 32
  mov rcx, r14
  
  jecxz setorSemResto
    xor rbx, rbx
    mov bx, [bytesPerSector]
    add rax, rbx


  setorSemResto:
  add rax, [rootDirectoryInit]
  mov [dataClustersInit], rax

  xor rax, rax
  xor rdx, rdx
  mov ax, [bytesPerSector]
  mov bx, [reservedSectors]
  
  imul rax, rbx
  mov [firstFATTable], rax

  mov rax, [rootDirectoryInit]
  mov [readNow], rax

_readHead: 
  mov [stackPointerRead], rsp
  xor r15, r15
  xor r14, r14
  xor r13, r13
_initRead:

  mov rax, _seek
  mov rdi, [arquivo]
  mov rsi, [readNow]
  add rsi, r15
  xor rdx, rdx
  syscall
  
  add r15, 32

  sub rsp, 32
  mov rax, _read
  mov rdi, [arquivo]
  mov rsi, rsp
  mov rdx, 32

  syscall

  inc r13
  
  cmp byte[rsp], 0xe5
  je naoExiste
    cmp byte[rsp + 11], 0x0f
    jne noLongFile
      naoExiste:
        add rsp, 32
        jmp _initRead
    noLongFile:
      inc r14
	  cmp r13w, WORD[directoryEntries]
		je fimLeitura
	  xor r10, r10
	  cmp r10b, BYTE[rsp]
		je fimLeituraComRedimensionamento
      jmp _initRead

fimLeituraComRedimensionamento:
	add rsp, 32
	dec r14
fimLeitura:
	mov [totalEntrances], r14
	xor r14, r14
	xor r15, r15
	mov r15, [stackPointerRead]
	sub r15, 32
directoryPrint:
	cmp r14, [totalEntrances]
	je printEnd
	
	mov rax, _write
	mov rdi, 1
	mov rsi, r15
	mov rdx, 11
	syscall
	
	mov rax, _write
	mov rdi, 1
	mov rsi, jumpLine
	mov rdx, 1
	syscall
	sub r15, 32
	inc r14
	jmp directoryPrint
printEnd:


preLecture:
	xor r15, r15
	
functionLecture:
	
	mov rax, _read
	mov rdi, 0
	lea rsi, [searcher + r15]
	;add rsi, r15
	
	mov rdx, 1
	syscall

	cmp BYTE[searcher + r15], 0x0a
	

	inc r15
	jmp functionLecture
	
caseCommands:






_stop:
  mov rax, _close
  mov rdi, [arquivo]
  syscall

_end:
  mov rax, _exit
  mov rdi, 0
  syscall

_arqError:

  mov rax, _write
  mov rdi, 1
  lea rsi, [arqErrorS] 
  mov rdx, arqErrorSL
  syscall
  jmp _end


_argError:
  
  mov rax, _write
  mov rdi, 1
  lea rsi, [argErrorS]
  mov rdx, argErrorSL
  syscall
  jmp _end


