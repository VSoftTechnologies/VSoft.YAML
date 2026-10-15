unit VSoft.YAML.IO;

interface

uses
  System.SysUtils,
  System.Classes;

type
  IInputReader = interface
  ['{F4D64EB1-939C-42DE-9C1A-EFD70FF60102}']
    function GetPosition : integer;
    function GetLine : integer;
    function GetColumn : integer;

    function GetCurrent : Char;
    function GetPreviousChar : Char;

    /// <summary> returns true is position is past the end. </summary>
    function IsAtEnd : boolean;


    /// <summary>Increments Position and return current, #0 if past the end </summary>
    function Read : Char;overload;
    //skip ahead n chars
    function Read(n : integer) : Char;overload;
    /// <summary> Look ahead 1 char, returns #0 if past the end. </summary>
    function Peek : Char;overload;

    /// <summary> Look ahead n chars, returns #0 if past the end. </summary>
    function Peek(n : integer) : Char;overload;


    /// <summary> Saves the current state - Position,Line,Column,Current,Previous. </summary>
    procedure Save;
    /// <summary> Restores the previously saved state, raises exception if none</summary>
    procedure Restore;
    /// <summary> Discards the saved state without restoring</summary>
    procedure DiscardSave;

    /// <summary> 1 based current position </summary>
    property Position : integer read GetPosition;

    /// <summary> Current Line - first line is 1</summary>
    property Line     : integer read GetLine;

    /// <summary> Current Column - colum is 1</summary>
    property Column   : integer read GetColumn;

    /// <summary> Returns Current Char if not past the start, otherwise #0 </summary>
    property Current : Char read GetCurrent;

    /// <summary> Returns Previous Char if not at start, otherwise #0 </summary>
    property Previous : Char read GetPreviousChar;

    /// <summary> Returns true if past the end of file </summary>
    property IsEOF : boolean read IsAtEnd;
  end;


  TInputReaderFactory = class
    class function CreateFromString(const value : string ) : IInputReader;static;
    class function CreateFromStream(const stream: TStream) : IInputReader; overload;static;
    class function CreateFromFile(const fileName: string) : IInputReader; overload;static;
  end;

  // Decodes a stream a block at a time: detects a BOM (defaulting to UTF-8) and never
  // splits a character between blocks.
  TStreamTextSource = class
  private
    FStream : TStream;
    FOwnsStream : boolean;
    FEncoding : TEncoding;
    FBytes : TBytes;
    FCarry : integer; // bytes of an incomplete character kept at the front of FBytes
    FFirst : boolean;
    FEOF : boolean;
    function CompleteLength(start, total : integer) : integer;
  public
    /// <summary> Bytes read at a time (at least 8). Tests make it small so that block
    ///  boundaries land everywhere. </summary>
    class var BlockSize : integer;
    constructor Create(const stream : TStream; ownsStream : boolean);
    destructor Destroy; override;
    /// <summary> Decodes the next block. Returns False once the stream is used up. </summary>
    function ReadChunk(out text : string) : boolean;
  end;

  /// <summary> The reader the lexer scans. It reads either a whole string or a stream,
  ///  which it decodes a block at a time into a window: text before the start of the
  ///  current token (see MarkTokenStart) and before any saved position is dropped as
  ///  the window moves on, so a stream is never held in memory whole.
  ///  Positions given to and returned by the run methods (ScanDoubleQuotedRun,
  ///  CopyText, ...) are absolute 1-based indexes into the whole input, and stay valid
  ///  until the next MarkTokenStart. Declared in the interface so the lexer can hold it
  ///  by class type: calls through IInputReader are virtual and cannot inline, and the
  ///  lexer makes several per char. </summary>
  TBufferedInputReader = class(TInterfacedObject,IInputReader)
  private
    FInput : string;     // the window; may have spare capacity past FLength
    FLength : integer;   // chars of FInput in use
    FBase : integer;     // chars dropped from before FInput[1]
    FPosition : integer; // 1-based index into FInput
    FLine : integer;
    FColumn : integer;
    FIsAtEnd : boolean;
    FMark : integer;     // absolute index the window must keep
    FSource : TStreamTextSource; // nil for a string, or once the stream is used up

    FSavedPosition : integer;
    FSavedLine : integer;
    FSavedColumn : integer;
    FSavedIsAtEnd : boolean;

    /// <summary> Appends the next block of the stream to the window, first dropping
    ///  text nothing can refer to any more. Returns False at the end of the input.
    ///  Indexes into FInput move down by any change in FBase. </summary>
    function FillMore : boolean;
    function PeekSlow(n : integer) : Char;
  public
    constructor Create(const theString : string);
    constructor CreateFromStream(const stream : TStream; ownsStream : boolean);
    destructor Destroy; override;
    function GetPosition : integer;inline;
    function GetLine : integer;inline;
    function GetColumn : integer;inline;
    function GetCurrent : Char;inline;
    function GetPreviousChar : Char;inline;
    function IsAtEnd : boolean;inline;
    function Read : Char;overload;inline;
    function Read(n : integer) : Char;overload;
    function Peek : Char;overload;inline;
    function Peek(n : integer) : Char;overload;inline;
    procedure Save;
    procedure Restore;
    procedure DiscardSave;

    /// <summary> Called by the lexer at the start of each token: nothing before the
    ///  current position will be referred to again. </summary>
    procedure MarkTokenStart;inline;

    /// <summary> Advances over a run of characters that need no special handling
    ///  inside a double-quoted scalar (anything except '"', '\' and C0 controls,
    ///  which includes line breaks). Returns the run length; start is its absolute
    ///  index. </summary>
    function ScanDoubleQuotedRun(out start : integer) : integer;

    /// <summary> Advances over a run of characters that can never end a plain
    ///  scalar: anything except line breaks, '#', ':', ',' and the flow brackets.
    ///  Returns the run length; start is its absolute index. </summary>
    function ScanPlainScalarRun(out start : integer) : integer;

    /// <summary> Advances count characters that the caller has checked contain no
    ///  line breaks (so only the column moves). </summary>
    procedure AdvanceInLine(count : integer);inline;

    /// <summary> Advances to the next #10/#13 (or the end) and returns the
    ///  rest of the current line. </summary>
    function ReadToLineEnd : string;

    /// <summary> Text at absolute indexes from a run method. </summary>
    function CopyText(start, count : integer) : string;inline;
    procedure AppendText(const sb : TStringBuilder; start, count : integer);inline;
    function CharAt(index : integer) : Char;inline;

    /// <summary> Direct access to the window for scanning in place: Buffer[1..BufferLength],
    ///  with the current char at BufferPosition. HasMoreInput means the input goes on
    ///  past the window. </summary>
    property Buffer : string read FInput;
    property BufferLength : integer read FLength;
    property BufferPosition : integer read FPosition;
    function HasMoreInput : boolean;inline;

    property Position : integer read GetPosition;
    property Line     : integer read GetLine;
    property Column   : integer read GetColumn;
    property Current : Char read GetCurrent;
    property Previous : Char read GetPreviousChar;
    property IsEOF : boolean read IsAtEnd;
  end;


implementation

uses
  System.RTLConsts;

{$I 'VSoft.YAML.inc'}

const
  cStreamBlockSize = 64 * 1024; // bytes read from a stream at a time


{ TInputReaderFactory }


class function TInputReaderFactory.CreateFromFile(const fileName: string): IInputReader;
begin
  result := TBufferedInputReader.CreateFromStream(TFileStream.Create(fileName, fmOpenRead or fmShareDenyWrite), true);
end;

class function TInputReaderFactory.CreateFromStream(const stream: TStream): IInputReader;
begin
  result := TBufferedInputReader.CreateFromStream(stream, false);
end;


class function TInputReaderFactory.CreateFromString(const value: string): IInputReader;
begin
  result := TBufferedInputReader.Create(value);
end;

{ TStreamTextSource }

constructor TStreamTextSource.Create(const stream : TStream; ownsStream : boolean);
begin
  inherited Create;
  if not Assigned(stream) then
    raise EArgumentException.CreateResFmt(@SParamIsNil, ['Stream']); // DO NOT LOCALIZE
  FStream := stream;
  FOwnsStream := ownsStream;
  if BlockSize < 8 then // room for a BOM plus a carried partial character
    SetLength(FBytes, 8)
  else
    SetLength(FBytes, BlockSize);
  FFirst := true;
end;

destructor TStreamTextSource.Destroy;
begin
  if FOwnsStream then
    FStream.Free;
  inherited;
end;

// How many bytes of FBytes[start..total) end on a character boundary; the rest wait
// for the next block. Only the encodings GetBufferEncoding can report need handling.
function TStreamTextSource.CompleteLength(start, total : integer) : integer;
var
  i, lead, need : integer;
  unitValue : Word;
begin
  result := total;
  case FEncoding.CodePage of
    65001 : // UTF-8: back up over continuation bytes to the lead byte
    begin
      i := total - 1;
      while (i >= start) and (i > total - 4) and ((FBytes[i] and $C0) = $80) do
        Dec(i);
      if i < start then
        exit;
      lead := FBytes[i];
      if lead >= $F0 then
        need := 4
      else if lead >= $E0 then
        need := 3
      else if lead >= $C0 then
        need := 2
      else
        need := 1;
      if i + need > total then
        result := i;
    end;
    1200, 1201 : // UTF-16: whole code units, and keep a pair's high surrogate back
    begin
      result := start + ((total - start) and not 1);
      if result - start >= 2 then
      begin
        if FEncoding.CodePage = 1200 then
          unitValue := FBytes[result - 2] or (FBytes[result - 1] shl 8)
        else
          unitValue := (FBytes[result - 2] shl 8) or FBytes[result - 1];
        if (unitValue >= $D800) and (unitValue <= $DBFF) then
          Dec(result, 2);
      end;
    end;
  end;
end;

function TStreamTextSource.ReadChunk(out text : string) : boolean;
var
  total, n, start, complete : integer;
  head : TBytes;
begin
  text := '';
  while true do
  begin
    if FEOF and (FCarry = 0) then
      exit(false);
    total := FCarry;
    if not FEOF then
    begin
      // the first block must hold a whole BOM, so read until it has 4 bytes
      repeat
        n := FStream.Read(FBytes[total], Length(FBytes) - total);
        if n <= 0 then
          FEOF := true
        else
          Inc(total, n);
      until FEOF or not FFirst or (total >= 4);
    end;
    start := 0;
    if FFirst then
    begin
      FFirst := false;
      head := Copy(FBytes, 0, total);
      FEncoding := nil;
      start := TEncoding.GetBufferEncoding(head, FEncoding, nil);
      if FEncoding = nil then
        FEncoding := TEncoding.UTF8;
    end;
    if FEOF then
      complete := total
    else
      complete := CompleteLength(start, total);
    if complete > start then
      text := FEncoding.GetString(FBytes, start, complete - start);
    FCarry := total - complete;
    if FCarry > 0 then
      Move(FBytes[complete], FBytes[0], FCarry);
    if text <> '' then
      exit(true);
  end;
end;

{ TBufferedInputReader }

constructor TBufferedInputReader.Create(const theString: string);
begin
  FInput := theString;
  FLength := Length(FInput);
  if FLength > 0 then
  begin
    FPosition := 1;  // Start at first character
    FLine := 1;
    FColumn := 1;    // First column
  end
  else
  begin
    FPosition := -1;
    FLine := -1;
    FColumn := -1;
    FIsAtEnd := true;
  end;
  FMark := 1;
  //default to not having saved anything;
  FSavedPosition := -1;
  FSavedLine := -1;
  FSavedColumn := -1;
end;

constructor TBufferedInputReader.CreateFromStream(const stream : TStream; ownsStream : boolean);
begin
  try
    FSource := TStreamTextSource.Create(stream, ownsStream);
  except
    if ownsStream then
      stream.Free;
    raise;
  end;
  FMark := 1;
  FSavedPosition := -1;
  FSavedLine := -1;
  FSavedColumn := -1;
  FPosition := 1;
  if FillMore then
  begin
    FLine := 1;
    FColumn := 1;
  end
  else
  begin
    FPosition := -1;
    FLine := -1;
    FColumn := -1;
    FIsAtEnd := true;
  end;
end;

destructor TBufferedInputReader.Destroy;
begin
  FSource.Free;
  inherited;
end;

function TBufferedInputReader.FillMore : boolean;
var
  chunk : string;
  keep, drop, need, capacity : integer;
begin
  result := false;
  if FSource = nil then
    exit;
  if not FSource.ReadChunk(chunk) then
  begin
    FreeAndNil(FSource);
    exit;
  end;

  // keep the previous char, any saved position and the current token
  keep := FPosition - 1;
  if (FSavedPosition <> -1) and (FSavedPosition < keep) then
    keep := FSavedPosition;
  if FMark - FBase < keep then
    keep := FMark - FBase;
  if keep < 1 then
    keep := 1;
  drop := keep - 1;
  // only move the kept text down once that frees at least half the window, so a
  // token longer than a block costs amortised linear time, not quadratic
  if (drop > 0) and (drop >= FLength div 2) then
  begin
    Move(FInput[keep], FInput[1], (FLength - drop) * SizeOf(Char));
    Dec(FLength, drop);
    Inc(FBase, drop);
    Dec(FPosition, drop);
    if FSavedPosition <> -1 then
      Dec(FSavedPosition, drop);
  end;

  need := FLength + Length(chunk);
  if need > Length(FInput) then
  begin
    capacity := 2 * Length(FInput);
    if capacity < need then
      capacity := need;
    SetLength(FInput, capacity);
  end;
  Move(chunk[1], FInput[FLength + 1], Length(chunk) * SizeOf(Char));
  FLength := need;
  result := true;
end;

function TBufferedInputReader.HasMoreInput : boolean;
begin
  result := FSource <> nil;
end;

procedure TBufferedInputReader.MarkTokenStart;
begin
  FMark := FBase + FPosition;
end;

function TBufferedInputReader.CopyText(start, count : integer) : string;
begin
  result := Copy(FInput, start - FBase, count);
end;

procedure TBufferedInputReader.AppendText(const sb : TStringBuilder; start, count : integer);
begin
  sb.Append(FInput, start - FBase - 1, count);
end;

function TBufferedInputReader.CharAt(index : integer) : Char;
begin
  result := FInput[index - FBase];
end;

function TBufferedInputReader.GetColumn: integer;
begin
  result := FColumn;
end;

function TBufferedInputReader.GetCurrent: Char;
begin
  if FIsAtEnd then
    result := #0
  else
    result := FInput[FPosition];
end;

function TBufferedInputReader.GetLine: integer;
begin
  result := FLine;
end;

function TBufferedInputReader.GetPosition: integer;
begin
  if FPosition < 0 then
    result := FPosition
  else
    result := FBase + FPosition;
end;

function TBufferedInputReader.GetPreviousChar: Char;
begin
  if FIsAtEnd or (FPosition < 2) or (FPosition > FLength + 1)  then
    result := #0
  else
    result := FInput[FPosition - 1];
end;

function TBufferedInputReader.IsAtEnd: boolean;
begin
  result := FIsAtEnd;
end;

function TBufferedInputReader.Peek: Char;
begin
  result := Peek(1);
end;

function TBufferedInputReader.Peek(n: integer): Char;
var
  i : integer;
begin
  i := FPosition + n;
  if i <= FLength then
    result := FInput[i]
  else if FSource <> nil then
    result := PeekSlow(n)
  else
    result := #0;
end;

function TBufferedInputReader.PeekSlow(n : integer) : Char;
begin
  while FPosition + n > FLength do
    if not FillMore then
      exit(#0);
  result := FInput[FPosition + n];
end;

function TBufferedInputReader.Read: Char;
begin
  // Return current character and then advance
  result := GetCurrent;

  if FPosition <= FLength then
  begin
    Inc(FPosition);
    if result = #10 then
    begin
      Inc(FLine);
      FColumn := 1;
    end
    else if result <> #13 then
      Inc(FColumn);
    if FPosition > FLength then
      FIsAtEnd := not FillMore;
  end;
end;

function TBufferedInputReader.Read(n: integer): Char;
var
  i : integer;
begin
  result := #0;
  if n < 0 then
    raise EArgumentException.Create('Input reader cannot read backwards');
  //do it this way for line/column tracking
  for i := 1 to n do
  begin
    result := Read;
    if result = #0 then
      exit;
  end;
end;

procedure TBufferedInputReader.Restore;
begin
  if FSavedPosition <> -1 then
  begin
    FPosition := FSavedPosition;
    FLine := FSavedLine;
    FColumn := FSavedColumn;
    FIsAtEnd := FSavedIsAtEnd;
    FSavedPosition := -1;
  end
  else
    raise Exception.Create('No saved position');
end;

function TBufferedInputReader.ScanDoubleQuotedRun(out start : integer) : integer;
var
  p, base : integer;
  ch : Char;
begin
  start := FBase + FPosition;
  if FIsAtEnd then
    exit(0);
  p := FPosition;
  while true do
  begin
    while p <= FLength do
    begin
      ch := FInput[p];
      if (ch = '"') or (ch = '\') or (ch < ' ') then
        break;
      Inc(p);
    end;
    if p <= FLength then
      break;
    base := FBase;
    if not FillMore then
      break;
    Dec(p, FBase - base);
  end;
  result := FBase + p - start;
  if result > 0 then
  begin
    // no line breaks in the run, so only the column moves
    Inc(FColumn, result);
    FPosition := p;
    FIsAtEnd := FPosition > FLength; // FillMore has already failed if so
  end;
end;

function TBufferedInputReader.ScanPlainScalarRun(out start : integer) : integer;
var
  p, base : integer;
begin
  start := FBase + FPosition;
  if FIsAtEnd then
    exit(0);
  p := FPosition;
  while true do
  begin
    while p <= FLength do
    begin
      case FInput[p] of
        #10, #13, '#', ':', ',', '[', ']', '{', '}' : break;
      end;
      Inc(p);
    end;
    if p <= FLength then
      break;
    base := FBase;
    if not FillMore then
      break;
    Dec(p, FBase - base);
  end;
  result := FBase + p - start;
  if result > 0 then
  begin
    Inc(FColumn, result);
    FPosition := p;
    FIsAtEnd := FPosition > FLength;
  end;
end;

procedure TBufferedInputReader.AdvanceInLine(count : integer);
begin
  Inc(FColumn, count);
  Inc(FPosition, count);
  if FPosition > FLength then
    FIsAtEnd := not FillMore;
end;

function TBufferedInputReader.ReadToLineEnd : string;
var
  p, base, start, count : integer;
begin
  if FIsAtEnd then
    exit('');
  start := FBase + FPosition;
  p := FPosition;
  while true do
  begin
    while (p <= FLength) and (FInput[p] <> #10) and (FInput[p] <> #13) do
      Inc(p);
    if p <= FLength then
      break;
    base := FBase;
    if not FillMore then
      break;
    Dec(p, FBase - base);
  end;
  count := FBase + p - start;
  result := Copy(FInput, start - FBase, count);
  if count > 0 then
  begin
    Inc(FColumn, count);
    FPosition := p;
    FIsAtEnd := FPosition > FLength;
  end;
end;

procedure TBufferedInputReader.Save;
begin
  FSavedPosition := FPosition;
  FSavedLine := FLine;
  FSavedColumn := FColumn;
  FSavedIsAtEnd := FIsAtEnd;
end;

procedure TBufferedInputReader.DiscardSave;
begin
  FSavedPosition := -1;
end;

initialization
  TStreamTextSource.BlockSize := cStreamBlockSize;

end.
