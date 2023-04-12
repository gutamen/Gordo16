# Gordo16
Trabalho de SO

Implementação de um leitor de imagem FAT16 desenvolvido em assembly.

Executa leituras em todos os diretórios acessíveis.
Exibe todos os bytes dos arquivos dentro de diretórios.

# Comandos
  *CD [nome_do_diretório]                 -> acessa o diretório selecionado
  *CAT [nome_do_arquvio_com_extensão]     -> imprime todos os bytes como caractere no terminal
  *LS                                     -> lista os arquivos do diretório atual

# Build and Run
Build -> nasm -f elf64 gordo.asm ; ld gordo.o -o gordo.x
Run   ->./gordo.x 


# Referência
  https://wiki.osdev.org/FAT
