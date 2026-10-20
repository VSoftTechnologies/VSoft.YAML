unit VSoft.YAML.StreamWriter;

interface

uses
  System.SysUtils,
  System.Classes;

type
  TYAMLWriter = class
    FNewLine: string;

  public
    procedure Write(const Value: string); virtual; abstract;
    procedure WriteLine(const Value: string); overload; virtual; abstract;
    procedure WriteLine; overload; virtual; abstract;
    procedure Flush;virtual;abstract;

    property NewLine: string read FNewLine write FNewLine;
  end;

  TYAMLStreamWriter = class(TYAMLWriter)
  private
    FStream: TStream;
    FEncoding: TEncoding;
    FNewLine: string;
    FNewLineBytes: TBytes;
    FAutoFlush: Boolean;
    FOwnsStream: Boolean;
    procedure SetNewLine(const Value: string);
  protected
    FBufferIndex: Integer;
    FBuffer: TBytes;
    procedure WriteBytes(Bytes: TBytes);
  public
    constructor Create(const Stream: TStream); overload;
    constructor Create(const Stream: TStream; WriteBOM : boolean; Encoding: TEncoding; BufferSize: Integer = 8192); overload;
    constructor Create(const Filename: string); overload;
    constructor Create(const Filename: string; WriteBOM : boolean; Encoding: TEncoding; BufferSize: Integer = 8192); overload;
    destructor Destroy; override;
    procedure Close;
    procedure Flush;override;
    procedure OwnStream; inline;
    procedure Write(const Value: string); override;
    procedure WriteLine; override;
    procedure WriteLine(const Value: string); override;
    property AutoFlush: Boolean read FAutoFlush write FAutoFlush;
    property NewLine: string read FNewLine write SetNewLine;
    property Encoding: TEncoding read FEncoding;
    property BaseStream: TStream read FStream;
  end;

  TYAMLStringWriter = class(TYAMLWriter)
  private
    FStringBuilder : TStringBuilder;
  public
    constructor Create;
    destructor Destroy;override;
    procedure Close;
    procedure Flush;override;
    procedure Write(const Value: string); override;
    procedure WriteLine(const Value: string); override;
    function ToString : string;override;
  end;

  /// <summary>
  ///  The writers' output sink. Text is appended straight into a UTF-16 buffer (no
  ///  per-piece strings, virtual calls or byte arrays). For string output, full buffers
  ///  are set aside as chunks and joined once at the end, so each character is copied
  ///  once (growing one big string re-copies it at every doubling); for stream output
  ///  the buffer is encoded and written as it fills, never splitting a surrogate pair.
  /// </summary>
  TYAMLOutputBuffer = class
  private
    FBuffer : string;
    FLength : integer;
    FCapacity : integer;
    FStream : TStream;      // nil for string output
    FEncoding : TEncoding;
    FChunks : TArray<string>;      // string output: filled buffers, in order
    FChunkLengths : TArray<integer>;
    FChunkCount : integer;
    FChunkedLength : integer;      // total characters in FChunks
    procedure MakeRoom(count : integer);
    procedure WriteChunk(count : integer);
  public
    constructor CreateForString(initialCapacity : integer = 65536);
    constructor CreateForStream(const stream : TStream; const encoding : TEncoding; writeBOM : boolean; chunkChars : integer = 32768);
    destructor Destroy; override;
    procedure Write(const value : string); overload; inline;
    procedure Write(p : PChar; count : integer); overload;
    procedure WriteChar(ch : Char); inline;
    procedure WriteSpaces(count : integer);
    procedure WriteNewLine; inline;
    procedure WriteLine(const value : string); inline;
    /// <summary> Stream output: writes out everything buffered. </summary>
    procedure Flush;
    /// <summary> String output: returns the text and empties the buffer. </summary>
    function ExtractString : string;
  end;


implementation

procedure TYAMLStreamWriter.Close;
begin
  Flush;
  if FOwnsStream  then
    FreeAndNil(FStream);
end;

constructor TYAMLStreamWriter.Create(const Stream: TStream);
begin
  inherited Create;
  FOwnsStream := False;
  FStream := Stream;
  FEncoding := TEncoding.UTF8;
  SetLength(FBuffer, 8192);
  FBufferIndex := 0;
  FNewLine := sLineBreak;
  FNewLineBytes := FEncoding.GetBytes(FNewLine);
  FAutoFlush := False;
end;

constructor TYAMLStreamWriter.Create(const Stream: TStream; WriteBOM : boolean; Encoding: TEncoding; BufferSize: Integer);
begin
  inherited Create;
  FOwnsStream := False;
  FStream := Stream;
  FEncoding := Encoding;
  if BufferSize >= 128 then
    SetLength(FBuffer, BufferSize)
  else
    SetLength(FBuffer, 128);
  FBufferIndex := 0;
  FNewLine := sLineBreak;
  FNewLineBytes := FEncoding.GetBytes(FNewLine);
  FAutoFlush := False;
  if WriteBOM and (Stream.Position = 0) then
    WriteBytes(FEncoding.GetPreamble);
end;

constructor TYAMLStreamWriter.Create(const Filename: string);
begin
  FStream := TFileStream.Create(Filename, fmCreate);
  Create(FStream);
  FOwnsStream := True;
end;

constructor TYAMLStreamWriter.Create(const Filename: string; WriteBOM : boolean;  Encoding: TEncoding; BufferSize: Integer);
begin
  FStream := TFileStream.Create(Filename, fmCreate);
  Create(FStream, WriteBOM, Encoding, BufferSize);
  FOwnsStream := True;
end;

destructor TYAMLStreamWriter.Destroy;
begin
  Close;
  SetLength(FBuffer, 0);
  inherited;
end;

procedure TYAMLStreamWriter.Flush;
begin
  if FBufferIndex = 0 then
    Exit;
  if FStream = nil then
    Exit;

  try
    // NB: pass FBuffer[0], not FBuffer. On XE2 TStream only has the untyped
    // WriteBuffer(const Buffer; Count), so passing the TBytes variable writes the
    // bytes of the array reference itself, not the data. Later RTLs have a TBytes
    // overload which masked this. FBuffer[0] is portable across all versions.
    FStream.WriteBuffer(FBuffer[0], FBufferIndex);
  finally
    FBufferIndex := 0;
  end;
end;

procedure TYAMLStreamWriter.OwnStream;
begin
  FOwnsStream := True;
end;


procedure TYAMLStreamWriter.Write(const Value: string);
begin
  WriteBytes(FEncoding.GetBytes(Value));
end;



procedure TYAMLStreamWriter.WriteBytes(Bytes: TBytes);
var
  ByteIndex: Integer;
  WriteLen: Integer;
begin
  ByteIndex := 0;

  while ByteIndex < Length(Bytes) do
  begin
    WriteLen := Length(Bytes) - ByteIndex;
    if WriteLen > Length(FBuffer) - FBufferIndex then
      WriteLen := Length(FBuffer) - FBufferIndex;

    Move(Bytes[ByteIndex], FBuffer[FBufferIndex], WriteLen);

    Inc(FBufferIndex, WriteLen);
    Inc(ByteIndex, WriteLen);

    if FBufferIndex >= Length(FBuffer) then
      Flush;
  end;

  if FAutoFlush then
    Flush;
end;


procedure TYAMLStreamWriter.SetNewLine(const Value: string);
begin
  FNewLine := Value;
  FNewLineBytes := FEncoding.GetBytes(FNewLine);
end;

procedure TYAMLStreamWriter.WriteLine;
begin
  WriteBytes(FNewLineBytes);
end;


procedure TYAMLStreamWriter.WriteLine(const Value: string);
begin
  WriteBytes(FEncoding.GetBytes(Value));
  WriteBytes(FNewLineBytes);
end;


{ TYAMLStringWriter }

procedure TYAMLStringWriter.Close;
begin

end;

constructor TYAMLStringWriter.Create;
begin
  FStringBuilder := TStringBuilder.Create(8192);
  FNewLine := sLineBreak;
end;

destructor TYAMLStringWriter.Destroy;
begin
  FStringBuilder.Free;
  inherited Destroy;
end;

procedure TYAMLStringWriter.Flush;
begin
  //NOOP
end;

function TYAMLStringWriter.ToString: string;
begin
  result := FStringBuilder.ToString;
end;

procedure TYAMLStringWriter.Write(const Value: string);
begin
  FStringBuilder.Append(Value);
end;

procedure TYAMLStringWriter.WriteLine(const Value: string);
begin
  FStringBuilder.AppendLine(Value)
end;

{ TYAMLOutputBuffer }

constructor TYAMLOutputBuffer.CreateForString(initialCapacity : integer);
begin
  inherited Create;
  if initialCapacity < 16 then
    initialCapacity := 16;
  FCapacity := initialCapacity;
  SetLength(FBuffer, FCapacity);
end;

constructor TYAMLOutputBuffer.CreateForStream(const stream : TStream; const encoding : TEncoding; writeBOM : boolean; chunkChars : integer);
var
  preamble : TBytes;
begin
  inherited Create;
  FStream := stream;
  FEncoding := encoding;
  if chunkChars < 64 then
    chunkChars := 64;
  FCapacity := chunkChars;
  SetLength(FBuffer, FCapacity);
  // same rule as TYAMLStreamWriter: only at the very start of the stream
  if writeBOM and (stream.Position = 0) then
  begin
    preamble := FEncoding.GetPreamble;
    if Length(preamble) > 0 then
      FStream.WriteBuffer(preamble[0], Length(preamble));
  end;
end;

destructor TYAMLOutputBuffer.Destroy;
begin
  if FStream <> nil then
    Flush;
  inherited Destroy;
end;

procedure TYAMLOutputBuffer.WriteChunk(count : integer);
var
  bytes : TBytes;
begin
  if count <= 0 then
    exit;
  bytes := FEncoding.GetBytes(Copy(FBuffer, 1, count));
  if Length(bytes) > 0 then
    FStream.WriteBuffer(bytes[0], Length(bytes));
  // keep whatever was not written (at most a held-back high surrogate)
  if count < FLength then
    Move(PChar(Pointer(FBuffer))[count], Pointer(FBuffer)^, (FLength - count) * SizeOf(Char));
  Dec(FLength, count);
end;

procedure TYAMLOutputBuffer.MakeRoom(count : integer);
var
  keep : integer;
begin
  if FStream <> nil then
  begin
    // write out what we have, holding back a trailing high surrogate so a pair is
    // never encoded in two halves
    keep := 0;
    if (FLength > 0) and (Ord(PChar(Pointer(FBuffer))[FLength - 1]) >= $D800) and
       (Ord(PChar(Pointer(FBuffer))[FLength - 1]) <= $DBFF) then
      keep := 1;
    WriteChunk(FLength - keep);
    if FLength + count <= FCapacity then
      exit;
  end;
  if FCapacity < 16 then
    FCapacity := 16; // after ExtractString
  if (FStream = nil) and (FLength > 0) then
  begin
    // string output: set the full buffer aside and start a fresh one
    if FChunkCount = Length(FChunks) then
    begin
      SetLength(FChunks, FChunkCount * 2 + 8);
      SetLength(FChunkLengths, FChunkCount * 2 + 8);
    end;
    FChunks[FChunkCount] := FBuffer;
    FChunkLengths[FChunkCount] := FLength;
    Inc(FChunkCount);
    Inc(FChunkedLength, FLength);
    FBuffer := '';
    FLength := 0;
    if FCapacity < 1024 * 1024 then
      FCapacity := FCapacity * 2;
  end;
  // (stream output only gets here for a single write larger than a chunk)
  while FLength + count > FCapacity do
    FCapacity := FCapacity * 2;
  SetLength(FBuffer, FCapacity);
end;

procedure TYAMLOutputBuffer.Write(const value : string);
begin
  Write(PChar(Pointer(value)), Length(value));
end;

procedure TYAMLOutputBuffer.Write(p : PChar; count : integer);
begin
  if count <= 0 then
    exit;
  if FLength + count > FCapacity then
    MakeRoom(count);
  Move(p^, PChar(Pointer(FBuffer))[FLength], count * SizeOf(Char));
  Inc(FLength, count);
end;

procedure TYAMLOutputBuffer.WriteChar(ch : Char);
begin
  if FLength + 1 > FCapacity then
    MakeRoom(1);
  PChar(Pointer(FBuffer))[FLength] := ch;
  Inc(FLength);
end;

procedure TYAMLOutputBuffer.WriteSpaces(count : integer);
var
  p : PChar;
  i : integer;
begin
  if count <= 0 then
    exit;
  if FLength + count > FCapacity then
    MakeRoom(count);
  p := @PChar(Pointer(FBuffer))[FLength];
  for i := 0 to count - 1 do
    p[i] := ' ';
  Inc(FLength, count);
end;

procedure TYAMLOutputBuffer.WriteNewLine;
begin
  Write(sLineBreak);
end;

procedure TYAMLOutputBuffer.WriteLine(const value : string);
begin
  Write(value);
  Write(sLineBreak);
end;

procedure TYAMLOutputBuffer.Flush;
begin
  if FStream <> nil then
    WriteChunk(FLength);
end;

function TYAMLOutputBuffer.ExtractString : string;
var
  i, pos : integer;
begin
  if FChunkCount = 0 then
  begin
    SetLength(FBuffer, FLength);
    result := FBuffer;
  end
  else
  begin
    SetLength(result, FChunkedLength + FLength);
    pos := 0;
    for i := 0 to FChunkCount - 1 do
    begin
      Move(Pointer(FChunks[i])^, PChar(Pointer(result))[pos], FChunkLengths[i] * SizeOf(Char));
      Inc(pos, FChunkLengths[i]);
      FChunks[i] := '';
    end;
    if FLength > 0 then
      Move(Pointer(FBuffer)^, PChar(Pointer(result))[pos], FLength * SizeOf(Char));
  end;
  FBuffer := '';
  FLength := 0;
  FCapacity := 0;
  FChunks := nil;
  FChunkLengths := nil;
  FChunkCount := 0;
  FChunkedLength := 0;
end;

end.
