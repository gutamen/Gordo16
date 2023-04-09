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
%define _cat	  0x20544143
%define _ls		  0x0000534c
%define _cd		  0x00204443

section .data
    
    argErrorS : db "Erro: Quantidade de Parâmetros incorreta", 10, 0
    argErrorSL: equ $-argErrorS 

    arqErrorS : db "Erro: Arquivo não foi aberto", 10, 0
    arqErrorSL: equ $-arqErrorS
	
	argErrorC : db "Erro: Comando incorreto", 10, 0
    argErrorCL: equ $-argErrorC

    strOla  : db "Testi", 10, 0
    strOlaL : equ $-strOla
	
	jumpLine : db 10, 0 
	
	clearTerm  : db   27,"[H",27,"[2J"    ; <ESC> [H <ESC> [2J
	clearTermL : equ  $-clearTerm         ; tamanho da string para limpar terminal
	
	


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
	
	commandType		  : resb 1
	longI             : resq 1
	
	
	searcher		  : resb 128; leitor do terminal
	tempSearcher	  : resb 128; reorganizar string lida
	
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

printDir:
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
	mov rdx, 1
	syscall

	cmp BYTE[searcher + r15], 0x0a
		je caseCommands

	inc r15
	jmp functionLecture
	
caseCommands:

	caseCAT:
		xor r12, r12
		mov r12d, [searcher]
		mov BYTE[commandType], 0x01
		xor r13, r13
		lea r13, [searcher + 4]
		and r12d, _cat
		cmp r12d, _cat
		je verifyParameter

	caseLS:
		xor r12, r12
		mov r12d, [searcher]
		mov BYTE[commandType], 0x02
		xor r13, r13
		lea r13, [searcher + 3]
		and r12d, _ls
		cmp r12d, _ls
		je cleanParams
		
	caseCD:
		xor r12, r12
		mov r12d, [searcher]
		mov BYTE[commandType], 0x03
		xor r13, r13
		lea r13, [searcher + 3]
		and r12d, _cd
		cmp r12d, _cd
		je verifyParameter
		
	caseERRO:
		jmp errorCommand
		

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


verifyParameter:
	and QWORD[longI], 0
	xor r15, r15
	mov r15, [stackPointerRead]
	sub r15, 32
	xor r11, r11
	xor r8, r8

		forCompare:
			xor rbx, rbx
			mov bl, BYTE[r13 + r11]
			cmp r8, 0				;
			je ponto				;	teste para ponto 
			preTestPonto:			;	e ponto + ponto
			cmp bl, 0x2e
			je posPonto
			cmp bl, 0x0a
			je forSearch
			mov BYTE[tempSearcher + r8], bl
			inc r11
			inc r8
			cmp r11, 8
			je posPonto
			jmp forCompare
			
		moreSpace:
			mov BYTE[tempSearcher + r8], 0x20
			inc r8
			cmp r8, 8
			jne moreSpace
			
		posPonto:
			cmp r8, 8 
			jl moreSpace
			
			inc r11
			
		continue:
			cmp BYTE[r13 + r11], 0x0a
			je moreSpacePoint
			
			xor rbx, rbx
			mov bl, BYTE[r13 + r11]
			mov BYTE[tempSearcher + r8], bl
			inc r8
			inc r11
			cmp r8, 11
			jl continue
			
		moreSpacePoint:
			cmp r8, 11
			jge preForSearch
			mov BYTE[tempSearcher + r8], 0x20
			inc r8
			jmp moreSpacePoint
			
		ponto:											;
			cmp bl, 0x2e								;
			jne preTestPonto							;
			cmp byte[r13 + 1], 0x2e						; tramento especial 
			je pontoPonto								; para condições de 
			inc r8										; navegação em arquivo
			mov BYTE[tempSearcher], 0x2e				;
			jmp posPonto								;
			
		pontoPonto:										;
			add r8, 2									;
			mov BYTE[tempSearcher], 0x2e				;
			mov BYTE[tempSearcher + 1], 0x2e			;
			jmp posPonto								;
	
	preForSearch:
		mov r14, [totalEntrances]
		xor rcx, rcx
		xor rdx, rdx
		mov rcx, [tempSearcher]
		mov edx, [tempSearcher + 8]
		xor rbx, rbx
	forSearch:
		cmp QWORD[longI], r14
		je endSearch
		mov ebx, [r15 + 8]
		and ebx, 0x00ffffff
		cmp QWORD[r15], rcx
		je firstEqual
		inc QWORD[longI]
		sub r15, 32
		jmp forSearch
		
		firstEqual:
			cmp ebx, edx
			je endSearch
			inc QWORD[longI]
			sub r15, 32
			jmp forSearch
	
endSearch:
	cmp r14, QWORD[longI]
	je errorCommand
	cmp BYTE[commandType], 0x01
	je catCommand
	
errorCommand:
	mov rax, _write
	mov rdi, 1
	lea rsi, [argErrorC]
	mov rdx, argErrorCL
	syscall
	jmp cleanParams
	
cleanParams:
	xor rcx, rcx
	mov rcx, 16
	forClear:
	dec rcx
	and QWORD[searcher + rcx * 8], 0
	and QWORD[tempSearcher + rcx * 8], 0
	jecxz forClear
	cmp BYTE[commandType], 0x02
	je lsCommand
	jmp preLecture
	
lsCommand:

	mov rax, _write
	mov rdi, 1
	lea rsi, [clearTerm]
	mov rdx, clearTermL
	syscall
	
	and BYTE[commandType], 0x00
	jmp printDir
	
	
catCommand: