/**********************************************
        CS515  Compilers  
        Project1
        Spring  2016
**********************************************/

#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include "symtab.h"

#define HASH_TABLE_SIZE 347

/*  --- STATIC VARIABLES AND FUNCTIONS --- */
static 
SymTabEntry **HashTable;

static
int hash(char *name) {
  int i;
  int hashValue = 1;
  
  for (i=0; i < strlen(name); i++) {
    hashValue = (hashValue * name[i]) % HASH_TABLE_SIZE;
  }

  return hashValue;
}


void
InitSymbolTable() {
  int i;
  int dummy;

  HashTable = (SymTabEntry **) malloc (sizeof(SymTabEntry *) * HASH_TABLE_SIZE);
  for (i=0; i < HASH_TABLE_SIZE; i++)
    HashTable[i] = NULL;
}


/* Returns pointer to symbol table entry, if entry is found */
/* Otherwise, NULL is returned */
SymTabEntry * 
lookup(char *name) {
  int currentIndex;
  int visitedSlots = 0;
  
  currentIndex = hash(name);
  while (HashTable[currentIndex] != NULL && visitedSlots < HASH_TABLE_SIZE) {
    if (!strcmp(HashTable[currentIndex]->name, name) )
      return HashTable[currentIndex];
    currentIndex = (currentIndex + 1) % HASH_TABLE_SIZE; 
    visitedSlots++;
  }
  return NULL;
}


void 
insert(char *name,int offset,int rowDim,int colDim) {
  int currentIndex;
  int visitedSlots = 0;

  currentIndex = hash(name);
  while (HashTable[currentIndex] != NULL && visitedSlots < HASH_TABLE_SIZE) {
    if (!strcmp(HashTable[currentIndex]->name, name) ) 
      printf("*** WARNING *** in function \"insert\": %s has already an entry\n", name);
    currentIndex = (currentIndex + 1) % HASH_TABLE_SIZE; 
    visitedSlots++;
  }
  if (visitedSlots == HASH_TABLE_SIZE) {
    printf("*** ERROR *** in function \"insert\": No more space for entry %s\n", name);
    return;
  }
  
  HashTable[currentIndex] = (SymTabEntry *) malloc (sizeof(SymTabEntry));
  HashTable[currentIndex]->name = (char *) malloc (strlen(name)+1);
  strcpy(HashTable[currentIndex]->name, name);
  HashTable[currentIndex]->offset = offset; //Offset of the identifier is stored;
  HashTable[currentIndex]->rowDim = rowDim; //rowDimension of the Array;
  HashTable[currentIndex]->colDim = colDim; //colDimension of the Array;
}


void 
PrintSymbolTable() {
  int i;
  
  printf("\n --- Symbol Table ---------------\n\n");
  for (i=0; i < HASH_TABLE_SIZE; i++) {
    if (HashTable[i] != NULL) {
      printf("\"%s\"", HashTable[i]->name); 
      printf("\t\"%d\" ",HashTable[i]->offset);
      printf("\t%d",HashTable[i]->rowDim);
      printf("\t%d\n",HashTable[i]->colDim);
    }
  }
  printf("\n --------------------------------\n\n");
}


