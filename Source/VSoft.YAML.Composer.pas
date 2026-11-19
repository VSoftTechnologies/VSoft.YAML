unit VSoft.YAML.Composer;

interface

{$I 'VSoft.YAML.inc'}

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  VSoft.YAML,
  VSoft.YAML.IO,
  VSoft.YAML.Classes,
  VSoft.YAML.Scanner;

type
  /// <summary>
  ///  Reads YAML 1.2 into documents: a recursive descent parser over the tokens of
  ///  TYAMLScanner (the YAML 1.2 grammar, as libyaml parses it) that builds the value classes
  ///  directly.
  ///
  ///  With YAML11Compatibility on (the default) it also reads the YAML 1.1 forms VSoft.YAML has
  ///  always read: yes/no/on/off booleans, 0b integers, '_' digit separators and timestamps
  ///  (see YAMLResolvePlainScalar), '&lt;&lt;' merge keys, and a block mapping of '? ' keys
  ///  without values as a set. Off, plain scalars resolve by the YAML 1.2 core schema alone
  ///  and those forms are as YAML 1.2 reads them. The syntax is YAML 1.2's either way.
  ///
  ///  Mapping keys are strings: a scalar key is its text, a collection key the collection in
  ///  flow style. Comments are kept as the YAML parser has always kept them: a comment after a
  ///  scalar or flow collection, on the same line, is its Comment, comment lines go to the
  ///  next collection that starts (those at the top of a document to the first collection
  ///  inside the root, or to the root when there is none), and comments after the root's
  ///  content to the document's EndComments.
  /// </summary>
  TYAMLComposer = class
  private
    FScanner : TYAMLScanner;
    FLenient : boolean;
    FDuplicateError : boolean;
    FAnchors : TDictionary<string, IYAMLValue>;
    FPendingComments : TArray<string>; // comment lines not given to a collection yet:
    FPendingCount : integer;           // the first FPendingCount
    FIsDocumentLevel : boolean;
    FDepth : integer;
    FLastContentIndex : integer; // start of the last content token taken
    FLastScalarPlain : boolean;  // the last scalar composed was plain and had no tag
    FPrevDocumentOpen : boolean; // the previous document did not end with '...'

    // the directives of the current document
    FVersion : IYAMLVersionDirective;
    FHasVersion : boolean;
    FTagDirectives : TList<IYAMLTagDirective>;
    FTagHandles : TStringList; // handle=prefix, the defaults first
    FDeclaredHandles : TStringList;

    procedure RaiseError(const msg : string);overload;{$IFDEF NORETURN}noreturn;{$ENDIF}
    procedure RaiseError(const fmt : string; const args : array of const);overload;{$IFDEF NORETURN}noreturn;{$ENDIF}
    procedure RaiseErrorAt(const msg : string; line, column : integer);{$IFDEF NORETURN}noreturn;{$ENDIF}

    procedure ResetDocument;
    procedure ProcessDirective(tok : PYAMLScanToken);
    function ResolveTag(const handle, suffix : string; line, column : integer; out nonSpecific : boolean) : IYAMLTagInfo;

    procedure EnterCollection;
    procedure PullComments(beforeIndex : integer);
    function TakePendingComments : TArray<string>;
    procedure TakeLeadingComments(const collection : IYAMLCollection; startIndex : integer);
    procedure TakeSameLineComment(const value : IYAMLValue; line : integer);

    function NewNull(const parent : IYAMLValue) : IYAMLValue;inline;
    function IsSetTag(const tagInfo : IYAMLTagInfo) : boolean;
    function KeyText(const key : IYAMLValue) : string;
    procedure AddEntry(const mapping : IYAMLMapping; const mappingPriv : IYAMLMappingPrivate; const text : string;
      const value : IYAMLValue; isMergeKey : boolean; line, column : integer);

    function ParseNode(const parent : IYAMLValue; block, indentlessSequence : boolean) : IYAMLValue;
    function ParseNodeWithProperties(const parent : IYAMLValue; block, indentlessSequence : boolean) : IYAMLValue;
    function ParseKey(const mapping : IYAMLValue; block, keepNode : boolean; out key : IYAMLValue; out isMergeKey : boolean) : string;
    function ParseScalar(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo; nonSpecific : boolean) : IYAMLValue;
    function ParseTaggedScalar(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo; nonSpecific : boolean) : IYAMLValue;
    function ParseBlockSequence(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo) : IYAMLValue;
    function ParseIndentlessSequence(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo) : IYAMLValue;
    function ParseBlockMapping(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo) : IYAMLValue;
    function ParseFlowSequence(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo) : IYAMLValue;
    function ParseFlowMapping(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo) : IYAMLValue;
    function ParseFlowPair(const parent : IYAMLValue) : IYAMLValue;
    function ParseDocument : IYAMLDocument;
  public
    constructor Create(const reader : IInputReader; const options : IYAMLParserOptions);
    destructor Destroy;override;

    /// <summary> The first document of the stream (null when there is none); what follows it
    ///  is not read. </summary>
    function Parse : IYAMLDocument;
    /// <summary> Every document of the stream - none for an empty stream (or one that has
    ///  only comments). </summary>
    function ParseAll : TArray<IYAMLDocument>;
  end;

implementation

uses
  System.StrUtils,
  VSoft.YAML.TagInfo;

const
  // Collections nested deeper than this are an error rather than a stack overflow.
  cMaxNestingDepth = 1000;
  cCoreTagPrefix = 'tag:yaml.org,2002:';

function PercentDecode(const value : string) : string;
var
  bytes : TBytes;
  i, count, hi, lo : integer;

  function Hex(ch : Char) : integer;
  begin
    case ch of
      '0'..'9' : result := Ord(ch) - Ord('0');
      'a'..'f' : result := Ord(ch) - Ord('a') + 10;
      'A'..'F' : result := Ord(ch) - Ord('A') + 10;
    else
      result := -1;
    end;
  end;

begin
  if Pos('%', value) = 0 then
    exit(value);
  // decode the %xx escapes as UTF-8 bytes; the rest of a tag is ASCII
  SetLength(bytes, Length(value));
  count := 0;
  i := 1;
  while i <= Length(value) do
  begin
    if (value[i] = '%') and (i + 2 <= Length(value)) then
    begin
      hi := Hex(value[i + 1]);
      lo := Hex(value[i + 2]);
      if (hi >= 0) and (lo >= 0) then
      begin
        bytes[count] := (hi shl 4) or lo;
        Inc(count);
        Inc(i, 3);
        continue;
      end;
    end;
    bytes[count] := Byte(Ord(value[i]) and $FF);
    Inc(count);
    Inc(i);
  end;
  result := TEncoding.UTF8.GetString(bytes, 0, count);
end;

// A collection written in flow style, for a collection used as a mapping key.
function FlowText(const value : IYAMLValue) : string;
var
  i : integer;
  sb : TStringBuilder;
  mapping : IYAMLMapping;
  sequence : IYAMLSequence;
begin
  if value = nil then
    exit('');
  if value.IsMapping then
  begin
    mapping := value.AsMapping;
    sb := TStringBuilder.Create;
    try
      sb.Append('{');
      for i := 0 to mapping.Count - 1 do
      begin
        if i > 0 then
          sb.Append(', ');
        sb.Append(mapping.Keys[i]);
        sb.Append(': ');
        sb.Append(FlowText(mapping.Values[mapping.Keys[i]]));
      end;
      sb.Append('}');
      result := sb.ToString;
    finally
      sb.Free;
    end;
  end
  else if value.IsSequence or value.IsSet then
  begin
    if value.IsSet then
      sequence := value.AsSet
    else
      sequence := value.AsSequence;
    sb := TStringBuilder.Create;
    try
      sb.Append('[');
      for i := 0 to sequence.Count - 1 do
      begin
        if i > 0 then
          sb.Append(', ');
        sb.Append(FlowText(sequence[i]));
      end;
      sb.Append(']');
      result := sb.ToString;
    finally
      sb.Free;
    end;
  end
  else if value.IsNull then
    result := 'null'
  else
    result := value.RawValue;
end;

// A decimal number with YAML 1.1 '_' digit separators in its integer part:
// [-+]?[0-9][0-9_]*(\.[0-9]*)?([eE][-+]?[0-9]+)?
function IsSeparatedDecimal(const text : string) : boolean;
var
  i, len, start : integer;
begin
  result := false;
  len := Length(text);
  i := 1;
  if (i <= len) and ((text[i] = '-') or (text[i] = '+')) then
    Inc(i);
  if (i > len) or not ((text[i] >= '0') and (text[i] <= '9')) then
    exit;
  while (i <= len) and (((text[i] >= '0') and (text[i] <= '9')) or (text[i] = '_')) do
    Inc(i);
  if (i <= len) and (text[i] = '.') then
  begin
    Inc(i);
    while (i <= len) and (text[i] >= '0') and (text[i] <= '9') do
      Inc(i);
  end;
  if (i <= len) and ((text[i] = 'e') or (text[i] = 'E')) then
  begin
    Inc(i);
    if (i <= len) and ((text[i] = '-') or (text[i] = '+')) then
      Inc(i);
    start := i;
    while (i <= len) and (text[i] >= '0') and (text[i] <= '9') do
      Inc(i);
    if i = start then
      exit;
  end;
  result := i > len;
end;

// The type of a plain scalar with the YAML 1.1 extras: YAMLResolvePlainScalar, and a decimal
// number written with '_' separators, which are dropped from text (4_200 is 4200).
function ResolveLenient(var text : string) : TYAMLValueType;
var
  stripped : string;
begin
  result := YAMLResolvePlainScalar(text);
  if (result = TYAMLValueType.vtString) and (Pos('_', text) > 0) and IsSeparatedDecimal(text) then
  begin
    stripped := StringReplace(text, '_', '', [rfReplaceAll]);
    result := YAMLResolvePlainScalar(stripped);
    if (result = TYAMLValueType.vtInteger) or (result = TYAMLValueType.vtFloat) then
      text := stripped
    else
      result := TYAMLValueType.vtString;
  end;
end;

{ TYAMLComposer }

constructor TYAMLComposer.Create(const reader : IInputReader; const options : IYAMLParserOptions);
begin
  inherited Create;
  FScanner := TYAMLScanner.Create(reader);
  FLenient := (options = nil) or options.YAML11Compatibility;
  FDuplicateError := (options <> nil) and (options.DuplicateKeyBehavior = TYAMLDuplicateKeyBehavior.dkError);
  FAnchors := TDictionary<string, IYAMLValue>.Create;
  FTagDirectives := TList<IYAMLTagDirective>.Create;
  FTagHandles := TStringList.Create;
  FDeclaredHandles := TStringList.Create;
end;

destructor TYAMLComposer.Destroy;
begin
  FDeclaredHandles.Free;
  FTagHandles.Free;
  FTagDirectives.Free;
  FAnchors.Free;
  FScanner.Free;
  inherited;
end;

procedure TYAMLComposer.RaiseError(const msg : string);
var
  tok : PYAMLScanToken;
begin
  tok := FScanner.Peek;
  raise EYAMLParseException.Create(msg, tok^.Line, tok^.Column + 1);
end;

procedure TYAMLComposer.RaiseError(const fmt : string; const args : array of const);
begin
  RaiseError(Format(fmt, args));
end;

procedure TYAMLComposer.RaiseErrorAt(const msg : string; line, column : integer);
begin
  raise EYAMLParseException.Create(msg, line, column + 1);
end;

{ directives }

procedure TYAMLComposer.ResetDocument;
begin
  FAnchors.Clear;
  FIsDocumentLevel := true;
  FDepth := 0;
  FLastContentIndex := 0;
  FVersion := TYAMLVersionDirective.YAML_1_2;
  FHasVersion := false;
  FTagDirectives.Clear;
  FTagDirectives.Add(TYAMLTagDirective.Create('!', '!'));
  FTagDirectives.Add(TYAMLTagDirective.Create('!!', cCoreTagPrefix));
  FTagHandles.Clear;
  FTagHandles.Add('!=!');
  FTagHandles.Add('!!=' + cCoreTagPrefix);
  FDeclaredHandles.Clear;
end;

procedure TYAMLComposer.ProcessDirective(tok : PYAMLScanToken);
var
  text, handle, prefix : string;
  dotPos, major, minor, i, index : integer;
  version : IYAMLVersionDirective;
  valid : boolean;
begin
  case tok^.Kind of
    TYAMLScanTokenKind.VersionDirective :
      begin
        if FHasVersion then
          RaiseError('Multiple YAML directives are not allowed in the same document');
        text := tok^.Value;
        dotPos := Pos('.', text);
        valid := (dotPos > 1) and (dotPos < Length(text));
        if valid then
        begin
          for i := 1 to Length(text) do
          begin
            if (i <> dotPos) and not ((text[i] >= '0') and (text[i] <= '9')) then
              valid := false;
          end;
        end;
        if not valid then
          RaiseError('Invalid YAML directive format, expected "major.minor"');
        if not (TryStrToInt(Copy(text, 1, dotPos - 1), major) and TryStrToInt(Copy(text, dotPos + 1, MaxInt), minor)) then
          RaiseError('Invalid YAML version numbers');
        version := TYAMLVersionDirective.Create(major, minor);
        if major <> 1 then
          RaiseError('Unsupported YAML version %s - major version %d not supported', [version.ToString, major]);
        // 1.1 and 1.2 are read as they are; a later 1.x is read as 1.2 (YAML 1.2, 6.8.1)
        if minor < 1 then
          RaiseError('Incompatible YAML version %s', [version.ToString]);
        FVersion := version;
        FHasVersion := true;
      end;
    TYAMLScanTokenKind.TagDirective :
      begin
        handle := tok^.Value;
        prefix := tok^.Value2;
        valid := (Length(handle) >= 1) and (handle[1] = '!') and ((Length(handle) = 1) or (handle[Length(handle)] = '!'));
        if valid then
        begin
          for i := 2 to Length(handle) - 1 do
          begin
            case handle[i] of
              '0'..'9', 'a'..'z', 'A'..'Z', '-' : ;
            else
              valid := false;
            end;
          end;
        end;
        if not valid then
          RaiseError('Invalid TAG handle "%s" - a handle is "!", "!!" or "!name!"', [handle]);
        if FDeclaredHandles.IndexOf(handle) >= 0 then
          RaiseError('The TAG handle "%s" is declared more than once in this document', [handle]);
        FDeclaredHandles.Add(handle);
        index := FTagHandles.IndexOfName(handle);
        if index >= 0 then
        begin
          // the default '!' or '!!' redefined
          FTagHandles[index] := handle + '=' + prefix;
          FTagDirectives[index] := TYAMLTagDirective.Create(handle, prefix);
        end
        else
        begin
          FTagHandles.Add(handle + '=' + prefix);
          FTagDirectives.Add(TYAMLTagDirective.Create(handle, prefix));
        end;
      end;
  end;
  // reserved directives are ignored (YAML 1.2, 6.8)
end;

function TYAMLComposer.ResolveTag(const handle, suffix : string; line, column : integer; out nonSpecific : boolean) : IYAMLTagInfo;
var
  index : integer;
  prefix, uri : string;
begin
  nonSpecific := false;
  if handle = '' then
  begin
    // verbatim
    uri := PercentDecode(suffix);
    if StartsStr(cCoreTagPrefix, uri) then
      result := TYAMLTagInfoFactory.CreateStandardTag(Copy(uri, Length(cCoreTagPrefix) + 1, MaxInt))
    else
      result := TYAMLTagInfoFactory.CreateVerbatimTag(uri);
    exit;
  end;
  if (handle = '!') and (suffix = '') then
  begin
    // the non-specific tag: a scalar is a string
    nonSpecific := true;
    result := TYAMLTagInfoFactory.ParseTag('!');
    exit;
  end;
  // a %TAG directive applies to its own document only
  index := FTagHandles.IndexOfName(handle);
  if index < 0 then
    RaiseErrorAt(Format('The tag handle "%s" is not declared by a %%TAG directive in this document', [handle]), line, column);
  prefix := FTagHandles.ValueFromIndex[index];
  if (handle = '!!') and (prefix = cCoreTagPrefix) then
    result := TYAMLTagInfoFactory.CreateStandardTag(suffix)
  else if (handle = '!') and (prefix = '!') then
    result := TYAMLTagInfoFactory.CreateLocalTag(suffix)
  else
  begin
    uri := prefix + PercentDecode(suffix);
    if StartsStr(cCoreTagPrefix, uri) then
      result := TYAMLTagInfoFactory.CreateStandardTag(Copy(uri, Length(cCoreTagPrefix) + 1, MaxInt))
    else if handle = '!!' then
      // '!!' given another prefix - written out in full, so that '!!int' is not taken for the
      // core schema's int
      result := TYAMLTagInfoFactory.CreateVerbatimTag(uri)
    else
      result := TYAMLTagInfoFactory.CreateCustomTag(handle, suffix, prefix);
  end;
end;

{ comments }

procedure TYAMLComposer.EnterCollection;
begin
  Inc(FDepth);
  if FDepth > cMaxNestingDepth then
    RaiseError('Collections are nested more than %d deep', [cMaxNestingDepth]);
end;

// Moves the comments that come before beforeIndex into the pending list.
procedure TYAMLComposer.PullComments(beforeIndex : integer);
var
  c : PYAMLScanComment;
begin
  while true do
  begin
    c := FScanner.PeekComment;
    if (c = nil) or (c^.Index >= beforeIndex) then
      break;
    if c^.Text <> '' then
    begin
      if FPendingCount = Length(FPendingComments) then
        SetLength(FPendingComments, FPendingCount * 2 + 4);
      FPendingComments[FPendingCount] := c^.Text;
      Inc(FPendingCount);
    end;
    FScanner.SkipComment;
  end;
end;

// The pending comment lines, which are then no longer pending.
function TYAMLComposer.TakePendingComments : TArray<string>;
var
  i : integer;
begin
  SetLength(result, FPendingCount);
  for i := 0 to FPendingCount - 1 do
  begin
    result[i] := FPendingComments[i];
    FPendingComments[i] := '';
  end;
  FPendingCount := 0;
end;

// The comments before a collection are its Comments - except that those at the top of a
// document go to the first collection inside the root, not to the root itself.
procedure TYAMLComposer.TakeLeadingComments(const collection : IYAMLCollection; startIndex : integer);
var
  lines : TArray<string>;
  i : integer;
begin
  PullComments(startIndex);
  if FPendingCount = 0 then
    exit;
  if FIsDocumentLevel and (collection.Parent = nil) then
    exit;
  lines := TakePendingComments;
  if collection.HasComments then
  begin
    for i := 0 to Length(lines) - 1 do
      collection.AddComment(lines[i]);
  end
  else
    collection.Comments := lines;
  FIsDocumentLevel := false;
end;

// A comment on line, after the value that ends there and before the next token, is the
// value's Comment.
procedure TYAMLComposer.TakeSameLineComment(const value : IYAMLValue; line : integer);
var
  c : PYAMLScanComment;
  nextIndex : integer;
begin
  // a comment is found as the scanner looks for the token after it
  nextIndex := FScanner.Peek^.Index;
  c := FScanner.PeekComment;
  if (c <> nil) and c^.Trailing and (c^.Line = line) and (c^.Index < nextIndex) then
  begin
    if c^.Text <> '' then
      value.Comment := c^.Text;
    FScanner.SkipComment;
  end;
end;

{ nodes }

function TYAMLComposer.NewNull(const parent : IYAMLValue) : IYAMLValue;
begin
  result := TYAMLValue.Create(parent, TYAMLValueType.vtNull, '', '');
end;

function TYAMLComposer.IsSetTag(const tagInfo : IYAMLTagInfo) : boolean;
begin
  result := (tagInfo <> nil) and (tagInfo.ResolvedTag = cCoreTagPrefix + 'set');
end;

function TYAMLComposer.KeyText(const key : IYAMLValue) : string;
begin
  if key = nil then
    result := ''
  else if key.IsScalar then
    result := key.RawValue
  else
    result := FlowText(key);
end;

// Reads a mapping key and returns the text it is stored under. A scalar without properties is
// taken as its text, with no node made for it, unless keepNode is set; any other key is
// returned in key as well.
function TYAMLComposer.ParseKey(const mapping : IYAMLValue; block, keepNode : boolean; out key : IYAMLValue; out isMergeKey : boolean) : string;
var
  tok : PYAMLScanToken;
begin
  tok := FScanner.Peek;
  if (tok^.Kind = TYAMLScanTokenKind.Scalar) and not keepNode then
  begin
    result := tok^.Value;
    isMergeKey := (tok^.Style = TYAMLScalarStyle.Plain) and (result = '<<');
    FLastContentIndex := tok^.Index;
    key := nil;
    FScanner.Skip;
    exit;
  end;
  key := ParseNode(mapping, block, block);
  isMergeKey := FLastScalarPlain and key.IsScalar and (key.RawValue = '<<');
  result := KeyText(key);
end;

procedure TYAMLComposer.AddEntry(const mapping : IYAMLMapping; const mappingPriv : IYAMLMappingPrivate; const text : string;
  const value : IYAMLValue; isMergeKey : boolean; line, column : integer);
var
  i : integer;
  sequence : IYAMLSequence;
begin
  if isMergeKey and FLenient then
  begin
    // YAML 1.1 merge key: the keys of the mapping (or of each mapping in a sequence, the
    // earlier ones first) that this mapping does not have yet
    if value.IsMapping then
      mappingPriv.MergeMapping(value.AsMapping)
    else if value.IsSequence then
    begin
      sequence := value.AsSequence;
      for i := 0 to sequence.Count - 1 do
      begin
        if sequence[i].IsMapping then
          mappingPriv.MergeMapping(sequence[i].AsMapping);
      end;
    end;
    exit;
  end;
  if FDuplicateError and mapping.ContainsKey(text) then
    RaiseErrorAt(Format('duplicated mapping key : "%s"', [text]), line, column);
  mappingPriv.AddOrSetValue(text, value);
end;

// A node with no anchor or tag goes straight to its parse method; the rest (and errors) to
// ParseNodeWithProperties, which keeps the managed locals they need off the common path.
function TYAMLComposer.ParseNode(const parent : IYAMLValue; block, indentlessSequence : boolean) : IYAMLValue;
var
  tok : PYAMLScanToken;
begin
  tok := FScanner.Peek;
  case tok^.Kind of
    TYAMLScanTokenKind.Scalar :
      result := ParseScalar(parent, nil, false);
    TYAMLScanTokenKind.FlowSequenceStart :
      result := ParseFlowSequence(parent, nil);
    TYAMLScanTokenKind.FlowMappingStart :
      result := ParseFlowMapping(parent, nil);
    TYAMLScanTokenKind.BlockSequenceStart :
      if block then
        result := ParseBlockSequence(parent, nil)
      else
        result := ParseNodeWithProperties(parent, block, indentlessSequence);
    TYAMLScanTokenKind.BlockMappingStart :
      if block then
        result := ParseBlockMapping(parent, nil)
      else
        result := ParseNodeWithProperties(parent, block, indentlessSequence);
    TYAMLScanTokenKind.BlockEntry :
      if indentlessSequence then
        result := ParseIndentlessSequence(parent, nil)
      else
        result := ParseNodeWithProperties(parent, block, indentlessSequence);
  else
    result := ParseNodeWithProperties(parent, block, indentlessSequence);
  end;
end;

function TYAMLComposer.ParseNodeWithProperties(const parent : IYAMLValue; block, indentlessSequence : boolean) : IYAMLValue;
var
  tok : PYAMLScanToken;
  anchor, name : string;
  hasAnchor, hasTag, nonSpecific : boolean;
  tagInfo : IYAMLTagInfo;
  line, column : integer;
begin
  tok := FScanner.Peek;
  if tok^.Kind = TYAMLScanTokenKind.Alias then
  begin
    name := tok^.Value;
    line := tok^.Line;
    column := tok^.Column;
    FLastContentIndex := tok^.Index;
    FScanner.Skip;
    if not FAnchors.TryGetValue(name, result) then
      RaiseErrorAt(Format('Undefined alias "%s"', [name]), line, column);
    FLastScalarPlain := false;
    exit;
  end;

  hasAnchor := false;
  hasTag := false;
  nonSpecific := false;
  while true do
  begin
    tok := FScanner.Peek;
    if tok^.Kind = TYAMLScanTokenKind.Anchor then
    begin
      if hasAnchor then
        RaiseError('A node can have only one anchor');
      hasAnchor := true;
      anchor := tok^.Value;
      FLastContentIndex := tok^.Index;
      FScanner.Skip;
    end
    else if tok^.Kind = TYAMLScanTokenKind.Tag then
    begin
      if hasTag then
        RaiseError('A node can have only one tag');
      hasTag := true;
      tagInfo := ResolveTag(tok^.Value2, tok^.Value, tok^.Line, tok^.Column, nonSpecific);
      FLastContentIndex := tok^.Index;
      FScanner.Skip;
    end
    else
      break;
  end;

  tok := FScanner.Peek;
  case tok^.Kind of
    TYAMLScanTokenKind.Scalar :
      result := ParseScalar(parent, tagInfo, nonSpecific);
    TYAMLScanTokenKind.FlowSequenceStart :
      result := ParseFlowSequence(parent, tagInfo);
    TYAMLScanTokenKind.FlowMappingStart :
      result := ParseFlowMapping(parent, tagInfo);
  else
    if block and (tok^.Kind = TYAMLScanTokenKind.BlockSequenceStart) then
      result := ParseBlockSequence(parent, tagInfo)
    else if block and (tok^.Kind = TYAMLScanTokenKind.BlockMappingStart) then
      result := ParseBlockMapping(parent, tagInfo)
    else if indentlessSequence and (tok^.Kind = TYAMLScanTokenKind.BlockEntry) then
      result := ParseIndentlessSequence(parent, tagInfo)
    else if hasAnchor or hasTag then
    begin
      // properties with no content: an empty scalar
      if IsSetTag(tagInfo) then
        RaiseError('Cannot apply !!set tag to scalar value');
      try
        result := TYAMLValue.Create(parent, TYAMLValueType.vtNull, '', tagInfo);
      except
        on E : EYAMLParseException do
          raise;
        on E : Exception do
          RaiseError(E.Message);
      end;
      FLastScalarPlain := false;
    end
    else
    begin
      case tok^.Kind of
        TYAMLScanTokenKind.BlockEnd :
          RaiseError('A node was expected here - check the indentation of the line');
        TYAMLScanTokenKind.FlowSequenceEnd :
          RaiseError('Unexpected "]"');
        TYAMLScanTokenKind.FlowMappingEnd :
          RaiseError('Unexpected "}"');
        TYAMLScanTokenKind.FlowEntry :
          RaiseError('Unexpected "," - a node was expected');
        TYAMLScanTokenKind.Alias :
          RaiseError('An alias cannot have an anchor or a tag');
      else
        RaiseError('A node was expected here');
      end;
    end;
  end;
  if hasAnchor then
    FAnchors.AddOrSetValue(anchor, result);
end;

function TYAMLComposer.ParseScalar(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo; nonSpecific : boolean) : IYAMLValue;
var
  tok : PYAMLScanToken;
  valueType : TYAMLValueType;
  endLine : integer;
begin
  if (tagInfo <> nil) or nonSpecific then
    exit(ParseTaggedScalar(parent, tagInfo, nonSpecific));
  tok := FScanner.Peek;
  if tok^.Style <> TYAMLScalarStyle.Plain then
    valueType := TYAMLValueType.vtString
  else if FLenient then
  begin
    valueType := YAMLResolvePlainScalar(tok^.Value);
    if (valueType = TYAMLValueType.vtString) and (Pos('_', tok^.Value) > 0) then
      valueType := ResolveLenient(tok^.Value);
  end
  else
    valueType := YAMLResolveCoreScalar(tok^.Value);
  result := TYAMLValue.Create(parent, valueType, tok^.Value, '');
  endLine := tok^.EndLine;
  FLastContentIndex := tok^.Index;
  FLastScalarPlain := tok^.Style = TYAMLScalarStyle.Plain;
  FScanner.Skip;
  TakeSameLineComment(result, endLine);
end;

function TYAMLComposer.ParseTaggedScalar(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo; nonSpecific : boolean) : IYAMLValue;
var
  tok : PYAMLScanToken;
  text : string;
  plain : boolean;
  valueType : TYAMLValueType;
  line, column, endLine : integer;
begin
  tok := FScanner.Peek;
  text := tok^.Value;
  plain := tok^.Style = TYAMLScalarStyle.Plain;
  line := tok^.Line;
  column := tok^.Column;
  endLine := tok^.EndLine;
  FLastContentIndex := tok^.Index;
  FScanner.Skip;

  if (not plain) or nonSpecific then
    valueType := TYAMLValueType.vtString
  else if FLenient then
    valueType := ResolveLenient(text)
  else
    valueType := YAMLResolveCoreScalar(text);

  if tagInfo = nil then
    result := TYAMLValue.Create(parent, valueType, text, '')
  else
  begin
    if IsSetTag(tagInfo) then
      RaiseErrorAt('Cannot apply !!set tag to scalar value', line, column);
    try
      result := TYAMLValue.Create(parent, valueType, text, tagInfo);
    except
      on E : EYAMLParseException do
        raise;
      on E : Exception do
        RaiseErrorAt(E.Message, line, column);
    end;
  end;
  FLastScalarPlain := plain and (tagInfo = nil);
  TakeSameLineComment(result, endLine);
end;

function TYAMLComposer.ParseBlockSequence(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo) : IYAMLValue;
var
  tok : PYAMLScanToken;
  sequence : IYAMLSequence;
  item : IYAMLValue;
begin
  tok := FScanner.Peek;
  if IsSetTag(tagInfo) then
    sequence := TYAMLSet.Create(parent, tagInfo)
  else
    sequence := TYAMLSequence.Create(parent, tagInfo);
  result := sequence;
  TakeLeadingComments(sequence, tok^.Index);
  FScanner.Skip;
  EnterCollection;
  while true do
  begin
    tok := FScanner.Peek;
    if tok^.Kind = TYAMLScanTokenKind.BlockEntry then
    begin
      FScanner.Skip;
      tok := FScanner.Peek;
      if (tok^.Kind = TYAMLScanTokenKind.BlockEntry) or (tok^.Kind = TYAMLScanTokenKind.BlockEnd) then
        item := NewNull(sequence)
      else
        item := ParseNode(sequence, true, false);
      sequence.AddValue(item);
    end
    else if tok^.Kind = TYAMLScanTokenKind.BlockEnd then
    begin
      FScanner.Skip;
      break;
    end
    else
      RaiseError('A block sequence entry ("- ") was expected - check the indentation of the line');
  end;
  Dec(FDepth);
end;

// A sequence at the same indentation as the mapping key it is the value of.
function TYAMLComposer.ParseIndentlessSequence(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo) : IYAMLValue;
var
  tok : PYAMLScanToken;
  sequence : IYAMLSequence;
  item : IYAMLValue;
begin
  tok := FScanner.Peek;
  if IsSetTag(tagInfo) then
    sequence := TYAMLSet.Create(parent, tagInfo)
  else
    sequence := TYAMLSequence.Create(parent, tagInfo);
  result := sequence;
  TakeLeadingComments(sequence, tok^.Index);
  EnterCollection;
  while true do
  begin
    tok := FScanner.Peek;
    if tok^.Kind <> TYAMLScanTokenKind.BlockEntry then
      break;
    FScanner.Skip;
    tok := FScanner.Peek;
    case tok^.Kind of
      TYAMLScanTokenKind.BlockEntry, TYAMLScanTokenKind.Key, TYAMLScanTokenKind.Value, TYAMLScanTokenKind.BlockEnd :
        item := NewNull(sequence);
    else
      item := ParseNode(sequence, true, false);
    end;
    sequence.AddValue(item);
  end;
  Dec(FDepth);
end;

function TYAMLComposer.ParseBlockMapping(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo) : IYAMLValue;
var
  tok : PYAMLScanToken;
  mapping : IYAMLMapping;
  mappingPriv : IYAMLMappingPrivate; // obtained once; a per-key 'as' cast is a QueryInterface
  aSet : IYAMLSet;
  key, value : IYAMLValue;
  text : string;
  isSet, setCandidate, explicit, hasValue, isMergeKey : boolean;
  keyLine, keyColumn, i : integer;
  keys : TList<IYAMLValue>;
begin
  tok := FScanner.Peek;
  isSet := IsSetTag(tagInfo);
  // YAML 1.1 style: a mapping of '? ' keys without values is read as a set
  setCandidate := FLenient and (tagInfo = nil);
  keys := nil;
  if isSet then
  begin
    aSet := TYAMLSet.Create(parent, tagInfo);
    result := aSet;
    TakeLeadingComments(aSet, tok^.Index);
  end
  else
  begin
    mapping := TYAMLMapping.Create(parent, tagInfo);
    mappingPriv := mapping as IYAMLMappingPrivate;
    result := mapping;
    TakeLeadingComments(mapping, tok^.Index);
  end;
  FScanner.Skip;
  EnterCollection;
  try
    while true do
    begin
      tok := FScanner.Peek;
      keyLine := tok^.Line;
      keyColumn := tok^.Column;
      isMergeKey := false;
      explicit := false;
      key := nil;
      text := '';
      if tok^.Kind = TYAMLScanTokenKind.Key then
      begin
        explicit := tok^.Explicit;
        FScanner.Skip;
        tok := FScanner.Peek;
        keyLine := tok^.Line;
        keyColumn := tok^.Column;
        case tok^.Kind of
          TYAMLScanTokenKind.Key, TYAMLScanTokenKind.Value, TYAMLScanTokenKind.BlockEnd :
            ; // an empty key
        else
          text := ParseKey(result, true, isSet or (setCandidate and explicit), key, isMergeKey);
        end;
      end
      else if tok^.Kind = TYAMLScanTokenKind.BlockEnd then
      begin
        FScanner.Skip;
        break;
      end
      else if tok^.Kind <> TYAMLScanTokenKind.Value then
        RaiseError('A mapping key was expected - check the indentation of the line');

      tok := FScanner.Peek;
      hasValue := tok^.Kind = TYAMLScanTokenKind.Value;
      if hasValue then
      begin
        FScanner.Skip;
        tok := FScanner.Peek;
        case tok^.Kind of
          TYAMLScanTokenKind.Key, TYAMLScanTokenKind.Value, TYAMLScanTokenKind.BlockEnd :
            value := NewNull(result);
        else
          value := ParseNode(result, true, true);
        end;
      end
      else
        value := NewNull(result);

      if isSet then
      begin
        if key = nil then
          key := NewNull(aSet);
        aSet.AddValue(key);
      end
      else
      begin
        if setCandidate and ((not explicit) or hasValue) then
        begin
          setCandidate := false;
          FreeAndNil(keys);
        end;
        if setCandidate then
        begin
          if keys = nil then
            keys := TList<IYAMLValue>.Create;
          keys.Add(key);
        end;
        AddEntry(mapping, mappingPriv, text, value, isMergeKey, keyLine, keyColumn);
      end;
    end;

    if setCandidate and (keys <> nil) and (keys.Count > 0) then
    begin
      aSet := TYAMLSet.Create(parent, '');
      for i := 0 to keys.Count - 1 do
      begin
        key := keys[i];
        if key = nil then
          key := NewNull(aSet)
        else
          YAMLSetParent(key, aSet);
        aSet.AddValue(key);
      end;
      if mapping.HasComments then
        aSet.Comments := mapping.Comments;
      aSet.Comment := mapping.Comment;
      result := aSet;
    end;
  finally
    keys.Free;
  end;
  Dec(FDepth);
end;

// A single key: value pair inside a flow sequence ('[a: 1]' or '[? a : 1]'), which is a
// mapping with one entry.
function TYAMLComposer.ParseFlowPair(const parent : IYAMLValue) : IYAMLValue;
var
  tok : PYAMLScanToken;
  mapping : IYAMLMapping;
  key, value : IYAMLValue;
  text : string;
  isMergeKey : boolean;
  keyLine, keyColumn : integer;
begin
  mapping := TYAMLMapping.Create(parent, '');
  result := mapping;
  tok := FScanner.Peek;
  keyLine := tok^.Line;
  keyColumn := tok^.Column;
  text := '';
  isMergeKey := false;
  if tok^.Kind = TYAMLScanTokenKind.Key then
  begin
    FScanner.Skip;
    tok := FScanner.Peek;
    case tok^.Kind of
      TYAMLScanTokenKind.Value, TYAMLScanTokenKind.FlowEntry, TYAMLScanTokenKind.FlowSequenceEnd :
        ; // an empty key
    else
      text := ParseKey(mapping, false, false, key, isMergeKey);
    end;
  end;
  tok := FScanner.Peek;
  if tok^.Kind = TYAMLScanTokenKind.Value then
  begin
    FScanner.Skip;
    tok := FScanner.Peek;
    case tok^.Kind of
      TYAMLScanTokenKind.FlowEntry, TYAMLScanTokenKind.FlowSequenceEnd :
        value := NewNull(mapping);
    else
      value := ParseNode(mapping, false, false);
    end;
  end
  else
    value := NewNull(mapping);
  AddEntry(mapping, mapping as IYAMLMappingPrivate, text, value, isMergeKey, keyLine, keyColumn);
end;

function TYAMLComposer.ParseFlowSequence(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo) : IYAMLValue;
var
  tok : PYAMLScanToken;
  sequence : IYAMLSequence;
  item : IYAMLValue;
  first : boolean;
  endLine : integer;
begin
  tok := FScanner.Peek;
  if IsSetTag(tagInfo) then
    sequence := TYAMLSet.Create(parent, tagInfo)
  else
    sequence := TYAMLSequence.Create(parent, tagInfo);
  result := sequence;
  TakeLeadingComments(sequence, tok^.Index);
  FScanner.Skip;
  EnterCollection;
  first := true;
  while true do
  begin
    tok := FScanner.Peek;
    if tok^.Kind = TYAMLScanTokenKind.FlowSequenceEnd then
      break;
    if not first then
    begin
      if tok^.Kind <> TYAMLScanTokenKind.FlowEntry then
        RaiseError('Expected "," or "]" in a flow sequence');
      FScanner.Skip;
      tok := FScanner.Peek;
      // a single trailing comma is allowed
      if tok^.Kind = TYAMLScanTokenKind.FlowSequenceEnd then
        break;
    end;
    if (tok^.Kind = TYAMLScanTokenKind.Key) or (tok^.Kind = TYAMLScanTokenKind.Value) then
      item := ParseFlowPair(sequence)
    else
      item := ParseNode(sequence, false, false);
    sequence.AddValue(item);
    first := false;
  end;
  endLine := tok^.Line;
  FLastContentIndex := tok^.Index;
  FScanner.Skip;
  Dec(FDepth);
  TakeSameLineComment(result, endLine);
end;

function TYAMLComposer.ParseFlowMapping(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo) : IYAMLValue;
var
  tok : PYAMLScanToken;
  mapping : IYAMLMapping;
  mappingPriv : IYAMLMappingPrivate;
  aSet : IYAMLSet;
  key, value : IYAMLValue;
  text : string;
  first, isSet, isMergeKey : boolean;
  endLine, keyLine, keyColumn : integer;
begin
  tok := FScanner.Peek;
  isSet := IsSetTag(tagInfo);
  if isSet then
  begin
    aSet := TYAMLSet.Create(parent, tagInfo);
    result := aSet;
    TakeLeadingComments(aSet, tok^.Index);
  end
  else
  begin
    mapping := TYAMLMapping.Create(parent, tagInfo);
    mappingPriv := mapping as IYAMLMappingPrivate;
    result := mapping;
    TakeLeadingComments(mapping, tok^.Index);
  end;
  FScanner.Skip;
  EnterCollection;
  first := true;
  while true do
  begin
    tok := FScanner.Peek;
    if tok^.Kind = TYAMLScanTokenKind.FlowMappingEnd then
      break;
    if not first then
    begin
      if tok^.Kind <> TYAMLScanTokenKind.FlowEntry then
        RaiseError('Expected "," or "}" in a flow mapping');
      FScanner.Skip;
      tok := FScanner.Peek;
      // a single trailing comma is allowed
      if tok^.Kind = TYAMLScanTokenKind.FlowMappingEnd then
        break;
    end;
    keyLine := tok^.Line;
    keyColumn := tok^.Column;
    isMergeKey := false;
    key := nil;
    text := '';
    if tok^.Kind = TYAMLScanTokenKind.Key then
    begin
      FScanner.Skip;
      tok := FScanner.Peek;
      case tok^.Kind of
        TYAMLScanTokenKind.Value, TYAMLScanTokenKind.FlowEntry, TYAMLScanTokenKind.FlowMappingEnd :
          ; // an empty key
      else
        text := ParseKey(result, false, isSet, key, isMergeKey);
      end;
    end
    else if tok^.Kind <> TYAMLScanTokenKind.Value then
      // an entry with no ':' - its value is null
      text := ParseKey(result, false, isSet, key, isMergeKey);
    tok := FScanner.Peek;
    if tok^.Kind = TYAMLScanTokenKind.Value then
    begin
      FScanner.Skip;
      tok := FScanner.Peek;
      case tok^.Kind of
        TYAMLScanTokenKind.FlowEntry, TYAMLScanTokenKind.FlowMappingEnd :
          value := NewNull(result);
      else
        value := ParseNode(result, false, false);
      end;
    end
    else
      value := NewNull(result);
    if isSet then
    begin
      if key = nil then
        key := NewNull(aSet);
      aSet.AddValue(key);
    end
    else
      AddEntry(mapping, mappingPriv, text, value, isMergeKey, keyLine, keyColumn);
    first := false;
  end;
  endLine := tok^.Line;
  FLastContentIndex := tok^.Index;
  FScanner.Skip;
  Dec(FDepth);
  TakeSameLineComment(result, endLine);
end;

{ documents }

// The next document of the stream, or nil at its end.
function TYAMLComposer.ParseDocument : IYAMLDocument;
var
  tok : PYAMLScanToken;
  sawDirective : boolean;
  root : IYAMLValue;
  endIndex : integer;
begin
  result := nil;
  ResetDocument;
  sawDirective := false;
  while true do
  begin
    tok := FScanner.Peek;
    case tok^.Kind of
      TYAMLScanTokenKind.StreamStart :
        FScanner.Skip;
      TYAMLScanTokenKind.DocumentEnd :
        begin
          // '...' with no document before it
          FScanner.Skip;
          FPrevDocumentOpen := false;
        end;
      TYAMLScanTokenKind.VersionDirective, TYAMLScanTokenKind.TagDirective, TYAMLScanTokenKind.ReservedDirective :
        begin
          if FPrevDocumentOpen then
            RaiseError('A directive must come after the "..." end marker of the document before it');
          ProcessDirective(tok);
          FScanner.Skip;
          sawDirective := true;
        end;
    else
      break;
    end;
  end;

  tok := FScanner.Peek;
  if tok^.Kind = TYAMLScanTokenKind.StreamEnd then
  begin
    if sawDirective then
      RaiseError('Directives must be followed by a "---" document start marker');
    exit;
  end;

  if tok^.Kind = TYAMLScanTokenKind.DocumentStart then
  begin
    FScanner.Skip;
    tok := FScanner.Peek;
    case tok^.Kind of
      TYAMLScanTokenKind.DocumentStart, TYAMLScanTokenKind.DocumentEnd, TYAMLScanTokenKind.StreamEnd,
      TYAMLScanTokenKind.VersionDirective, TYAMLScanTokenKind.TagDirective, TYAMLScanTokenKind.ReservedDirective :
        root := NewNull(nil);
    else
      root := ParseNode(nil, true, false);
    end;
  end
  else
  begin
    if sawDirective then
      RaiseError('Directives must be followed by a "---" document start marker');
    root := ParseNode(nil, true, false);
  end;

  // the end of the document
  tok := FScanner.Peek;
  endIndex := tok^.Index;
  case tok^.Kind of
    TYAMLScanTokenKind.DocumentEnd :
      begin
        FScanner.Skip;
        FPrevDocumentOpen := false;
      end;
    TYAMLScanTokenKind.DocumentStart, TYAMLScanTokenKind.StreamEnd :
      FPrevDocumentOpen := true;
    TYAMLScanTokenKind.VersionDirective, TYAMLScanTokenKind.TagDirective, TYAMLScanTokenKind.ReservedDirective :
      RaiseError('A directive must come after the "..." end marker of the document before it');
    TYAMLScanTokenKind.BlockEntry :
      RaiseError('Unexpected sequence item "-" - it does not belong to the preceding collection (check its indentation)');
  else
    RaiseError('Unexpected content after the end of the document''s root node - check its indentation');
  end;

  result := TYAMLDocument.Create(root, FVersion, FTagDirectives);

  // comments inside the root's content that no collection took go to the root collection;
  // those after it to the document
  PullComments(FLastContentIndex + 1);
  if (FPendingCount > 0) and (root.IsMapping or root.IsSequence or root.IsSet) then
  begin
    FIsDocumentLevel := false;
    TakeLeadingComments(root.AsCollection, FLastContentIndex + 1);
  end;
  TakePendingComments; // (those before a scalar root are dropped, as they always were)
  PullComments(endIndex);
  if FPendingCount > 0 then
    result.EndComments := TakePendingComments;
end;

function TYAMLComposer.Parse : IYAMLDocument;
begin
  try
    result := ParseDocument;
    if result = nil then
      result := TYAMLDocument.Create(NewNull(nil), FVersion, FTagDirectives);
  except
    on E : EYAMLParseException do
      raise;
    on E : Exception do
      raise EYAMLParseException.Create('Unexpected parsing error: ' + E.Message, FScanner.Line, 1);
  end;
end;

function TYAMLComposer.ParseAll : TArray<IYAMLDocument>;
var
  documents : TList<IYAMLDocument>;
  doc : IYAMLDocument;
begin
  documents := TList<IYAMLDocument>.Create;
  try
    while true do
    begin
      try
        doc := ParseDocument;
      except
        on E : EYAMLParseException do
          raise EYAMLParseException.Create(Format('Error in document %d: %s', [documents.Count + 1, E.Message], YAMLFormatSettings),
            E.Line, E.Column);
        on E : Exception do
          raise EYAMLParseException.Create(Format('Error in document %d: Unexpected parsing error: %s', [documents.Count + 1, E.Message], YAMLFormatSettings),
            FScanner.Line, 1);
      end;
      if doc = nil then
        break;
      documents.Add(doc);
    end;
    // a stream with no documents (empty, or only comments) gives none
    result := documents.ToArray;
  finally
    documents.Free;
  end;
end;

end.
