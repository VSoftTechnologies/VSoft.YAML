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


implementation

uses VSoft.YAML.StreamReader;

{$I 'VSoft.YAML.inc'}


type
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
  protected
    function GetPosition : integer;inline;
    function GetLine : integer;inline;
    function GetColumn : integer;inline;
    function GetCurrent : Char;inline;
    function GetPreviousChar : Char;inline;
    function IsAtEnd : boolean;inline;
    function Read : Char;overload;
    function Read(n : integer) : Char;overload;
    function Peek : Char;overload;inline;
    function Peek(n : integer) : Char;overload;
    procedure Save;
    procedure Restore;
  public
    constructor Create(const theString : string);
  end;

  TStreamInputReader = class(TInterfacedObject, IInputReader)
  private
    FStream : TStream;
    FStreamReader : TYAMLStreamReader;


    FPosition : integer;
    FLine : integer;
    FColumn : integer;
    FCurrentChar : Char;
    FPreviousChar : Char;
    FAtEnd : boolean;

    // Save/restore state
    FSavedPosition : integer;
    FSavedLine : integer;
    FSavedColumn : integer;
    FSavedStreamPos : Int64;
    FSavedCurrentChar : Char;
    FSavedPreviousChar : Char;
    FSavedAtEnd : Boolean;

    procedure InitializeReader;
    procedure ReadNextChar;
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
  public
    constructor Create(const stream: TStream); overload;
    destructor Destroy; override;
  end;


  TFileInputReader = class(TStreamInputReader, IInputReader)
  public
    constructor Create(const filename: string); overload;
    destructor Destroy;override;
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

procedure TStringInputReader.Save;
begin
  FSavedPosition := FPosition;
  FSavedLine := FLine;
  FSavedColumn := FColumn;
  FSavedIsAtEnd := FIsAtEnd;
end;

{ TStreamInputReader }

constructor TStreamInputReader.Create(const stream: TStream);
begin
  inherited Create;
  FStream := stream;
  FStreamReader := TYAMLStreamReader.Create(stream, TEncoding.UTF8, True, 2048); // Default UTF8 with BOM detection
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
var
  value : integer;
begin
  result := #0;

  if n <= 0 then
    Exit;

  if FAtEnd then
    Exit;

  value := FStreamReader.Peek(n);
  if value <> -1 then
    result := Char(value);

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
  if FSavedPosition = -1 then
    raise Exception.Create('No saved position');

  // Always restore the stream position and state
  FStreamReader.RestorePosition;

  // Restore parser state
  FPosition := FSavedPosition;
  FLine := FSavedLine;
  FColumn := FSavedColumn;
  FCurrentChar := FSavedCurrentChar;
  FPreviousChar := FSavedPreviousChar;
  FAtEnd := FSavedAtEnd;

  FSavedPosition := -1;

end;

procedure TStreamInputReader.Save;
begin
  FStreamReader.SavePosition;
  FSavedPosition := FPosition;
  FSavedLine := FLine;
  FSavedColumn := FColumn;
  FSavedStreamPos := FStream.Position;
  FSavedCurrentChar := FCurrentChar;
  FSavedPreviousChar := FPreviousChar;
  FSavedAtEnd := FAtEnd;
end;

procedure TStreamInputReader.InitializeReader;
begin
  if FStreamReader.EndOfStream then
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
    
    // Read the first character
    try
      FCurrentChar := Char(FStreamReader.Read);
    except
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

  // Note: First character already read in else block above
end;

procedure TStreamInputReader.ReadNextChar;
var
  charValue: Integer;
begin
  if FAtEnd then
  begin
    FCurrentChar := #0;
    Exit;
  end;
  
  FPreviousChar := FCurrentChar;
  
  // Use Read() and check for -1 instead of EndOfStream for more reliable EOF detection
  charValue := FStreamReader.Read;
  if charValue = -1 then
  begin
    FAtEnd := True;
    FCurrentChar := #0;
    Exit;
  end;

  FCurrentChar := Char(charValue);
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


{ TFileInputReader }

constructor TFileInputReader.Create(const filename: string);
begin
  inherited Create(TFileStream.Create(filename, fmOpenRead or fmShareDenyWrite));
end;


destructor TFileInputReader.Destroy;
begin
  //The fileinput reader always owns the stream
  FStream.Free;
  inherited;
end;

destructor TStreamInputReader.Destroy;
begin
  FStreamReader.Free;
  inherited;
end;

end.
