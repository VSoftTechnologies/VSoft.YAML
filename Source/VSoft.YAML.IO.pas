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

    /// <summary> Decodes the rest of a stream to a string, detecting a BOM and
    ///  defaulting to UTF-8 (the same rules the stream reader applies). </summary>
    class function ReadStreamText(const stream : TStream) : string;static;
  end;

  // Declared in the interface so the lexer can hold it by class type: calls through
  // IInputReader are virtual and cannot inline, and the lexer makes several per char.
  TStringInputReader = class(TInterfacedObject,IInputReader)
  private
    FInput : string;
    FLength : integer;
    FPosition : integer;
    FLine : integer;
    FColumn : integer;
    FIsAtEnd : boolean;

    FSavedPosition : integer;
    FSavedLine : integer;
    FSavedColumn : integer;
    FSavedIsAtEnd : boolean;
  public
    constructor Create(const theString : string);
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

    /// <summary> Advances over a run of characters that need no special handling
    ///  inside a double-quoted scalar (anything except '"', '\' and C0 controls,
    ///  which includes line breaks). Returns the run length; start is its 1-based
    ///  index into Text. </summary>
    function ScanDoubleQuotedRun(out start : integer) : integer;

    /// <summary> Advances over a run of characters that can never end a plain
    ///  scalar: anything except line breaks, '#', ':', ',' and the flow brackets.
    ///  Returns the run length; start is its 1-based index into Text. </summary>
    function ScanPlainScalarRun(out start : integer) : integer;

    /// <summary> Advances count characters that the caller has checked contain no
    ///  line breaks (so only the column moves). </summary>
    procedure AdvanceInLine(count : integer);inline;

    /// <summary> Advances to the next #10/#13 (or the end) and returns the
    ///  rest of the current line. </summary>
    function ReadToLineEnd : string;

    property Text : string read FInput;
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


type

  TStreamInputReader = class(TInterfacedObject, IInputReader)
  private type
    TBufferedData = class(TStringBuilder)
    private
      FStart: Integer;
      FBufferSize: Integer;
      function GetChars(AIndex: Integer): Char; inline;
    public
      constructor Create(ABufferSize: Integer);
      procedure Clear; inline;
      function Length: Integer; inline;
      function PeekChar: Char; overload;inline;
      function PeekChar(n : integer): Char; overload;inline;
      function MoveChar: Char; inline;
      procedure MoveArray(DestinationIndex, Count: Integer; var Destination: TCharArray);
      procedure MoveString(Count, NewPos: Integer; var Destination: string);
      procedure TrimBuffer;
      property Chars[AIndex: Integer]: Char read GetChars;
      property BufferSize : integer read FBufferSize;
      property Position : integer read FStart;
    end;

  private
    FStream : TStream;
    FDetectBOM: Boolean;
    FEncoding: TEncoding;
    FOwnsStream: Boolean;
    FSkipPreamble: Boolean;
    FBOMLength : integer;


    FBufferedData: TBufferedData;
    FNoDataInStream: Boolean;

    FPosition : integer;
    FLine : integer;
    FColumn : integer;
    FCurrentChar : Char;
    FPreviousChar : Char;
    FAtEnd : boolean;

    // Save/restore state fields
    FSavedPosition : integer;
    FSavedLine : integer;
    FSavedColumn : integer;
    FSavedStreamPos : Int64;
    FSavedCurrentChar : Char;
    FSavedPreviousChar : Char;
    FSavedAtEnd : Boolean;
    FSavedNoDataInStream: Boolean;
    FSavedSkipPreamble: Boolean;
    FSavedDetectBOM: Boolean;
    FSavedBufferStart: Integer;

    procedure InitializeReader;
    procedure ReadNextChar;
    function DetectBOM(var Encoding: TEncoding; Buffer: TBytes): Integer;
    function SkipPreamble(Encoding: TEncoding; Buffer: TBytes): Integer;
    procedure FillBuffer(var Encoding: TEncoding);
    function GetEndOfStream: Boolean;
  protected
    function GetPosition : integer;inline;
    function GetLine : integer;inline;
    function GetColumn : integer;inline;
    function GetCurrent : Char;inline;
    function GetPreviousChar : Char;inline;
    function IsAtEnd : boolean;inline;
    function Read : Char;overload;
    function Read(n : integer) : Char;overload;
    function Peek : Char;overload;
    function Peek(n : integer) : Char;overload;
    procedure Save;
    procedure Restore;
    procedure DiscardSave;
  public
    constructor Create(const stream: TStream); overload;
    destructor Destroy; override;
  end;


  TFileInputReader = class(TStreamInputReader, IInputReader)
  public
    constructor Create(const filename: string); overload;
  end;



{ TInputReaderFactory }


class function TInputReaderFactory.CreateFromFile(const fileName: string): IInputReader;
begin
  result := TFileInputReader.Create(fileName);
end;

class function TInputReaderFactory.CreateFromStream(const stream: TStream): IInputReader;
begin
  result := TStreamInputReader.Create(stream)
end;


class function TInputReaderFactory.CreateFromString(const value: string): IInputReader;
begin
  result := TStringInputReader.Create(value);
end;

class function TInputReaderFactory.ReadStreamText(const stream : TStream) : string;
var
  bytes : TBytes;
  chunk, total : integer;
  encoding : TEncoding;
  bomLength : integer;
begin
  if not Assigned(stream) then
    raise EArgumentException.CreateResFmt(@SParamIsNil, ['Stream']); // DO NOT LOCALIZE
  // read in chunks rather than trusting Size, which not every stream supports
  total := 0;
  SetLength(bytes, 65536);
  repeat
    if total = Length(bytes) then
      SetLength(bytes, total * 2);
    chunk := stream.Read(bytes[total], Length(bytes) - total);
    Inc(total, chunk);
  until chunk <= 0;
  SetLength(bytes, total);

  encoding := nil;
  bomLength := TEncoding.GetBufferEncoding(bytes, encoding, nil);
  if encoding = nil then
    encoding := TEncoding.UTF8;
  result := encoding.GetString(bytes, bomLength, total - bomLength);
end;

{ TStringInputReader }

constructor TStringInputReader.Create(const theString: string);
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
  //default to not having saved anything;
  FSavedPosition := -1;
  FSavedLine := -1;
  FSavedColumn := -1;
end;

function TStringInputReader.GetColumn: integer;
begin
  result := FColumn;
end;

function TStringInputReader.GetCurrent: Char;
begin
  if FIsAtEnd then
    result := #0
  else
    result := FInput[FPosition];
end;

function TStringInputReader.GetLine: integer;
begin
  result := FLine;
end;

function TStringInputReader.GetPosition: integer;
begin
  result := FPosition;
end;

function TStringInputReader.GetPreviousChar: Char;
begin
  if FIsAtEnd or (FPosition < 2) or (FPosition > FLength + 1)  then
    result := #0
  else
    result := FInput[FPosition - 1];
end;

function TStringInputReader.IsAtEnd: boolean;
begin
  result := FIsAtEnd;
end;

function TStringInputReader.Peek: Char;
begin
  result := Peek(1);
end;

function TStringInputReader.Peek(n: integer): Char;
var
  i : integer;
begin
  i := FPosition + n;
  if i <= FLength then
    result := FInput[i]
  else
    result := #0;
end;

function TStringInputReader.Read: Char;
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
    FIsAtEnd :=  (FPosition > FLength)
  end;
end;

function TStringInputReader.Read(n: integer): Char;
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

procedure TStringInputReader.Restore;
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

function TStringInputReader.ScanDoubleQuotedRun(out start : integer) : integer;
var
  p : integer;
  ch : Char;
begin
  start := FPosition;
  if FIsAtEnd then
    exit(0);
  p := FPosition;
  while p <= FLength do
  begin
    ch := FInput[p];
    if (ch = '"') or (ch = '\') or (ch < ' ') then
      break;
    Inc(p);
  end;
  result := p - start;
  if result > 0 then
  begin
    // no line breaks in the run, so only the column moves
    Inc(FColumn, result);
    FPosition := p;
    FIsAtEnd := FPosition > FLength;
  end;
end;

function TStringInputReader.ScanPlainScalarRun(out start : integer) : integer;
var
  p : integer;
begin
  start := FPosition;
  if FIsAtEnd then
    exit(0);
  p := FPosition;
  while p <= FLength do
  begin
    case FInput[p] of
      #10, #13, '#', ':', ',', '[', ']', '{', '}' : break;
    end;
    Inc(p);
  end;
  result := p - start;
  if result > 0 then
  begin
    Inc(FColumn, result);
    FPosition := p;
    FIsAtEnd := FPosition > FLength;
  end;
end;

procedure TStringInputReader.AdvanceInLine(count : integer);
begin
  Inc(FColumn, count);
  Inc(FPosition, count);
  FIsAtEnd := FPosition > FLength;
end;

function TStringInputReader.ReadToLineEnd : string;
var
  p, count : integer;
begin
  if FIsAtEnd then
    exit('');
  p := FPosition;
  while (p <= FLength) and (FInput[p] <> #10) and (FInput[p] <> #13) do
    Inc(p);
  count := p - FPosition;
  result := Copy(FInput, FPosition, count);
  if count > 0 then
  begin
    Inc(FColumn, count);
    FPosition := p;
    FIsAtEnd := FPosition > FLength;
  end;
end;

procedure TStringInputReader.Save;
begin
  FSavedPosition := FPosition;
  FSavedLine := FLine;
  FSavedColumn := FColumn;
  FSavedIsAtEnd := FIsAtEnd;
end;

procedure TStringInputReader.DiscardSave;
begin
  FSavedPosition := -1;
end;

{ TStreamInputReader }

constructor TStreamInputReader.Create(const stream: TStream);
begin
  inherited Create;
  if not Assigned(stream) then
    raise EArgumentException.CreateResFmt(@SParamIsNil, ['Stream']); // DO NOT LOCALIZE

  FStream := stream;
  FEncoding := TEncoding.UTF8;
  FBufferedData := TBufferedData.Create(8192);
  FNoDataInStream := False;
  FOwnsStream := False;
  FDetectBOM := True;
  FSkipPreamble := not FDetectBOM;
  FBOMLength := 0;
  InitializeReader;
end;


function TStreamInputReader.GetColumn: integer;
begin
  result := FColumn;
end;

function TStreamInputReader.GetCurrent: Char;
begin
  result := FCurrentChar;
end;

function TStreamInputReader.GetLine: integer;
begin
  result := FLine;
end;

function TStreamInputReader.GetPosition: integer;
begin
  result := FPosition;
end;

function TStreamInputReader.GetPreviousChar: Char;
begin
  result := FPreviousChar;
end;

function TStreamInputReader.IsAtEnd: boolean;
begin
  result := FAtEnd;
end;

function TStreamInputReader.Peek: Char;
begin
  result := Peek(1);
end;

function TStreamInputReader.Peek(n: integer): Char;
begin
  result := #0;

  if n <= 0 then
    Exit;

  if FAtEnd then
    Exit;

  // For n=1, we want the next character (PeekChar())
  // For n>1, we want to look ahead n characters from current position
  if n = 1 then
  begin
    // Ensure we have at least 1 character in buffer
    while (FBufferedData.Length < 1) and (not FNoDataInStream) do
      FillBuffer(FEncoding);

    if (FBufferedData <> nil) and (FBufferedData.Length >= 1) then
      result := FBufferedData.PeekChar;
  end
  else
  begin
    // Ensure we have enough data in buffer for n characters
    while (FBufferedData.Length < n) and (not FNoDataInStream) do
      FillBuffer(FEncoding);

    if (FBufferedData <> nil) and (FBufferedData.Length >= n) then
      result := FBufferedData.PeekChar(n);
  end;
end;

function TStreamInputReader.Read: Char;
begin
  // Return current character and then advance
  result := FCurrentChar;
  if not FAtEnd then
    ReadNextChar;
end;

function TStreamInputReader.Read(n: integer): Char;
var
  i: integer;
begin
  result := #0;
  if n < 0 then
    raise EArgumentException.Create('Input reader cannot read backwards');
    
  // Read n characters, returning the last one
  for i := 1 to n do
  begin
    result := Read;
    if result = #0 then
      Exit;
  end;
end;

procedure TStreamInputReader.Restore;
begin
  if FSavedStreamPos = -1 then
    raise Exception.Create('No saved position');

  // Check if stream position has changed
  if FStream.Position <> FSavedStreamPos then
  begin
    // Stream moved - restore stream position and clear buffer
    FStream.Position := FSavedStreamPos;
    FBufferedData.Clear;
  end
  else
  begin
    // Stream unchanged - just restore buffer position
    FBufferedData.FStart := FSavedBufferStart;
  end;

  // Restore flags
  FNoDataInStream := FSavedNoDataInStream;
  FSkipPreamble := FSavedSkipPreamble;
  FDetectBOM := FSavedDetectBOM;

  // Restore parser state
  FPosition := FSavedPosition;
  FLine := FSavedLine;
  FColumn := FSavedColumn;
  FCurrentChar := FSavedCurrentChar;
  FPreviousChar := FSavedPreviousChar;
  FAtEnd := FSavedAtEnd;

  FSavedStreamPos := -1;
end;

procedure TStreamInputReader.Save;
begin
  // Detect nested saves - should never happen
  if FSavedStreamPos <> -1 then
    raise Exception.Create('Nested save detected - not supported');

  FSavedStreamPos := FStream.Position;
  FSavedBufferStart := FBufferedData.FStart;
  FSavedNoDataInStream := FNoDataInStream;
  FSavedSkipPreamble := FSkipPreamble;
  FSavedDetectBOM := FDetectBOM;

  FSavedPosition := FPosition;
  FSavedLine := FLine;
  FSavedColumn := FColumn;
  FSavedCurrentChar := FCurrentChar;
  FSavedPreviousChar := FPreviousChar;
  FSavedAtEnd := FAtEnd;
end;

procedure TStreamInputReader.DiscardSave;
begin
  FSavedStreamPos := -1;
end;

procedure TStreamInputReader.InitializeReader;
begin
  // Fill buffer initially to get some data
  if not FNoDataInStream then
    FillBuffer(FEncoding);
    
  if GetEndOfStream then
  begin
    FPosition := -1;
    FLine := -1;
    FColumn := -1;
    FAtEnd := True;
    FCurrentChar := #0;
  end
  else
  begin
    FPosition := 1;
    FLine := 1;
    FColumn := 1;
    FAtEnd := False;
    
    // Read the first character from buffer directly like original did
    if (FBufferedData <> nil) and (FBufferedData.Length > 0) then
    begin
      FCurrentChar := FBufferedData.MoveChar;
      FBufferedData.TrimBuffer;
    end
    else
    begin
      FAtEnd := True;
      FCurrentChar := #0;
    end;
  end;
  
  FPreviousChar := #0;

  // Initialize saved state
  FSavedPosition := -1;
  FSavedLine := -1;
  FSavedColumn := -1;
  FSavedStreamPos := -1;
  FSavedCurrentChar := #0;
  FSavedPreviousChar := #0;
  FSavedAtEnd := False;
  FSavedNoDataInStream := False;
  FSavedSkipPreamble := False;
  FSavedDetectBOM := False;
end;

procedure TStreamInputReader.ReadNextChar;
begin
  if FAtEnd then
  begin
    FCurrentChar := #0;
    Exit;
  end;
  
  FPreviousChar := FCurrentChar;
  
  // Read from buffer, filling if needed
  if (FBufferedData = nil) or (FBufferedData.Length < 1) then
  begin
    if not FNoDataInStream then
      FillBuffer(FEncoding);
      
    if (FBufferedData = nil) or (FBufferedData.Length = 0) then
    begin
      FAtEnd := True;
      FCurrentChar := #0;
      Exit;
    end;
  end;

  FCurrentChar := FBufferedData.MoveChar;
  FBufferedData.TrimBuffer;
  Inc(FPosition);

  // Track line and column
  if FPreviousChar = #10 then // LF
  begin
    Inc(FLine);
    FColumn := 1;
  end
  else if (FPreviousChar = #13) and (FCurrentChar <> #10) then // CR not followed by LF
  begin
    Inc(FLine);
    FColumn := 1;
  end
  else if FCurrentChar <> #13 then // Don't increment column for CR
    Inc(FColumn);
end;

{ TStreamInputReader.TBufferedData }

constructor TStreamInputReader.TBufferedData.Create(ABufferSize: Integer);
begin
  inherited Create;
  FBufferSize := ABufferSize;
end;

procedure TStreamInputReader.TBufferedData.Clear;
begin
  inherited Length := 0;
  FStart := 0;
end;

// NOTE: use the public, 0-based TStringBuilder.Chars[]/Length API rather than reaching
// into the FData/FLength internals. The internal buffer layout is not stable across
// Delphi versions (e.g. XE2's FData is 0-based, later RTLs are not), so direct
// FData[FStart + 1] access silently dropped the first character of the stream on XE2.
function TStreamInputReader.TBufferedData.GetChars(AIndex: Integer): Char;
begin
  Result := inherited Chars[FStart + AIndex];
end;

function TStreamInputReader.TBufferedData.Length: Integer;
begin
  Result := inherited Length - FStart;
end;

function TStreamInputReader.TBufferedData.PeekChar: Char;
begin
  Result := inherited Chars[FStart];
end;

function TStreamInputReader.TBufferedData.PeekChar(n : integer): Char;
begin
  Result := inherited Chars[FStart + n - 1];
end;

function TStreamInputReader.TBufferedData.MoveChar: Char;
begin
  Result := inherited Chars[FStart];
  Inc(FStart);
end;

procedure TStreamInputReader.TBufferedData.MoveArray(DestinationIndex, Count: Integer;
  var Destination: TCharArray);
begin
  CopyTo(FStart, Destination, DestinationIndex, Count);
  Inc(FStart, Count);
end;

procedure TStreamInputReader.TBufferedData.MoveString(Count, NewPos: Integer; var Destination: string);
begin
  if (FStart = 0) and (Count = inherited Length) then
  {$IFDEF D10_3PLUS}
    Destination := ToString(True)
  {$ELSE}
    Destination := ToString
  {$ENDIF}
  else
    Destination := ToString(FStart, Count);
  Inc(FStart, NewPos);
end;

procedure TStreamInputReader.TBufferedData.TrimBuffer;
begin
  if inherited Length > FBufferSize then
  begin
    Remove(0, FStart);
    FStart := 0;
  end;
end;

function TStreamInputReader.DetectBOM(var Encoding: TEncoding; Buffer: TBytes): Integer;
var
  LEncoding: TEncoding;
begin
  // try to automatically detect the buffer encoding
  LEncoding := nil;
  Result := TEncoding.GetBufferEncoding(Buffer, LEncoding, nil);
  if LEncoding <> nil then
    Encoding := LEncoding
  else if Encoding = nil then
    Encoding := TEncoding.Default;

  FDetectBOM := False;
end;

function TStreamInputReader.SkipPreamble(Encoding: TEncoding; Buffer: TBytes): Integer;
var
  I: Integer;
  LPreamble: TBytes;
  BOMPresent: Boolean;
begin
  Result := 0;
  LPreamble := Encoding.GetPreamble;
  if (Length(LPreamble) > 0) then
  begin
    if Length(Buffer) >= Length(LPreamble) then
    begin
      BOMPresent := True;
      for I := 0 to Length(LPreamble) - 1 do
        if LPreamble[I] <> Buffer[I] then
        begin
          BOMPresent := False;
          Break;
        end;
      if BOMPresent then
      begin
        Result := Length(LPreamble);

      end;
    end;
  end;
  FSkipPreamble := False;
end;

procedure TStreamInputReader.FillBuffer(var Encoding: TEncoding);
const
  BufferPadding = 4;
var
  LString: string;
  LBuffer: TBytes;
  BytesRead: Integer;
  StartIndex: Integer;
  ByteCount: Integer;
  ByteBufLen: Integer;
  ExtraByteCount: Integer;

  procedure AdjustEndOfBuffer(const ABuffer: TBytes; Offset: Integer);
  var
    Pos, Size: Integer;
    Rewind: Integer;
  begin
    Dec(Offset);
    for Pos := Offset downto 0 do
    begin
      for Size := Offset - Pos + 1 downto 1 do
      begin
        if Encoding.GetCharCount(ABuffer, Pos, Size) > 0 then
        begin
          Rewind := Offset - (Pos + Size - 1);
          if Rewind <> 0 then
          begin
            FStream.Position := FStream.Position - Rewind;
            BytesRead := BytesRead - Rewind;
          end;
          Exit;
        end;
      end;
    end;
  end;

begin
  SetLength(LBuffer, FBufferedData.BufferSize + BufferPadding);

  // Read data from stream
  BytesRead := FStream.Read(LBuffer[0], FBufferedData.BufferSize);
  FNoDataInStream := BytesRead = 0;

  // Check for byte order mark and calc start index for character data
  if FDetectBOM then
    StartIndex := DetectBOM(Encoding, LBuffer)
  else if FSkipPreamble then
    StartIndex := SkipPreamble(Encoding, LBuffer)
  else
    StartIndex := 0;

  // Adjust the end of the buffer to be sure we have a valid encoding
  if not FNoDataInStream then
    AdjustEndOfBuffer(LBuffer, BytesRead);

  // Convert to string and calc byte count for the string
  ByteBufLen := BytesRead - StartIndex;
  LString := FEncoding.GetString(LBuffer, StartIndex, ByteBufLen);
  ByteCount := FEncoding.GetByteCount(LString);

  // If byte count <> number of bytes read from the stream
  // the buffer boundary is mid-character and additional bytes
  // need to be read from the stream to complete the character
  ExtraByteCount := 0;
  while (ByteCount <> ByteBufLen) and (ExtraByteCount < FEncoding.GetMaxByteCount(1)) do
  begin
    // Expand buffer if padding is used
    if (StartIndex + ByteBufLen) = Length(LBuffer) then
      SetLength(LBuffer, Length(LBuffer) + BufferPadding);

    // Read one more byte from the stream into the
    // buffer padding and convert to string again
    BytesRead := FStream.Read(LBuffer[StartIndex + ByteBufLen], 1);
    if BytesRead = 0 then
      // End of stream, append what's been read and discard remaining bytes
      Break;

    Inc(ExtraByteCount);

    Inc(ByteBufLen);
    LString := FEncoding.GetString(LBuffer, StartIndex, ByteBufLen);
    ByteCount := FEncoding.GetByteCount(LString);
  end;

  if FBufferedData.Length < 1 then
    FBufferedData.Clear;
  // Add string to character data buffer
  FBufferedData.Append(LString);
end;

function TStreamInputReader.GetEndOfStream: Boolean;
begin
  if not FNoDataInStream and (FBufferedData <> nil) and (FBufferedData.Length < 1) then
    FillBuffer(FEncoding);
  Result := FNoDataInStream and ((FBufferedData = nil) or (FBufferedData.Length = 0));
end;

{ TFileInputReader }

constructor TFileInputReader.Create(const filename: string);
begin
  inherited Create(TFileStream.Create(filename, fmOpenRead or fmShareDenyWrite));
  FOwnsStream := True;
end;



destructor TStreamInputReader.Destroy;
begin
  if FOwnsStream then
    FreeAndNil(FStream);
  FreeAndNil(FBufferedData);
  inherited;
end;

end.
