grammar Liquid;

options {
  output=AST;
  ASTLabelType=CommonTree;
}

tokens {
  ASSIGNMENT;
  ATTRIBUTES;
  BLOCK;
  CAPTURE;
  CASE;
  COMMENT;
  CYCLE; 
  ELSE;
  FILTERS;
  FILTER;
  FOR_ARRAY;
  FOR_RANGE;
  GROUP;
  IF;
  INCLUDE;
  LOOKUP;
  OUTPUT;
  PARAMS;
  PLAIN;
  RAW;
  TABLE;
  UNLESS;
  WHEN;
  WITH;
}

@parser::header {
  package liqp;
}

@lexer::header {
  package liqp;
}

@parser::members {
  @Override
  public void reportError(RecognitionException e) {
    throw new RuntimeException(e); 
  }
}

@lexer::members {
  private boolean inTag = false;
  
  private boolean openTagAhead() {
    return input.LA(1) == '{' && (input.LA(2) == '{' || input.LA(2) == '\u0025');
  }
  
  @Override
  public void reportError(RecognitionException e) {
    throw new RuntimeException(e); 
  }
}

/* parser rules */
parse
 : block EOF -> block
   //(t=. {System.out.printf("\%-20s '\%s'\n", tokenNames[$t.type], $t.text);})* EOF
 ;

block
 : (options{greedy=true;}: atom)* -> ^(BLOCK atom*)
 ;

atom
 : tag
 | output
 | assignment
 | Other -> ^(PLAIN Other)
 ;

tag
 : raw_tag
 | comment_tag
 | if_tag
 | unless_tag
 | case_tag
 | cycle_tag
 | for_tag
 | table_tag
 | capture_tag
 | include_tag
 ;

raw_tag
 : TagStart RawStart TagEnd raw_body TagStart RawEnd TagEnd 
   -> ^(RAW raw_body)
 ;

raw_body
 : ~TagStart*
 ;

comment_tag
 : TagStart CommentStart TagEnd comment_body TagStart CommentEnd TagEnd 
   -> ^(COMMENT comment_body)
 ;

comment_body
 : ~TagStart*
 ;

if_tag
 : TagStart IfStart expr TagEnd block else_tag? TagStart IfEnd TagEnd 
   -> ^(IF expr block ^(ELSE else_tag?))
 ;

else_tag
 : TagStart Else TagEnd block 
   -> block
 ;

unless_tag
 : TagStart UnlessStart expr TagEnd block else_tag? TagStart UnlessEnd TagEnd 
   -> ^(UNLESS expr block ^(ELSE else_tag?))
 ;

case_tag
 : TagStart CaseStart expr TagEnd when_tag+ else_tag? TagStart CaseEnd TagEnd 
   -> ^(CASE expr when_tag+ ^(ELSE else_tag?))
 ;

when_tag
 : TagStart When expr TagEnd block 
   -> ^(WHEN expr block)
 ;

cycle_tag
 : TagStart Cycle cycle_group? expr (Comma expr)* TagEnd 
   -> ^(CYCLE ^(GROUP cycle_group?) expr+)
 ;

cycle_group
 : expr Col -> expr
 ;

for_tag
 : for_array
 | for_range    
 ;

for_array // attributes must be 'limit' or 'offset'!
 : TagStart ForStart Id In lookup attribute* TagEnd block TagStart ForEnd TagEnd
   -> ^(FOR_ARRAY Id lookup ^(ATTRIBUTES attribute*) block)
 ;

attribute 
 : Id Col expr -> ^(Id expr)
 ;

for_range
 : TagStart ForStart Id In OPar expr DotDot expr CPar TagEnd block TagStart ForEnd TagEnd
   -> ^(FOR_RANGE Id expr expr block)
 ;

table_tag // attributes must be 'limit' or 'cols'!
 : TagStart TableStart Id In Id attribute* TagEnd block TagStart TableEnd TagEnd
   -> ^(TABLE Id Id ^(ATTRIBUTES attribute*) block)
 ;

capture_tag
 : TagStart CaptureStart Id TagEnd block TagStart CaptureEnd TagEnd
   -> ^(CAPTURE Id block)
 ;

include_tag
 : TagStart Include a=Str (With b=Str)? TagEnd 
   -> ^(INCLUDE $a ^(WITH $b?))
 ;

output
 : OutStart expr filter* OutEnd 
   -> ^(OUTPUT expr ^(FILTERS filter*))
 ;

filter
 : Pipe Id params? 
   -> ^(FILTER Id ^(PARAMS params?))
 ;

params
 : Col expr (Comma expr)*  -> expr+
 ;

assignment
 : TagStart Assign Id EqSign expr TagEnd 
   -> ^(ASSIGNMENT Id expr)
 ;

expr
 : or_expr
 ;

or_expr
 : and_expr (Or^ and_expr)*
 ;

and_expr
 : eq_expr (And^ eq_expr)*
 ;

eq_expr
 : rel_expr ((Eq | NEq)^ rel_expr)*
 ;

rel_expr
 : term ((LtEq | Lt | GtEq | Gt)^ term)?
 ;

term
 : Num
 | Str
 | True
 | False
 | Nil
 | lookup
 ;

lookup
 : Id (Dot Id)* -> ^(LOOKUP Id+)
 ;

/* lexer rules */
OutStart : '{{' {inTag=true;};
OutEnd   : '}}' {inTag=false;};
TagStart : '{%' {inTag=true;};
TagEnd   : '%}' {inTag=false;};

Str : {inTag}?=> (SStr | DStr);

DotDot : {inTag}?=> '..';
Dot    : {inTag}?=> '.';
NEq    : {inTag}?=> '!=';
Eq     : {inTag}?=> '==';
EqSign : {inTag}?=> '=';
GtEq   : {inTag}?=> '>=';
Gt     : {inTag}?=> '>';
LtEq   : {inTag}?=> '<=';
Lt     : {inTag}?=> '<';
Pipe   : {inTag}?=> '|';
Col    : {inTag}?=> ':';
Comma  : {inTag}?=> ',';
OPar   : {inTag}?=> '(';
CPar   : {inTag}?=> ')';
Num    : {inTag}?=> Digit+;
WS     : {inTag}?=> (' ' | '\t' | '\r' | '\n')+ {skip();};

Id
 : {inTag}?=> (Letter | '_') (Letter | '_' | '-' | Digit)*
   {
     if($text.equals("capture"))          $type = CaptureStart;
     else if($text.equals("endcapture"))  $type = CaptureEnd;
     else if($text.equals("comment"))     $type = CommentStart;
     else if($text.equals("endcomment"))  $type = CommentEnd;
     else if($text.equals("raw"))         $type = RawStart;
     else if($text.equals("endraw"))      $type = RawEnd;
     else if($text.equals("if"))          $type = IfStart;
     else if($text.equals("endif"))       $type = IfEnd;
     else if($text.equals("unless"))      $type = UnlessStart;
     else if($text.equals("endunless"))   $type = UnlessEnd;
     else if($text.equals("else"))        $type = Else;
     else if($text.equals("case"))        $type = CaseStart;
     else if($text.equals("endcase"))     $type = CaseEnd;
     else if($text.equals("when"))        $type = When;
     else if($text.equals("cycle"))       $type = Cycle;
     else if($text.equals("for"))         $type = ForStart;
     else if($text.equals("endfor"))      $type = ForEnd;
     else if($text.equals("in"))          $type = In;
     else if($text.equals("and"))         $type = And;
     else if($text.equals("or"))          $type = Or;
     else if($text.equals("tablerow"))    $type = TableStart;
     else if($text.equals("endtablerow")) $type = TableEnd;
     else if($text.equals("assign"))      $type = Assign;
     else if($text.equals("true"))        $type = True;
     else if($text.equals("false"))       $type = False;
     else if($text.equals("nil"))         $type = Nil;
     else if($text.equals("include"))     $type = Include;
     else if($text.equals("with"))        $type = With;
   }
 ;

Other
 : ({!inTag && !openTagAhead()}?=> . )+
   {
     String s = getText().replaceAll("\\s+", " ").trim();
     if(s.isEmpty()) {
       skip();
     }
     else {
       setText(s);
     }
   }
 ;

/* fragment rules */
fragment Letter : 'a'..'z' | 'A'..'Z';
fragment Digit  : '0'..'9';
fragment SStr   : '\'' ~'\''* '\'';
fragment DStr   : '"' ~'"'* '"';

fragment CommentStart : ;
fragment CommentEnd : ;
fragment RawStart : ;
fragment RawEnd : ;
fragment IfStart : ;
fragment IfEnd : ;
fragment UnlessStart : ;
fragment UnlessEnd : ;
fragment Else : ;
fragment CaseStart : ;
fragment CaseEnd : ;
fragment When : ;
fragment Cycle : ;
fragment ForStart : ;
fragment ForEnd : ;
fragment In : ;
fragment And : ;
fragment Or : ;
fragment TableStart : ;
fragment TableEnd : ;
fragment Assign : ;
fragment True : ;
fragment False : ;
fragment Nil : ;
fragment Include : ;
fragment With : ;
fragment CaptureStart : ;
fragment CaptureEnd : ;
