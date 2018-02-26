* -*- text -*-
&use_xdc setb 0
* uncomment the next line to enable xdc
*&use_xdc setb 1
         title 'JES symbol manipulation CP'
         csect
jesx     loctr
         amode 31
         rmode 31
         dc cl32'JESSYM &SYSDATE &SYSTIME'
         entry JESSYM
JESSYM ds 0d
JESSYM alias C'JESSYM'
JESSYM xattr linkage(os)
         SYSSTATE AMODE64=NO,ARCHLVL=OSREL
         IEABRCX DEFINE
         YREGS
         stm r14,r12,12(r13)
         lr r11,r1              save CPPL pointer
         using CPPL,r11         map
         basr r12,0             get a base register
         using *,r12            tell assembler
         lay r0,dsa_length      we need this much storage
         STORAGE OBTAIN,LENGTH=(0),LOC=31,BNDRY=PAGE
         st r1,8(,r13)          chain forward
         st r13,4(,r1)          chain back
         lr r13,r1              activate out dsa
         using dsa,r13          map it
* Initialize the DSA
         la r2,dsa_model_start
         lay r3,dsa_model_length
         lay r4,model_model_start
         lr r5,r3
         mvcl r2,r4
* Set up the parm list for IKJEFF02 (the TSO message issuer)
         lay r9,dsa_mi_msgcsect
         st r9,dsa_mi_descriptor
         st r11,dsa_mi_cppl
         lay r9,messages
         st r9,dsa_mi_msgcsect
         la r10,dsa_ppl
         using PPL,r10
         mvc  pplupt,cpplupt        put in the upt address from cppl
         mvc  pplect,cpplect        put in the ect address from cppl
         mvc  pplcbuf,cpplcbuf      put in the command buffer address
         la r1,dsa_cmdecb           get ECB address
         st r1,pplecb               store in the PPL
         l r1,=a(pcldefs)           get PCL address
         st r1,pplpcl               store in the PPL
         la r1,dsa_answer_ptr       get address of answer pointer
         st r1,pplans               store in the PPL
         xc ppluwa,ppluwa           clear the user work area pointer
         CALLTSSR EP=IKJPARS,MF=(E,PPL)   INVOKE PARSE
         drop r10
         ltr r15,r15
         jnz parse_failed
         l r10,dsa_answer_ptr       get parse response
         using pdl_result,r10
         tm pdl_verb_flags,pdl_flag_present  is there a verb?
         bz no_verb
         tm pdl_name_flags,pdl_flag_present  is there a name?
         bz no_name
         llh r9,pdl_verb_code       get the verb
         clije r9,1,verb_is_get
         clije r9,2,verb_is_set
         clije r9,3,verb_is_delete
         j bad_verb                  WTF?
verb_is_get ds 0h
         mvc dsa_jsymsnma,pdl_name_txt  copy pointer to name
         llh r9,pdl_name_len            get the length
         st  r9,dsa_jsymsnml            store in the parm list
         mvhi dsa_jsymsnmn,1            just one selection element
         mvi dsa_jsymrqop,JSYMEXTR      "extract" the values
         mvi dsa_jsymlvl,JSYMLVLJ       access at job step level
         lay r9,dsa_symtab              where to put the result
         st r9,dsa_jsymouta
         lay r9,dsa_symtab_length       how much space we're providing
         st r9,dsa_jsymouts             for the result
         IAZSYMBL PARM=dsa_iazsymbl_template do it
         l r9,dsa_jsymretn              get the return code
         clijne r9,JSYMOK,bad_get
         lay r9,dsa_symtab              point to symbol table
         using JSYTABLE,r9              map
         lt r8,JSYTENTN                 how many entries were returned?
         jnz show_entries
* Nothing to show
         mvc dsa_mi_msgid,=c'0001'
         llh r9,pdl_name_len
         st  r9,dsa_mi_i0_len
         mvc dsa_mi_i0_ptr(4),pdl_name_txt
         CALLTSSR EP=IKJEFF02,MF=(E,dsa_mi_parm)
         j done
show_entries ds 0h
         mvc dsa_mi_msgid,=c'0002'
         mvhi dsa_mi_i0_len,16          set name length
         lr r7,r9                       copy symbol table ptr
         a r7,JSYTENT1                  add offset to first entry
         using JSYENTRY,r7
show_loop ds 0h
         la r6,JSYENAME                 point to the symbol name
         st r6,dsa_mi_i0_ptr            store for insertion
         lr r6,r9                       get symbol table base
         a r6,JSYEVALO                  add offset to value
         st r6,dsa_mi_i1_ptr            store for insertion
         lh r6,JSYEVALS                 get the value length
         st r6,dsa_mi_i1_len            store for insertion
         CALLTSSR EP=IKJEFF02,MF=(E,dsa_mi_parm)
         a r7,JSYTENTS                  bump to next entry
         jct r8,show_loop
         j done
verb_is_set ds 0h
* Set up the symbol table template (for one entry) and then plug in
* the name and value fron IKJPARS.
         mvc dsa_symtab(one_entry_table_length),one_entry_table
         llh r9,pdl_name_len            get the length of the name
         ltr r9,r9                      empty?
         jz bad_name
         clijh r9,16,bad_name           too long?
         lay r9,-1(r9)                  decrement for execute
         l r8,pdl_name_txt              get pointer to name
         exrl r9,copy_name              copy
         llh r9,pdl_value_len           get the length of the value
         ltr r9,r9                      empty?
         jz bad_value
         clijh r9,255,bad_value         too long?
         sth r9,dsa_symtab+one_entry_value_length_offset
         lay r9,-1(r9)                  decrement for execute
         l r8,pdl_value_txt             get pointer to value
         exrl r9,copy_value             copy
* Now set up the parameter block for the JES symbol service
         mvi dsa_jsymrqop,JSYMCRT       "create" the values
         lay r9,dsa_symtab              the input symbol table
         st r9,dsa_jsymisyt
         mvi dsa_jsymlvl,JSYMLVLJ+JSYMLVUD access at job step level,
*                                       and create will update
         IAZSYMBL PARM=dsa_iazsymbl_template do it
         l r9,dsa_jsymretn              get the return code
         clijne r9,JSYMOK,bad_set
* TBD: check return code, display results
         j done
copy_name mvc dsa_symtab+one_entry_offset_to_first(0),0(r8)
copy_value mvc dsa_symtab+one_entry_value_offset(0),0(r8)
verb_is_delete ds 0h
         mvc dsa_jsymsnma,pdl_name_txt  copy pointer to name
         llh r9,pdl_name_len            get the length
         st  r9,dsa_jsymsnml            store in the parm list
         mvhi dsa_jsymsnmn,1            just one selection element
         mvi dsa_jsymrqop,JSYMDELE      delete the symbols
         mvi dsa_jsymlvl,JSYMLVLJ       access at job step level
* Not sure this stuff is needed
         lay r9,dsa_symtab              where to put the result
         st r9,dsa_jsymouta            
         lay r9,dsa_symtab_length       how much space we're providing
         st r9,dsa_jsymouts             for the result
         IAZSYMBL PARM=dsa_iazsymbl_template do it
         l r9,dsa_jsymretn              get the return code
         clijne r9,JSYMOK,bad_delete
         mvc dsa_mi_msgid,=c'0003'
         llh r9,pdl_name_len
         st  r9,dsa_mi_i0_len
         mvc dsa_mi_i0_ptr(4),pdl_name_txt
         CALLTSSR EP=IKJEFF02,MF=(E,dsa_mi_parm)
done     ds 0h
         IKJRLSA dsa_answer_ptr
         lr r1,r13              copy dsa address
         lay r0,dsa_length
         l r13,4(,r13)          get the old save area pointer
         STORAGE RELEASE,ADDR=(1),LENGTH=(0)
         lm r14,r12,12(r13)
         xr r15,r15
         br r14
parse_failed ds 0h
         abend 101
no_verb  ds 0h
         abend 102
bad_verb ds 0h
         abend 103
no_name  ds 0h
         abend 104
bad_name ds 0h
         abend 105
bad_value ds 0h
         abend 106
bad_get ds 0h
         mvc dsa_mi_i0_len(8),mi_get
         j bad_func
bad_set ds 0h
         mvc dsa_mi_i0_len(8),mi_set
         j bad_func
bad_delete ds 0h
         mvc dsa_mi_i0_len(8),mi_delete
bad_func ds 0h
         mvc dsa_mi_msgid,=c'0000'
         mvc dsa_mi_i1_len(4),mi_hex_4_len        
         lay r9,dsa_jsymretn
         st r9,dsa_mi_i1_ptr
         mvc dsa_mi_i2_len(4),mi_hex_4_len        
         lay r9,dsa_jsymreas
         st r9,dsa_mi_i2_ptr
         CALLTSSR EP=IKJEFF02,MF=(E,dsa_mi_parm)
         j done
         ltorg
pcldefs  IKJPARM  DSECT=parsect
pclverb  IKJRSVWD 'Action',PROMPT='The action to be performed',        X
               HELP=('Must be GET, SET, or DELETE')
         IKJNAME 'GET'
         IKJNAME 'SET'
         IKJNAME 'DELETE'
pclname  IKJIDENT 'Symbol name',UPPERCASE,                             X
               MAXLNTH=16,FIRST=ALPHA,OTHER=ANY,                       X
               PROMPT='The name of the JES symbol to be acted on'
pclvalue IKJPOSIT QSTRING,ASIS
         IKJENDP
* Message insertions
mi_get      dc a(l'con_get),a(con_get)
mi_set      dc a(l'con_set),a(con_set)
mi_delete   dc a(l'con_delete),a(con_delete)
mi_hex_4_len dc a(x'80000004')
con_get     dc cl3'GET'
con_set     dc cl3'SET'
con_delete  dc cl6'DELETE'
* Template for a single-element symbol table
one_entry_table ds 0d
         dc    cl4'JSYT'           Eyecatcher
         dc    a(one_entry_table_length+255) Total size of the table
         dc    al1(JSYTVER1)       Version of the table
         dc    xl3'000000'         Reserved
         dc    a(one_entry_offset_to_first) Offset from beginning of
*                                    the table to the first entry
         dc    f'1'                Number of entries in the table
         dc    f'24'               Size of each entry
         dc    2f'0'               Reserved
*        Entry in a symbol table
one_entry_offset_to_first equ *-one_entry_table
         dc    cl16' '             Symbol name
         dc    a(one_entry_value_offset) Offset from the beginning
*                                  of table header (JSYTABLE) to the
*                                  symbol value
one_entry_value_length_offset equ *-one_entry_table
one_entry_value_length dc al2(0)   Size of the symbol value
         dc    xl2'0000'           Reserved
one_entry_value equ *
one_entry_value_offset equ *-one_entry_table
one_entry_table_length equ *-one_entry_table
messages ds 0d
         IKJTSMSG ('RKTJ0000 IAZSYMBL failed for ',,', return code ',, X
               ', reason code ',),0000
         IKJTSMSG ('RKTJ0001 No symbols were found for ',),0001
         IKJTSMSG ('RKTJ0002 ',,'="',,'"'),0002
         IKJTSMSG ('RKTJ0003 Deleted symbol ',),0003
         IKJTSMSG
         macro
&PREFIX  DSA &DSECT=NO
         aif ('&DSECT' EQ 'NO').nodsect
&PREFIX  dsect
         ago .start
.nodsect anop
&PREFIX  ds 0d
.start   anop
&PREFIX._save ds 18f
&PREFIX._model_start equ *
&PREFIX._cmdecb dc f'0'             ecb needed by IKJPARS
&PREFIX._ppl equ *
         org *+PPLSIZE
&PREFIX._answer_ptr dc f'0'         IKJPARS will set
* This is a template for the IAZSYMBL parameter list. What
* a hack; the z/OS team needs to provide real service macros
* for this stuff.
&PREFIX._iazsymbl_template ds 0d
&PREFIX._jsymeye  DC    CL4'JSYM'
&PREFIX._jsymlng  DC    AL2(JSYMSIZE)
&PREFIX._jsymvrm  DC    AL2(JSYMVRMC)
&PREFIX._jsymsvrm DC    AL2(0)
&PREFIX._jsymrqop DC    AL1(0) I.Requested operation
&PREFIX._jsymlvl  DC    B'00000000' I.Symbol options
&PREFIX._jsymisyt DC    A(0) I. Pointer to an input symbol table
*                       Used by CREATE/UPDATE/DELETE
&PREFIX._jsymsnma DC    A(0) IS*. Pointer to selection list
&PREFIX._jsymsnmn DC    F'0' IS.  Number of elements in selection list
&PREFIX._jsymsnml DC    F'0' IS.  Length of each element in selection
*                                 list. Valid values 0-16. 0 means 16.
&PREFIX._jsymouta DC    A(0) I. Pointer to caller provided output area
&PREFIX._jsymouts DC    F'0' I. Size of caller provided output area
&PREFIX._jsymretn DC    F'0' O. Service return code
&PREFIX._jsymreas DC    F'0' O. Service reason code
&PREFIX._jsymsrcm DC    F'0' O. Recommended size of the output area
&PREFIX._jsymerad DC    A(0) O. If service returns an error this
*                               points to approximate location
*                               where error was detected
         DC    9F'0'            Reserved
* Parameter list for IKJEFF02 (TSO message issuer)
&PREFIX._mi_parm       ds 0d
&PREFIX._mi_descriptor dc a(0)
&PREFIX._mi_cppl       dc a(0)
&PREFIX._mi_ecbptr     dc a(0)
&PREFIX._mi_last       dc xl4'80000000'
&PREFIX._mi_msgcsect   dc a(0)
&PREFIX._mi_sw1        dc b'11000001'
                       dc xl3'000000'
&PREFIX._mi_sw2        dc b'00000010'
                       dc xl3'000000'
&PREFIX._mi_old       dc a(0)
&PREFIX._mi_extrbf    dc a(0)
&PREFIX._mi_extrbf2   dc a(0)
&PREFIX._mi_msgid     dc cl4'    '
&PREFIX._mi_reply     dc a(0)
&PREFIX._mi_inserts   equ *
&PREFIX._mi_i0_len    dc f'0'
&PREFIX._mi_i0_ptr    dc a(0)
&PREFIX._mi_i1_len    dc f'0'
&PREFIX._mi_i1_ptr    dc a(0)
&PREFIX._mi_i2_len    dc f'0'
&PREFIX._mi_i2_ptr    dc a(0)
&PREFIX._mi_i3_len    dc f'0'
&PREFIX._mi_i3_ptr    dc a(0)
&PREFIX._mi_i4_len    dc f'0'
&PREFIX._mi_i4_ptr    dc a(0)
 
         ds 0d                      align the length
&PREFIX._model_end equ *
&PREFIX._model_length equ &PREFIX._model_end-&PREFIX._model_start
* The fields from here on down do not have to be initialized.
&PREFIX._symtab ds 0d  align
         org *+8192  space for the symbol table. Overkill.
&PREFIX._symtab_length equ *-&PREFIX._symtab
&PREFIX._length EQU *-&PREFIX
         MEND
         print nogen
model    DSA
         print gen
dsa      DSA DSECT=YES
* The DSECT that the IKJPARM macros build is pretty lame, so here's
* a homebrew.
pdl_result dsect
pdl_header      ds 2f
*
                ds h
pdl_verb_code   ds h
                ds h
pdl_verb_flags  ds h
*
pdl_name_txt    ds a
pdl_name_len    ds h
pdl_name_flags  ds h
*
pdl_value_txt   ds a
pdl_value_len   ds h
pdl_value_flags ds h
*
pdl_flag_present equ x'80'
         print nogen
         CVT DSECT=YES
         IHAECVT
         IKJPPL
PPLSIZE  EQU *-PPL
         IKJTSVT
         IKJCPPL
         print gen
         IAZSYMDF DSECT=YES
         end