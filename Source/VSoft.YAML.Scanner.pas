unit VSoft.YAML.Scanner;

interface

{$I 'VSoft.YAML.inc'}

uses
  System.SysUtils,
  VSoft.YAML,
  VSoft.YAML.IO,
  VSoft.YAML.Utils;

type
  /// <summary> The tokens of the YAML 1.2 syntax, as libyaml names them. </summary>
  TYAMLScanTokenKind = (
    StreamStart, StreamEnd,
    VersionDirective, TagDirective, ReservedDirective,
    DocumentStart, DocumentEnd,
    BlockSequenceStart, BlockMappingStart, BlockEnd,
    FlowSequenceStart, FlowSequenceEnd, FlowMappingStart, FlowMappingEnd,
    BlockEntry, FlowEntry, Key, Value,
    Alias, Anchor, Tag, Scalar);

  TYAMLScalarStyle = (Plain, SingleQuoted, DoubleQuoted, Literal, Folded);

  TYAMLScanToken = record
    Kind : TYAMLScanTokenKind;
    Style : TYAMLScalarStyle;  // Scalar
    Explicit : boolean;        // Key: written with '?'
    // Scalar: the text; Anchor, Alias: the name; Tag: the suffix (the URI of a verbatim tag);
    // VersionDirective: the version; TagDirective: the handle; ReservedDirective: the name
    Value : string;
    // Tag: the handle ('' for a verbatim tag); TagDirective: the prefix
    Value2 : string;
    Index : integer;   // absolute index of the first char
    Line : integer;    // 1-based
    Column : integer;  // 0-based
    EndLine : integer; // the line the token's text ends on (the header line of a block scalar)
  end;
  PYAMLScanToken = ^TYAMLScanToken;

  TYAMLScanComment = record
    Text : string;      // without the '#' and the white space around the text
    Index : integer;    // absolute index of the '#'
    Line : integer;
    Trailing : boolean; // a token ends on the same line, before it
  end;
  PYAMLScanComment = ^TYAMLScanComment;

  TYAMLSimpleKey = record
    Possible : boolean;
    Required : boolean;
    TabBefore : boolean;
    TokenNumber : integer;
    Index : integer;
    Line : integer;
    Column : integer;
  end;

  /// <summary>
  ///  Splits YAML 1.2 text into tokens, the way libyaml does: a queue of tokens in which a
  ///  KEY token (and the BLOCK-MAPPING-START of a new mapping) is put in front of an implicit
  ///  key once the ':' after it is found, an indentation stack that turns indentation into
  ///  BLOCK-*-START and BLOCK-END tokens, and simple key tracking for each flow level.
  ///  Scalars are read with the 1.2 folding rules, so a token's text is the scalar's content.
  ///  Comments are not tokens: they are kept, in order, in a list of their own that the parser
  ///  reads alongside the tokens.
  ///
  ///  Beyond libyaml, it checks the YAML 1.2 rules on tabs (never indentation, and not before
  ///  a block indicator or an implicit key that starts a block collection), on the indentation
  ///  of flow content and of quoted scalar lines, on implicit keys in flow sequences (one line)
  ///  and on ':' after a JSON-like key in a flow collection.
  /// </summary>
  TYAMLScanner = class
  private
    FReaderRef : IInputReader; // holds the reader's lifetime
    FReader : TBufferedInputReader;
    FText : PChar;   // FText[i] is the reader's Buffer[i] - the window, 1-based
    FLen : integer;  // chars in the window
    FPos : integer;  // window index of the current char
    FLine : integer;
    FLineStart : integer; // absolute index of the first char of the current line

    // the token queue: FTokens[FHead..FTail-1]
    FTokens : TArray<TYAMLScanToken>;
    FHead : integer;
    FTail : integer;
    FTokensParsed : integer; // tokens taken from the queue so far
    FHeadReady : boolean;    // the head token is final - no KEY can go in front of it
    FStreamStarted : boolean;
    FStreamEnded : boolean;

    // the start of the token being fetched
    FStartIndex : integer;
    FStartLine : integer;
    FStartColumn : integer;

    FIndent : integer;
    FIndents : TArray<integer>;
    FIndentCount : integer;

    FFlowLevel : integer;
    FFlowMapping : TArray<boolean>;      // per flow level: a mapping, not a sequence
    FSimpleKeys : TArray<TYAMLSimpleKey>; // per flow level (0 is the block context)
    FSimpleKeyAllowed : boolean;
    FTabBeforeToken : boolean;  // a tab came before the current token, on its line (block context)
    FJSONLikeToken : boolean;   // the last token was a quoted scalar or the end of a flow collection
    FLastTokenLine : integer;

    // comments not yet taken: FComments[FCommentHead..FCommentTail-1]
    FComments : TArray<TYAMLScanComment>;
    FCommentHead : integer;
    FCommentTail : integer;

    FScratch : string;  // the text of a scalar that is not a single run of the input
    FScratchLen : integer;

    FInterner : TYAMLStringInterner;
    FKeyIntern : TInternState;
    FValueIntern : TInternState;

    procedure RaiseError(const msg : string);{$IFDEF NORETURN}noreturn;{$ENDIF}
    procedure RaiseErrorAt(const msg : string; line, column : integer);{$IFDEF NORETURN}noreturn;{$ENDIF}

    // window access
    function Fill : boolean;
    function At(offset : integer) : Char;inline;
    function AtSlow(offset : integer) : Char;
    function IsEndAt(offset : integer) : boolean;
    function AbsIndex : integer;inline;
    function CurColumn : integer;inline;
    function IsBlankZAt(offset : integer) : boolean;inline;
    function IsDocumentMarker : boolean;
    function IsWhiteLineAt(offset : integer) : boolean;
    procedure SkipBreak;
    function CopyAbs(start, count : integer) : string;

    procedure ScratchAppend(p : PChar; count : integer);
    procedure ScratchAppendAbs(start, count : integer);
    procedure ScratchAppendChar(ch : Char);
    procedure ScratchAppendBreaks(count : integer);
    function ScratchText : string;

    // the token queue
    function AppendToken(kind : TYAMLScanTokenKind) : PYAMLScanToken;
    procedure InsertToken(position : integer; kind : TYAMLScanTokenKind; index, line, column : integer);
    function NeedMoreTokens : boolean;
    procedure MarkStart;

    // indentation and simple keys
    procedure UnrollIndent(column : integer);
    procedure RollIndent(column, number : integer; kind : TYAMLScanTokenKind; index, line, col : integer);
    procedure SaveSimpleKey;
    procedure RemoveSimpleKey;
    procedure StaleSimpleKeys;
    procedure IncreaseFlowLevel(mapping : boolean);
    procedure DecreaseFlowLevel;

    procedure AddComment(const text : string; index, line : integer; trailing : boolean);
    procedure ScanComment;
    procedure ScanToNextToken;

    procedure FetchNextToken;
    procedure FetchToken(ch : Char);
    procedure FetchStreamEnd;
    procedure FetchDirective;
    procedure FetchDocumentIndicator(start : boolean);
    procedure FetchFlowCollectionStart(mapping : boolean);
    procedure FetchFlowCollectionEnd(mapping : boolean);
    procedure FetchFlowEntry;
    procedure FetchBlockEntry;
    procedure FetchKey;
    procedure FetchValue;
    procedure FetchAnchor(alias : boolean);
    procedure FetchTag;
    procedure FetchBlockScalar(literal : boolean);
    procedure FetchFlowScalar(double : boolean);
    procedure FetchPlainScalar;
    function CanStartPlain(ch : Char) : boolean;

    procedure ScanDirective;
    function ScanTagChars(uri : boolean) : integer;
    procedure ScanPlainScalar;
    procedure ScanFlowScalar(double : boolean);
    procedure FoldQuotedLines(escaped : boolean);
    procedure ScanEscape;
    procedure ScanBlockScalar(literal : boolean);
  public
    constructor Create(const reader : IInputReader);

    /// <summary> The next token - the pointer is valid until the next call to Peek or Skip.
    ///  After the end of the stream it is a StreamEnd token again. </summary>
    function Peek : PYAMLScanToken;
    /// <summary> Takes the token Peek returned off the queue. </summary>
    procedure Skip;

    /// <summary> The oldest comment not yet taken, or nil. Comments are found as the tokens
    ///  are, so all those before the token Peek returns are in the list. </summary>
    function PeekComment : PYAMLScanComment;
    procedure SkipComment;

    property Line : integer read FLine;
  end;

implementation

const
  // An implicit key must fit on one line, in at most this many chars (YAML 1.2, 7.4.2).
  cMaxSimpleKeyLength = 1024;
  // Block collections nested deeper than this are an error (the limit the YAML parser has
  // always had).
  cMaxBlockDepth = 100;

function IsFlowIndicator(ch : Char) : boolean;inline;
begin
  result := (ch = ',') or (ch = '[') or (ch = ']') or (ch = '{') or (ch = '}');
end;

function IsBlankZ(ch : Char) : boolean;inline;
begin
  result := (ch = ' ') or (ch = #9) or (ch = #10) or (ch = #13) or (ch = #0);
end;

function IsBreak(ch : Char) : boolean;inline;
begin
  result := (ch = #10) or (ch = #13);
end;

// ns-word-char
function IsWordChar(ch : Char) : boolean;inline;
begin
  case ch of
    '0'..'9', 'a'..'z', 'A'..'Z', '-' : result := true;
  else
    result := false;
  end;
end;

function HexValue(ch : Char) : integer;inline;
begin
  case ch of
    '0'..'9' : result := Ord(ch) - Ord('0');
    'a'..'f' : result := Ord(ch) - Ord('a') + 10;
    'A'..'F' : result := Ord(ch) - Ord('A') + 10;
  else
    result := -1;
  end;
end;

{ TYAMLScanner }

constructor TYAMLScanner.Create(const reader : IInputReader);
var
  obj : TObject;
  sb : TStringBuilder;
begin
  inherited Create;
  obj := reader as TObject;
  if obj is TBufferedInputReader then
    FReaderRef := reader
  else
  begin
    // Some other reader implementation: drain what is left of it into a string reader.
    sb := TStringBuilder.Create;
    try
      while not reader.IsEOF do
        sb.Append(reader.Read);
      FReaderRef := TInputReaderFactory.CreateFromString(sb.ToString);
    finally
      sb.Free;
    end;
  end;
  FReader := FReaderRef as TObject as TBufferedInputReader;
  FText := PChar(Pointer(FReader.Buffer)) - 1;
  FLen := FReader.BufferLength;
  FPos := FReader.BufferPosition;
  if FPos < 1 then // empty input
    FPos := 1;
  FLine := 1;
  FLineStart := FReader.BufferBase + FPos;
  FIndent := -1;
  SetLength(FTokens, 16);
  SetLength(FIndents, 16);
  SetLength(FSimpleKeys, 8);
  SetLength(FFlowMapping, 8);
  SetLength(FScratch, 256);
end;

procedure TYAMLScanner.RaiseError(const msg : string);
begin
  raise EYAMLParseException.Create(msg, FLine, CurColumn + 1);
end;

procedure TYAMLScanner.RaiseErrorAt(const msg : string; line, column : integer);
begin
  raise EYAMLParseException.Create(msg, line, column + 1);
end;

{ window access }

// Appends the next block of input to the window. FPos moves down by whatever the reader
// drops from the front of the window; absolute indexes are unchanged.
function TYAMLScanner.Fill : boolean;
begin
  result := FReader.FillBuffer(FPos);
  if result then
  begin
    FText := PChar(Pointer(FReader.Buffer)) - 1;
    FLen := FReader.BufferLength;
  end;
end;

// The char offset chars on from the current one, or #0 past the end of the input.
function TYAMLScanner.At(offset : integer) : Char;
begin
  if FPos + offset <= FLen then
    result := FText[FPos + offset]
  else
    result := AtSlow(offset);
end;

function TYAMLScanner.AtSlow(offset : integer) : Char;
begin
  while FPos + offset > FLen do
  begin
    if not Fill then
      exit(#0);
  end;
  result := FText[FPos + offset];
end;

// True when offset chars on is past the end of the input.
function TYAMLScanner.IsEndAt(offset : integer) : boolean;
begin
  result := (At(offset) = #0) and (FPos + offset > FLen);
end;

function TYAMLScanner.AbsIndex : integer;
begin
  result := FReader.BufferBase + FPos;
end;

function TYAMLScanner.CurColumn : integer;
begin
  result := FReader.BufferBase + FPos - FLineStart;
end;

function TYAMLScanner.IsBlankZAt(offset : integer) : boolean;
begin
  result := IsBlankZ(At(offset));
end;

// '---' or '...' at the start of a line, followed by white space or the end of the line
function TYAMLScanner.IsDocumentMarker : boolean;
var
  ch : Char;
begin
  ch := At(0);
  result := ((ch = '-') or (ch = '.')) and (At(1) = ch) and (At(2) = ch) and IsBlankZAt(3) and (CurColumn = 0);
end;

// True when the chars from offset to the end of the line are all spaces and tabs.
function TYAMLScanner.IsWhiteLineAt(offset : integer) : boolean;
var
  ch : Char;
begin
  while (At(offset) = ' ') or (At(offset) = #9) do
    Inc(offset);
  ch := At(offset);
  result := IsBreak(ch) or ((ch = #0) and IsEndAt(offset));
end;

// Consumes the line break at the current char (CR LF counts as one).
procedure TYAMLScanner.SkipBreak;
begin
  if At(0) = #13 then
  begin
    Inc(FPos);
    if At(0) = #10 then
      Inc(FPos);
  end
  else
    Inc(FPos);
  Inc(FLine);
  FLineStart := FReader.BufferBase + FPos;
end;

function TYAMLScanner.CopyAbs(start, count : integer) : string;
begin
  SetString(result, FText + (start - FReader.BufferBase), count);
end;

procedure TYAMLScanner.ScratchAppend(p : PChar; count : integer);
begin
  if count <= 0 then
    exit;
  if FScratchLen + count > Length(FScratch) then
    SetLength(FScratch, (FScratchLen + count) * 2);
  Move(p^, PChar(Pointer(FScratch))[FScratchLen], count * SizeOf(Char));
  Inc(FScratchLen, count);
end;

procedure TYAMLScanner.ScratchAppendAbs(start, count : integer);
begin
  ScratchAppend(FText + (start - FReader.BufferBase), count);
end;

procedure TYAMLScanner.ScratchAppendChar(ch : Char);
begin
  if FScratchLen >= Length(FScratch) then
    SetLength(FScratch, (FScratchLen + 1) * 2);
  PChar(Pointer(FScratch))[FScratchLen] := ch;
  Inc(FScratchLen);
end;

procedure TYAMLScanner.ScratchAppendBreaks(count : integer);
var
  i : integer;
begin
  for i := 1 to count do
    ScratchAppendChar(#10);
end;

function TYAMLScanner.ScratchText : string;
begin
  SetString(result, PChar(Pointer(FScratch)), FScratchLen);
end;

{ the token queue }

function TYAMLScanner.AppendToken(kind : TYAMLScanTokenKind) : PYAMLScanToken;
var
  count, i : integer;
begin
  if FTail = Length(FTokens) then
  begin
    count := FTail - FHead;
    if FHead > 0 then
    begin
      for i := 0 to count - 1 do
        FTokens[i] := FTokens[FHead + i];
      for i := count to FTail - 1 do
      begin
        FTokens[i].Value := '';
        FTokens[i].Value2 := '';
      end;
      FHead := 0;
      FTail := count;
    end;
    if FTail = Length(FTokens) then
      SetLength(FTokens, Length(FTokens) * 2);
  end;
  result := @FTokens[FTail];
  Inc(FTail);
  result^.Kind := kind;
  result^.Style := TYAMLScalarStyle.Plain;
  result^.Explicit := false;
  result^.Index := FStartIndex;
  result^.Line := FStartLine;
  result^.Column := FStartColumn;
  result^.EndLine := FLine;
end;

// Puts a token position places after the head of the queue.
procedure TYAMLScanner.InsertToken(position : integer; kind : TYAMLScanTokenKind; index, line, column : integer);
var
  i, at : integer;
  p : PYAMLScanToken;
begin
  AppendToken(kind);
  at := FHead + position;
  for i := FTail - 1 downto at + 1 do
    FTokens[i] := FTokens[i - 1];
  p := @FTokens[at];
  p^.Kind := kind;
  p^.Style := TYAMLScalarStyle.Plain;
  p^.Explicit := false;
  p^.Value := '';
  p^.Value2 := '';
  p^.Index := index;
  p^.Line := line;
  p^.Column := column;
  p^.EndLine := line;
end;

// More tokens are needed while the queue is empty, or while the token at its head may yet
// turn out to be an implicit key (a KEY token would go in front of it).
function TYAMLScanner.NeedMoreTokens : boolean;
var
  level : integer;
begin
  if FHead = FTail then
    exit(true);
  StaleSimpleKeys;
  for level := 0 to FFlowLevel do
  begin
    if FSimpleKeys[level].Possible and (FSimpleKeys[level].TokenNumber = FTokensParsed) then
      exit(true);
  end;
  result := false;
end;

function TYAMLScanner.Peek : PYAMLScanToken;
begin
  // Once the head token is final it stays so until it is taken: a simple key saved later
  // belongs to a later token.
  if not FHeadReady then
  begin
    while NeedMoreTokens do
      FetchNextToken;
    FHeadReady := true;
  end;
  result := @FTokens[FHead];
end;

procedure TYAMLScanner.Skip;
begin
  FHeadReady := false;
  FTokens[FHead].Value := '';
  FTokens[FHead].Value2 := '';
  Inc(FHead);
  Inc(FTokensParsed);
  if FHead = FTail then
  begin
    FHead := 0;
    FTail := 0;
  end;
end;

function TYAMLScanner.PeekComment : PYAMLScanComment;
begin
  if FCommentHead < FCommentTail then
    result := @FComments[FCommentHead]
  else
    result := nil;
end;

procedure TYAMLScanner.SkipComment;
begin
  FComments[FCommentHead].Text := '';
  Inc(FCommentHead);
  if FCommentHead = FCommentTail then
  begin
    FCommentHead := 0;
    FCommentTail := 0;
  end;
end;

procedure TYAMLScanner.MarkStart;
begin
  FStartIndex := FReader.BufferBase + FPos;
  FStartLine := FLine;
  FStartColumn := FStartIndex - FLineStart;
  FReader.MarkAt(FPos);
end;

{ indentation and simple keys }

// Closes the block collections indented more than column (block context only).
procedure TYAMLScanner.UnrollIndent(column : integer);
begin
  if FFlowLevel > 0 then
    exit;
  while FIndent > column do
  begin
    AppendToken(TYAMLScanTokenKind.BlockEnd);
    Dec(FIndentCount);
    FIndent := FIndents[FIndentCount];
  end;
end;

// Opens a block collection at column when it is indented more than the current one. number
// is the token number to put its start token in front of, or -1 to append it.
procedure TYAMLScanner.RollIndent(column, number : integer; kind : TYAMLScanTokenKind; index, line, col : integer);
var
  tok : PYAMLScanToken;
begin
  if FFlowLevel > 0 then
    exit;
  if FIndent < column then
  begin
    if FIndentCount >= cMaxBlockDepth then
      RaiseErrorAt(Format('Maximum nesting depth exceeded - block collections are nested more than %d deep', [cMaxBlockDepth]), line, col);
    if FIndentCount = Length(FIndents) then
      SetLength(FIndents, FIndentCount * 2);
    FIndents[FIndentCount] := FIndent;
    Inc(FIndentCount);
    FIndent := column;
    if number = -1 then
    begin
      tok := AppendToken(kind);
      tok^.Index := index;
      tok^.Line := line;
      tok^.Column := col;
      tok^.EndLine := line;
    end
    else
      InsertToken(number - FTokensParsed, kind, index, line, col);
  end;
end;

// The token about to be fetched may be an implicit key - remember where it starts.
procedure TYAMLScanner.SaveSimpleKey;
var
  key : ^TYAMLSimpleKey;
  column : integer;
begin
  if not FSimpleKeyAllowed then
    exit;
  RemoveSimpleKey;
  column := CurColumn;
  key := @FSimpleKeys[FFlowLevel];
  key^.Possible := true;
  // At the indentation of the block mapping it must be a key.
  key^.Required := (FFlowLevel = 0) and (FIndent = column);
  key^.TabBefore := FTabBeforeToken;
  key^.TokenNumber := FTokensParsed + (FTail - FHead);
  key^.Index := AbsIndex;
  key^.Line := FLine;
  key^.Column := column;
end;

procedure TYAMLScanner.RemoveSimpleKey;
var
  key : ^TYAMLSimpleKey;
begin
  key := @FSimpleKeys[FFlowLevel];
  if key^.Possible and key^.Required then
    RaiseErrorAt('Could not find the expected ":" after this implicit mapping key', key^.Line, key^.Column);
  key^.Possible := false;
end;

// An implicit key that has not been followed by ':' on its line, or within 1024 chars, is not
// a key after all. In a flow mapping a key may span lines.
procedure TYAMLScanner.StaleSimpleKeys;
var
  level, index : integer;
  key : ^TYAMLSimpleKey;
begin
  index := AbsIndex;
  for level := 0 to FFlowLevel do
  begin
    key := @FSimpleKeys[level];
    if key^.Possible and ((level = 0) or not FFlowMapping[level]) and
       ((key^.Line < FLine) or (key^.Index + cMaxSimpleKeyLength < index)) then
    begin
      if key^.Required then
        RaiseErrorAt('Could not find the expected ":" after this implicit mapping key', key^.Line, key^.Column);
      key^.Possible := false;
    end;
  end;
end;

procedure TYAMLScanner.IncreaseFlowLevel(mapping : boolean);
begin
  Inc(FFlowLevel);
  if FFlowLevel >= Length(FSimpleKeys) then
  begin
    SetLength(FSimpleKeys, FFlowLevel * 2);
    SetLength(FFlowMapping, FFlowLevel * 2);
  end;
  FSimpleKeys[FFlowLevel].Possible := false;
  FSimpleKeys[FFlowLevel].Required := false;
  FFlowMapping[FFlowLevel] := mapping;
end;

procedure TYAMLScanner.DecreaseFlowLevel;
begin
  if FFlowLevel > 0 then
  begin
    FSimpleKeys[FFlowLevel].Possible := false;
    Dec(FFlowLevel);
  end;
end;

{ comments and white space }

procedure TYAMLScanner.AddComment(const text : string; index, line : integer; trailing : boolean);
var
  count, i : integer;
  c : PYAMLScanComment;
begin
  if FCommentTail = Length(FComments) then
  begin
    count := FCommentTail - FCommentHead;
    if FCommentHead > 0 then
    begin
      for i := 0 to count - 1 do
        FComments[i] := FComments[FCommentHead + i];
      for i := count to FCommentTail - 1 do
        FComments[i].Text := '';
      FCommentHead := 0;
      FCommentTail := count;
    end;
    if FCommentTail = Length(FComments) then
      SetLength(FComments, FCommentTail * 2 + 8);
  end;
  c := @FComments[FCommentTail];
  Inc(FCommentTail);
  c^.Text := text;
  c^.Index := index;
  c^.Line := line;
  c^.Trailing := trailing;
end;

// At a '#': keeps the comment and moves to the end of its line.
procedure TYAMLScanner.ScanComment;
var
  hashIndex, textStart, len : integer;
  ch : Char;
begin
  hashIndex := AbsIndex;
  FReader.MarkAt(FPos);
  Inc(FPos);
  while (At(0) = ' ') or (At(0) = #9) do
    Inc(FPos);
  textStart := AbsIndex;
  while true do
  begin
    ch := At(0);
    if IsBreak(ch) or ((ch = #0) and IsEndAt(0)) then
      break;
    Inc(FPos);
  end;
  len := AbsIndex - textStart;
  while (len > 0) and ((FText[textStart - FReader.BufferBase + len - 1] = ' ') or
                       (FText[textStart - FReader.BufferBase + len - 1] = #9)) do
    Dec(len);
  AddComment(CopyAbs(textStart, len), hashIndex, FLine, FLastTokenLine = FLine);
end;

// Skips white space, comments and line breaks up to the start of the next token, checking
// the YAML 1.2 rules on tabs and on the indentation of flow content.
procedure TYAMLScanner.ScanToNextToken;
var
  ch : Char;
  atLineStart, tabSeen : boolean;
  spaces : integer;
begin
  FTabBeforeToken := false;
  while true do
  begin
    atLineStart := FReader.BufferBase + FPos = FLineStart;
    // a byte order mark may start any line before a document
    if atLineStart and (At(0) = #$FEFF) then
    begin
      Inc(FPos);
      FLineStart := FReader.BufferBase + FPos;
    end;
    spaces := 0;
    while At(0) = ' ' do
    begin
      Inc(FPos);
      Inc(spaces);
    end;
    tabSeen := false;
    ch := At(0);
    if ch = #9 then
    begin
      tabSeen := true;
      repeat
        Inc(FPos);
        ch := At(0);
      until (ch <> ' ') and (ch <> #9);
    end;
    if ch = '#' then
    begin
      // (a plain scalar takes the white space after it, so look at the char before)
      if (not atLineStart) and (FText[FPos - 1] <> ' ') and (FText[FPos - 1] <> #9) then
        RaiseError('A comment must be separated from the text before it by white space');
      ScanComment;
      ch := At(0);
    end;
    if IsBreak(ch) then
    begin
      SkipBreak;
      if FFlowLevel = 0 then
        FSimpleKeyAllowed := true;
      continue;
    end;
    if (ch = #0) and IsEndAt(0) then
      exit;
    if atLineStart then
    begin
      if FFlowLevel = 0 then
      begin
        // tabs may follow the indentation, but cannot be part of it
        if tabSeen and (spaces <= FIndent) then
          RaiseError('Tabs are not allowed for indentation in YAML');
      end
      else if spaces < FIndent + 1 then
        RaiseError('A line of a flow collection must be indented more than the block collection it is in');
    end;
    if tabSeen and (FFlowLevel = 0) then
      FTabBeforeToken := true;
    exit;
  end;
end;

{ fetching tokens }

procedure TYAMLScanner.FetchNextToken;
var
  ch : Char;
  tok : PYAMLScanToken;
begin
  if not FStreamStarted then
  begin
    FStreamStarted := true;
    FSimpleKeyAllowed := true;
    MarkStart;
    AppendToken(TYAMLScanTokenKind.StreamStart);
    exit;
  end;
  if FStreamEnded then
  begin
    MarkStart;
    AppendToken(TYAMLScanTokenKind.StreamEnd);
    exit;
  end;
  ScanToNextToken;
  StaleSimpleKeys;
  MarkStart;
  UnrollIndent(FStartColumn);
  ch := At(0);
  if (ch = #0) and IsEndAt(0) then
    FetchStreamEnd
  else
    FetchToken(ch);
  tok := @FTokens[FTail - 1];
  FLastTokenLine := tok^.EndLine;
  FJSONLikeToken := ((tok^.Kind = TYAMLScanTokenKind.Scalar) and
                     ((tok^.Style = TYAMLScalarStyle.SingleQuoted) or (tok^.Style = TYAMLScalarStyle.DoubleQuoted))) or
                    (tok^.Kind = TYAMLScanTokenKind.FlowSequenceEnd) or (tok^.Kind = TYAMLScanTokenKind.FlowMappingEnd);
end;

procedure TYAMLScanner.FetchToken(ch : Char);
var
  nx : Char;
begin
  if FStartColumn = 0 then
  begin
    if (ch = '%') and (FFlowLevel = 0) then
    begin
      FetchDirective;
      exit;
    end;
    if ((ch = '-') or (ch = '.')) and IsDocumentMarker then
    begin
      FetchDocumentIndicator(ch = '-');
      exit;
    end;
  end;

  case ch of
    '[' : FetchFlowCollectionStart(false);
    '{' : FetchFlowCollectionStart(true);
    ']' : FetchFlowCollectionEnd(false);
    '}' : FetchFlowCollectionEnd(true);
    ',' : FetchFlowEntry;
    '*' : FetchAnchor(true);
    '&' : FetchAnchor(false);
    '!' : FetchTag;
    '''' : FetchFlowScalar(false);
    '"' : FetchFlowScalar(true);
    '|', '>' :
      begin
        if FFlowLevel > 0 then
          RaiseError(Format('A block scalar ("%s") cannot appear inside a flow collection', [ch]));
        FetchBlockScalar(ch = '|');
      end;
    '-' :
      if IsBlankZAt(1) then
        FetchBlockEntry
      else if CanStartPlain(ch) then
        FetchPlainScalar
      else
        RaiseError('"-" followed by a flow indicator cannot start a plain scalar - quote the scalar');
    '?' :
      begin
        nx := At(1);
        if IsBlankZ(nx) or ((FFlowLevel > 0) and IsFlowIndicator(nx)) then
          FetchKey
        else
          FetchPlainScalar;
      end;
    ':' :
      begin
        nx := At(1);
        if IsBlankZ(nx) or ((FFlowLevel > 0) and (IsFlowIndicator(nx) or FJSONLikeToken)) then
          FetchValue
        else
          FetchPlainScalar;
      end;
  else
    if CanStartPlain(ch) then
      FetchPlainScalar
    else if (ch = '@') or (ch = '`') then
      RaiseError(Format('"%s" is a reserved indicator and cannot start a plain scalar - quote the scalar', [ch]))
    else if ch = '%' then
      RaiseError('"%" cannot start a plain scalar - quote the scalar (a directive must start a line, before a document)')
    else if ch = #9 then
      RaiseError('Tabs are not allowed here')
    else if ch = #0 then
      RaiseError('Invalid character (#0) in the input')
    else
      RaiseError(Format('Found a character that cannot start any token: "%s"', [ch]));
  end;
end;

// ns-plain-first: any non-space char that is not an indicator, or '-', '?' or ':' followed by
// a char that can be part of a plain scalar.
function TYAMLScanner.CanStartPlain(ch : Char) : boolean;
var
  nx : Char;
begin
  case ch of
    '-', '?', ':' :
      begin
        nx := At(1);
        result := (not IsBlankZ(nx)) and not ((FFlowLevel > 0) and IsFlowIndicator(nx));
      end;
    ',', '[', ']', '{', '}', '#', '&', '*', '!', '|', '>', '''', '"', '%', '@', '`', ' ', #9, #10, #13, #0 :
      result := false;
  else
    result := true;
  end;
end;

procedure TYAMLScanner.FetchStreamEnd;
begin
  if FFlowLevel > 0 then
    RaiseError('Unexpected end of the input inside a flow collection (a closing "]" or "}" is missing)');
  UnrollIndent(-1);
  RemoveSimpleKey;
  FSimpleKeyAllowed := false;
  FStreamEnded := true;
  AppendToken(TYAMLScanTokenKind.StreamEnd);
end;

procedure TYAMLScanner.FetchDirective;
begin
  UnrollIndent(-1);
  RemoveSimpleKey;
  FSimpleKeyAllowed := false;
  ScanDirective;
end;

procedure TYAMLScanner.FetchDocumentIndicator(start : boolean);
var
  blanks : integer;
  ch : Char;
begin
  if FFlowLevel > 0 then
    RaiseError('A document marker ("---" or "...") cannot appear inside a flow collection');
  UnrollIndent(-1);
  RemoveSimpleKey;
  FSimpleKeyAllowed := false;
  Inc(FPos, 3);
  if start then
    AppendToken(TYAMLScanTokenKind.DocumentStart)
  else
  begin
    AppendToken(TYAMLScanTokenKind.DocumentEnd);
    // only a comment may follow '...' on its line
    blanks := 0;
    while (At(0) = ' ') or (At(0) = #9) do
    begin
      Inc(FPos);
      Inc(blanks);
    end;
    ch := At(0);
    if not (IsBreak(ch) or ((ch = #0) and IsEndAt(0)) or ((ch = '#') and (blanks > 0))) then
      RaiseError('Only a comment may follow the document end marker "..." on its line');
  end;
end;

procedure TYAMLScanner.FetchFlowCollectionStart(mapping : boolean);
begin
  SaveSimpleKey;
  IncreaseFlowLevel(mapping);
  FSimpleKeyAllowed := true;
  Inc(FPos);
  if mapping then
    AppendToken(TYAMLScanTokenKind.FlowMappingStart)
  else
    AppendToken(TYAMLScanTokenKind.FlowSequenceStart);
end;

procedure TYAMLScanner.FetchFlowCollectionEnd(mapping : boolean);
begin
  if FFlowLevel = 0 then
  begin
    if mapping then
      RaiseError('Unexpected "}" - there is no "{" for it to close')
    else
      RaiseError('Unexpected "]" - there is no "[" for it to close');
  end;
  RemoveSimpleKey;
  DecreaseFlowLevel;
  FSimpleKeyAllowed := false;
  Inc(FPos);
  if mapping then
    AppendToken(TYAMLScanTokenKind.FlowMappingEnd)
  else
    AppendToken(TYAMLScanTokenKind.FlowSequenceEnd);
end;

procedure TYAMLScanner.FetchFlowEntry;
begin
  if FFlowLevel = 0 then
    RaiseError('Unexpected "," - it separates the entries of a flow collection, and cannot start a plain scalar');
  RemoveSimpleKey;
  FSimpleKeyAllowed := true;
  Inc(FPos);
  AppendToken(TYAMLScanTokenKind.FlowEntry);
end;

procedure TYAMLScanner.FetchBlockEntry;
begin
  if FFlowLevel > 0 then
    RaiseError('A block sequence entry ("- ") cannot appear inside a flow collection');
  if not FSimpleKeyAllowed then
    RaiseError('A block sequence entry ("- ") is not allowed here - it must start a line (or follow "- ", "? " or ": ")');
  if FTabBeforeToken then
    RaiseError('Tabs are not allowed before a block sequence entry ("- ")');
  RollIndent(FStartColumn, -1, TYAMLScanTokenKind.BlockSequenceStart, FStartIndex, FStartLine, FStartColumn);
  RemoveSimpleKey;
  FSimpleKeyAllowed := true;
  Inc(FPos);
  AppendToken(TYAMLScanTokenKind.BlockEntry);
end;

procedure TYAMLScanner.FetchKey;
begin
  if FFlowLevel = 0 then
  begin
    if not FSimpleKeyAllowed then
      RaiseError('A mapping key ("? ") is not allowed here');
    if FTabBeforeToken then
      RaiseError('Tabs are not allowed before a mapping key indicator ("? ")');
    RollIndent(FStartColumn, -1, TYAMLScanTokenKind.BlockMappingStart, FStartIndex, FStartLine, FStartColumn);
  end;
  RemoveSimpleKey;
  FSimpleKeyAllowed := FFlowLevel = 0;
  Inc(FPos);
  AppendToken(TYAMLScanTokenKind.Key)^.Explicit := true;
end;

procedure TYAMLScanner.FetchValue;
var
  key : ^TYAMLSimpleKey;
begin
  key := @FSimpleKeys[FFlowLevel];
  if key^.Possible then
  begin
    if (FFlowLevel = 0) and key^.TabBefore then
      RaiseErrorAt('Tabs are not allowed before an implicit mapping key', key^.Line, key^.Column);
    // the key token goes in front of the key's first token, and in front of that the start
    // of a block mapping, when the key starts one
    InsertToken(key^.TokenNumber - FTokensParsed, TYAMLScanTokenKind.Key, key^.Index, key^.Line, key^.Column);
    RollIndent(key^.Column, key^.TokenNumber, TYAMLScanTokenKind.BlockMappingStart, key^.Index, key^.Line, key^.Column);
    key^.Possible := false;
    // no implicit key straight after another one ('a: b: c')
    FSimpleKeyAllowed := false;
  end
  else
  begin
    // an explicit value (after '? '), or a value with an empty key
    if FFlowLevel = 0 then
    begin
      if not FSimpleKeyAllowed then
        RaiseError('A mapping value is not allowed here (a ": " that does not follow a mapping key on the same line)');
      if FTabBeforeToken then
        RaiseError('Tabs are not allowed before a mapping value indicator (": ")');
      RollIndent(FStartColumn, -1, TYAMLScanTokenKind.BlockMappingStart, FStartIndex, FStartLine, FStartColumn);
    end;
    FSimpleKeyAllowed := FFlowLevel = 0;
  end;
  Inc(FPos);
  AppendToken(TYAMLScanTokenKind.Value);
end;

// '&name' or '*name' - the name runs to white space or a flow indicator (ns-anchor-char).
procedure TYAMLScanner.FetchAnchor(alias : boolean);
var
  start : integer;
  ch : Char;
  tok : PYAMLScanToken;
begin
  SaveSimpleKey;
  FSimpleKeyAllowed := false;
  Inc(FPos);
  start := AbsIndex;
  while true do
  begin
    ch := At(0);
    if IsBlankZ(ch) or IsFlowIndicator(ch) then
      break;
    Inc(FPos);
  end;
  if AbsIndex = start then
  begin
    if alias then
      RaiseError('An alias ("*") must be followed by the name of an anchor')
    else
      RaiseError('An anchor ("&") must be followed by its name');
  end;
  if alias then
    tok := AppendToken(TYAMLScanTokenKind.Alias)
  else
    tok := AppendToken(TYAMLScanTokenKind.Anchor);
  tok^.Value := CopyAbs(start, AbsIndex - start);
end;

// Advances over tag chars (ns-tag-char, or ns-uri-char when uri is set), checking the
// %xx escapes, and returns how many there were.
function TYAMLScanner.ScanTagChars(uri : boolean) : integer;
var
  start : integer;
  ch : Char;
begin
  start := AbsIndex;
  while true do
  begin
    ch := At(0);
    case ch of
      '0'..'9', 'a'..'z', 'A'..'Z', '-', '#', ';', '/', '?', ':', '@', '&', '=', '+', '$', '_', '.', '~', '*', '''', '(', ')' :
        Inc(FPos);
      '!', ',', '[', ']' :
        if uri then
          Inc(FPos)
        else
          break;
      '%' :
        begin
          if (HexValue(At(1)) < 0) or (HexValue(At(2)) < 0) then
            RaiseError('Invalid URI escape in a tag - "%" must be followed by two hex digits');
          Inc(FPos, 3);
        end;
    else
      break;
    end;
  end;
  result := AbsIndex - start;
end;

// '!<uri>', '!', '!suffix', '!!suffix' or '!handle!suffix'. The handle is resolved by the
// parser, which knows the document's %TAG directives.
procedure TYAMLScanner.FetchTag;
var
  start, len, k : integer;
  handle, suffix : string;
  ch : Char;
  tok : PYAMLScanToken;
begin
  SaveSimpleKey;
  FSimpleKeyAllowed := false;
  Inc(FPos); // '!'
  if At(0) = '<' then
  begin
    // verbatim
    Inc(FPos);
    start := AbsIndex;
    len := ScanTagChars(true);
    if (len = 0) or (At(0) <> '>') then
      RaiseError('Invalid verbatim tag - expected "!<uri>"');
    handle := '';
    suffix := CopyAbs(start, len);
    Inc(FPos);
  end
  else
  begin
    k := 0;
    while IsWordChar(At(k)) do
      Inc(k);
    if At(k) = '!' then
    begin
      handle := '!' + CopyAbs(AbsIndex, k) + '!';
      Inc(FPos, k + 1);
    end
    else
      handle := '!';
    start := AbsIndex;
    len := ScanTagChars(false);
    suffix := CopyAbs(start, len);
    if (len = 0) and (handle <> '!') then
      RaiseError(Format('The tag handle "%s" must be followed by a tag name', [handle]));
  end;
  ch := At(0);
  if not (IsBlankZ(ch) or ((FFlowLevel > 0) and ((ch = ',') or (ch = ']') or (ch = '}')))) then
    RaiseError('A tag must be followed by white space');
  tok := AppendToken(TYAMLScanTokenKind.Tag);
  tok^.Value := suffix;
  tok^.Value2 := handle;
end;

procedure TYAMLScanner.FetchBlockScalar(literal : boolean);
begin
  RemoveSimpleKey;
  // a simple key may follow a block scalar
  FSimpleKeyAllowed := true;
  ScanBlockScalar(literal);
end;

procedure TYAMLScanner.FetchFlowScalar(double : boolean);
begin
  SaveSimpleKey;
  FSimpleKeyAllowed := false;
  ScanFlowScalar(double);
end;

procedure TYAMLScanner.FetchPlainScalar;
begin
  SaveSimpleKey;
  FSimpleKeyAllowed := false;
  ScanPlainScalar;
end;

{ directives }

procedure TYAMLScanner.ScanDirective;
var
  start, blanks : integer;
  name : string;
  ch : Char;
  tok : PYAMLScanToken;

  function SkipBlanks : integer;
  begin
    result := 0;
    while (At(0) = ' ') or (At(0) = #9) do
    begin
      Inc(FPos);
      Inc(result);
    end;
  end;

  function ScanWord : string;
  var
    wordStart : integer;
  begin
    wordStart := AbsIndex;
    while not IsBlankZ(At(0)) do
      Inc(FPos);
    result := CopyAbs(wordStart, AbsIndex - wordStart);
  end;

begin
  Inc(FPos); // '%'
  start := AbsIndex;
  while not IsBlankZ(At(0)) do
    Inc(FPos);
  name := CopyAbs(start, AbsIndex - start);
  if name = '' then
    RaiseError('A directive name must follow "%"');
  if name = 'YAML' then
  begin
    tok := AppendToken(TYAMLScanTokenKind.VersionDirective);
    if SkipBlanks = 0 then
      RaiseError('Invalid YAML directive format, expected "major.minor"');
    tok^.Value := ScanWord;
  end
  else if name = 'TAG' then
  begin
    tok := AppendToken(TYAMLScanTokenKind.TagDirective);
    SkipBlanks;
    tok^.Value := ScanWord;
    SkipBlanks;
    tok^.Value2 := ScanWord;
    if (tok^.Value = '') or (tok^.Value2 = '') then
      RaiseError('A TAG directive needs both a handle and a prefix');
  end
  else
  begin
    // a reserved directive - its parameters are ignored
    tok := AppendToken(TYAMLScanTokenKind.ReservedDirective);
    tok^.Value := name;
    while true do
    begin
      blanks := SkipBlanks;
      ch := At(0);
      if IsBreak(ch) or ((ch = #0) and IsEndAt(0)) or ((ch = '#') and (blanks > 0)) then
        break;
      ScanWord;
    end;
  end;
  tok^.EndLine := FLine;
  SkipBlanks;
  ch := At(0);
  if not (IsBreak(ch) or ((ch = #0) and IsEndAt(0)) or ((ch = '#') and ((FText[FPos - 1] = ' ') or (FText[FPos - 1] = #9)))) then
    RaiseError(Format('Unexpected text after the %%%s directive', [name]));
end;

{ plain scalars }

// A plain scalar, folded per YAML 1.2 (7.3.3): a single line break between two lines becomes
// a space, each empty line a line feed. It ends at ': ', ' #', a flow indicator (in a flow
// collection), a line indented too little, a comment line or a document marker. When it ends
// at a line break, it is left at the start of the next non-empty line - not past its
// indentation, which ScanToNextToken checks.
procedure TYAMLScanner.ScanPlainScalar;
var
  flow : boolean;
  indent, runStart, runLen, firstStart, firstLen, wsStart, wsLen, breaks, k, spaces, endLine : integer;
  inScratch, emptyLine : boolean;
  ch, nx : Char;
  p, pEnd : PChar;
  text : string;
  tok : PYAMLScanToken;
begin
  flow := FFlowLevel > 0;
  indent := FIndent + 1;
  inScratch := false;
  firstStart := 0;
  firstLen := -1;
  wsStart := 0;
  wsLen := 0;
  breaks := 0;
  endLine := FLine;
  while true do
  begin
    // a run of chars that cannot end the scalar
    runStart := AbsIndex;
    while true do
    begin
      p := FText + FPos;
      pEnd := FText + FLen;
      while p <= pEnd do
      begin
        case p^ of
          ' ', #9, #10, #13, #0, ':' :
            break;
          ',', '[', ']', '{', '}' :
            if flow then
              break;
        end;
        Inc(p);
      end;
      FPos := p - FText;
      if p <= pEnd then
      begin
        if p^ <> ':' then
          break;
        // ':' ends the scalar only before white space (or a flow indicator)
        nx := At(1);
        if IsBlankZ(nx) or (flow and IsFlowIndicator(nx)) then
          break;
        Inc(FPos);
      end
      else if not Fill then
        break; // the end of the input
    end;
    runLen := AbsIndex - runStart;
    if runLen = 0 then
      break;

    if firstLen < 0 then
    begin
      firstStart := runStart;
      firstLen := runLen;
    end
    else
    begin
      if not inScratch then
      begin
        FScratchLen := 0;
        ScratchAppendAbs(firstStart, firstLen);
        inScratch := true;
      end;
      if breaks = 1 then
        ScratchAppendChar(' ')
      else if breaks > 1 then
        ScratchAppendBreaks(breaks - 1)
      else
        ScratchAppendAbs(wsStart, wsLen);
      ScratchAppendAbs(runStart, runLen);
    end;
    breaks := 0;
    wsLen := 0;
    endLine := FLine;

    ch := At(0);
    if (ch = ' ') or (ch = #9) then
    begin
      wsStart := AbsIndex;
      repeat
        Inc(FPos);
        ch := At(0);
      until (ch <> ' ') and (ch <> #9);
      wsLen := AbsIndex - wsStart;
      if not IsBreak(ch) then
      begin
        // more of the scalar on this line, unless a comment or an indicator follows
        if (ch = '#') or (ch = #0) then
          break;
        if ch = ':' then
        begin
          nx := At(1);
          if IsBlankZ(nx) or (flow and IsFlowIndicator(nx)) then
            break;
        end
        else if flow and IsFlowIndicator(ch) then
          break;
        continue;
      end;
      wsLen := 0; // white space at the end of a line is not content
    end;
    if not IsBreak(ch) then
      break; // an indicator ends the scalar

    // the line break, and any empty lines after it
    repeat
      SkipBreak;
      Inc(breaks);
      k := 0;
      while At(k) = ' ' do
        Inc(k);
      spaces := k;
      ch := At(k);
      if ch = #9 then
      begin
        while (At(k) = ' ') or (At(k) = #9) do
          Inc(k);
        ch := At(k);
      end;
      emptyLine := IsBreak(ch);
      if emptyLine then
        Inc(FPos, k);
    until not emptyLine;

    // does the next line go on with the scalar?
    if (ch = #0) and IsEndAt(k) then
      break;
    if flow then
    begin
      if spaces < FIndent + 1 then
        break;
    end
    else if spaces < indent then
      break;
    if (spaces = 0) and IsDocumentMarker then
      break;
    if ch = '#' then
      break;
    if ch = ':' then
    begin
      nx := At(k + 1);
      if IsBlankZ(nx) or (flow and IsFlowIndicator(nx)) then
        break;
    end
    else if flow and IsFlowIndicator(ch) then
      break;
    Inc(FPos, k);
  end;

  // a scalar that ends at a line break is followed by the start of a line
  if (breaks > 0) and not flow then
    FSimpleKeyAllowed := true;

  if inScratch then
    text := FInterner.InternChars(PChar(Pointer(FScratch)), FScratchLen, FValueIntern)
  else if (breaks = 0) and (At(0) = ':') then
    text := FInterner.InternChars(FText + (firstStart - FReader.BufferBase), firstLen, FKeyIntern)
  else
    text := FInterner.InternChars(FText + (firstStart - FReader.BufferBase), firstLen, FValueIntern);
  tok := AppendToken(TYAMLScanTokenKind.Scalar);
  tok^.Value := text;
  tok^.EndLine := endLine;
end;

{ quoted scalars }

// A single or double quoted scalar. Its line breaks fold as a plain scalar's do (white
// space around them is dropped), and every line after the first must be indented more than
// the block collection the scalar is in.
procedure TYAMLScanner.ScanFlowScalar(double : boolean);
var
  quote, ch : Char;
  contentStart, runStart, wsStart : integer;
  simple : boolean;
  p, pEnd : PChar;
  text : string;
  tok : PYAMLScanToken;
begin
  if double then
    quote := '"'
  else
    quote := '''';
  Inc(FPos); // the opening quote
  contentStart := AbsIndex;
  simple := true; // the content so far is the input from contentStart, unchanged
  FScratchLen := 0;
  while true do
  begin
    runStart := AbsIndex;
    while true do
    begin
      p := FText + FPos;
      pEnd := FText + FLen;
      while (p <= pEnd) and (p^ <> quote) and (p^ <> '\') and (p^ > ' ') do
        Inc(p);
      FPos := p - FText;
      if p > pEnd then
      begin
        if not Fill then
          break;
        continue;
      end;
      ch := p^;
      // a '\' in a single quoted scalar, or a char below space that is not white space or
      // a line break, is content
      if ((ch = '\') and not double) or ((ch < ' ') and (ch <> #9) and (ch <> #10) and (ch <> #13) and (ch <> #0)) then
      begin
        Inc(FPos);
        continue;
      end;
      break;
    end;
    ch := At(0);
    if not simple then
      ScratchAppendAbs(runStart, AbsIndex - runStart);

    if ch = quote then
    begin
      if (not double) and (At(1) = '''') then
      begin
        // '' is a quote
        if simple then
        begin
          ScratchAppendAbs(contentStart, AbsIndex - contentStart);
          simple := false;
        end;
        ScratchAppendChar('''');
        Inc(FPos, 2);
        continue;
      end;
      break;
    end;

    if (ch = ' ') or (ch = #9) then
    begin
      wsStart := AbsIndex;
      repeat
        Inc(FPos);
        ch := At(0);
      until (ch <> ' ') and (ch <> #9);
      if not IsBreak(ch) then
      begin
        if not simple then
          ScratchAppendAbs(wsStart, AbsIndex - wsStart);
        continue;
      end;
      // white space before a line break is not content
      if simple then
      begin
        ScratchAppendAbs(contentStart, wsStart - contentStart);
        simple := false;
      end;
    end;

    if IsBreak(ch) then
    begin
      if simple then
      begin
        ScratchAppendAbs(contentStart, AbsIndex - contentStart);
        simple := false;
      end;
      FoldQuotedLines(false);
      continue;
    end;

    if ch = '\' then
    begin
      if simple then
      begin
        ScratchAppendAbs(contentStart, AbsIndex - contentStart);
        simple := false;
      end;
      ScanEscape;
      continue;
    end;

    // #0
    if IsEndAt(0) then
      RaiseError('Unexpected end of the input inside a quoted scalar (the closing quote is missing)');
    RaiseError('Invalid character (#0) in a quoted scalar');
  end;

  if simple then
    text := FInterner.InternChars(FText + (contentStart - FReader.BufferBase), AbsIndex - contentStart, FValueIntern)
  else
    text := FInterner.InternChars(PChar(Pointer(FScratch)), FScratchLen, FValueIntern);
  Inc(FPos); // the closing quote
  tok := AppendToken(TYAMLScanTokenKind.Scalar);
  if double then
    tok^.Style := TYAMLScalarStyle.DoubleQuoted
  else
    tok^.Style := TYAMLScalarStyle.SingleQuoted;
  tok^.Value := text;
end;

// At a line break inside a quoted scalar: consumes it, the empty lines after it and the
// next line's indentation, and appends what they fold to - a space for a single break, a
// line feed for each empty line. After an escaped line break ('\' at the end of a line)
// the break itself adds nothing.
procedure TYAMLScanner.FoldQuotedLines(escaped : boolean);
var
  breaks, spaces : integer;
  ch : Char;
begin
  breaks := 0;
  while true do
  begin
    SkipBreak;
    Inc(breaks);
    spaces := 0;
    while At(0) = ' ' do
    begin
      Inc(FPos);
      Inc(spaces);
    end;
    ch := At(0);
    if ch = #9 then
    begin
      repeat
        Inc(FPos);
        ch := At(0);
      until (ch <> ' ') and (ch <> #9);
    end;
    if IsBreak(ch) then
      continue;
    if (ch = #0) and IsEndAt(0) then
      break; // reported by the caller
    if spaces < FIndent + 1 then
      RaiseError('A line of a quoted scalar must be indented more than the block collection it is in');
    if IsDocumentMarker then
      RaiseError('A document marker ("---" or "...") cannot appear inside a quoted scalar');
    break;
  end;
  if escaped then
    ScratchAppendBreaks(breaks - 1)
  else if breaks = 1 then
    ScratchAppendChar(' ')
  else
    ScratchAppendBreaks(breaks - 1);
end;

// At a '\' in a double quoted scalar.
procedure TYAMLScanner.ScanEscape;
var
  ch : Char;
  digits, i, value, d : integer;
begin
  Inc(FPos); // '\'
  ch := At(0);
  digits := 0;
  case ch of
    '0' : ScratchAppendChar(#0);
    'a' : ScratchAppendChar(#7);
    'b' : ScratchAppendChar(#8);
    't', #9 : ScratchAppendChar(#9);
    'n' : ScratchAppendChar(#10);
    'v' : ScratchAppendChar(#11);
    'f' : ScratchAppendChar(#12);
    'r' : ScratchAppendChar(#13);
    'e' : ScratchAppendChar(#27);
    ' ' : ScratchAppendChar(' ');
    '"' : ScratchAppendChar('"');
    '/' : ScratchAppendChar('/');
    '\' : ScratchAppendChar('\');
    'N' : ScratchAppendChar(Char($85));
    '_' : ScratchAppendChar(Char($A0));
    'L' : ScratchAppendChar(#$2028);
    'P' : ScratchAppendChar(#$2029);
    'x' : digits := 2;
    'u' : digits := 4;
    'U' : digits := 8;
    #10, #13 :
      begin
        // an escaped line break: the lines join with nothing between them
        FoldQuotedLines(true);
        exit;
      end;
  else
    if (ch = #0) and IsEndAt(0) then
      RaiseError('Unexpected end of the input inside a quoted scalar (the closing quote is missing)');
    RaiseError(Format('Invalid escape sequence "\%s" in a double quoted scalar', [ch]));
  end;
  Inc(FPos);
  if digits = 0 then
    exit;
  value := 0;
  for i := 0 to digits - 1 do
  begin
    d := HexValue(At(i));
    if d < 0 then
      RaiseError(Format('Invalid escape sequence - "\%s" must be followed by %d hex digits', [ch, digits]));
    value := (value shl 4) or d;
  end;
  if ((value >= $D800) and (value <= $DFFF)) or (value > $10FFFF) or (value < 0) then
    RaiseError('Invalid Unicode escape - not a Unicode character');
  Inc(FPos, digits);
  if value > $FFFF then
  begin
    Dec(value, $10000);
    ScratchAppendChar(Char($D800 + (value shr 10)));
    ScratchAppendChar(Char($DC00 + (value and $3FF)));
  end
  else
    ScratchAppendChar(Char(value));
end;

{ block scalars }

// A literal ('|') or folded ('>') block scalar, with its chomping and indentation
// indicators. The content indentation is the indicator's value more than the indentation of
// the block collection the scalar is in, or else that of its first non-empty line. It ends
// at the first non-empty line indented less, which is left for ScanToNextToken.
procedure TYAMLScanner.ScanBlockScalar(literal : boolean);
var
  chomping, increment, indent, minIndent, k, maxLeading, trailingBreaks, blanks, headerLine, lineStart : integer;
  haveContent, pendingBreak, prevSpaced, lineSpaced, indentKnown, ended, emptyLine : boolean;
  ch : Char;
  tok : PYAMLScanToken;
begin
  headerLine := FLine;
  Inc(FPos); // '|' or '>'
  chomping := 0;
  increment := 0;
  ch := At(0);
  if (ch = '+') or (ch = '-') then
  begin
    if ch = '+' then
      chomping := 1
    else
      chomping := -1;
    Inc(FPos);
    ch := At(0);
    if (ch >= '0') and (ch <= '9') then
    begin
      if ch = '0' then
        RaiseError('The indentation indicator of a block scalar must be 1 to 9');
      increment := Ord(ch) - Ord('0');
      Inc(FPos);
    end;
  end
  else if (ch >= '0') and (ch <= '9') then
  begin
    if ch = '0' then
      RaiseError('The indentation indicator of a block scalar must be 1 to 9');
    increment := Ord(ch) - Ord('0');
    Inc(FPos);
    ch := At(0);
    if (ch = '+') or (ch = '-') then
    begin
      if ch = '+' then
        chomping := 1
      else
        chomping := -1;
      Inc(FPos);
    end;
  end;

  // the rest of the header line: white space and a comment
  blanks := 0;
  while (At(0) = ' ') or (At(0) = #9) do
  begin
    Inc(FPos);
    Inc(blanks);
  end;
  ch := At(0);
  if ch = '#' then
  begin
    if blanks = 0 then
      RaiseError('A comment must be separated from the text before it by white space');
    ScanComment;
    ch := At(0);
  end;
  if not (IsBreak(ch) or ((ch = #0) and IsEndAt(0))) then
    RaiseError('Invalid block scalar header - only a chomping indicator ("+" or "-"), an indentation indicator (1-9) and a comment may follow "|" or ">"');

  FScratchLen := 0;
  minIndent := FIndent + 1;
  indentKnown := increment > 0;
  if indentKnown then
    indent := FIndent + increment
  else
    indent := minIndent;
  haveContent := false;
  pendingBreak := false;
  prevSpaced := false;
  trailingBreaks := 0;
  maxLeading := 0;
  ended := not IsBreak(ch);
  if not ended then
    SkipBreak;

  if (not ended) and (not indentKnown) then
  begin
    // leading empty lines, and the first non-empty line, which sets the indentation
    repeat
      k := 0;
      while At(k) = ' ' do
        Inc(k);
      emptyLine := IsBreak(At(k));
      if emptyLine then
      begin
        if k > maxLeading then
          maxLeading := k;
        Inc(FPos, k);
        SkipBreak;
        Inc(trailingBreaks);
      end
      else if (k > 0) and IsEndAt(k) then
      begin
        // the end of the input ends a last line of spaces as a line break would
        if k > maxLeading then
          maxLeading := k;
        Inc(FPos, k);
        Inc(trailingBreaks);
        k := 0;
      end;
    until not emptyLine;
    if IsEndAt(k) or (k < minIndent) or ((k = 0) and IsDocumentMarker) then
    begin
      // no content
      if (k < minIndent) and (At(k) = #9) and IsWhiteLineAt(k) then
        RaiseError('Tabs are not allowed for indentation in YAML');
      if maxLeading > indent then
        indent := maxLeading;
      ended := true;
    end
    else
    begin
      indent := k;
      if maxLeading > indent then
        RaiseError('A leading empty line of a block scalar has more spaces than its first non-empty line');
    end;
  end;

  while not ended do
  begin
    k := 0;
    while (k < indent) and (At(k) = ' ') do
      Inc(k);
    ch := At(k);
    if (ch = #0) and IsEndAt(k) then
    begin
      // a last line of spaces with no line break is an empty line
      if k > 0 then
      begin
        Inc(FPos, k);
        Inc(trailingBreaks);
      end;
      break;
    end;
    if k < indent then
    begin
      if IsBreak(ch) then
      begin
        // an empty line
        Inc(FPos, k);
        SkipBreak;
        Inc(trailingBreaks);
        continue;
      end;
      if (ch = #9) and IsWhiteLineAt(k) then
        RaiseError('Tabs are not allowed for indentation in YAML');
      break; // indented less: the end of the scalar
    end;
    if (indent = 0) and IsDocumentMarker then
      break;
    Inc(FPos, k);
    ch := At(0);
    if IsBreak(ch) then
    begin
      SkipBreak;
      Inc(trailingBreaks);
      continue;
    end;
    if (ch = #0) and IsEndAt(0) then
      break;

    // a line of text
    lineSpaced := (ch = ' ') or (ch = #9);
    if haveContent then
    begin
      if (not literal) and pendingBreak and (not prevSpaced) and (not lineSpaced) then
      begin
        if trailingBreaks = 0 then
          ScratchAppendChar(' ');
      end
      else if pendingBreak then
        ScratchAppendChar(#10);
    end;
    ScratchAppendBreaks(trailingBreaks);
    trailingBreaks := 0;
    lineStart := AbsIndex;
    while true do
    begin
      ch := At(0);
      if IsBreak(ch) or ((ch = #0) and IsEndAt(0)) then
        break;
      Inc(FPos);
    end;
    ScratchAppendAbs(lineStart, AbsIndex - lineStart);
    haveContent := true;
    prevSpaced := lineSpaced;
    // the end of the input ends the last line as a line break would
    pendingBreak := true;
    if IsBreak(ch) then
      SkipBreak
    else
      break;
  end;

  // chomping
  if (chomping >= 0) and haveContent and pendingBreak then
    ScratchAppendChar(#10);
  if chomping = 1 then
    ScratchAppendBreaks(trailingBreaks);

  tok := AppendToken(TYAMLScanTokenKind.Scalar);
  if literal then
    tok^.Style := TYAMLScalarStyle.Literal
  else
    tok^.Style := TYAMLScalarStyle.Folded;
  tok^.Value := ScratchText;
  tok^.EndLine := headerLine;
end;

end.
