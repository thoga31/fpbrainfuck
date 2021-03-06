(*
===== fpbrainfuck =====
Unit for Free Pascal and compatible Extended Pascal, Object Pascal and Delphi compilers.
Licensed under the GNU-GPL 3.0.
Author:                   Igor Nunes, a.k.a. thoga31
Versions:   Stable:       2.1.1
            In progress:  2.2.0 (?)
Date:                     December 27, 2016
*)

unit fpbrainfuck;
{$MODE objfpc}

interface
uses fpbftype;

const
  version : string = '2.1.1';
  CRLF = {$IFDEF windows} #13 + {$ENDIF} #10;

type
  TBFInput   = function : char;
  TBFOutput  = procedure(prompt : char);


(* METHODS *)
function  ExecuteBrainfuck(filename : string) : byte;
function  ExecuteBrainfuck(thecode : TBFCode) : byte; overload;

procedure DefIOBrainfuck(inmethod : TBFInput; outmethod : TBFOutput);
procedure DefIOBrainfuck(inmethod : TBFInput); overload;
procedure DefIOBrainfuck(outmethod : TBFOutput); overload;
procedure ResetToBrainfuck;

function  SetBFOperators(nextcell     , previouscell ,
                         incrementcell, decrementcell,
                         outcell      , incell       ,
                         initcycle    , endcycle     : TToken) : byte;
function  SetBFOperators(tokens : TArrToken) : byte; overload;

(* ==================== DEBUG MODE ==================== *)
  procedure BF_SwitchDebugMode;
  function  BF_DebugStatus : boolean;
(* ==================== DEBUG MODE ==================== *)



implementation
uses crt, sysutils, fpbferr;

const
  TAPE_INITSIZE = 65535;  // MAX_WORD

// acting like constant while the State Machine runs the code
var
  tokOpers : TArrToken;

(* CELLS *)
type
  TBFCell    = byte;
  TBFArrCell = array of TBFCell;
  TBFIO = record
    Input  : TBFInput;
    Output : TBFOutput;
  end;

  TStateMachine = record         (* STATE MACHINE *)
    datacells : TBFArrCell;      // cells
    cellidx   : longword;        // pointer
    lastcell  : longword;        // indicates which cell is the last one
    bfIO      : TBFIO;           // I/O methods
  end;

var
  sm     : TStateMachine;
  toklen : longword; // Length of tokens
  flag   : record
    aretokensregular : boolean;  // [flag] Are Tokens Regular? (a.k.a. are all lengths equal?)
    debugmode        : boolean;  // [flag] Debug Mode Switch
  end;


(* IMPLEMENTATION *)
{$i debug.pas}

function GetToken(c : TToken; var tok : TTokenEnum) : boolean;
begin
  GetToken := false;
  for tok in tokEnum do
    if tokOpers[tok] = c then begin
      GetToken := true;
      break;
    end;
end;


{$REGION Cell Management}
function CountCells : longword;
begin
  CountCells := Length(sm.datacells);
end;

procedure CreateCell;
begin
  if (sm.lastcell mod TAPE_INITSIZE) = 0 then
    SetLength(sm.datacells, Length(sm.datacells) + TAPE_INITSIZE);
  Inc(sm.lastcell);
  sm.datacells[sm.lastcell] := 0;
end;

procedure IncCell(idx : longword);
begin
  Inc(sm.datacells[idx]);
end;

procedure DecCell(idx : longword);
begin
  Dec(sm.datacells[idx]);
end;

function GetCell(idx : longword) : TBFCell;
begin
  GetCell := sm.datacells[idx];
end;

function CellToChar(data : TBFCell) : char;
begin
  CellToChar := Chr(data);
end;

procedure OutputCell(idx : longword);
begin
  sm.bfIO.Output(CellToChar(GetCell(idx)));
end;

procedure InputCell(idx : longword);
begin
  sm.datacells[idx] := Ord(PChar(sm.bfIO.Input)^);
end;
{$ENDREGION}

{$REGION Brainfuck interpreter}
procedure ProcessBrainfuck(tok : TTokenEnum);
(* Main procedure of all! This is the brain of the interpreter. *)

  function IncR(var n : longword) : longword;
  (* Just to avoid a little begin-end block :) *)
  begin
    Inc(n);
    IncR := n;
  end;

begin
  case tok of
    tokIn   : InputCell(sm.cellidx);
    tokOut  : OutputCell(sm.cellidx);
    tokInc  : IncCell(sm.cellidx);
    tokDec  : DecCell(sm.cellidx);
    tokNext : if CountCells-1 < IncR(sm.cellidx) then
                CreateCell;
    tokPrev : if sm.cellidx > 0 then
                Dec(sm.cellidx);
  end;
end;

{$MACRO on}
procedure ParseBrainfuck(thecode : TBFCode); overload;
var
  i : longword;
  cycles : TStackOfWord;
  cycle_count : longword = 0;
  {$DEFINE cmd:=thecode.Token(i)}  // lets simplify the code...

  procedure SeekEndOfCycle;
  (* Just to make the code more easy for the eyes. *)
  begin
    cycle_count := 1;
    while (cmd <> tokEnd) or (cycle_count > 0) do begin
      Inc(i);
      case cmd of
        tokBegin : Inc(cycle_count);
        tokEnd   : Dec(cycle_count);
      end;
    end;
  end;

begin
  i := 0;
  while i < thecode.Count do begin
    case cmd of
      tokBegin : if GetCell(sm.cellidx) = 0 then
                   SeekEndOfCycle
                 else
                   cycles.Push(i);
      tokEnd   : if GetCell(sm.cellidx) = 0 then
                   cycles.Pop
                 else
                   i := cycles.Peek;
    else
      ProcessBrainfuck(cmd);
    end;

    Inc(i);
  end;
end;
{$MACRO off}
{$ENDREGION}

{$REGION Brainfuck source code management}
function LoadBrainfuck(filename : string; var thecode : TBFCode) : byte;
var
  f   : file of char;
  ch  : char;
  t   : TToken;
  tok : TTokenEnum;
  i   : byte;
label _TOTALBREAK;

begin
  if not flag.aretokensregular then
    LoadBrainfuck := ERR_TOKSIZE
  else if not FileExists(filename) then
    LoadBrainfuck := ERR_NOSOURCE
  else
    LoadBrainfuck := ERR_SUCCESS;

  // __debug__('LoadBrainfuck initially returned ' + IntToStr(LoadBrainfuck) + CRLF);
  if LoadBrainfuck <> ERR_SUCCESS then
    Exit;

  AssignFile(f, filename);
  Reset(f);
  // __debug__('LoadBrainfuck is now reading the source file...' + CRLF);
  while not eof(f) do begin
    t := '';
    for i in [1..toklen] do begin
      read(f, ch);
      t := t + ch;
      if eof(f) and (i < toklen) then begin
        if ch <> #10 then
          LoadBrainfuck := ERR_CONTROLLED;  { TODO: new error code is needed! }
        goto _TOTALBREAK;
      end;
    end;
    if GetToken(t, tok) then
      // __debug__('  >>> Appending token «' + t + '»' + CRLF);
      thecode.Append(tok)
    else
      Seek(f, FilePos(f)-toklen+1);
  end;

  _TOTALBREAK:
  CloseFile(f);
  // __debug__('LoadBrainfuck terminated successfully.' + CRLF);

  // if debugmode then DebugCommands(thecode);   (* === DEBUG MODE === *)
end;

procedure ResetParser; forward;
procedure FreeBrainfuck;
begin
  ResetParser;
end;


function ExecuteBrainfuck(filename : string) : byte;
var thecode : TBFCode;
begin
  ExecuteBrainfuck := LoadBrainfuck(filename, thecode);
  if ExecuteBrainfuck <> ERR_SUCCESS then
    Exit;

  ExecuteBrainfuck := ExecuteBrainfuck(thecode);

  if flag.debugmode then DebugCells;  (* === DEBUG MODE === *)

  FreeBrainfuck;
end;

function ExecuteBrainfuck(thecode : TBFCode) : byte; overload;
var _defaultflushfunc : CodePointer;
begin
  _defaultflushfunc := Textrec(Output).FlushFunc;   // Saves the default FlushFunc for later
  Textrec(Output).FlushFunc := nil;                 // And now disables it

  if flag.aretokensregular then begin
    ParseBrainfuck(thecode);
    ExecuteBrainfuck := ERR_SUCCESS;
  end else
    ExecuteBrainfuck := ERR_TOKSIZE;

  if flag.debugmode then DebugCells;  (* === DEBUG MODE === *)

  Flush(Output);                                    // Empties stdout if it still has content
  Textrec(Output).FlushFunc := _defaultflushfunc;   // Back to default FlushFunc
end;
{$ENDREGION}

{$REGION Define I/O methods}
function DefaultInput : char;
begin
  DefaultInput := ReadKey;
end;

procedure DefaultOutput(ch : char);
begin
  if ch = #10 then
    Flush(Output)
  else
    write(Output, ch);
end;

procedure DefIOBrainfuck(inmethod : TBFInput; outmethod : TBFOutput);
begin
  sm.bfIO.Input  := inmethod;
  sm.bfIO.Output := outmethod;
end;

procedure DefIOBrainfuck(inmethod : TBFInput); overload;
begin
  DefIOBrainfuck(inmethod, @DefaultOutput);
end;

procedure DefIOBrainfuck(outmethod : TBFOutput); overload;
begin
  DefIOBrainfuck(@DefaultInput, outmethod);
end;
{$ENDREGION}

procedure ResetParser;
begin
  SetLength(sm.datacells, TAPE_INITSIZE);  // every program starts with cell 'c0' defined
  sm.lastcell := 0;
  sm.cellidx := 0;
end;

function SetBFOperators(nextcell     , previouscell ,
                        incrementcell, decrementcell,
                        outcell      , incell       ,
                        initcycle    , endcycle     : TToken) : byte;
var
  i : TToken;
begin
  tokOpers[tokNext]  := nextcell;
  tokOpers[tokPrev]  := previouscell;
  tokOpers[tokInc]   := incrementcell;
  tokOpers[tokDec]   := decrementcell;
  tokOpers[tokOut]   := outcell;
  tokOpers[tokIn]    := incell;
  tokOpers[tokBegin] := initcycle;
  tokOpers[tokEnd]   := endcycle;

  SetBFOperators := 0;
  toklen := Length(tokOpers[tokNext]);
  for i in tokOpers do
    if Length(i) <> toklen then
      Inc(SetBFOperators);
  flag.aretokensregular := SetBFOperators = 0;
end;

function SetBFOperators(tokens : TArrToken) : byte; overload;
begin
  SetBFOperators :=
    SetBFOperators(tokens[tokNext] , tokens[tokPrev],
                   tokens[tokInc]  , tokens[tokDec] ,
                   tokens[tokOut]  , tokens[tokIn]  ,
                   tokens[tokBegin], tokens[tokEnd] );
end;

procedure ResetToBrainfuck;
const
  BF_COMMANDS : TArrToken = ('>', '<', '+', '-', '.', ',', '[', ']');
  // Original Brainfuck, as defined by Urban Müller, 1993
begin
  SetBFOperators(BF_COMMANDS);
end;



initialization
  flag.debugmode := false;
  ResetToBrainfuck;
  ResetParser;
  sm.bfIO.Input  := @DefaultInput;
  sm.bfIO.Output := @DefaultOutput;

finalization
  SetLength(sm.datacells, 0);  // free alocated memory for cells
  sm.datacells := nil;

end.
