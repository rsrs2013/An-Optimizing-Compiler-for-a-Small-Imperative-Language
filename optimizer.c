#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include "optimizer.h"


#define TABLE_SIZE 347


/*  --- STATIC VARIABLES AND FUNCTIONS --- */
static 
OptimizeTabEntry **Table;

static
int calculateHash(char *name) {
  int i;
  int hashValue = 1;
  for (i=0; i < strlen(name); i++) {
    //printf("%c",name[i]);
    hashValue = (hashValue * name[i]) % TABLE_SIZE;
  }
  
  return hashValue;
}


void InitOptimizeTable(){

   int i;
   int dummy;
   
   Table = (OptimizeTabEntry **)malloc(sizeof(OptimizeTabEntry*) * TABLE_SIZE);
   for (i=0; i < TABLE_SIZE; i++)
       Table[i] = NULL;
  
}


OptimizeTabEntry * lookupOPT(char *name){

       int currentIndex=0;
       int visitedSlots = 0;
       currentIndex = calculateHash(name);
       
       while (Table[currentIndex] != NULL && visitedSlots < TABLE_SIZE) {
           if (!strcmp(Table[currentIndex]->name, name) )
           return Table[currentIndex];
           currentIndex = (currentIndex + 1) % TABLE_SIZE; 
           visitedSlots++;
       }
       return NULL;
}

void insertOPT(char *name,int registerNumber){

   
    int currentIndex;
    int visitedSlots = 0;

  currentIndex = calculateHash(name);
  while (Table[currentIndex] != NULL && visitedSlots < TABLE_SIZE) {
    if (!strcmp(Table[currentIndex]->name, name) ) 
      printf("*** WARNING *** in function \"insert\": %s has already an entry\n", name);
      currentIndex = (currentIndex + 1) % TABLE_SIZE; 
      visitedSlots++;
  }
  if (visitedSlots == TABLE_SIZE) {
    printf("*** ERROR *** in function \"insert\": No more space for entry %s\n", name);
    return;
  }
  
  Table[currentIndex] = (OptimizeTabEntry *) malloc (sizeof(OptimizeTabEntry));
  Table[currentIndex]->name = (char *) malloc (strlen(name)+1);
  strcpy(Table[currentIndex]->name, name);
  Table[currentIndex]->value = registerNumber;
  
}

void deleteOptTab(){
   int i;
   for (i=0; i < TABLE_SIZE; i++)
       {
           if(Table[i]){
            
              free(Table[i]);
              Table[i] = NULL;
           
           }
       }
       
}



void PrintOptimizeTable()
{
   int i;
  
  printf("\n --- Optimizer Hash Table ---------------\n\n");
  for (i=0; i < TABLE_SIZE; i++) {
    if (Table[i] != NULL) {
      printf("\"%s\"", Table[i]->name); 
      printf("\t\"%d\" \n",Table[i]->value);
      
    }
  }
  printf("\n --------------------------------\n\n");
}




