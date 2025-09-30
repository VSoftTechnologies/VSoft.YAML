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
    FAutoFlush: Boolean;
    FOwnsStream: Boolean;
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
    property NewLine: string read FNewLine write FNewLine;
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
    FStream.WriteBuffer(FBuffer, FBufferIndex);
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


procedure TYAMLStreamWriter.WriteLine;
begin
  WriteBytes(FEncoding.GetBytes(FNewLine));
end;


procedure TYAMLStreamWriter.WriteLine(const Value: string);
begin
  WriteBytes(FEncoding.GetBytes(Value + FNewLine));
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

end.
