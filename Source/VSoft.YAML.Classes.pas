unit VSoft.YAML.Classes;

interface

{$I 'VSoft.YAML.inc'}

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  VSoft.YAML,
  VSoft.YAML.TagInfo;

type
  IYAMLValuePrivate = interface
  ['{B6122037-9063-45C4-BD6F-279583AA4576}']
    procedure ClearParent;
  end;

  TYAMLValue = class(TInterfacedObject, IYAMLValue, IYAMLValuePrivate)
  private
    FValueType : TYAMLValueType;
    FRawValue : string;
    FTag : string;  // Keep for backward compatibility
    FTagInfo : IYAMLTagInfo;
    FParent : Pointer;
    FComment : string;

  protected
    function GetComment : string;
    procedure SetComment(const value : string);
    function GetCount : integer;virtual;
    procedure ClearParent;
    function GetParent : IYAMLValue;
    function FindRoot : IYAMLValue;
    function GetNodes(Index : integer) : IYAMLValue;virtual;
    function GetValue(const key : string) : IYAMLValue;virtual;
    function IsTaggedAs(const TagName : string) : boolean;inline;
    procedure ApplyTagConversion;


    function GetRawValue : string;
    function GetTag : string;
    function GetTagInfo : IYAMLTagInfo;
    function GetValueType : TYAMLValueType;

   // Type checking methods
    function IsNull : boolean;inline;
    function IsBoolean : boolean;inline;
    function IsInteger : boolean;inline;
    function IsFloat : boolean;inline;
    function IsString : boolean;inline;
    function IsSequence : boolean;inline;
    function IsCollection : boolean;inline;
    function IsMapping : boolean;inline;
    function IsSet : boolean;inline;
    function IsAlias : boolean;inline;
    function IsTimeStamp : boolean;inline;
    function IsNumeric : boolean;inline;
    function IsScalar : boolean;
    // Value conversion methods
    function AsBoolean : boolean;
    function AsInteger : Int64;
    function AsFloat : Double;
    function AsString : string;
    function AsSequence : IYAMLSequence;
    function AsMapping : IYAMLMapping;
    function AsSet : IYAMLSet;
    function AsCollection : IYAMLCollection;
    function AsLocalDateTime : TDateTime;
    function AsUTCDateTime : TDateTime;

    function TryGetValue(const key : string; out value : IYAMLValue) : boolean;virtual;

    // Tag modification methods
    procedure SetTag(const tag : string);virtual;
    procedure SetTagInfo(const tagInfo : IYAMLTagInfo);virtual;
    procedure ClearTag;virtual;

  public
    constructor Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue : string = ''; const tag : string = ''); overload;
    constructor Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue : string; const tagInfo : IYAMLTagInfo); overload;
    constructor CreateNull;
    destructor Destroy; override;
    // String representation
    function ToString : string; override;
  end;

  TYAMLCollection = class(TYAMLValue, IYAMLValue, IYAMLCollection)
  private
    FComments : TStringList; // lazy create;
  protected
    procedure EnsureComments;
    function GetHasComments : boolean;
    function GetComments : TStrings;
    procedure SetComments(const value : TStrings);
    procedure AddComment(const value : string);
    procedure ClearComments;
    procedure Clear;virtual;abstract;
    function Query(const AExpression : string) : IYAMLSequence;
    function QuerySingle(const AExpression : string; out AMatch : IYAMLValue) : boolean;

  public
    constructor Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue : string = ''; const tag : string = ''); overload;
    constructor Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue : string; const tagInfo : IYAMLTagInfo); overload;
    destructor Destroy; override;

  end;

  TYAMLSequence = class(TYAMLCollection, IYAMLSequence,IYAMLCollection, IYAMLValue, IYAMLValuePrivate)
  private
    FItems : TList<IYAMLValue>;
  protected
    class function GetNodeValueType : TYAMLValueType;virtual;
    function GetNodes(Index : integer) : IYAMLValue;override;
    function GetValue(const key : string) : IYAMLValue;override;

    function GetCount : integer;override;
    function GetItem(Index : integer) : IYAMLValue;

    // JSONDataObjects api
    function GetString(index : integer) : string;
    function GetInt(index: Integer): Integer;
    function GetLong(index: Integer): Int64;
    function GetULong(index: Integer): UInt64;
    function GetFloat(index: Integer): Double;
    function GetDateTime(index: Integer): TDateTime;
    function GetUtcDateTime(index: Integer): TDateTime;
    function GetBool(index: Integer): Boolean;
    function GetArray(index: Integer): IYAMLSequence;
    function GetObj(index: Integer): IYAMLMapping;

    procedure SetString(index: Integer; const value: string);
    procedure SetInt(index: Integer; const value: integer);
    procedure SetLong(index: Integer; const value: Int64);
    procedure SetULong(index: Integer; const value: UInt64);
    procedure SetFloat(index: Integer; const value: double);
    procedure SetDateTime(index: Integer; const value: TDateTime);
    procedure SetUtcDateTime(index: Integer; const value: TDateTime);
    procedure SetBool(index: Integer; const value: Boolean);
    procedure SetArray(index: Integer; const value: IYAMLSequence);
    procedure SetObject(index: Integer; const value: IYAMLMapping);
    // JSONDataObjects api



    procedure AddValue(const value : IYAMLValue);overload;virtual;

    // Tag-aware value creation methods
    function AddValue(const value : boolean; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddValue(const value : Int32; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : Int32; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddValue(const value : UInt32; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : UInt32; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddValue(const value : Int64; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : Int64; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddValue(const value : UInt64; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : UInt64; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddValue(const value : Single; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : Single; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddValue(const value : Double; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : Double; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddValue(const value : string; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : string; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddValue(const value : TDateTime; isUTC : boolean; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : TDateTime; isUTC : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddMapping(const tag : string = '') : IYAMLMapping;overload;
    function AddMapping(const tagInfo : IYAMLTagInfo) : IYAMLMapping;overload;
    function AddSequence(const tag : string = '') : IYAMLSequence;overload;
    function AddSequence(const tagInfo : IYAMLTagInfo) : IYAMLSequence;overload;
    function AddSet(const tag : string = '') : IYAMLSet;overload;
    function AddSet(const tagInfo : IYAMLTagInfo) : IYAMLSet;overload;

    procedure Clear;override;

  public
    constructor Create(const parent : IYAMLValue; const tag : string);overload;virtual;
    constructor Create(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo);overload;virtual;
    destructor Destroy; override;

  end;


  TYAMLSet = class(TYAMLSequence, IYAMLSet,IYAMLSequence, IYAMLCollection, IYAMLValue, IYAMLValuePrivate)
  private
    FValues : TStringList; // For fast duplicate checking using string representations
  protected
    class function GetNodeValueType : TYAMLValueType;override;
    procedure AddValue(const value : IYAMLValue);override;
     procedure Clear;override;

  public
    constructor Create(const parent : IYAMLValue; const tag : string);override;
    constructor Create(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo);override;
    destructor Destroy; override;

  end;

  IYAMLMappingPrivate = interface
  ['{F14352DD-0C83-4BDE-988B-C007D0FE93AC}']
    procedure AddOrSetValue(const key : string; const value : IYAMLValue);
    procedure MergeMapping(const ASourceMapping : IYAMLMapping);
  end;

  TYAMLMapping = class(TYAMLCollection, IYAMLMapping, IYAMLCollection, IYAMLValue, IYAMLValuePrivate, IYAMLMappingPrivate)
  private
    FPairs : TDictionary<string, IYAMLValue>;
    FKeys : TStringList;  // To maintain order
  protected
    function GetCount : integer;override;
    function GetNodes(Index : integer) : IYAMLValue;override;

    function GetKey(Index : integer) : string;
    function GetValue(const key : string) : IYAMLValue;override;


    procedure AddOrSetValue(const key : string; const value : IYAMLValue);overload;
    function AddOrSetValue(const key : string; const value : boolean) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Int32) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : UInt32) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Int64) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : UInt64) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Single) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Double) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : string) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : TDateTime; isUTC : boolean) : IYAMLValue; overload;

    // Tag-aware value creation methods
    function AddOrSetValue(const key : string; const value : boolean; const tag : string) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Int32; const tag : string) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Int32; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : UInt32; const tag : string) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : UInt32; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Int64; const tag : string) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Int64; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : UInt64; const tag : string) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : UInt64; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Single; const tag : string) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Single; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Double; const tag : string) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Double; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : string; const tag : string) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : string; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : TDateTime; isUTC : boolean; const tag : string) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : TDateTime; isUTC : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddOrSetSequence(const key : string; const tag : string = '') : IYAMLSequence;overload;
    function AddOrSetSequence(const key : string; const tagInfo : IYAMLTagInfo) : IYAMLSequence;overload;

    function AddOrSetMapping(const key : string; const tag : string = '') : IYAMLMapping;overload;
    function AddOrSetMapping(const key : string; const tagInfo : IYAMLTagInfo) : IYAMLMapping;overload;

    function AddOrSetSet(const key : string; const tag : string = '') : IYAMLSet;overload;
    function AddOrSetSet(const key : string; const tagInfo : IYAMLTagInfo) : IYAMLSet;overload;

    function ContainsKey(const key : string) : boolean;
    function Contains(const key : string) : boolean;//for JSONDataObjects api compat
    function TryGetValue(const key : string; out value : IYAMLValue) : boolean;override;

    procedure MergeMapping(const ASourceMapping : IYAMLMapping);

    function GetObjectString(const key : string) : string;
    function GetObjectInt(const key: string): Integer;
    function GetObjectLong(const key: string): Int64;
    function GetObjectULong(const key: string): UInt64;
    function GetObjectFloat(const key: string): Double;
    function GetObjectDateTime(const key: string): TDateTime;
    function GetObjectUtcDateTime(const key: string): TDateTime;
    function GetObjectBool(const key: string): Boolean;
    function GetArray(const key: string): IYAMLSequence;
    function GetObj(const key: string): IYAMLMapping;

    procedure SetObjectString(const key : string; const value : string);
    procedure SetObjectInt(const key: string; const Value: Integer);
    procedure SetObjectLong(const key: string; const Value: Int64);
    procedure SetObjectULong(const key: string; const Value: UInt64);
    procedure SetObjectFloat(const key: string; const Value: Double);
    procedure SetObjectDateTime(const key: string; const Value: TDateTime);
    procedure SetObjectUtcDateTime(const key: string; const Value: TDateTime);
    procedure SetObjectBool(const key: string; const Value: Boolean);
    procedure SetArray(const key: string; const Value: IYAMLSequence);
    procedure SetObject(const key: string; const Value: IYAMLMapping);

    procedure Clear;override;

  public
    constructor Create(const parent : IYAMLValue; const tag : string);overload;
    constructor Create(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo);overload;
    destructor Destroy; override;
  end;

  TYAMLEmitOptions = class(TInterfacedObject, IYAMLEmitOptions)
  private
    FEncoding : TEncoding;
    FFormat : TYAMLOutputFormat;
    FIndentSize : integer;
    FQuoteStrings : boolean;
    FEmitDocumentMarkers : boolean;
    FMaxLineLength : integer;
    FWriteBOM : boolean;
    FEmitTags : boolean;
    FEmitExplicitNull : boolean;
    FEmitTagDirectives : boolean;
    FEmitYAMLDirective : boolean;
    FPrettyPrint : boolean;
  protected
    function GetFormat : TYAMLOutputFormat;
    procedure SetFormat(value : TYAMLOutputFormat);
    function GetIndentSize : UInt32;
    procedure SetIndentSize(value : UInt32);
    function GetQuoteStrings : boolean;
    procedure SetQuoteStrings(value : boolean);
    function GetEmitDocumentMarkers : boolean;
    procedure SetEmitDocumentMarkers(value : boolean);
    function GetMaxLineLength : UInt32;
    procedure SetMaxLineLength(value : UInt32);
    function GetEncoding : TEncoding;
    procedure SetEncoding(const value : TEncoding);
    function GetWriteBOM : boolean;
    procedure SetWriteBOM(const value : boolean);
    function GetEmitTags : boolean;
    procedure SetEmitTags(const value : boolean);
    function GetEmitExplicitNull : boolean;
    procedure SetEmitExplicitNull(const value : boolean);
    function GetEmitTagDirectives : boolean;
    procedure SetEmitTagDirectives(value : boolean);
    function GetEmitYAMLDirective : boolean;
    procedure SetEmitYAMLDirective(value : boolean);
    function GetPrettyPrint : boolean;
    procedure SetPrettyPrint(const value : boolean);

    function Clone : IYAMLEmitOptions;
    constructor CreateClone(const source : IYAMLEmitOptions);
  public
    constructor Create;
    destructor Destroy;override;
  end;

  TYAMLVersionDirective = class(TInterfacedObject, IYAMLVersionDirective)
  private
    FMajor : integer;
    FMinor : integer;
  protected
    function GetMajor : integer;
    function GetMinor : integer;
    function IsCompatible(const other : IYAMLVersionDirective) : boolean;
  public
    constructor Create(major : integer; minor : integer);
    function ToString : string;override;
    class function YAML_1_1 : IYAMLVersionDirective; static;
    class function YAML_1_2 : IYAMLVersionDirective; static;
  end;


  TYAMLTagDirective = class(TInterfacedObject, IYAMLTagDirective)
  private
    FPrefix : string;
    FHandle : string;
  protected
    function GetHandle : string;
    function GetPrefix : string;
  public
    constructor Create(const prefix : string; const handle : string);
    function ToString : string;override;
  end;

  TYAMLDocument = class(TInterfacedObject, IYAMLDocument)
  private
    FRoot : IYAMLValue;
    FOptions : IYAMLEmitOptions;
    FYAMLVersion : IYAMLVersionDirective;
    FTagDirectives : TList<IYAMLTagDirective>;
  protected
    function GetVersion : IYAMLVersionDirective;
    function GetOptions : IYAMLEmitOptions;
    function GetIsMapping : boolean;
    function GetIsSequence : boolean;
    function GetIsSet : boolean;
    function GetIsScalar : boolean;
    function GetIsNull : boolean;
    function GetRoot : IYAMLValue;
    function GetTagDirectives : TList<IYAMLTagDirective>;


    procedure WriteToFile(const filename : string);
    function ToYAMLString : string;
    function AsMapping : IYAMLMapping;
    function AsSequence : IYAMLSequence;
    function AsSet : IYAMLSet;
    function Query(const expression : string) : IYAMLSequence;
    function QuerySingle(const expression : string; out AMatch : IYAMLValue) : boolean;
  public
    constructor Create;overload;
    constructor Create(const ARoot : IYAMLValue; const yamlVersion : IYAMLVersionDirective; const tagDirectives : TList<IYAMLTagDirective>);overload;
    destructor Destroy;override;
  end;


  TYAMLParserOptions = class(TInterfacedObject, IYAMLParserOptions)
  private
    FDuplicateKeyBehavior : TYAMLDuplicateKeyBehavior;
    FJSONMode : boolean;
  protected
    procedure SetDuplicateKeyBehavior(value : TYAMLDuplicateKeyBehavior);
    function GetDuplicateKeyBehavior : TYAMLDuplicateKeyBehavior;
    function GetJSONMode : boolean;
    procedure SetJSONMode(value : boolean);

  public
    constructor Create;
  end;

const
  YAMLFormatSettings : TFormatSettings = (
    DateSeparator: '-';
    TimeSeparator: ':';
    ShortDateFormat: 'YYYY-MM-DD';
    LongDateFormat: 'YYYY-MM-DD';
    TimeAMString: '';
    TimePMString: '';
    ShortTimeFormat: 'hh:nn:ss';
    LongTimeFormat: 'hh:nn:ss';
    DecimalSeparator: '.';
  );

implementation

uses
  System.Math,
  System.StrUtils,
  VSoft.YAML.Utils,
  VSoft.YAML.Writer,
  VSoft.YAML.Path;

{ TYAMLValue }

//TODO : handle !yaml! style tags
procedure TYAMLValue.ApplyTagConversion;
begin
  // Apply type conversion based on tag
  if FTag <> '' then
  begin
    if IsTaggedAs('!!str') then
      FValueType := TYAMLValueType.vtString
    else if IsTaggedAs('!!int') then
    begin
      FValueType := TYAMLValueType.vtInteger;
      // Validate that the value can be converted to integer
      try
        StrToInt(FRawValue);
      except
        raise Exception.CreateFmt('Invalid integer value "%s" for !!int tag', [FRawValue]);
      end;
    end
    else if IsTaggedAs('!!float') then
    begin
      FValueType := TYAMLValueType.vtFloat;
      // Validate that the value can be converted to float
      try
        StrToFloat(FRawValue, YAMLFormatSettings);
      except
        raise Exception.CreateFmt('Invalid float value "%s" for !!float tag', [FRawValue]);
      end;
    end
    else if IsTaggedAs('!!bool') then
    begin
      FValueType := TYAMLValueType.vtBoolean;
      //TODO:  change this based on yaml version
      // Validate boolean value
      if not (SameText(FRawValue, 'true') or SameText(FRawValue, 'false') or
              SameText(FRawValue, 'yes') or SameText(FRawValue, 'no') or
              SameText(FRawValue, 'on') or SameText(FRawValue, 'off')) then
        raise Exception.CreateFmt('Invalid boolean value "%s" for !!bool tag', [FRawValue]);
    end
    else if IsTaggedAs('!!timestamp') then
    begin
      FValueType := TYAMLValueType.vtTimestamp;
      try
        TYAMLDateUtils.ISO8601StrToUTCDateTime(FRawValue);
      except
        raise Exception.CreateFmt('Invalid timestamp value "%s" for !!timestamp tag', [FRawValue]);
      end;
    end
    else if IsTaggedAs('!!null') then
    begin
      FValueType := TYAMLValueType.vtNull;
      FRawValue := '';
    end;
  end;

end;

function TYAMLValue.AsBoolean : boolean;
begin
  if not IsBoolean then
    raise Exception.Create('Value is not a boolean');
  result := SameText(FRawValue, 'true') or SameText(FRawValue, 'yes') or SameText(FRawValue, 'on');
end;

function TYAMLValue.AsCollection: IYAMLCollection;
begin
  if not IsCollection then
    raise Exception.Create('Value is not a collection');
  result := Self as IYAMLCollection;
end;

function TYAMLValue.AsLocalDateTime : TDateTime;
begin
  if not IsTimeStamp then
    raise Exception.Create('Value is not a timestamp');
  result := TYAMLDateUtils.ISO8601StrToLocalDateTime(FRawValue );
end;

function TYAMLValue.AsUTCDateTime : TDateTime;
begin
  if not IsTimeStamp then
    raise Exception.Create('Value is not a timestamp');
  result := TYAMLDateUtils.ISO8601StrToUTCDateTime(FRawValue);
end;


function TYAMLValue.AsFloat : Double;
var
  trimmedValue : string;
begin
  if not IsFloat then
    raise Exception.Create('Value is not a float');

  trimmedValue := Trim(FRawValue);

  // Handle special YAML float values
  if SameText(trimmedValue, '.nan') or SameText(trimmedValue, '.NaN') or SameText(trimmedValue, '.NAN') then
    result := NaN
  else if SameText(trimmedValue, '.inf') or SameText(trimmedValue, '.Inf') or SameText(trimmedValue, '.INF') or
          SameText(trimmedValue, '+.inf') or SameText(trimmedValue, '+.Inf') or SameText(trimmedValue, '+.INF') then
    result := Infinity
  else if SameText(trimmedValue, '-.inf') or SameText(trimmedValue, '-.Inf') or SameText(trimmedValue, '-.INF') then
    result := NegInfinity
  else
    result := StrToFloat(trimmedValue, YAMLFormatSettings);
end;

function TYAMLValue.AsInteger : Int64;
var
  trimmedValue: string;
  i: Integer;
  octalStr: string;
  binaryStr: string;
  uInt64Value : UInt64;
begin
  if not IsInteger then
    raise Exception.Create('Value is not an integer');

  trimmedValue := Trim(FRawValue);

  //safety
  if Length(trimmedValue) = 0 then
    exit(0);


  // Handle hexadecimal numbers (0x or 0X prefix)
  if (Length(trimmedValue) > 2) and (trimmedValue[1] = '0') and
     ((trimmedValue[2] = 'x') or (trimmedValue[2] = 'X')) then
  begin
    result := StrToInt('$' + Copy(trimmedValue, 3, Length(trimmedValue) - 2));
  end
  // Handle octal numbers (0o or 0O prefix)
  else if (Length(trimmedValue) > 2) and (trimmedValue[1] = '0') and
          ((trimmedValue[2] = 'o') or (trimmedValue[2] = 'O')) then
  begin
    // Convert octal to decimal
    result := 0;
    octalStr := Copy(trimmedValue, 3, Length(trimmedValue) - 2);
    for i := 1 to Length(octalStr) do
    begin
      if (octalStr[i] < '0') or (octalStr[i] > '7') then
        raise Exception.CreateFmt('Invalid octal digit "%s" in value "%s"', [octalStr[i], FRawValue]);
      result := result * 8 + (Ord(octalStr[i]) - Ord('0'));
    end;
  end
  // Handle binary numbers (0b or 0B prefix)
  else if (Length(trimmedValue) > 2) and (trimmedValue[1] = '0') and
          ((trimmedValue[2] = 'b') or (trimmedValue[2] = 'B')) then
  begin
    // Convert binary to decimal
    result := 0;
    binaryStr := Copy(trimmedValue, 3, Length(trimmedValue) - 2);
    for i := 1 to Length(binaryStr) do
    begin
      if (binaryStr[i] <> '0') and (binaryStr[i] <> '1') then
        raise Exception.CreateFmt('Invalid binary digit "%s" in value "%s"', [binaryStr[i], FRawValue]);
      result := result * 2 + (Ord(binaryStr[i]) - Ord('0'));
    end;
  end
  else
  begin
    if CharInSet(trimmedValue[1],['-', '+']) then
    begin
      result := StrToInt64(trimmedValue);
      exit;
    end;

    // Handle regular decimal numbers (including negative)
    if Length(trimmedValue) >= 13 then
    begin
      if TryStrToUInt64(trimmedValue, uInt64Value) then
        Exit(Int64(uInt64Value));
    end;
    result := StrToInt64(trimmedValue);
  end;
end;

function TYAMLValue.AsMapping : IYAMLMapping;
begin
  if not IsMapping then
    raise Exception.Create('Value is not a mapping : ');
  result := Self as IYAMLMapping;
end;

function TYAMLValue.AsSequence : IYAMLSequence;
begin
  //todo : a set is a sequence too - should we allow it here
  if not IsSequence then
    raise Exception.Create('Value is not a sequence');
  result := Self as IYAMLSequence;
end;

function TYAMLValue.AsSet : IYAMLSet;
begin
  if not IsSet then
    raise Exception.Create('Value is not a set');
  result := Self as IYAMLSet;
end;

function TYAMLValue.AsString : string;
begin
  if IsNull then
    result := ''
  else
    result := FRawValue;
end;

procedure TYAMLValue.ClearParent;
begin
  FParent := nil;
end;

constructor TYAMLValue.Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue, tag : string);
begin
  inherited Create;
  FParent := Pointer(parent);
  FValueType := valueType;
  FRawValue := rawValue;
  FTag := tag;

  // Create tag info from string
  if FTag <> '' then
  begin
    FTagInfo := TYAMLTagInfoFactory.ParseTag(FTag);
    ApplyTagConversion;
  end
  else
    FTagInfo := TYAMLTagInfoFactory.CreateUnresolvedTag();
end;

constructor TYAMLValue.Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue : string; const tagInfo : IYAMLTagInfo);
begin
  inherited Create;
  FParent := Pointer(parent);
  FValueType := valueType;
  FRawValue := rawValue;
  FTagInfo := tagInfo;

  // Set backward compatible string tag
  if FTagInfo <> nil then
  begin
    FTag := FTagInfo.ToString;
    ApplyTagConversion;
  end
  else
  begin
    FTag := '';
    FTagInfo := TYAMLTagInfoFactory.CreateUnresolvedTag();
  end;
end;

constructor TYAMLValue.CreateNull;
begin
  Create(nil, TYAMLValueType.vtNull, '','');
end;

destructor TYAMLValue.Destroy;
begin

  inherited;
end;

function TYAMLValue.FindRoot : IYAMLValue;
var
  nextParent : IYAMLValue;
begin
  result := Self;
  nextParent := GetParent;
  while nextParent <> nil do
  begin
    result := nextParent;
    nextParent := nextParent.Parent;
  end;
end;

function TYAMLValue.GetComment: string;
begin
  result := FComment;
end;

function TYAMLValue.GetCount : integer;
begin
  result := 0;
end;

function TYAMLValue.GetNodes(Index : integer) : IYAMLValue;
begin
  raise Exception.Create('Cannot access Nodes on non-sequence type');
end;

function TYAMLValue.GetParent : IYAMLValue;
begin
  //not ideal
  if FParent <> nil then
    result := IYAMLValue(FParent)
  else
    result := nil;
end;

function TYAMLValue.GetRawValue : string;
begin
  result := FRawValue;
end;

function TYAMLValue.GetTag : string;
begin
  result := FTag;
end;

function TYAMLValue.GetTagInfo : IYAMLTagInfo;
begin
  result := FTagInfo;
end;

function TYAMLValue.GetValue(const key : string) : IYAMLValue;
begin
  if not IsMapping then
    raise Exception.Create('Cannot access Values on non-mapping type');
  result := AsMapping.Items[key];
  if result = nil then
    raise Exception.CreateFmt('key "%s" not found in mapping', [key]);
end;

function TYAMLValue.GetValueType : TYAMLValueType;
begin
  result := FValueType;
end;

function TYAMLValue.IsAlias : boolean;
begin
  result := FValueType = TYAMLValueType.vtAlias;
end;

function TYAMLValue.IsBoolean : boolean;
begin
  result := FValueType = TYAMLValueType.vtBoolean;
end;

function TYAMLValue.IsCollection: boolean;
begin
result := FValueType in [TYAMLValueType.vtSequence, TYAMLValueType.vtMapping, TYAMLValueType.vtSet];
end;

function TYAMLValue.IsFloat : boolean;
begin
  result := FValueType = TYAMLValueType.vtFloat;
end;

function TYAMLValue.IsInteger : boolean;
begin
  result := FValueType = TYAMLValueType.vtInteger;
end;

function TYAMLValue.IsMapping : boolean;
begin
  result := FValueType = TYAMLValueType.vtMapping;
end;

function TYAMLValue.IsNull : boolean;
begin
  result := FValueType = TYAMLValueType.vtNull;
end;

function TYAMLValue.IsScalar: boolean;
begin
  result := not (FValueType in [TYAMLValueType.vtSequence,TYAMLValueType.vtSet,TYAMLValueType.vtMapping, TYAMLValueType.vtAlias]);
end;

function TYAMLValue.IsSequence : boolean;
begin
  result := FValueType = TYAMLValueType.vtSequence;
end;

function TYAMLValue.IsSet : boolean;
begin
  result := FValueType = TYAMLValueType.vtSet;
end;

function TYAMLValue.IsString : boolean;
begin
  result := FValueType = TYAMLValueType.vtString;
end;

function TYAMLValue.IsTaggedAs(const TagName : string) : boolean;
begin
  // Check both resolved tag and original text for compatibility
  if FTagInfo <> nil then
    result := SameText(FTagInfo.ResolvedTag, TagName) or SameText(FTagInfo.OriginalText, TagName)
  else
    result := SameText(FTag, TagName);
end;

function TYAMLValue.IsTimeStamp : boolean;
begin
  result := FValueType = TYAMLValueType.vtTimestamp;
end;

function TYAMLValue.IsNumeric : boolean;
begin
  result := (FValueType = TYAMLValueType.vtInteger) or (FValueType = TYAMLValueType.vtFloat);
end;

procedure TYAMLValue.SetComment(const value: string);
begin
  FComment := value;
end;

function TYAMLValue.ToString : string;
begin
  case FValueType of
    TYAMLValueType.vtNull : result := 'null';
    TYAMLValueType.vtBoolean,
    TYAMLValueType.vtInteger,
    TYAMLValueType.vtFloat,
    TYAMLValueType.vtString : result := FRawValue;
    TYAMLValueType.vtSequence : result := '[Sequence]';
    TYAMLValueType.vtMapping : result := '[Mapping]';
    TYAMLValueType.vtSet : result := '[Set]';
    TYAMLValueType.vtAlias : result := '*' + FRawValue;
  else
    result := '[Unknown]';
  end;

  // Add tag information if present
  if FTag <> '' then
    result := FTag + ' ' + result;
end;

function TYAMLValue.TryGetValue(const key : string; out value : IYAMLValue) : boolean;
begin
  raise Exception.Create('Cannot access values on non-mapping type');
end;

// Tag modification methods

procedure TYAMLValue.SetTag(const tag : string);
begin
  FTag := tag;
  if tag <> '' then
    FTagInfo := TYAMLTagInfoFactory.ParseTag(tag)
  else
    FTagInfo := TYAMLTagInfoFactory.CreateUnresolvedTag();
end;

procedure TYAMLValue.SetTagInfo(const tagInfo : IYAMLTagInfo);
begin
  FTagInfo := tagInfo;
  if tagInfo <> nil then
    FTag := tagInfo.ToString
  else
  begin
    FTag := '';
    FTagInfo := TYAMLTagInfoFactory.CreateUnresolvedTag();
  end;
end;

procedure TYAMLValue.ClearTag;
begin
  FTag := '';
  FTagInfo := TYAMLTagInfoFactory.CreateUnresolvedTag();
end;

{ TYAMLSequence }

function TYAMLSequence.AddMapping(const tag : string) : IYAMLMapping;
begin
  result := TYAMLMapping.Create(Self, tag);
  AddValue(result);
end;

function TYAMLSequence.AddMapping(const tagInfo : IYAMLTagInfo) : IYAMLMapping;
begin
  result := TYAMLMapping.Create(Self, tagInfo);
  AddValue(result);
end;


function TYAMLSequence.AddSequence(const tag : string) : IYAMLSequence;
begin
  result := TYAMLSequence.Create(Self, tag);
  AddValue(result);
end;

function TYAMLSequence.AddSequence(const tagInfo : IYAMLTagInfo) : IYAMLSequence;
begin
  result := TYAMLSequence.Create(Self, tagInfo);
  AddValue(result);
end;


function TYAMLSequence.AddSet(const tag : string) : IYAMLSet;
begin
  result := TYAMLSet.Create(Self, tag);
  AddValue(result);
end;

function TYAMLSequence.AddSet(const tagInfo : IYAMLTagInfo) : IYAMLSet;
begin
  result := TYAMLSet.Create(Self, tagInfo);
  AddValue(result);
end;




// Tag-aware AddValue implementations

function TYAMLSequence.AddValue(const value : boolean; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtBoolean, LowerCase(BoolToStr(value, true)), tag);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtBoolean, LowerCase(BoolToStr(value, true)), tagInfo);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : Int32; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tag);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : Int32; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tagInfo);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : UInt32; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tag);
  AddValue(result);
end;

procedure TYAMLSequence.AddValue(const value : IYAMLValue);
begin
  if value = nil then
    raise EArgumentNilException.Create('cannot add nil to sequence');
  FItems.Add(value);
end;

function TYAMLSequence.AddValue(const value : UInt32; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tagInfo);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : Int64; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tag);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : Int64; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tagInfo);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : UInt64; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tag);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : UInt64; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tagInfo);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : Single; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, FloatToStr(value, YAMLFormatSettings), tag);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : Single; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, FloatToStr(value, YAMLFormatSettings), tagInfo);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : Double; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, FloatToStr(value, YAMLFormatSettings), tag);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : Double; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, FloatToStr(value, YAMLFormatSettings), tagInfo);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : string; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtString, value, tag);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : string; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtString, value, tagInfo);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : TDateTime; isUTC : boolean; const tag : string) : IYAMLValue;
begin
  if isUTC then
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.UTCDateToISO8601Str(value), tag)
  else
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.LocalDateToISO8601Str(value), tag);
  AddValue(result);
end;

function TYAMLSequence.AddValue(const value : TDateTime; isUTC : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  if isUTC then
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.UTCDateToISO8601Str(value), tagInfo)
  else
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.LocalDateToISO8601Str(value), tagInfo);
  AddValue(result);
end;


constructor TYAMLSequence.Create(const parent : IYAMLValue; const tag : string);
var
  vt : TYAMLValueType;
begin
  vt := GetNodeValueType;
  inherited Create(parent, vt, '', tag);
  FItems := TList<IYAMLValue>.Create;
end;

procedure TYAMLSequence.Clear;
begin
  FItems.Clear;
  ClearComments;
end;

constructor TYAMLSequence.Create(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo);
var
  vt : TYAMLValueType;
begin
  vt := GetNodeValueType;
  inherited Create(parent, vt, '', tagInfo);
  FItems := TList<IYAMLValue>.Create;
end;


destructor TYAMLSequence.Destroy;
var
  item : IYAMLValue;
begin
  for item in FItems do
    (item as IYAMLValuePrivate).ClearParent;
  FItems.Free;
  inherited;
end;


function TYAMLSequence.GetArray(index: Integer): IYAMLSequence;
begin
  result := nil;
  if (index >= 0) and (index < FItems.Count) then
    result := FItems[index].AsSequence
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

function TYAMLSequence.GetBool(index: Integer): Boolean;
begin
  if (index >= 0) and (index < FItems.Count) then
    result := FItems[index].AsBoolean
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

function TYAMLSequence.GetCount : integer;
begin
  result := FItems.Count;
end;

function TYAMLSequence.GetDateTime(index: Integer): TDateTime;
begin
  if (index >= 0) and (index < FItems.Count) then
    result := FItems[index].AsLocalDateTime
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

function TYAMLSequence.GetFloat(index: Integer): Double;
begin
  if (index >= 0) and (index < FItems.Count) then
    result := FItems[index].AsFloat
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

function TYAMLSequence.GetInt(index: Integer): Integer;
begin
  if (index >= 0) and (index < FItems.Count) then
    result := Integer(FItems[index].AsInteger)
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));

end;

function TYAMLSequence.GetItem(Index : integer) : IYAMLValue;
begin
  if (index >= 0) and (index < FItems.Count) then
    result := FItems[index]
  else
    result := TYAMLValue.Create(Self, TYAMLValueType.vtNull, '', '');
end;

function TYAMLSequence.GetString(index: integer): string;
begin
  result := '';
  if (index >= 0) and (index < FItems.Count) then
    result := FItems[index].AsString
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));

end;

function TYAMLSequence.GetLong(index: Integer): Int64;
begin
  if (index >= 0) and (index < FItems.Count) then
    result := FItems[index].AsInteger
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));

end;

function TYAMLSequence.GetNodes(Index : integer) : IYAMLValue;
begin
  result := GetItem(Index);
end;


class function TYAMLSequence.GetNodeValueType : TYAMLValueType;
begin
  result := TYAMLValueType.vtSequence;
end;



function TYAMLSequence.GetObj(index: Integer): IYAMLMapping;
begin
  result := nil;
  if (index >= 0) and (index < FItems.Count) then
    result := FItems[index].AsMapping
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));

end;


function TYAMLSequence.GetULong(index: Integer): UInt64;
begin
  if (index >= 0) and (index < FItems.Count) then
    result := UInt64(FItems[index].AsInteger)
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));

end;

function TYAMLSequence.GetUtcDateTime(index: Integer): TDateTime;
begin
  if (index >= 0) and (index < FItems.Count) then
    result := FItems[index].AsUTCDateTime
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

function TYAMLSequence.GetValue(const key : string) : IYAMLValue;
begin
  raise Exception.Create('Cannot access Values on sequence type. Use Nodes[index] instead.');
end;


procedure TYAMLSequence.SetArray(index: Integer; const value: IYAMLSequence);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems[index] := value
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

procedure TYAMLSequence.SetBool(index: Integer; const value: Boolean);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems[index] := TYAMLValue.Create(Self, TYAMLValueType.vtBoolean, LowerCase(BoolToStr(value,true)))
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

procedure TYAMLSequence.SetDateTime(index: Integer; const value: TDateTime);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems[index] := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.LocalDateToISO8601Str(value))
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

procedure TYAMLSequence.SetFloat(index: Integer; const value: double);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems[index] := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, FloatToStr(value, YAMLFormatSettings))
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

procedure TYAMLSequence.SetInt(index: Integer; const value: integer);
begin
  SetLong(index, Int64(value));
end;

procedure TYAMLSequence.SetString(index: integer; const value: string);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems[index] := TYAMLValue.Create(Self, TYAMLValueType.vtString, value)
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

procedure TYAMLSequence.SetLong(index: Integer; const value: Int64);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems[index] := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value))
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;


procedure TYAMLSequence.SetObject(index: Integer; const value: IYAMLMapping);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems[index] := value
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

procedure TYAMLSequence.SetULong(index: Integer; const value: UInt64);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems[index] := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value))
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

procedure TYAMLSequence.SetUtcDateTime(index: Integer; const value: TDateTime);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems[index] := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.UTCDateToISO8601Str(value))
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

{ TYAMLMapping }

function TYAMLMapping.AddOrSetMapping(const key : string; const tag : string = '') : IYAMLMapping;
begin
  result := TYAMLMapping.Create(Self, tag);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetMapping(const key : string;  const tagInfo : IYAMLTagInfo) : IYAMLMapping;
begin
  result := TYAMLMapping.Create(Self, tagInfo);
  AddOrSetValue(key, result);
end;


function TYAMLMapping.AddOrSetSequence(const key : string; const tag : string = '') : IYAMLSequence;
begin
  result := TYAMLSequence.Create(Self, tag);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetSequence(const key : string; const tagInfo : IYAMLTagInfo) : IYAMLSequence;
begin
  result := TYAMLSequence.Create(Self, tagInfo);
  AddOrSetValue(key, result);
end;


function TYAMLMapping.AddOrSetSet(const key : string; const tag : string = '') : IYAMLSet;
begin
  result := TYAMLSet.Create(Self, tag);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetSet(const key : string; const tagInfo : IYAMLTagInfo) : IYAMLSet;
begin
  result := TYAMLSet.Create(Self, tagInfo);
  AddOrSetValue(key, result);
end;


function TYAMLMapping.AddOrSetValue(const key : string; const value : Single) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, FloatToStr(value, YAMLFormatSettings));
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Double) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, FloatToStr(value, YAMLFormatSettings));
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key, value : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtString,value);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : TDateTime; isUTC : boolean) : IYAMLValue;
begin
  if isUTC then
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.UTCDateToISO8601Str(value), '!!timestamp')
  else
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.LocalDateToISO8601Str(value), '!!timestamp');
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : UInt64) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value));
  AddOrSetValue(key, result);
end;

procedure TYAMLMapping.AddOrSetValue(const key : string; const value : IYAMLValue);
begin
  if not FPairs.ContainsKey(key) then
    FKeys.Add(key);
  FPairs.AddOrSetValue(key, value);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : boolean) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtBoolean, LowerCase(BoolToStr(value, true)));
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Int32) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value));
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : UInt32) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value));
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Int64) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value));
  AddOrSetValue(key, result);
end;

// Tag-aware AddOrSetValue implementations

function TYAMLMapping.AddOrSetValue(const key : string; const value : boolean; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtBoolean, LowerCase(BoolToStr(value, true)), tag);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtBoolean, LowerCase(BoolToStr(value, true)), tagInfo);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Int32; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tag);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Int32; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tagInfo);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : UInt32; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tag);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : UInt32; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tagInfo);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Int64; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tag);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Int64; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tagInfo);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : UInt64; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tag);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : UInt64; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tagInfo);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Single; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, FloatToStr(value, YAMLFormatSettings), tag);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Single; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, FloatToStr(value, YAMLFormatSettings), tagInfo);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Double; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, FloatToStr(value, YAMLFormatSettings), tag);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Double; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, FloatToStr(value, YAMLFormatSettings), tagInfo);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : string; const tag : string) : IYAMLValue;
begin
  if value = '' then
    result := TYAMLValue.Create(Self, TYAMLValueType.vtNull, value, tag)
  else
    result := TYAMLValue.Create(Self, TYAMLValueType.vtString, value, tag);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : string; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  if value = '' then
    result := TYAMLValue.Create(Self, TYAMLValueType.vtNull, value, tagInfo)
  else
    result := TYAMLValue.Create(Self, TYAMLValueType.vtString, value, tagInfo);

  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : TDateTime; isUTC : boolean; const tag : string) : IYAMLValue;
begin
  if isUTC then
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.UTCDateToISO8601Str(value), tag)
  else
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.LocalDateToISO8601Str(value), tag);
  AddOrSetValue(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : TDateTime; isUTC : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  if isUTC then
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.UTCDateToISO8601Str(value), tagInfo)
  else
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.LocalDateToISO8601Str(value), tagInfo);
  AddOrSetValue(key, result);
end;


procedure TYAMLMapping.Clear;
begin
  FKeys.Clear;
  FPairs.Clear;
  if FComments <> nil then
    FComments.Clear;
  FComment := '';
end;

function TYAMLMapping.Contains(const key: string): boolean;
begin
  result := FPairs.ContainsKey(key);
end;

function TYAMLMapping.ContainsKey(const key : string) : boolean;
begin
  result := FPairs.ContainsKey(key);
end;

constructor TYAMLMapping.Create(const parent : IYAMLValue; const tag : string);
begin
  inherited Create(parent, TYAMLValueType.vtMapping, '', tag);
  FPairs := TDictionary<string, IYAMLValue>.Create;
  FKeys := TStringList.Create;
end;

constructor TYAMLMapping.Create(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo);
begin
  inherited Create(parent, TYAMLValueType.vtMapping, '', tagInfo);
  FPairs := TDictionary<string, IYAMLValue>.Create;
  FKeys := TStringList.Create;
end;


destructor TYAMLMapping.Destroy;
var
  item : IYAMLValue;
begin
  for item in FPairs.Values do
    (item as IYAMLValuePrivate).ClearParent;

  FKeys.Free;
  FPairs.Free;
  inherited Destroy;
end;

function TYAMLMapping.GetArray(const key: string): IYAMLSequence;
var
  value : IYAMLValue;
begin
  if not TryGetValue(key, value ) then
    value := AddOrSetSequence(key);
  result := value.AsSequence;
end;

function TYAMLMapping.GetCount : integer;
begin
  result := FPairs.Count;
end;

function TYAMLMapping.GetKey(Index : integer) : string;
begin
  if (index >= 0) and (Index < FKeys.Count) then
    result := FKeys[index]
  else
    raise EArgumentOutOfRangeException.Create('Index out of range');
end;

function TYAMLMapping.GetNodes(Index : integer) : IYAMLValue;
begin
  raise Exception.Create('Cannot access Nodes on mapping type. Use Values["key"] instead.');
end;

function TYAMLMapping.GetObj(const key: string): IYAMLMapping;
var
  value : IYAMLValue;
begin
  if not TryGetValue(key, value ) then
    value := AddOrSetMapping(key);
  result := value.AsMapping;
end;

function TYAMLMapping.GetObjectBool(const key: string): Boolean;
var
  value : IYAMLValue;
begin
  if not TryGetValue(key, value ) then
    value := AddOrSetValue(key, false);
  result := value.AsBoolean;
end;

function TYAMLMapping.GetObjectDateTime(const key: string): TDateTime;
var
  value : IYAMLValue;
begin
  if not TryGetValue(key, value ) then
    value := AddOrSetValue(key, MinDateTime);
  result := value.AsLocalDateTime;
end;

function TYAMLMapping.GetObjectFloat(const key: string): Double;
var
  value : IYAMLValue;
begin
  if not TryGetValue(key, value ) then
    value := AddOrSetValue(key, 0);
  result := value.AsFloat;
end;

function TYAMLMapping.GetObjectInt(const key: string): Integer;
var
  value : IYAMLValue;
begin
  if not TryGetValue(key, value ) then
    value := AddOrSetValue(key, 0);
  result := Integer(value.AsInteger);
end;

function TYAMLMapping.GetObjectLong(const key: string): Int64;
var
  value : IYAMLValue;
begin
  if not TryGetValue(key, value ) then
    value := AddOrSetValue(key, 0);
  result := value.AsInteger;
end;

function TYAMLMapping.GetObjectString(const key: string): string;
var
  value : IYAMLValue;
begin
  if not TryGetValue(key, value ) then
    value := AddOrSetValue(key, '');
  result := value.AsString;
end;

function TYAMLMapping.GetObjectULong(const key: string): UInt64;
var
  value : IYAMLValue;
begin
  if not TryGetValue(key, value ) then
    value := AddOrSetValue(key, 0);
  result := UInt64(value.AsInteger);

end;

function TYAMLMapping.GetObjectUtcDateTime(const key: string): TDateTime;
var
  value : IYAMLValue;
begin
  if not TryGetValue(key, value ) then
    value := AddOrSetValue(key, MinDateTime);
  result := value.AsUTCDateTime;
end;

function TYAMLMapping.GetValue(const key : string) : IYAMLValue;
begin
  if not FPairs.TryGetValue(key, result) then
    result := TYAMLValue.Create(Self, TYAMLValueType.vtNull,'');
end;

procedure TYAMLMapping.MergeMapping(const ASourceMapping : IYAMLMapping);
var
  i : integer;
  key : string;
  value, copiedValue : IYAMLValue;
begin
  if ASourceMapping = nil then
    Exit;

  // Merge all key-value pairs from source mapping
  for i := 0 to ASourceMapping.Count - 1 do
  begin
    key := ASourceMapping.Keys[i];
    value := ASourceMapping.GetValue(key);

    // Only add if we don't already have this key (don't override existing values)
    if not ContainsKey(key) then
    begin
      // Create a copy to avoid shared ownership issues
      case Value.ValueType of
        TYAMLValueType.vtString : CopiedValue := TYAMLValue.Create(Self, TYAMLValueType.vtString, Value.AsString, value.Tag);
        TYAMLValueType.vtInteger : CopiedValue := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(Value.AsInteger), value.Tag);
        TYAMLValueType.vtFloat : CopiedValue := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, FloatToStr(Value.AsFloat, YAMLFormatSettings), value.Tag);
        TYAMLValueType.vtBoolean : CopiedValue := TYAMLValue.Create(Self, TYAMLValueType.vtBoolean, BoolToStr(Value.AsBoolean, True), value.Tag);
        TYAMLValueType.vtNull : CopiedValue := TYAMLValue.Create(Self, TYAMLValueType.vtNull, '', '');
      else
        // For complex types like mappings and sequences, reference the original
        // (this is safe as long as the source mapping outlives the target)
        //TODO : replace this with a deeep copy
        copiedValue := value;
      end;

      AddOrSetValue(key, copiedValue);
    end;
  end;

end;

procedure TYAMLMapping.SetArray(const key: string; const Value: IYAMLSequence);
begin
  AddOrSetValue(key,Value);
end;

procedure TYAMLMapping.SetObject(const key: string; const Value: IYAMLMapping);
begin
  AddOrSetValue(key,Value);
end;

procedure TYAMLMapping.SetObjectBool(const key: string; const Value: Boolean);
begin
  AddOrSetValue(key,Value);
end;

procedure TYAMLMapping.SetObjectDateTime(const key: string; const Value: TDateTime);
begin
  AddOrSetValue(key,Value, true);
end;

procedure TYAMLMapping.SetObjectFloat(const key: string; const Value: Double);
begin
  AddOrSetValue(key,Value);
end;

procedure TYAMLMapping.SetObjectInt(const key: string; const Value: Integer);
begin
  AddOrSetValue(key,Value);
end;

procedure TYAMLMapping.SetObjectLong(const key: string; const Value: Int64);
begin
  AddOrSetValue(key,Value);
end;

procedure TYAMLMapping.SetObjectString(const key, value: string);
begin
  AddOrSetValue(key,Value);
end;

procedure TYAMLMapping.SetObjectULong(const key: string; const Value: UInt64);
begin
  AddOrSetValue(key,Value);
end;

procedure TYAMLMapping.SetObjectUtcDateTime(const key: string; const Value: TDateTime);
begin
  AddOrSetValue(key,Value, true)
end;

function TYAMLMapping.TryGetValue(const key : string; out value : IYAMLValue) : boolean;
begin
  result := FPairs.TryGetValue(key, value);
  if not result then
    value := TYAMLValue.CreateNull;
end;

{ TYAMLDocument }

function TYAMLDocument.AsMapping : IYAMLMapping;
begin
  result := FRoot.AsMapping;
end;

function TYAMLDocument.AsSequence : IYAMLSequence;
begin
  result := FRoot.AsSequence;
end;

function TYAMLDocument.AsSet: IYAMLSet;
begin
  result := FRoot.AsSet;
end;

constructor TYAMLDocument.Create(const ARoot : IYAMLValue; const yamlVersion : IYAMLVersionDirective; const tagDirectives : TList<IYAMLTagDirective>);
begin
  inherited Create;
  FRoot := ARoot;
  FOptions := TYAMLEmitOptions.Create;
  FYAMLVersion := yamlVersion;
  if FYAMLVersion = nil then
    FYAMLVersion := TYAMLVersionDirective.YAML_1_2;
  if (tagDirectives <> nil) and (tagDirectives.Count > 0) then
  begin
    FTagDirectives := TList<IYAMLTagDirective>.Create;
    FTagDirectives.AddRange(tagDirectives);
  end;

end;

destructor TYAMLDocument.Destroy;
begin
  FTagDirectives.Free;
  inherited;
end;

constructor TYAMLDocument.Create;
begin
  FRoot := TYAMLSequence.Create(nil,'');
  FOptions := TYAMLEmitOptions.Create;
  FYAMLVersion := TYAMLVersionDirective.YAML_1_2;
  FTagDirectives := nil;
end;

function TYAMLDocument.GetIsMapping : boolean;
begin
  result := FRoot.IsMapping;
end;

function TYAMLDocument.GetIsNull: boolean;
begin
  result := FRoot.IsNull;
end;

function TYAMLDocument.GetIsScalar: boolean;
begin
  result := FRoot.IsScalar;
end;

function TYAMLDocument.GetIsSequence : boolean;
begin
  result := FRoot.IsSequence;
end;

function TYAMLDocument.GetIsSet: boolean;
begin
  result := FRoot.IsSet;
end;

function TYAMLDocument.GetOptions : IYAMLEmitOptions;
begin
  result := FOptions;
end;

function TYAMLDocument.GetRoot : IYAMLValue;
begin
  result := FRoot;
end;

function TYAMLDocument.GetTagDirectives: TList<IYAMLTagDirective>;
begin
  if FTagDirectives = nil then
    FTagDirectives := TList<IYAMLTagDirective>.Create;
  result := FTagDirectives;
end;

function TYAMLDocument.GetVersion: IYAMLVersionDirective;
begin
  result := FYAMLVersion;
end;

function TYAMLDocument.Query(const expression: string): IYAMLSequence;
begin
  result := TYAMLPathProcessor.Query(FRoot, expression);
end;

function TYAMLDocument.QuerySingle(const expression: string; out AMatch: IYAMLValue): boolean;
begin
  result := TYAMLPathProcessor.QuerySingle(FRoot, expression, AMatch);
end;

procedure TYAMLDocument.WriteToFile(const filename : string);
begin
  TYAML.WriteToFile(Self, fileName);
end;

function TYAMLDocument.ToYAMLString : string;
begin
  result := TYAML.WriteToString(Self);
end;

{ TYAMLEmitOptions }

function TYAMLEmitOptions.Clone: IYAMLEmitOptions;
begin
  result := TYAMLEmitOptions.CreateClone(Self);
end;

constructor TYAMLEmitOptions.Create;
begin
  FEncoding := TEncoding.UTF8;
  FFormat := TYAMLOutputFormat.yofBlock;
  FIndentSize := 2;
  FQuoteStrings := False;
  FMaxLineLength := 80;
  FWriteBOM := false;
  FEmitTags := true;
  FEmitExplicitNull := false;
  FEmitDocumentMarkers := false;
  FEmitTagDirectives := false;
  FEmitYAMLDirective := false;
  FPrettyPrint := true;
end;

constructor TYAMLEmitOptions.CreateClone(const source: IYAMLEmitOptions);
begin
  FEncoding := source.Encoding;
  FFormat := source.Format;
  FIndentSize := source.IndentSize;
  FQuoteStrings := source.QuoteStrings;
  FEmitDocumentMarkers := source.EmitDocumentMarkers;
  FMaxLineLength := source.MaxLineLength;
  FWriteBOM := source.WriteByteOrderMark;
  FEmitTags := source.EmitTags;
  FEmitExplicitNull := source.EmitExplicitNull;
  FEmitTagDirectives := source.EmitTagDirectives;
  FEmitYAMLDirective := source.EmitYAMLDirective;
  FPrettyPrint := source.PrettyPrint;
end;

destructor TYAMLEmitOptions.Destroy;
begin
  if (FEncoding <> nil) and (not TEncoding.IsStandardEncoding(FEncoding)) then
    FEncoding.Free;

  inherited;
end;

function TYAMLEmitOptions.GetEmitDocumentMarkers : boolean;
begin
  result := FEmitDocumentMarkers;
end;

function TYAMLEmitOptions.GetEncoding : TEncoding;
begin
  result := FEncoding;
end;

function TYAMLEmitOptions.GetFormat : TYAMLOutputFormat;
begin
  result := FFormat;
end;

function TYAMLEmitOptions.GetIndentSize : UInt32;
begin
  result := FIndentSize;
end;

function TYAMLEmitOptions.GetMaxLineLength : UInt32;
begin
  result := FMaxLineLength;
end;

function TYAMLEmitOptions.GetPrettyPrint: boolean;
begin
  result := FPrettyPrint;
end;

function TYAMLEmitOptions.GetQuoteStrings : boolean;
begin
  result := FQuoteStrings;
end;

function TYAMLEmitOptions.GetWriteBOM : boolean;
begin
  result := FWriteBOM;
end;

function TYAMLEmitOptions.GetEmitExplicitNull: boolean;
begin
  result := FEmitExplicitNull;
end;

function TYAMLEmitOptions.GetEmitTagDirectives: boolean;
begin
  result := FEmitTagDirectives;
end;

function TYAMLEmitOptions.GetEmitTags : boolean;
begin
  result := FEmitTags;
end;

function TYAMLEmitOptions.GetEmitYAMLDirective: boolean;
begin
  result := FEmitYAMLDirective;
end;

procedure TYAMLEmitOptions.SetEmitDocumentMarkers(value : boolean);
begin
  FEmitDocumentMarkers := value;
end;

procedure TYAMLEmitOptions.SetEncoding(const value : TEncoding);
begin
  if (FEncoding <> nil) and (not TEncoding.IsStandardEncoding(FEncoding)) then
    FEncoding.Free;
  FEncoding := value;
  if FEncoding = nil then
    FEncoding := TEncoding.UTF8;
end;

procedure TYAMLEmitOptions.SetFormat(value : TYAMLOutputFormat);
begin
  FFormat := value;
end;

procedure TYAMLEmitOptions.SetIndentSize(value : UInt32);
begin
  FIndentSize := value;
  if FIndentSize < 1 then
    FIndentSize := 1;
end;

procedure TYAMLEmitOptions.SetMaxLineLength(value : UInt32);
begin
  FMaxLineLength := value;
  if FMaxLineLength < 80 then
    FMaxLineLength := 80;
end;

procedure TYAMLEmitOptions.SetPrettyPrint(const value: boolean);
begin
  FPrettyPrint := value;
end;

procedure TYAMLEmitOptions.SetQuoteStrings(value : boolean);
begin
  FQuoteStrings := value;
end;

procedure TYAMLEmitOptions.SetWriteBOM(const value : boolean);
begin
  FWriteBOM := value;
end;

procedure TYAMLEmitOptions.SetEmitExplicitNull(const value: boolean);
begin
  FEmitExplicitNull := value;
end;

procedure TYAMLEmitOptions.SetEmitTagDirectives(value: boolean);
begin
  FEmitTagDirectives := value;
end;

procedure TYAMLEmitOptions.SetEmitTags(const value : boolean);
begin
  FEmitTags := value;
end;

procedure TYAMLEmitOptions.SetEmitYAMLDirective(value: boolean);
begin
  FEmitYAMLDirective := value;
end;

{ TYAMLParserOptions }

constructor TYAMLParserOptions.Create;
begin
  FDuplicateKeyBehavior := TYAMLDuplicateKeyBehavior.dkOverwrite;
  FJSONMode := false;
end;

function TYAMLParserOptions.GetDuplicateKeyBehavior : TYAMLDuplicateKeyBehavior;
begin
  result := FDuplicateKeyBehavior;
end;

function TYAMLParserOptions.GetJSONMode: boolean;
begin
  result := FJSONMode;
end;

procedure TYAMLParserOptions.SetDuplicateKeyBehavior(value : TYAMLDuplicateKeyBehavior);
begin
  FDuplicateKeyBehavior := value;
end;

procedure TYAMLParserOptions.SetJSONMode(value: boolean);
begin
  FJSONMode := value;
end;

{ TYAMLSet }

procedure TYAMLSet.AddValue(const value : IYAMLValue);
var
  ValueStr : string;
begin
  if value = nil then Exit;

  ValueStr := value.AsString;

  // Check for duplicates using string representation
  if not FValues.IndexOf(ValueStr) >= 0 then
  begin
    FValues.Add(ValueStr);
    inherited AddValue(value);
  end;
end;

constructor TYAMLSet.Create(const parent : IYAMLValue; const tag : string);
begin
  inherited Create(parent, tag);
  FValues := TStringList.Create;
  FValues.Sorted := True;  // For fast duplicate detection
end;

procedure TYAMLSet.Clear;
begin
  inherited;
  FValues.Clear;
end;

constructor TYAMLSet.Create(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo);
begin
  inherited Create(parent, tagInfo);
  FValues := TStringList.Create;
  FValues.Sorted := True;  // For fast duplicate detection
end;


destructor TYAMLSet.Destroy;
begin
  FValues.Free;
  inherited;
end;

class function TYAMLSet.GetNodeValueType : TYAMLValueType;
begin
  result := TYAMLValueType.vtSet;
end;

{ TYAMLCollection }

procedure TYAMLCollection.AddComment(const value: string);
begin
  EnsureComments;
  FComments.Add(value);
end;

procedure TYAMLCollection.ClearComments;
begin
  if FComments <> nil then
    FComments.Clear;
end;

constructor TYAMLCollection.Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue : string; const tag : string);
begin
  inherited Create(parent, valueType,rawValue, tag);
end;

constructor TYAMLCollection.Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue : string; const tagInfo : IYAMLTagInfo);
begin
  inherited Create(parent, valueType, rawValue, tagInfo);
end;

destructor TYAMLCollection.Destroy;
begin
  FComments.Free;

  inherited;
end;

procedure TYAMLCollection.EnsureComments;
begin
  if FComments = nil then
    FComments := TStringList.Create;
end;

function TYAMLCollection.GetComments: TStrings;
begin
  EnsureComments;
  result := FComments;
end;

function TYAMLCollection.GetHasComments: boolean;
begin
  result := (FComments <> nil) and (FComments.Count > 0);
end;

function TYAMLCollection.Query(const AExpression: string): IYAMLSequence;
begin
  result := TYAMLPathProcessor.Query(Self, AExpression);
end;

function TYAMLCollection.QuerySingle(const AExpression: string; out AMatch: IYAMLValue): boolean;
begin
  result := TYAMLPathProcessor.QuerySingle(Self, AExpression, AMatch);
end;

procedure TYAMLCollection.SetComments(const value: TStrings);
begin
  if value <> nil then
  begin
    EnsureComments;
    FComments.Assign(value);
  end
  else
    FreeAndNil(FComments);
end;

{ TYAMLVersion }

constructor TYAMLVersionDirective.Create(major, minor: integer);
begin
  FMajor := major;
  FMinor := minor;
end;

function TYAMLVersionDirective.GetMajor: integer;
begin
  result := FMajor;
end;

function TYAMLVersionDirective.GetMinor: integer;
begin
  result := FMinor;
end;

function TYAMLVersionDirective.IsCompatible(const other: IYAMLVersionDirective): boolean;
begin
  // YAML 1.2 parser should accept 1.1 and 1.2 documents
  result := (FMajor = 1) and ((FMinor = 1) or (FMinor = 2)) and
            (other.Major = 1) and ((other.Minor = 1) or (other.Minor = 2));
end;

function TYAMLVersionDirective.ToString: string;
begin
  result := Format('%d.%d', [FMajor, FMinor]);
end;

class function TYAMLVersionDirective.YAML_1_1: IYAMLVersionDirective;
begin
  result := TYAMLVersionDirective.Create(1,1);
end;

class function TYAMLVersionDirective.YAML_1_2: IYAMLVersionDirective;
begin
  result := TYAMLVersionDirective.Create(1,2);
end;

{ TYAMLTagDirective }

constructor TYAMLTagDirective.Create(const prefix, handle: string);
begin
  FPrefix := prefix;
  FHandle := handle;
end;

function TYAMLTagDirective.GetHandle: string;
begin
  result := FHandle;
end;

function TYAMLTagDirective.GetPrefix: string;
begin
  result := FPrefix;
end;

function TYAMLTagDirective.ToString: string;
begin
  result := FPrefix + ' ' + FHandle;
end;




end.
