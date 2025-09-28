unit VSoft.YAML.StreamReader;

interface

{$I 'VSoft.YAML.inc'}

//The reason this exists is because the RTL TStreamReader has no ability to save it's position and then
//later revert back to that position.

uses
	System.SysUtils,
	System.Classes;

type
  TYAMLStreamReader = class(TTextReader)
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
    end;

  private
    FBufferSize: Integer;
    FDetectBOM: Boolean;
    FEncoding: TEncoding;
    FOwnsStream: Boolean;
    FSkipPreamble: Boolean;
    FStream: TStream;
    // Save/restore state fields
    FSavedStreamPos: Int64;
    FSavedBufferData: string;
    FSavedBufferStart: Integer;
    FSavedNoDataInStream: Boolean;
    FSavedSkipPreamble: Boolean;
    FSavedDetectBOM: Boolean;

    function DetectBOM(var Encoding: TEncoding; Buffer: TBytes): Integer;
    function SkipPreamble(Encoding: TEncoding; Buffer: TBytes): Integer;
  protected
    FBufferedData: TBufferedData;
    FNoDataInStream: Boolean;
    procedure FillBuffer(var Encoding: TEncoding);
    function GetEndOfStream: Boolean; {$IFDEF D12PLUS } override; {$ENDIF}
  public
    constructor Create(Stream: TStream); overload;
    constructor Create(Stream: TStream; DetectBOM: Boolean); overload;
    constructor Create(Stream: TStream; Encoding: TEncoding;
      DetectBOM: Boolean = False; BufferSize: Integer = 8192); overload;
    constructor Create(const Filename: string); overload;
    constructor Create(const Filename: string; DetectBOM: Boolean); overload;
    constructor Create(const Filename: string; Encoding: TEncoding;
      DetectBOM: Boolean = False; BufferSize: Integer = 8192); overload;
    destructor Destroy; override;
    procedure Close; override;
    procedure DiscardBufferedData;
    procedure OwnStream; inline;
    function Peek: Integer; overload;override;
    function Peek(n : integer): Integer;reintroduce;overload;
    function Read: Integer; overload; override;

    {$IFDEF XE3PLUS}
    function Read(var Buffer: TCharArray; Index, Count: Integer): Integer; overload; override;
    function ReadBlock(var Buffer: TCharArray; Index, Count: Integer): Integer; override;
    {$ELSE}
    function Read(const Buffer: TCharArray; Index, Count: Integer): Integer; overload; override;
    function ReadBlock(const Buffer: TCharArray; Index, Count: Integer): Integer; override;
    {$ENDIF}
    function ReadLine: string; override;
    function ReadToEnd: string; override;
  	procedure SavePosition;
	  procedure RestorePosition;
    procedure Rewind; {$IFDEF D10_3PLUS} override; {$ENDIF}
    property BaseStream: TStream read FStream;
    property CurrentEncoding: TEncoding read FEncoding;
    property EndOfStream: Boolean read GetEndOfStream;
  end;

implementation

uses
  System.RTLConsts;

constructor TYAMLStreamReader.TBufferedData.Create(ABufferSize: Integer);
begin
  inherited Create;
  FBufferSize := ABufferSize;
end;

procedure TYAMLStreamReader.TBufferedData.Clear;
begin
  inherited Length := 0;
  FStart := 0;
end;

function TYAMLStreamReader.TBufferedData.GetChars(AIndex: Integer): Char;
begin
  Result := FData[FStart + 1 + AIndex];
end;

function TYAMLStreamReader.TBufferedData.Length: Integer;
begin
  Result := FLength - FStart;
end;

function TYAMLStreamReader.TBufferedData.PeekChar: Char;
begin
  Result := FData[FStart + 1];
end;

function TYAMLStreamReader.TBufferedData.PeekChar(n : integer): Char;
begin
  Result := FData[FStart + n];
end;


function TYAMLStreamReader.TBufferedData.MoveChar: Char;
begin
  Result := FData[FStart + 1];
  Inc(FStart);
end;

procedure TYAMLStreamReader.TBufferedData.MoveArray(DestinationIndex, Count: Integer;
  var Destination: TCharArray);
begin
  CopyTo(FStart, Destination, DestinationIndex, Count);
  Inc(FStart, Count);
end;

procedure TYAMLStreamReader.TBufferedData.MoveString(Count, NewPos: Integer; var Destination: string);
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

procedure TYAMLStreamReader.TBufferedData.TrimBuffer;
begin
  if inherited Length > FBufferSize then
  begin
    Remove(0, FStart);
    FStart := 0;
  end;
end;




constructor TYAMLStreamReader.Create(Stream: TStream);
begin
  Create(Stream, TEncoding.UTF8, True);
end;

constructor TYAMLStreamReader.Create(Stream: TStream; DetectBOM: Boolean);
begin
  Create(Stream, TEncoding.UTF8, DetectBOM);
end;

constructor TYAMLStreamReader.Create(Stream: TStream; Encoding: TEncoding;
  DetectBOM: Boolean; BufferSize: Integer);
begin
  inherited Create;

  if not Assigned(Stream) then
    raise EArgumentException.CreateResFmt(@SParamIsNil, ['Stream']); // DO NOT LOCALIZE
  if not Assigned(Encoding) then
    raise EArgumentException.CreateResFmt(@SParamIsNil, ['Encoding']); // DO NOT LOCALIZE

  FEncoding := Encoding;
  FBufferSize := BufferSize;
  if FBufferSize < 128 then
    FBufferSize := 128;
  FBufferedData := TBufferedData.Create(FBufferSize);
  FNoDataInStream := False;
  FStream := Stream;
  FOwnsStream := False;
  FDetectBOM := DetectBOM;
  FSkipPreamble := not FDetectBOM;
end;

constructor TYAMLStreamReader.Create(const Filename: string; Encoding: TEncoding;
  DetectBOM: Boolean; BufferSize: Integer);
begin
  Create(TFileStream.Create(Filename, fmOpenRead or fmShareDenyWrite), Encoding, DetectBOM, BufferSize);
  FOwnsStream := True;
end;

constructor TYAMLStreamReader.Create(const Filename: string; DetectBOM: Boolean);
begin
  Create(TFileStream.Create(Filename, fmOpenRead or fmShareDenyWrite), DetectBOM);
  FOwnsStream := True;
end;

constructor TYAMLStreamReader.Create(const Filename: string);
begin
  Create(TFileStream.Create(Filename, fmOpenRead or fmShareDenyWrite));
  FOwnsStream := True;
end;

destructor TYAMLStreamReader.Destroy;
begin
  Close;
  inherited;
end;

procedure TYAMLStreamReader.Close;
begin
  if FOwnsStream then
    FreeAndNil(FStream);
  FreeAndNil(FBufferedData);
end;

procedure TYAMLStreamReader.DiscardBufferedData;
begin
  if FBufferedData <> nil then
  begin
    FBufferedData.Clear;
    FNoDataInStream := False;
  end;
end;

function TYAMLStreamReader.DetectBOM(var Encoding: TEncoding; Buffer: TBytes): Integer;
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

procedure TYAMLStreamReader.FillBuffer(var Encoding: TEncoding);
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
  SetLength(LBuffer, FBufferSize + BufferPadding);

  // Read data from stream
  BytesRead := FStream.Read(LBuffer[0], FBufferSize);
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

function TYAMLStreamReader.GetEndOfStream: Boolean;
begin
  if not FNoDataInStream and (FBufferedData <> nil) and (FBufferedData.Length < 1) then
    FillBuffer(FEncoding);
  Result := FNoDataInStream and ((FBufferedData = nil) or (FBufferedData.Length = 0));
end;

procedure TYAMLStreamReader.OwnStream;
begin
  FOwnsStream := True;
end;

function TYAMLStreamReader.Peek: Integer;
var
  LData: TBufferedData;
begin
  LData := FBufferedData;
  if not Assigned(LData) or (LData.Length < 1) and EndOfStream then
    Result := -1
  else
    Result := Integer(LData.PeekChar);
end;


function TYAMLStreamReader.Peek(n : integer): Integer;
var
  LData: TBufferedData;
begin
  LData := FBufferedData;
  if not Assigned(LData) or (LData.Length < 1) or (LData.Length >= n) and EndOfStream then
    Result := -1
  else
    Result := Integer(LData.PeekChar(n));
end;


{$IFDEF XE3PLUS}
function TYAMLStreamReader.Read(var Buffer: TCharArray; Index, Count: Integer): Integer;
{$ELSE}
function TYAMLStreamReader.Read(const Buffer: TCharArray; Index, Count: Integer): Integer;
{$ENDIF}
begin
  Result := -1;
  if (FBufferedData <> nil) and (not EndOfStream) then
  begin
    while (FBufferedData.Length < Count) and (not EndOfStream) and (not FNoDataInStream) do
      FillBuffer(FEncoding);

    if FBufferedData.Length > Count then
      Result := Count
    else
      Result := FBufferedData.Length;

  {$IFDEF XE3PLUS}
    FBufferedData.MoveArray(Index, Result, Buffer);
    FBufferedData.TrimBuffer;
  {$ELSE}
    FBufferedData.CopyTo(0, Buffer, Index, Result);
    FBufferedData.Remove(0, Result);
  {$ENDIF}
  end;
end;

{$IFDEF XE3PLUS}
function TYAMLStreamReader.ReadBlock(var Buffer: TCharArray; Index, Count: Integer): Integer;
{$ELSE}
function TYAMLStreamReader.ReadBlock(const Buffer: TCharArray; Index, Count: Integer): Integer;
{$ENDIF}
begin
  Result := Read(Buffer, Index, Count);
end;

function TYAMLStreamReader.Read: Integer;
var
  LData: TBufferedData;
begin
  LData := FBufferedData;
  if not Assigned(LData) or (LData.Length < 1) and EndOfStream then
    Result := -1
  else
    Result := Integer(LData.MoveChar);
end;

function TYAMLStreamReader.ReadLine: string;
var
  NewLineIndex: Integer;
  PostNewLineIndex: Integer;
  LChar: Char;
  LData: TBufferedData;
begin
  LData := FBufferedData;
  Result := '';
  if LData = nil then
    Exit;
  NewLineIndex := 0;
  PostNewLineIndex := 0;

  while True do
  begin
    if (NewLineIndex + 2 > LData.Length) and (not FNoDataInStream) then
      FillBuffer(FEncoding);

    if NewLineIndex >= LData.Length then
    begin
      if FNoDataInStream then
      begin
        PostNewLineIndex := NewLineIndex;
        Break;
      end
      else
      begin
        FillBuffer(FEncoding);
        if LData.Length = 0 then
          Break;
      end;
    end;
    LChar := LData.Chars[NewLineIndex];
    if LChar = #10 then
    begin
      PostNewLineIndex := NewLineIndex + 1;
      Break;
    end
    else if LChar = #13 then
    begin
      if (NewLineIndex + 1 < LData.Length) and (LData.Chars[NewLineIndex + 1] = #10) then
        PostNewLineIndex := NewLineIndex + 2
      else
        PostNewLineIndex := NewLineIndex + 1;
      Break;
    end;

    Inc(NewLineIndex);
  end;

  LData.MoveString(NewLineIndex, PostNewLineIndex, Result);
  LData.TrimBuffer;
end;

function TYAMLStreamReader.ReadToEnd: string;
begin
  Result := '';
  if (FBufferedData <> nil) and (not EndOfStream) then
  begin
    repeat
      FillBuffer(FEncoding);
    until FNoDataInStream;
    FBufferedData.MoveString(FBufferedData.Length, FBufferedData.Length, Result);
    FBufferedData.Clear;
  end;
end;

function TYAMLStreamReader.SkipPreamble(Encoding: TEncoding; Buffer: TBytes): Integer;
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
        Result := Length(LPreamble);
    end;
  end;
  FSkipPreamble := False;
end;

procedure TYAMLStreamReader.Rewind;
begin
  DiscardBufferedData;
  FSkipPreamble := not FDetectBOM;
  FStream.Position := 0;
end;

procedure TYAMLStreamReader.SavePosition;
begin
  FSavedStreamPos := FStream.Position;
  FSavedBufferStart := FBufferedData.FStart;
  FSavedNoDataInStream := FNoDataInStream;
  FSavedSkipPreamble := FSkipPreamble;
  FSavedDetectBOM := FDetectBOM;

  // Save current unconsumed buffer contents as string
  if FBufferedData.Length > 0 then
    FSavedBufferData := FBufferedData.ToString(FBufferedData.FStart, FBufferedData.Length)
  else
    FSavedBufferData := '';
end;

procedure TYAMLStreamReader.RestorePosition;
begin
  // Restore stream position
  FStream.Position := FSavedStreamPos;
  
  // Restore flags
  FNoDataInStream := FSavedNoDataInStream;
  FSkipPreamble := FSavedSkipPreamble;
  FDetectBOM := FSavedDetectBOM;
  
  // Rebuild buffer with saved unconsumed data
  FBufferedData.Clear;
  
  if FSavedBufferData <> '' then
  begin
    FBufferedData.Append(FSavedBufferData);
    // Reset FStart to 0 since we only saved the unconsumed portion
    FBufferedData.FStart := 0;
  end;
end;


end.
