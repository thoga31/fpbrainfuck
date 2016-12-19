{$MODE objfpc}
// {$MODESWITCH advancedrecords}
program brainfuck;
uses
  sysutils,
  fpbrainfuck,  // interpreter - portable for other programs.
  fpbfarg;      // specific unit to manage parameters - not portable for other programs!

const
  CRLF = {$IFDEF windows} #13 + {$ENDIF} #10;
  VERSION = '1.1.0';

(* Natively supported Brainfuck-like regular variants *)
const
  //           BRAINFUCK:    >      <      +      -      .      ,      [      ]      // As defined by Urban Müller, 1993
  MORSEFUCK : TArrToken = ('.--', '--.', '..-', '-..', '-.-', '.-.', '---', '...');  // As defined by Igor Nunes, 2016
  BITFUCK   : TArrToken = ('001', '000', '010', '011', '100', '101', '110', '111');  // As defined by Nuno Picado, 2016

(*
  HALT CODES
    0 = success
    1 = no arguments given
    2 = source file does no exist
    3 = external brainfuck-like language definition does not exist or is invalid
    4 = source file does not contain a correct number of characters
    5 = controlled internal error
    6 = uncontrolled general error
    9 = unimplemented feature
*)
type
  TExitOutput = procedure (n : byte; s : string);

var
  err_unexpected_message : string = '';

procedure WriteExit(n : byte; s : string);
begin
  writeln(CRLF, n:2, ': ', s);
end;

function ShowExitMessage(const exitcode : byte; print : TExitOutput) : byte;
(* Shows the meaning of the exit code and returns it unchanged *)
begin
  case exitcode of
    0 : {default} ;
    1 : print(exitcode, 'No arguments given.');
    2 : print(exitcode, 'Source file does not exist.');
    3 : print(exitcode, 'External brainfuck-like language definition does not exist or is invalid.');
    4 : print(exitcode, 'Source file does not contain a correct number of characters.');
    5 : print(exitcode, 'Controlled internal error.');
    6 : print(exitcode, 'Uncontrolled general error' + err_unexpected_message + '.');
    9 : print(exitcode, 'Unimplemented feature.');
  end;
  ShowExitMessage := exitcode;
end;

function Main(ps : TSetParam) : byte;
{$MACRO on}
{$DEFINE __err := begin Main:=}
{$DEFINE err__ := ;Exit; end}
{$DEFINE __void__ := begin __err 9 err__ end}
begin
  try
    if ParamCount < 1 then
      Halt(1);

    ps := GetParamSet;
    case GetFucker(ps) of
      bfBrain : {default case, already loaded} ;
      bfMorse : SetBFCommands(MORSEFUCK);
      bfBit   : SetBFCommands(BITFUCK)  ;
      bfOther : __void__;
    end;

    if not ExecuteBrainfuck(ParamStr(ParamCount)) then
      __err 5 err__
    else
      write(CRLF, 'I''m done brainfucking for now... geez! Give me some vodka... -.-''');
  except
    on e : Exception do begin
      __err 6 err__;
      err_unexpected_message := e.message;
    end;
  end;
end;


begin
  writeln('Regular Brainfuck-like Languages Interpreter');
  writeln('By: Igor Nunes. Version: ', VERSION,'. Unit Version: ', fpbrainfuck.version);
  writeln;

  if ParamCount < 1 then
    writeln('No source file given for brainfucking! Too scared to try it? :P')
  else if ParamCount > 1 then
    writeln('You''ve given a source file and more! I just need the source file, my dear brainfucker! ;)')
  else if not ExecuteBrainfuck(ParamStr(1)) then
    writeln('Dude! Where the heck is this source file?')
  else
    write(CRLF, 'I''m done brainfucking for now... geez! Give me some vodka... -.-''');

  {$IFDEF windows}
    readln;
  {$ELSE}
    writeln;
  {$ENDIF}

  Halt(0);  // END OF INITIAL INTERPRETER


  (* ===== NEW INTERPRETER in development ===== *)

  Halt(ShowExitMessage(Main(GetParamSet), @WriteExit));
end.
