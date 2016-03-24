/**********************************************
        CS515  Compiler 
        Project 1
        Spring 2016
**********************************************/

#include <stdio.h>
#include <stdlib.h>
#include "attr.h" 

List* allocate(char *str){

  List* list = (List*)malloc(sizeof(List));
  list->str = str;
  list->next = NULL;
  
  return list;
  
}