{$MODE objfpc}
{$MODESWITCH advancedrecords}
unit fpbftype;

interface

type
  TToken = string;
  TTokenEnum = (tokNext , tokPrev,
                tokInc  , tokDec ,
                tokOut  , tokIn  ,
                tokBegin, tokEnd );
  TArrToken  = array[TTokenEnum] of TToken;

  TBFCode    = record
    private
      tokens : array of TTokenEnum;
      idx : longword;
    public
      property Count : longword read idx;
      function Token(i : longword) : TTokenEnum;
      procedure Append(tok : TTokenEnum);
  end;

  TStackOfWord = record
    private
      idx  : longword;
      data : array of word;
    public
      property Count : longword read idx;
      function Pop : word;
      function Peek : word;
      procedure Push(n : word);
      function IsEmpty : boolean;
  end;


const
  TOKENUM : set of TTokenEnum = [tokNext , tokPrev,
                                 tokInc  , tokDec ,
                                 tokOut  , tokIn  ,
                                 tokBegin, tokEnd ];


implementation
uses
  SysUtils;

const
  INITSIZE = 65535;

{$REGION TBFCode}
function TBFCode.Token(i : longword) : TTokenEnum;
begin
  if i <= self.idx then
    Token := self.tokens[i];
  // else raise exception?
end;

procedure TBFCode.Append(tok : TTokenEnum);
begin
  if Length(self.tokens) = 0 then begin
    self.idx := 0;
    SetLength(self.tokens, INITSIZE);
    self.tokens[self.idx] := tok;
  end else begin
    if (self.idx > 0) and ((self.Count mod INITSIZE) = 0) then
      SetLength(self.tokens, Length(self.tokens) + INITSIZE);
    Inc(self.idx);
    self.tokens[self.idx] := tok;
  end;
end;
{$ENDREGION}

{$REGION TStackOfWord}
function TStackOfWord.Pop : word;
begin
  Pop := self.Peek;
  Dec(self.idx);
end;

function TStackOfWord.Peek : word;
begin
  Peek := self.data[idx];
end;

procedure TStackOfWord.Push(n : word);
begin
  if Length(self.data) = 0 then begin
    self.idx := 0;
    SetLength(self.data, INITSIZE);
    self.data[self.idx] := n;
  end else begin
    if (self.idx > 0) and ((self.idx mod INITSIZE) = 0) then
      SetLength(self.data, Length(self.data) + INITSIZE);
    Inc(self.idx);
    self.data[self.idx] := n;
  end;
end;

function TStackOfWord.IsEmpty : boolean;
begin
  IsEmpty := self.idx = 0;
end;
{$ENDREGION}

end.
