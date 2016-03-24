/**********************************************
        CS515  Compiler  
        Project 1
        Spring 2016
**********************************************/

#ifndef ATTR_H
#define ATTR_H

typedef union {int num; char *str;} tokentype;
typedef struct{int reg;} reginfo;

typedef struct List{
                char* str;
                struct List* next;
              }List;
              
typedef struct{
               List* head;
               List* tail;
               int count;
              }listOfIdentifiers;
              

typedef struct{
                int numberOfUnits; 
                int rowDim;
                int colDim;
                
              } typeInfo;     
 
 typedef struct{
                 int location;
                 
               }memInfo;                     
 
 typedef struct{
                   int reg;
                   int trueLabel;
                   int falseLabel;
                   int exitLabel;
               
               }labelInfo;
               
 typedef struct{
                   int initialIndex;
                   int finalIndex;
                   int iteratorOffset;
                   int forLabel;
                   int doLabel;
                   int exitLabel;
                   
               }ctrlExpInfo;              
 
              
 extern
 List* allocate(char *str);             

#endif

