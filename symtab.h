/**********************************************
        CS515  Compilers  
        Project1
        Spring  2016
**********************************************/

#ifndef SYMTAB_H
#define SYMTAB_H

#include <string.h>

/* The symbol table implementation uses a single hash     */
/* function. Starting from the hashed position, entries   */
/* are searched in increasing index order until a         */
/* matching entry is found, or an empty entry is reached. */


typedef struct {
  char *name;
  int offset;
  int rowDim;
  int colDim;
  /* need to add stuff here */
} SymTabEntry;

extern
void InitSymbolTable();

extern
SymTabEntry * lookup(char *name);

extern
void insert(char *name,int offset,int rowDim,int colDim);

extern
void PrintSymbolTable();


#endif
