%{
#include <stdio.h>
#include "attr.h"
#include "instrutil.h"
int yylex();
void yyerror(char * s);
#include "symtab.h"
#include "optimizer.h"

FILE *outfile;
char *CommentBuffer;
extern int optimize_flag; 
 
%}

%union {tokentype token;
        reginfo reg; 
        listOfIdentifiers idList;
        typeInfo typeinfo;
        memInfo meminfo;
        labelInfo labelinfo;
        ctrlExpInfo ctrlexpinfo;
       }

%token PROG PERIOD VAR 
%token INT WRITELN THEN IF BEG END 
%token DO ARRAY OF UNTIL ELSE FOR
%token ASG EQ NEQ LT LEQ 
%token <token> ID ICONST 
%token <labelinfo> REPEAT

%type <reg> exp condexp lhs 
%type <idList> idlist
%type <typeinfo> type
%type <labelinfo> ifhead 
%type <ctrlexpinfo> ctrlexp

%start program

%nonassoc EQ NEQ LT LEQ GT GEQ 
%left '+' '-' 
%left '*' 

%nonassoc THEN
%nonassoc ELSE

%%
program : {emitComment("Assign STATIC_AREA_ADDRESS to register \"r0\"");
           emit(NOLABEL, LOADI, STATIC_AREA_ADDRESS, 0, EMPTY);} 
           PROG ID ';' block PERIOD { }
	;

block	: variables cmpdstmt { }
	;

variables: /* empty */
	| VAR vardcls { }
	;

vardcls	: vardcls vardcl ';' { }
	| vardcl ';' { }
	| error ';' { yyerror("***Error: illegal variable declaration\n");}  
	;

vardcl	: idlist ':' type {
                            int countOfVariables = $1.count;
                            int offset;
                            char *str;
                            List* node = $1.head;
                            
                            while(node != NULL){
                               
                               //Get the identifier from the node.str;
                               str = node->str;
                               
                               //Get the offset from the starting location of the memory;
                               
                               if(!($3.rowDim))
                               {
                                  offset = NextOffset($3.numberOfUnits);
                               
                               }
                               else{
                               
                                   if(!$3.colDim){
                                     //One dimensional Array
                                     
                                     offset = NextOffset($3.rowDim);
                                    
                                   }
                                   else
                                   {
                                      //Two-Dimensional Array, with column major.
                                      offset = NextOffset($3.colDim*$3.rowDim);
                               
                                   }
                               
                               }
                               
                               //insert the identifier into the symbol table;
                               insert(str,offset,$3.rowDim,$3.colDim);   
                               node = node->next;
                            }//End of While Loop
                            
                          }
	;

type	: INT 	{
                   $$.numberOfUnits = 1;
                   $$.rowDim = $$.colDim = 0;

                }
	| ARRAY '[' ICONST ']' OF INT	{
	                                   $$.numberOfUnits =  $3.num;
	                                   $$.rowDim = $3.num;
	                                   $$.colDim = 0;
	                                }	
        | ARRAY '[' ICONST ',' ICONST ']' OF INT {
                                                     $$.rowDim = $3.num;
                                                     $$.colDim = $5.num;
        
                                                  }
	;

idlist	: idlist ',' ID { 
                         
                            int count;
                            struct List* node = allocate($3.str);
                            $1.tail->next = node;
                            $1.tail = node;
                            count = $1.count + 1;
                            $$.head = $1.head;
                            $$.tail = $1.tail;
                            $$.count = count;
                            
                        }
        | ID		{
                        
                        struct List* node = allocate($1.str);
                        $$.head = node;
                        $$.tail = node;
                        $$.count = 1; 
                    }
	;

stmtlist : stmtlist ';' stmt { }
	| stmt { }
        | error { yyerror("***Error: ';' expected or illegal statement \n");}
	;

stmt    : ifstmt { }
	| fstmt { }
	| repeatstmt {}
	| astmt { }
	| writestmt { }
	| cmpdstmt { }
	;

cmpdstmt: BEG stmtlist END { }
	;

ifstmt :  ifhead THEN stmt {
                              emit($1.falseLabel,NOP,EMPTY,EMPTY,EMPTY);
                           }
        | ifhead THEN stmt ELSE {
                                  emit(NOLABEL,BR,$1.exitLabel,EMPTY,EMPTY);
                                  emit($1.falseLabel,NOP,EMPTY,EMPTY,EMPTY); 
                                   
                                } stmt {
                                         emit($1.exitLabel,NOP,EMPTY,EMPTY,EMPTY);
                                         
                                       }
    ;

ifhead : IF condexp {
                        int trueLabel,falseLabel,exitLabel;
                        $$.reg = $2.reg;
                        $$.trueLabel = NextLabel();
                        $$.falseLabel = NextLabel();
                        $$.exitLabel = NextLabel();
                        emitComment("Evaluate the boolean value of condexp and branch to respective label");
                        emit(NOLABEL,CBR,$2.reg,$$.trueLabel,$$.falseLabel);
                        emit($$.trueLabel,NOP,EMPTY,EMPTY,EMPTY);

                    }
        ;

writestmt: WRITELN '(' exp ')' {
                                int offset = NextOffset(1);
                                emit(NOLABEL,STOREAI,$3.reg,0,offset);
                                emit(NOLABEL,OUTPUT,1024+offset,EMPTY,EMPTY);

                               }
	;

fstmt	: FOR ctrlexp{
                         //check if the controlling label is within the bounds of the ctrlexp;
                         int reg1,reg2;
                         int forLabel,doLabel,exitLabel;
                         $2.forLabel = NextLabel();
                         $2.doLabel = NextLabel();
                         $2.exitLabel = NextLabel();
    
                         emitComment("Generate the control code for FOR");
                         reg1 = NextRegister();
                         emit($2.forLabel,LOADAI,0,$2.iteratorOffset,reg1);
                                       
                         reg2 =  NextRegister();
                         emit(NOLABEL,CMPLE,reg1,$2.finalIndex,reg2);
                         emit(NOLABEL,CBR,reg2,$2.doLabel,$2.exitLabel);
                                       
                     } 
                    DO {
                             //emit the do label;
                             emit($2.doLabel,NOP,EMPTY,EMPTY,EMPTY);
                       }
                      stmt { 
                                //Increment the iterator of  the loop;
                                int reg3,reg4;
                                reg3 = NextRegister();
                                reg4 = NextRegister();
                                emitComment("Increment the index");
                                emit(NOLABEL,LOADAI,0,$2.iteratorOffset,reg3);
                                emit(NOLABEL,ADDI,reg3,1,reg4);
                                emit(NOLABEL,STOREAI,reg4,0,$2.iteratorOffset);
                                emitComment("Loop back to the for label");
                                emit(NOLABEL,BR,$2.forLabel,EMPTY,EMPTY);
                                emit($2.exitLabel,NOP,EMPTY,EMPTY,EMPTY); 
                                
                           } 
	;
	
	
repeatstmt : REPEAT {
                        int trueLabel;
                        $1.trueLabel = NextLabel();
                        $1.falseLabel = NextLabel();
                        emit($1.trueLabel,NOP,EMPTY,EMPTY,EMPTY);

                    } 

                   stmt  UNTIL condexp {
                                          emit(NOLABEL,CBR,$5.reg,$1.falseLabel,$1.trueLabel);
                                          emit($1.falseLabel,NOP,EMPTY,EMPTY,EMPTY);
                                       }
    ;	

astmt : lhs ASG exp {
                        //Store the value in register in the memory location;
                        emitComment("Reducing astmt->lhs ASG exp");
                        emitComment("Store the value in register to the memory location");
                        emit(NOLABEL,STOREAO,$3.reg,0,$1.reg);
                        if(optimize_flag == 1){
                           deleteOptTab();
                        }
                       
                    }
	;

lhs	:  ID			     {
                             
                             char *str1;
                             int reg;
                             SymTabEntry* entry = lookup($1.str);
                             OptimizeTabEntry* optEntry;
                             if(optimize_flag == 1){
                                asprintf(&str1,"%s,%d","LOADI",lookup($1.str)->offset);
                                optEntry = lookupOPT(str1);
                                  if(optEntry){
                                    
                                    reg = optEntry->value;
                                  }
                                  else{
                                  
                                    reg = NextRegister();
                                    emit(NOLABEL,LOADI,lookup($1.str)->offset,reg,EMPTY);
                                    insertOPT(str1,reg);
                                     
                                  }
                                free(str1);
                               
                             }
                             else{
                             
                              reg = NextRegister();
                              emitComment("Reducing lhs->ID:Move the memory location of ID to a register");
                              emit(NOLABEL,LOADI,lookup($1.str)->offset,reg,EMPTY);
                             
                             }
                             
                             $$.reg = reg;
                              
                         }
        |  ID '[' exp ']'	    { 
                                   
                                   int reg1,reg2,reg3,reg4;
                                   char* str1 = NULL;
                                   SymTabEntry* entry = lookup($1.str);
                                   OptimizeTabEntry* optEntry;
                               
                                   if(entry!=NULL)
                                   {
                                       if(optimize_flag == 1){
                                        
                                          asprintf(&str1,"%s,%d","LOADI",4);
                                          optEntry = lookupOPT(str1);
                                          if(optEntry)
                                          {
                                              reg1 = optEntry->value;
                                          }
                                          else{
                                              
                                               reg1 = NextRegister();
                                               emit(NOLABEL,LOADI,4,reg1,0);
                                               insertOPT(str1,reg1);
                                          }
                                          free(str1);
                                          
                                          
                                          asprintf(&str1,"%s,%d,%d","MULT",$3.reg,reg1);
                                          optEntry = lookupOPT(str1);
                                          if(optEntry)
                                          {
                                              reg2 = optEntry->value;
                                          }
                                          else{
                                              
                                               reg2 = NextRegister();
                                               emit(NOLABEL,MULT,$3.reg,reg1,reg2);
                                               insertOPT(str1,reg2);
                                          }
                                          free(str1);
                                          
                                          
                                          asprintf(&str1,"%s,%d,%d","ADDI",reg2,entry->offset);
                                          optEntry = lookupOPT(str1);
                                          if(optEntry)
                                          {
                                              reg3 = optEntry->value;
                                          }
                                          else{
                                              
                                               reg3 = NextRegister();
                                               emit(NOLABEL,ADDI,reg2,entry->offset,reg3);
                                               insertOPT(str1,reg3);
                                          }
                                          free(str1);  
                                        
                                       }
                                       else{
                                            
                                            emitComment("Reducing lhs->ID[exp]:Move the memory location of array element to a register");
                                            //Move 4 bytes and store in another register;
                                            reg1 = NextRegister();
                                            emit(NOLABEL,LOADI,4,reg1,0);
                                     
                                            //Multiply 4 with the exp value
                                            reg2 = NextRegister();
                                            emit(NOLABEL,MULT,$3.reg,reg1,reg2);
                                     
                                            //Add the value in offsetReg to reg
                                            reg3 = NextRegister();
                                            emit(NOLABEL,ADDI,reg2,entry->offset,reg3);
                                          
                                       }
                                      
                                     $$.reg = reg3;
                                  
                               }
                               else{
                                  
                                  //Emit an error message
                                  emitComment("Array Identifier not declared!!");
                               } 
                                   
                                    
                                }
        |  ID '[' exp ',' exp ']'   {
                                      int reg1,reg2,reg3,reg4,reg5,reg6,reg7;
                                      char* str1;
                                      OptimizeTabEntry* optEntry;
                                      SymTabEntry* entry = lookup($1.str);
                                    
                                    if(entry!=NULL){
                                    
                                    
                                       if(optimize_flag == 1){
                                                
                                              asprintf(&str1,"%s,%d","LOADI",entry->rowDim);
                                              optEntry = lookupOPT(str1);
                                              if(optEntry)
                                              {
                                                reg1 = optEntry->value;
                                              }
                                              else{
                                              
                                               reg1 = NextRegister();
                                               emit(NOLABEL,LOADI,entry->rowDim,reg1,0);
                                               insertOPT(str1,reg1);
                                              }
                                              free(str1);
                                              
                                              asprintf(&str1,"%s,%d,%d","MULT",$5.reg,reg1);
                                              optEntry = lookupOPT(str1);
                                              if(optEntry)
                                              {
                                                reg2 = optEntry->value;
                                              }
                                              else{
                                               
                                               //Column Major;
                                               reg2 = NextRegister();
                                               emit(NOLABEL,MULT,$5.reg,reg1,reg2);
                                               insertOPT(str1,reg2);
                                              }
                                              free(str1);
                                              
                                              asprintf(&str1,"%s,%d,%d","ADD",reg2,$3.reg);
                                              optEntry = lookupOPT(str1);
                                              if(optEntry)
                                              {
                                                reg3 = optEntry->value;
                                              }
                                              else{
                                               
                                               //Column Major;
                                               reg3 = NextRegister();
                                               emit(NOLABEL,ADD,reg2,$3.reg,reg3);
                                               insertOPT(str1,reg3);
                                              }
                                              free(str1);
                                              
                                              asprintf(&str1,"%s,%d","LOADI",4);
                                              optEntry = lookupOPT(str1);
                                              if(optEntry)
                                              {
                                                reg4 = optEntry->value;
                                              }
                                              else{
                                               
                                               reg4 = NextRegister();
                                               emit(NOLABEL,LOADI,4,reg4,0);
                                               insertOPT(str1,reg4);
                                              }
                                              free(str1);
                                              
                                              asprintf(&str1,"%s,%d,%d","MULT",reg4,reg3);
                                              optEntry = lookupOPT(str1);
                                              if(optEntry)
                                              {
                                                reg5 = optEntry->value;
                                              }
                                              else{
                                               
                                               reg5 = NextRegister();
                                               emit(NOLABEL,MULT,reg4,reg3,reg5);
                                               insertOPT(str1,reg5);
                                              }
                                              free(str1);
                                              
                                              asprintf(&str1,"%s,%d,%d","ADDI",reg5,entry->offset);
                                              optEntry = lookupOPT(str1);
                                              if(optEntry)
                                              {
                                                reg6 = optEntry->value;
                                              }
                                              else{
                                               
                                               reg6 = NextRegister();
                                               emit(NOLABEL,ADDI,reg5,entry->offset,reg6);
                                               insertOPT(str1,reg6);
                                              }
                                              free(str1);
                                                 
                                                 
                                                 
                                            }else
                                            {
                                              
                                               emitComment("Reducing lhs->ID[exp,exp]:Move the memory location of array element to register");
                                              reg1 = NextRegister();
                                              emit(NOLABEL,LOADI,entry->rowDim,reg1,0);
                                          
                                              reg2 = NextRegister();
                                              emit(NOLABEL,MULT,$5.reg,reg1,reg2);
                                              //Column major
                                          
                                              reg3 = NextRegister();
                                              emit(NOLABEL,ADD,reg2,$3.reg,reg3);
                                          
                                              reg4 = NextRegister();
                                               emit(NOLABEL,LOADI,4,reg4,0);
                                          
                                              reg5 = NextRegister();
                                              emit(NOLABEL,MULT,reg4,reg3,reg5);
                                          
                                              reg6 = NextRegister();
                                              emit(NOLABEL,ADDI,reg5,entry->offset,reg6);
                                            
                                            }
                                                
                                           $$.reg = reg6;
                                    
                                    }
                                    else{
                                    
                                       //Emit an error message
                                       emitComment("Error:Array Identifier not declared!!");
                                    
                                    }
                                     
                                      
                            }
        ;

exp	: exp '+' exp		{   int reg;
                            char *str1;
                            OptimizeTabEntry* optEntry;
                            if(optimize_flag == 1){
                                  
                                  asprintf(&str1,"%s,%d,%d","ADD",$1.reg,$3.reg);
                                  optEntry = lookupOPT(str1);
                                  if(optEntry){
                                     
                                     reg = optEntry->value;
                                    
                                  }
                                  else{
                                    reg = NextRegister();
                                    emit(NOLABEL,ADD,$1.reg,$3.reg,reg);
                                    insertOPT(str1,reg);
                                  }
                                  free(str1);
                            
                            }
                            else{
                            
                                 reg = NextRegister();
                                 emitComment("Add the expressions in the two registers");
                                 emit(NOLABEL,ADD,$1.reg,$3.reg,reg);
                            }
                           
                           $$.reg = reg;
                        } 
        | exp '-' exp		{
                                   int reg;
                                   char *str1;
                                   OptimizeTabEntry* optEntry;
                                   if(optimize_flag == 1){
                                  
                                       asprintf(&str1,"%s,%d,%d","SUB",$1.reg,$3.reg);
                                       optEntry = lookupOPT(str1);
                                       if(optEntry){
                                     
                                          reg = optEntry->value;
                                    
                                       }
                                       else{
                                         reg = NextRegister();
                                         emit(NOLABEL,SUB,$1.reg,$3.reg,reg);
                                         insertOPT(str1,reg);
                                       }
                                       free(str1);
                            
                                  }
                                  else{
                            
                                      reg = NextRegister();
                                      emitComment("Subtract the expressions in the two registers");
                                      emit(NOLABEL,SUB,$1.reg,$3.reg,reg);
                                  }
                           
                                  $$.reg = reg;
          
                            }
	| exp '*' exp		{ 
	                              int reg;
	                        
	                               char *str1;
                                   OptimizeTabEntry* optEntry;
                                   if(optimize_flag == 1){
                                  
                                       asprintf(&str1,"%s,%d,%d","MULT",$1.reg,$3.reg);
                                       optEntry = lookupOPT(str1);
                                       if(optEntry){
                                     
                                          reg = optEntry->value;
                                    
                                       }
                                       else{
                                         reg = NextRegister();
                                         emit(NOLABEL,MULT,$1.reg,$3.reg,reg);
                                         insertOPT(str1,reg);
                                       }
                                       free(str1);
                            
                                  }
                                  else{
                            
                                      reg = NextRegister();
                                      emitComment("Multiply the expressions in the two registers");
                                      emit(NOLABEL,MULT,$1.reg,$3.reg,reg);
                                      
                                  }
                           
                            
                                 $$.reg = reg;
	
	                    }
        | ID			{ 
        
                             char *str;
                             int reg;
                             SymTabEntry* entry = lookup($1.str);
                             OptimizeTabEntry* optEntry;
                             if(optimize_flag == 1){
                                asprintf(&str,"%s,%d,%d","LOADAI",0,entry->offset);
                                optEntry = lookupOPT(str);
                                  if(optEntry){
                                    
                                    reg = optEntry->value;
                                  }
                                  else{
                                  
                                    reg = NextRegister();
                                    insertOPT(str,reg);
                                    emitComment("Reducing exp->ID:Load the value in memory to register");
                                    emit(NOLABEL,LOADAI,0,lookup($1.str)->offset,reg);
                                  
                                  }
                                
                               
                             }else{
                             
                              reg = NextRegister();
                              emitComment("Reducing exp->ID:Load the value in memory to register");
                              emit(NOLABEL,LOADAI,0,lookup($1.str)->offset,reg);
                             
                             }
                             $$.reg = reg;
                             
                        } 
        | ID '[' exp ']'	{ 
                               int reg1,reg2,reg3,reg4;
                               char *str1 = NULL;
                               SymTabEntry* entry = lookup($1.str);
                               OptimizeTabEntry* optEntry;
                               
                               if(entry!=NULL)
                               {
                               
                                        if(optimize_flag == 1)
                                        {
                                           
                                            asprintf(&str1,"%s,%d","LOADI",4);
                                            optEntry = lookupOPT(str1);
                                            if(optEntry){
                                              reg1 = optEntry->value;
                                            }
                                            else{
                                              reg1 = NextRegister();
                                              emit(NOLABEL,LOADI,4,reg1,0);
                                              insertOPT(str1,reg1);
                                            }
                                            free(str1);  
                                            
                                            asprintf(&str1,"%s,%d,%d","MULT",$3.reg,reg1);
                                            optEntry = lookupOPT(str1);
                                            if(optEntry){
                                              reg2 = optEntry->value;
                                              }
                                            else{
                                                reg2 = NextRegister();
                                                emit(NOLABEL,MULT,$3.reg,reg1,reg2);
                                                insertOPT(str1,reg2);
                                            
                                            }
                                            free(str1);
                                            
                                            asprintf(&str1,"%s,%d,%d","ADDI",reg2,entry->offset);
                                            optEntry = lookupOPT(str1);
                                            if(optEntry){
                                               reg3 = optEntry->value;
                                             }  
                                            else{
                                               reg3 = NextRegister();
                                               emit(NOLABEL,ADDI,reg2,entry->offset,reg3);
                                               insertOPT(str1,reg3);
                                            }
                                            free(str1);
                                             
                                            asprintf(&str1,"%s,%d,%d","LOADAO",0,reg3); 
                                            optEntry = lookupOPT(str1);
                                            if (optEntry){
                                               reg4 = optEntry->value;
                                            }
                                            else{
                                               reg4 = NextRegister();
                                               emit(NOLABEL,LOADAO,0,reg3,reg4);
                                               insertOPT(str1,reg4);
                                            }
                                            free(str1);
                                            $$.reg = reg4;
                                        }
                                        else{
                                        
                                           emitComment("Reducing exp->ID[exp]:");
                            
                                           //Move 4 bytes and store in another register;
                                           reg1 = NextRegister();
                                           emit(NOLABEL,LOADI,4,reg1,0);
                                     
                                          //Multiply 4 with the exp value
                                          reg2 = NextRegister();
                                          emit(NOLABEL,MULT,$3.reg,reg1,reg2);
                                     
                                          //Add the value in offsetReg to reg
                                          reg3 = NextRegister();
                                          emit(NOLABEL,ADDI,reg2,entry->offset,reg3);
                                     
                                          reg4 = NextRegister();
                                          emit(NOLABEL,LOADAO,0,reg3,reg4);
                                          $$.reg = reg4;     
                                        
                                        }
                                  
                               
                                     
                                  
                               }
                               else{
                                  
                                  //Emit an error message
                                  emitComment("Array Identifier not declared!!");
                               }
                               
                            }
        | ID '[' exp ',' exp ']' {
                                    int reg1,reg2,reg3,reg4,reg5,reg6,reg7;
                                    char* str1;
                                    SymTabEntry* entry = lookup($1.str);
                                    OptimizeTabEntry* optEntry;
                                    if(entry!=NULL){
                                     
                                         if(optimize_flag == 1){
                                           
                                             asprintf(&str1,"%s,%d,%d","LOADI",entry->rowDim,reg1);
                                             optEntry = lookupOPT(str1);
                                             if(optEntry){
                                                 reg1 =  optEntry->value;
                                             }
                                             else{
                                                 reg1 = NextRegister();
                                                 emit(NOLABEL,LOADI,entry->rowDim,reg1,0);
                                                 insertOPT(str1,reg1);
                                                 
                                             }
                                             free(str1);
                                             
                                             asprintf(&str1,"%s,%d,%d","MULT",$5.reg,reg1);
                                             optEntry = lookupOPT(str1);
                                             if(optEntry){
                                                 reg2 =  optEntry->value;
                                             }
                                             else{
                                                 reg2 = NextRegister();
                                                 emit(NOLABEL,MULT,$5.reg,reg1,reg2);
                                                 insertOPT(str1,reg2);
                                                 
                                             } 
                                             free(str1);
                                             
                                             asprintf(&str1,"%s,%d,%d","ADD",reg2,$3.reg);
                                             optEntry = lookupOPT(str1);
                                             if(optEntry){
                                                 reg3 =  optEntry->value;
                                             }
                                             else{
                                                 reg3 = NextRegister();
                                                 emit(NOLABEL,ADD,reg2,$3.reg,reg3);
                                                 insertOPT(str1,reg3);
                                                 
                                             } 
                                             free(str1);
                                         
                                             asprintf(&str1,"%s,%d","LOADI",4);
                                             optEntry = lookupOPT(str1);
                                             if(optEntry){
                                                 reg4 =  optEntry->value;
                                             }
                                             else{
                                                 reg4 = NextRegister();
                                                 emit(NOLABEL,LOADI,4,reg4,0);
                                                 insertOPT(str1,reg4);  
                                             } 
                                             free(str1);
                                             
                                             asprintf(&str1,"%s,%d,%d","MULT",reg4,reg3);
                                             optEntry = lookupOPT(str1);
                                             if(optEntry){
                                                 reg5 =  optEntry->value;
                                             }
                                             else{
                                                 reg5 = NextRegister();
                                                 emit(NOLABEL,MULT,reg4,reg3,reg5);
                                                 insertOPT(str1,reg5);  
                                             } 
                                             free(str1);    
                                         
                                             
                                             asprintf(&str1,"%s,%d,%d","ADDI",reg5,entry->offset);
                                             optEntry = lookupOPT(str1);
                                             if(optEntry){
                                                 reg6 =  optEntry->value;
                                             }
                                             else{
                                                 reg6 = NextRegister();
                                                 emit(NOLABEL,ADDI,reg5,entry->offset,reg6);
                                                 insertOPT(str1,reg6);  
                                             } 
                                             free(str1);   
                                              emit(NOLABEL,ADDI,reg5,entry->offset,reg6);
                                             
                                             asprintf(&str1,"%s,%d,%d","LOADAO",0,reg6);
                                             optEntry = lookupOPT(str1);
                                             if(optEntry){
                                                 reg7 =  optEntry->value;
                                             }
                                             else{
                                                 reg7 = NextRegister();
                                                 emit(NOLABEL,LOADAO,0,reg6,reg7);
                                                 insertOPT(str1,reg7);  
                                             } 
                                             free(str1);   
                                                 
                                         
                                         }
                                         else{
                                              
                                              emitComment("//Reducing exp->ID[exp,exp]:");
                                
                                          reg1 = NextRegister();
                                          emit(NOLABEL,LOADI,entry->rowDim,reg1,0);
                                          
                                          reg2 = NextRegister();
                                          emit(NOLABEL,MULT,$5.reg,reg1,reg2);
                                          //Column major
                                          
                                          reg3 = NextRegister();
                                          emit(NOLABEL,ADD,reg2,$3.reg,reg3);
                                          
                                          reg4 = NextRegister();
                                          emit(NOLABEL,LOADI,4,reg4,0);
                                          
                                          reg5 = NextRegister();
                                          emit(NOLABEL,MULT,reg4,reg3,reg5);
                                          
                                          reg6 = NextRegister();
                                          emit(NOLABEL,ADDI,reg5,entry->offset,reg6);
                                          
                                          reg7 = NextRegister();
                                          emit(NOLABEL,LOADAO,0,reg6,reg7);
                                          
                                          
                                         }
                                    
                                         $$.reg = reg7;
                                    
                                          
                                      
                                    
                                    }
                                    else{
                                    
                                       //Emit an error message
                                       emitComment("Error:Array Identifier not declared!!");
                                    
                                    }
                                     
        
        
                                 }
	| ICONST                 {
	                          int reg;
	                          OptimizeTabEntry* entry;
	                             
	                             if(optimize_flag == 1){
	                                 
	                                char *str;
	                                asprintf(&str,"%s,%d","LOADI",$1.num);
	                                entry = lookupOPT(str);
	                                if(entry){
	                                   reg = entry->value;
	                                   $$.reg = reg; 
	                                }
	                                else{
	                                
	                                   reg = NextRegister();
	                                   insertOPT(str,reg);
	                                   emitComment("Reducing exp->ICONST:Load constant to register");
	                                   emit(NOLABEL,LOADI,$1.num,reg,0);
	                                   $$.reg = reg;
	                                
	                                }
	                                free(str);
	                                
	                             }
	                             else{
	                               
	                                reg = NextRegister();
	                                emitComment("Reducing exp->ICONST:Load constant to register");
	                                emit(NOLABEL,LOADI,$1.num,reg,0);
	                                $$.reg = reg;
	                             }
	                
	                      
	                         }
	| error { yyerror("***Error: illegal expression\n");}  
	;


ctrlexp	: ID ASG ICONST ',' ICONST { 
                                       SymTabEntry* entry = lookup($1.str);
                                       int forLabel = NextLabel();
                                       int doLabel = NextLabel();
                                       int exitLabel = NextLabel();
                                       
                                       int reg1,reg2;
                                       
                                       if(entry){
                                       
                                        reg1 = NextRegister();
                                        reg2 = NextRegister();
                                       
                                        emitComment("Load the value of initial index into a register");
                                        emit(NOLABEL,LOADI,$3.num,reg1,EMPTY);
                                        emitComment("Load the value of final index into a register");
                                        emit(NOLABEL,LOADI,$5.num,reg2,EMPTY);
                                        emitComment("Store the value of ICONST1 in register to memory");
                                        emit(NOLABEL,STOREAI,reg1,0,entry->offset);
                                       
                                        $$.initialIndex = reg1;
                                        $$.finalIndex = reg2;
                                        $$.iteratorOffset = entry->offset; 
                                       
                                       }
                                       else{
                                           
                                           emitComment("Error:Initialization variable used without declaring!!");
                                       }
                                         
                                         
                                   }
        ;


condexp	: exp NEQ exp		{
                               emitComment("Reducing condexp-> exp NEQ exp");
                               OptimizeTabEntry* optEntry;
                               char* str1;
                               int reg;
                               
                                   if(optimize_flag == 1){
                                       asprintf(&str1,"%s,%d,%d","CMPNE",$1.reg,$3.reg);
                                       optEntry = lookupOPT(str1);
                                       if(optEntry){
                                         reg = optEntry->value;    
                                       }
                                       else{
                                          reg = NextRegister();
                                          emit(NOLABEL,CMPNE,$1.reg,$3.reg,reg);
                                          insertOPT(str1,reg);
                                       
                                       }
                                       free(str1);
                                       deleteOptTab();
                                   }
                                   else{
                                   
                                       reg = NextRegister();
                                       emit(NOLABEL,CMPNE,$1.reg,$3.reg,reg);
                                   
                                   }
                              
                               $$.reg = reg;
  
                            }
	| exp EQ exp		{ 
	                        
	                        emitComment("Reducing condexp-> exp EQ exp");
                               OptimizeTabEntry* optEntry;
                               char* str1;
                               int reg;
                                   if(optimize_flag == 1){
                                       asprintf(&str1,"%s,%d,%d","CMPEQ",$1.reg,$3.reg);
                                       optEntry = lookupOPT(str1);
                                       if(optEntry){
                                         reg = optEntry->value;    
                                       }
                                       else{
                                          reg = NextRegister();
                                          emit(NOLABEL,CMPEQ,$1.reg,$3.reg,reg);
                                          insertOPT(str1,reg);
                                       }
                                       free(str1);
                                       deleteOptTab();
                                   }
                                   else{
                                   
                                       reg = NextRegister();
                                       emit(NOLABEL,CMPEQ,$1.reg,$3.reg,reg);
                                   
                                   }
                            $$.reg = reg;
                            
	                          
	                     }
	| exp LT exp		{ 
	                        emitComment("Reducing condexp-> exp LT exp");
	                        OptimizeTabEntry* optEntry;
                               char* str1;
                               int reg;
                                   if(optimize_flag == 1){
                                       asprintf(&str1,"%s,%d,%d","CMPLT",$1.reg,$3.reg);
                                       optEntry = lookupOPT(str1);
                                       if(optEntry){
                                         reg = optEntry->value;    
                                       }
                                       else{
                                          reg = NextRegister();
                                          emit(NOLABEL,CMPLT,$1.reg,$3.reg,reg);
                                          insertOPT(str1,reg);
                                       }
                                       free(str1);
                                       deleteOptTab();
                                   }
                                   else{
                                   
                                        reg = NextRegister();
                                        emit(NOLABEL,CMPLT,$1.reg,$3.reg,reg);
                                   
                                   }
                            $$.reg = reg;
                            
	                    }
	| exp LEQ exp		{ 
	                        emitComment("Reducing condexp-> exp LEQ exp");
	                          OptimizeTabEntry* optEntry;
                               char* str1;
                               int reg;
                                   if(optimize_flag == 1){
                                       asprintf(&str1,"%s,%d,%d","CMPLE",$1.reg,$3.reg);
                                       optEntry = lookupOPT(str1);
                                       if(optEntry){
                                         reg = optEntry->value;    
                                       }
                                       else{
                                          reg = NextRegister();
                                          emit(NOLABEL,CMPLE,$1.reg,$3.reg,reg);
                                          insertOPT(str1,reg);
                                       }
                                       free(str1);
                                       deleteOptTab();
                                   }
                                   else{
                                   
                                        reg = NextRegister();
                                        emit(NOLABEL,CMPLE,$1.reg,$3.reg,reg);
                                   
                                   }
                            $$.reg = reg;
                            
	
	                    }
	| error { yyerror("***Error: illegal conditional expression\n");}  
        ;

%%

void yyerror(char* s) {
        fprintf(stderr,"%s\n",s);
        }

int optimize_flag = 0;


int
main(int argc, char* argv[]) {

  printf("\n     CS515 Spring 2016 Compiler\n");

  if (argc == 2 && strcmp(argv[1],"-O") == 0) {
    optimize_flag = 1;
    printf("     Version 1.0 CSE OPTIMIZER \n\n");
  }
    else
    printf("    Version 1.0 (non-optimizing)\n\n");
  
  outfile = fopen("iloc.out", "w");
  if (outfile == NULL) { 
    printf("ERROR: cannot open output file \"iloc.out\".\n");
    return -1;
  }

  CommentBuffer = (char *) malloc(500);  
  InitSymbolTable();

  InitOptimizeTable();
  
  printf("1\t");
  yyparse();
  printf("\n");

  PrintSymbolTable();
  
  fclose(outfile);
  
  return 1;
}




