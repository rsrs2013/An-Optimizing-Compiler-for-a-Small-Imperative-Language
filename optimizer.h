/* *********************** */
   /* OPTIMIZER*/
/* ************************ */   

#ifndef OPTIMIZER_H
#define OPTIMIZER_H

#include <string.h>

/* The hash table implementation uses a single hash     */
/* function. Starting from the hashed position, entries   */
/* are searched in increasing index order until a         */
/* matching entry is found, or an empty entry is reached. */


typedef struct {
  char *name;
  int value;

} OptimizeTabEntry;


extern
void InitOptimizeTable();

extern
OptimizeTabEntry * lookupOPT(char *name);

extern
void insertOPT(char *name,int registerNumber);

extern
void PrintOptimizeTable();

extern
void deleteOptTab();

extern
void initializeTable();



#endif