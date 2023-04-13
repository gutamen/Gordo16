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
%define _quit	  0x54495551

section .data
    
    argErrorS : db "Erro: Quantidade de Parâmetros incorreta", 10, 0
    argErrorSL: equ $-argErrorS 

    arqErrorS : db "Erro: Arquivo não foi aberto", 10, 0
    arqErrorSL: equ $-arqErrorS
	
	argErrorC : db "Erro: Comando incorreto", 10, 0
    argErrorCL: equ $-argErrorC
	
	argErrorCAT: db "Erro: não é possível fazer CAT neste tipo", 10, 0
    argErrorCATL: equ $-argErrorCAT
	
	argErrorDIR: db "Erro: não é possível abrir diretório", 10, 0
    argErrorDIRL: equ $-argErrorDIR

	promptDialog: db 10, 10, "Pressione [Enter] para continuar", 10, 0
    promptDialogL: equ $-promptDialog
	
    strOla  : db "Testi", 10, 0
    strOlaL : equ $-strOla
	
	jumpLine : db 10, 0 
	
	clearTerm   : db   27,"[H",27,"[2J"    ; <ESC> [H <ESC> [2J
	clearTermL : equ  $-clearTerm         ; tamanho da string para limpar terminal
	
	dotChar : db 0x2e, 0

	tabChar	: db 0x09, 0
	
	
	; moldura para print
	firstLine	: db "|", 0x09, "Nome", 0x09, 0x09, "|", 0x20, "Tipo", 0x20, "|", 0x09, "Tamanho", 0x09, 0x09, "|", 10 ,0 
	firstLineL	: equ $-firstLine
	
	initLine		: db "|", 0x09, 0
	initLineL	: equ $-initLine
	
	finishLine		: db "|", 0x0a, 0
	finishLineL	: equ $-finishLine
	
	typeSpace	: db 0x09,"|", 0x20, 0
	typeSpaceL	: equ $-typeSpace
	
	typeDir		: db "DIR", 0x20, 0
	typeArch	: db "ARCH", 0
	typeSize	: db 4
	
	typeFinish		: db 0x20, "|", 0x09, 0
	typeFinishL	: equ $-typeFinish
	
	dirSizeChar	: db "-------", 0x09, 0x09, "|", 10, 0
	dirSizeCharL	: equ $-dirSizeChar
	
	archFinish		: db 0x09, "|", 10, 0
	archFinishL	: equ $-archFinish
	
	beep			: db 0x07, 0

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
	clusterSize	      : resq 1  ; quantos bytes tem por cluster
	clusterCount	  : resq 1
	clustersPointer	  : resq 1
	bus				  : resb 1
	fileSize		  : resq 1
	suClusterPointer  : resq 1
	
	commandType		  : resb 1
	longI             : resq 1

	searcher		  	: resb 128; leitor do terminal
	tempSearcher	: resb 128; reorganizar string lida
	
	sizedChars		: resb 32
section .text

    global _start

_start:
	
	mov rax, _write
	mov rdi, 1
	lea rsi, [beep]
	mov rdx, 1
	syscall
	
	mov rax, _write
	mov rdi, 1
	lea rsi, [clearTerm]		; "limpar" terminal no começo do programa
	mov rdx, clearTermL
	syscall
  
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


	xor rdx, rdx
	xor rax, rax
	xor rbx, rbx
	mov ax, [bytesPerSector]
	mov bx, [reservedSectors]       ; reservados para boot record
	mul rbx
	mov rbx, rax
	
	xor rax, rax
	xor r9, r9
	mov al, [FATNumber]
	mov r9w, [sectorsPerFAT]
	mul r9
	mov r9w, [bytesPerSector]		; reservados pela FAT
	mul	r9

  add rax, rbx
  mov [rootDirectoryInit], rax

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

  xor rdx, rdx
  xor rax, rax
  xor rbx, rbx
  mov al, [sectorsPerCluster]
  mov bx, [bytesPerSector]
  mul rbx
  mov [clusterSize], rax

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
  
  cmp BYTE[rsp], 0xe5
  je naoExiste
    cmp BYTE[rsp + 11], 0x0f
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

printDir:	

	mov rax, _write
	mov rdi, 1
	lea rsi, [firstLine]
	mov rdx, firstLineL
	syscall
	
	xor r14, r14
	xor r15, r15
	xor r13, r13
	xor r11, r11
	mov r15, [stackPointerRead]
	sub r15, 32
directoryPrint:
	cmp r14, [totalEntrances]
	je printEnd
	
	mov rax, _write
	mov rdi, 1
	lea rsi, [initLine]
	mov rdx, initLineL
	syscall
	
	mov r13, r15
	xor rbx, rbx
	printNoSpace:
		cmp BYTE[r13], 0x20
		je spaceMoment
		mov rax, _write
		mov rdi, 1
		mov rsi,  r13
		mov rdx, 1
		syscall
	
		inc rbx
		inc r13
		jmp printNoSpace
	spaceMoment:
		mov r13, r15
		add r13, 8
		mov r11, 8
		cmp BYTE[r13], 0x20
		je endExtension
		
		mov rax, _write
		mov rdi, 1
		lea rsi,  [dotChar]
		mov rdx, 1
		syscall
	
		
	printExtension:
		cmp BYTE[r13], 0x20
		je endExtension
		cmp r11, 11
		je endExtension
		
		mov rax, _write
		mov rdi, 1
		mov rsi, r13
		mov rdx, 1
		syscall
		
		inc rbx
		inc r11
		inc r13
		jmp printExtension
	endExtension:
	
	cmp rbx, 6
	jle oneTab
	backTab:
	
	mov rax, _write
	mov rdi, 1
	lea rsi, [typeSpace]
	mov rdx, typeSpaceL
	syscall
	
	mov r13, r15
	add r13, 11
	cmp BYTE[r13], 0x10
	je printDirType
	cmp BYTE[r13], 0x20
	je printArchType
	returnPrintType:
	
	
	
	
	
	sub r15, 32
	inc r14
	jmp directoryPrint
	
	printDirType:
		mov rax, _write
		mov rdi, 1
		lea rsi, [typeDir]
		mov dl, [typeSize]
		syscall
		
		mov rax, _write
		mov rdi, 1
		lea rsi, [typeFinish]
		mov rdx, typeFinishL
		syscall
		
		mov rax, _write
		mov rdi, 1
		lea rsi, [dirSizeChar]
		mov rdx, dirSizeCharL
		syscall
		
		jmp returnPrintType
	
	printArchType:
		mov rax, _write
		mov rdi, 1
		lea rsi, [typeArch]
		mov dl, [typeSize]
		syscall
		
		mov rax, _write
		mov rdi, 1
		lea rsi, [typeFinish]
		mov rdx, typeFinishL
		syscall
		
		mov r13, r15
		mov eax, [r13 + 28]
		xor r11, r11
		and QWORD[sizedChars], 0
		and QWORD[sizedChars + 8], 0
		and QWORD[sizedChars + 16], 0
		and QWORD[sizedChars + 24], 0
		divChar:
			xor rdx, rdx
			cmp rax, 10
			jle endDiv
			mov r13, 10
			div r13
			add rdx, 48
			mov [sizedChars + r11], dl
			inc r11
			jmp divChar
			
		endDiv:
			inc r11
			add rax, 48
			mov [sizedChars + r11], al

		mov r13, r11
		mov rbx, r11
		printSizedChars:
			mov rax, _write
			mov rdi, 1
			lea rsi, [sizedChars + r13]
			mov rdx, 1
			syscall
			dec r13
			cmp r13d, -1
			jne printSizedChars
			
		cmp rbx, 9	
		jle oneTab2
		backTab2:
		
		mov rax, _write
		mov rdi, 1
		lea rsi, [archFinish]
		mov rdx, archFinishL
		syscall
			
		jmp returnPrintType
		
	oneTab:
		mov rax, _write
		mov rdi, 1
		lea rsi, [tabChar]
		mov dl, 1
		syscall
		jmp backTab
		
	oneTab2:
		mov rax, _write
		mov rdi, 1
		lea rsi, [tabChar]
		mov dl, 1
		syscall
		jmp backTab2
		
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
		
	caseQUIT:
		xor r12, r12
		mov r12d, [searcher]
		and r12d, _quit
		cmp r12d, _quit
		je _stop
		
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
			cmp r8, 0					;
			je ponto					;	teste para ponto 
			preTestPonto:			;	e ponto + ponto
			cmp bl, 0x2e
			je posPonto
			cmp bl, 0x0a
			je posPonto
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
			cmp BYTE[r13 + r11], 0
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
			
		ponto:													;
			cmp bl, 0x2e									;
			jne preTestPonto								;
			cmp byte[r13 + 1], 0x2e					; tramento especial 
			je pontoPonto									; para condições de 
			inc r8												; navegação em arquivo
			mov BYTE[tempSearcher], 0x2e		;
			jmp moreSpacePoint							;
																	;
		pontoPonto:											;
			add r8, 2											;
			mov BYTE[tempSearcher], 0x2e		;
			mov BYTE[tempSearcher + 1], 0x2e	;
			jmp moreSpacePoint							;
	
	preForSearch:
		and QWORD[longI], 0
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
	jmp cleanParams
	
errorCommand:
	mov rax, _write
	mov rdi, 1
	lea rsi, [argErrorC]
	mov rdx, argErrorCL
	syscall
	mov BYTE[commandType], 0
	jmp cleanParams
	
cleanParams:
	xor rcx, rcx
	mov rcx, 16
	forClear:
	dec rcx
	mov QWORD[searcher + rcx *  8], 0
	mov QWORD[tempSearcher + rcx * 8], 0
	jecxz fimClear
	jmp forClear
	fimClear:
	cmp BYTE[commandType], 0x02
	je lsCommand
	cmp BYTE[commandType], 0x01
	je catCommand
	cmp BYTE[commandType], 0x03
	je cdCommand
	
	jmp preLecture
	
lsCommand:

	mov rax, _write
	mov rdi, 1
	lea rsi, [clearTerm]
	mov rdx, clearTermL
	syscall
	
	mov BYTE[commandType], 0
	jmp printDir
	
	
catCommand:
	
	mov rax, _write
	mov rdi, 1
	lea rsi, [clearTerm]
	mov rdx, clearTermL
	syscall
	

	mov r14, [longI]
	xor rdx, rdx
	xor rax, rax
	inc r14
	imul r14, 32
	mov r15, [stackPointerRead]
	sub r15, r14
	xor r14, r14
	cmp BYTE[r15 + 11], 0x20
	jne errorFormat
	mov r14w, [r15 + 26]
	xor r13, r13
	mov QWORD[fileSize], 0
	mov r13d, [r15 + 28]
	mov [fileSize], r13
	
	xor rax, rax
	xor rdx, rdx
	
	mov rax, r13
	mov rbx, [clusterSize]
	div rbx
	
	mov [clusterCount], rax
	cmp rdx, 0
	je noResto
		inc QWORD[clusterCount]
	noResto:
	mov rax, [clusterCount]	
	inc rax
	shl rax, 1
	sub rsp, rax
	mov [clustersPointer], rsp
	
	mov [rsp], r14w
	and QWORD[longI], 0x0
	
	forClusters:
		mov rax, [firstFATTable]
		xor rdx, rdx
		mov r14, QWORD[longI]
		mov bx, [rsp + r14 * 2]
		cmp bx, 0xFFF8
		jae endClustrers
			shl rbx, 1
			add rax, rbx
			inc QWORD[longI]
			mov r14, [longI]

			mov rsi, rax
			mov rax, _seek
			mov rdi, [arquivo]
			xor rdx, rdx
			syscall
		
			mov rax, _read
			mov rdi, [arquivo]
			lea rsi, [rsp + r14 * 2]
			mov rdx, 2
			syscall

			
		jmp forClusters
	endClustrers:
	
	and QWORD[longI], 0
	xor r13, r13
	xor r12, r12
	
	printArchive:
		mov r14, QWORD[longI]
		xor rax, rax
		mov ax, [rsp + r14 * 2]
		cmp ax, 0xfff8
		jae printFinalize
		sub rax, 2
		xor rdx, rdx
		xor rbx, rbx
		mul QWORD[clusterSize]
		add rax, [dataClustersInit]
		
		inc QWORD[longI]
		
		mov rsi, rax
		mov rax, _seek
		mov rdi, [arquivo]
		xor rdx, rdx
		syscall
		
		xor r12, r12
		xor r15, r15
		readerGuest:
			cmp r12, QWORD[clusterSize]
			je readerEnd
			
			mov rax, _read
			mov rdi, [arquivo]
			lea rsi, [bus]
			mov rdx, 1
			syscall
			
			mov rax, _write
			mov rdi, 1
			lea rsi, [bus]
			mov rdx, 1
			syscall
			
			inc r12
			inc r13
			cmp r13, [fileSize]
				je readerEnd
			jmp readerGuest
		readerEnd:
		
		
	jmp printArchive
	
	errorFormat:
		mov rax, _write
		mov rdi, 1
		lea rsi, [argErrorCAT] 
		mov rdx, argErrorCATL
		syscall
		mov BYTE[commandType], 0
		jmp printDir
		
	printFinalize:
		add rsp, 2
		shl QWORD[clusterCount], 1
		add rsp, [clusterCount]
		mov QWORD[clusterCount], 0
		and BYTE[bus], 0
		mov QWORD[clustersPointer], 0
		mov BYTE[commandType], 0
		
		mov rax, _write
		mov rdi, 1
		lea rsi, [promptDialog]
		mov rdx, promptDialogL
		syscall
		
		printConfirm:
			mov rax, _read
			mov rdi, 0
			lea rsi, [bus]
			mov rdx, 1
			syscall
			
			cmp BYTE[bus], 0x0a
			jne printConfirm
		
		mov rax, _write
		mov rdi, 1
		lea rsi, [clearTerm]
		mov rdx, clearTermL
		syscall
		
		jmp printDir


cdCommand:
    mov r14, [longI]
	xor rdx, rdx
	xor rax, rax
	inc r14
	imul r14, 32
	mov r15, [stackPointerRead]
	sub r15, r14
	xor r14, r14
	cmp BYTE[r15 + 11], 0x10
	jne errorDirType
	mov r14w, [r15 + 26]
	cmp r14, 0
	je rootDirJMP
	
	mov rax, r14
	sub rax, 2
	xor rdx, rdx
	mul QWORD[clusterSize]
	add rax, [dataClustersInit]
	mov [readNow], rax
	
	cmp QWORD[suClusterPointer], 0
	jne withClusters
		mov rsp, [stackPointerRead]
	goBack:
	
	mov r13, r14
	
	shl r13, 1
	
	add r13, [firstFATTable]
	
	mov rax, _seek
	mov rdi, [arquivo]
	mov rsi, r13
	xor rdx, rdx
	syscall
	
	sub rsp, 2
	mov rax, _read
	mov rdi, [arquivo]
	mov rsi, rsp
	mov rdx, 2
	syscall
	
	mov [suClusterPointer], rsp
	and QWORD[longI], 0
	jmp cdWithMoreClusters
	
	withClusters:
		add QWORD[suClusterPointer], 2
		mov rsp, [suClusterPointer]
	jmp goBack
	
	stackCorrection:
		mov rax, [suClusterPointer]
		and QWORD[suClusterPointer], 0
		mov [stackPointerRead], rax

	rootDirJMP:
		mov rax, [rootDirectoryInit]
		mov [readNow], rax
		mov rsp, [stackPointerRead]
		
		cmp QWORD[suClusterPointer], 0
		jne stackCorrection
		
		mov rax, _write
		mov rdi, 1
		lea rsi, [clearTerm]
		mov rdx, clearTermL
		syscall
		
		jmp _readHead
		
	errorDirType:
		mov rax, _write
		mov rdi, 1
		lea rsi, [argErrorDIR] 
		mov rdx, argErrorDIRL
		syscall 
		jmp printDir
	
	cdWithMoreClusters:
		xor rbx, rbx
		mov bx, [rsp]
		cmp bx, 0xfff8
		jae _readHead2
			shl rbx, 1
			add rbx, [firstFATTable]
			mov rax, _seek
			mov rdi, [arquivo]
			mov rsi, rbx
			xor rdx, rdx
			syscall
				
			sub rsp, 2
			mov rax, _read
			mov rdi, [arquivo]
			mov rsi, [rsp]
			mov rdx, 2
			syscall
		jmp cdWithMoreClusters
	
	_readHead2: 
		
	  mov [stackPointerRead], rsp
	  xor r15, r15
	  xor r14, r14
	  xor r13, r13
	  xor r12, r12
	_initRead2:

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

	  
	  
	  cmp BYTE[rsp], 0xe5
	  je naoExiste2
		cmp BYTE[rsp + 11], 0x0f
		jne noLongFile2
		  naoExiste2:
			add rsp, 32
			jmp _initRead2
		noLongFile2:
		  inc r14
	
		  xor r10, r10
		  cmp r10b, BYTE[rsp]
			je fimLeituraComRedimensionamento2
		  cmp QWORD[clusterSize], r15
		  je updateReadNow
		  jmp _initRead2

	updateReadNow:
		mov r11, [suClusterPointer]
		sub r11, r12
		add r12, 2
		mov ax, [r11]
		cmp ax, 0xfff8
		jae fimLeitura2
		sub rax, 2
		xor rdx, rdx
		mul QWORD[clusterSize]
		add rax, [dataClustersInit]
		mov [readNow], rax
		xor r15, r15
		jmp _initRead2
		
	fimLeituraComRedimensionamento2:
		add rsp, 32
		dec r14
	fimLeitura2:
		mov [totalEntrances], r14
		
		mov rax, _write
		mov rdi, 1
		lea rsi, [clearTerm]
		mov rdx, clearTermL
		syscall
		
		jmp printDir