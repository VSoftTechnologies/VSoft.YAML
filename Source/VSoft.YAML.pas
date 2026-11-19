unit VSoft.YAML;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  // YAML Parse Exception
  EYAMLParseException = class(Exception)
  private
    FLine: integer;
    FColumn: integer;
  public
    constructor Create(const message : string; line : integer; column: integer);
    property Line: integer read FLine;
    property Column: integer read FColumn;
  end;

  EYAMLPathError = class(Exception)
  end;

  {$SCOPEDENUMS ON}
    // YAML Value Types
  TYAMLValueType = (
    vtNull,
    vtBoolean,
    vtInteger,
    vtFloat,
    vtString,
    vtSequence,
    vtMapping,
    vtSet,
    vtTimestamp,
    vtAlias
  );

  // YAML output format options
  TYAMLOutputFormat = (
    yofBlock,     // Block style (default)
    yofFlow,      // Flow style
    yofMixed      // Mixed style (flow for simple, block for complex)
  );

  // YAML block scalar style options
  TYAMLBlockScalarStyle = (
    bssNone,      // Don't use block scalars (escape newlines in quotes)
    bssLiteral,   // Use literal style (|) - preserves line breaks exactly
    bssFolded     // Use folded style (>) - folds line breaks into spaces
  );

  // YAML block scalar chomping indicator options
  TYAMLBlockChompingIndicator = (
    bciClip,      // Default - single trailing newline preserved (no indicator)
    bciStrip,     // All trailing newlines removed (-)
    bciKeep       // All trailing newlines preserved (+)
  );

  TYAMLDuplicateKeyBehavior = (
    dkOverwrite,  // the value will overwrite the existing one.
    dkError       // the parser will raise an exception.
  );

  // The syntax the parser reads.
  TYAMLInputFormat = (
    yifYAML,      // YAML 1.2 (default)
    yifJSON,      // strict JSON (RFC 8259)
    yifJSON5      // JSON5 (https://spec.json5.org/)
  );

  // YAML Tag Type Classification
  TYAMLTagType = (
    ytStandard,    // Built-in YAML 1.2 tags (!!str, !!int, !!bool, etc.)
    ytGlobal,      // URI-based globally unique tags (tag:yaml.org,2002:type)
    ytLocal,       // Application-specific tags (!local_tag)
    ytCustom,      // User-defined tags with custom handles (!handle!type)
    ytVerbatim,    // Explicit URI tags (!<uri>)
    ytUnresolved   // Non-specific tags awaiting resolution
  );

  IYAMLCollection = interface;
  IYAMLSequence = interface;
  IYAMLMapping = interface;
  IYAMLSet = interface;

  // Tag Information Interface
  IYAMLTagInfo = interface
  ['{A1B2C3D4-E5F6-4789-A012-3456789ABCDE}']
    function GetTagType : TYAMLTagType;
    function GetOriginalText : string;
    function GetResolvedTag : string;
    function GetHandle : string;
    function GetSuffix : string;
    function GetPrefix : string;
    function IsStandardTag : boolean;
    function IsGlobalTag : boolean;
    function IsLocalTag : boolean;
    function IsCustomTag : boolean;
    function IsVerbatimTag : boolean;
    function IsUnresolved : boolean;
    function AreEqual(const other : IYAMLTagInfo) : boolean;
    function ToString : string;

    property TagType : TYAMLTagType read GetTagType;
    property OriginalText : string read GetOriginalText;
    property ResolvedTag : string read GetResolvedTag;
    property Handle : string read GetHandle;
    property Suffix : string read GetSuffix;
    property Prefix : string read GetPrefix;
  end;


  IYAMLValue = interface
  ['{EE9C4727-863F-4B7E-9331-A51E78E51068}']
    function GetComment : string;
    procedure SetComment(const value : string);
    function GetHasComments : boolean;
    function GetComments : TArray<string>;
    procedure SetComments(const value : TArray<string>);
    procedure AddComment(const value : string);
    procedure ClearComments;
    function GetTag : string;
    function GetTagInfo : IYAMLTagInfo;
    function GetParent : IYAMLValue;
    function GetRawValue : string;
    function GetValueType : TYAMLValueType;
    function GetValue(const key : string) : IYAMLValue;
    function GetCount : integer;
     // Type checking methods
    function IsNull : boolean;
    function IsBoolean : boolean;
    function IsInteger : boolean;
    function IsFloat : boolean;
    function IsString : boolean;
    function IsSequence : boolean;
    function IsMapping : boolean;
    function IsSet : boolean;
    function IsScalar : boolean;
    function IsAlias : boolean;
    function IsTimeStamp : boolean;
    function IsNumeric : boolean;

    // Value conversion methods
    function AsBoolean : boolean;
    function AsInteger : Int64;
    function AsFloat : Double;
    function AsCurrency : Currency;
    function AsString : string;
    function AsSequence : IYAMLSequence;
    function AsMapping : IYAMLMapping;
    function AsCollection : IYAMLCollection;

    function AsSet : IYAMLSet;
    function AsLocalDateTime : TDateTime;
    function AsUTCDateTime : TDateTime;

    function ToString : string;

    function TryGetValue(const key : string; out value : IYAMLValue) : boolean;

    // Tag modification methods
    procedure SetTag(const tag : string);
    procedure SetTagInfo(const tagInfo : IYAMLTagInfo);
    procedure ClearTag;

    /// <summary>
    ///  The comment on the same line as the value, after it (and after its comma in JSON5).
    /// </summary>
    property Comment : string read GetComment write SetComment;

    /// <summary>
    ///  Comments on the lines before the value, one line each - for a mapping entry, before
    ///  its key. The YAML parser sets these on collections only; the JSON5 parser on any
    ///  value. Reading gives a copy, so change them with AddComment, ClearComments or by
    ///  setting the property.
    /// </summary>
    property Comments : TArray<string> read GetComments write SetComments;
    property HasComments : boolean read GetHasComments;

    property Count : integer read GetCount;
    property Parent : IYAMLValue read GetParent;
    property ValueType : TYAMLValueType read GetValueType;
    property RawValue : string read GetRawValue;
    property Tag : string read GetTag;
    property TagInfo : IYAMLTagInfo read GetTagInfo;
    property Values[const Key : string] : IYAMLValue read GetValue;
  end;

  IYAMLCollection = interface(IYAMLValue)
  ['{9FAE91CC-6945-4D51-882F-EBA0EEF6F7DB}']

    function GetHasEndComments : boolean;
    function GetEndComments : TArray<string>;
    procedure SetEndComments(const value : TArray<string>);
    procedure AddEndComment(const value : string);
    procedure ClearEndComments;
    procedure Clear;

    /// <summary>
    /// Executes a JSONPath expression on a collection.
    /// </summary>
    /// <param name="AExpression">the JSONPath expression to run</param>
    /// <returns>A yaml sequence that match this JSONPath expression</returns>
    /// <exception cref="EYAMLPathError">if AExpression is invalid</exception>
    function Query(const AExpression : string) : IYAMLSequence;

    /// <summary>
    /// Executes a JSONPath expression on a document and returns the first match.
    /// </summary>
    /// <param name="AExpression">the JSONPath expression to run</param>
    /// <param name="AMatch">is set to the first match found, or a Null value if no match is found</param>
    /// <returns>True if a match is found or False otherwise</returns>
    /// <exception cref="EYAMLPathError">if AExpression is invalid</exception>
    function QuerySingle(const AExpression : string; out AMatch : IYAMLValue) : boolean;

    /// <summary>
    ///  Comments after the last item, before the closing bracket - or inside an empty
    ///  collection. Set by the JSON5 parser. Reading gives a copy, as for Comments.
    /// </summary>
    property EndComments : TArray<string> read GetEndComments write SetEndComments;
    property HasEndComments : boolean read GetHasEndComments;
  end;

  IYAMLMapping = interface(IYAMLCollection)
  ['{536225FF-85BF-41EB-B1D1-6E96665EC6E0}']
    function GetCount : integer;
    function GetKey(Index : integer) : string;
    function GetValue(const Key : string) : IYAMLValue;

    function GetObjectString(const key : string) : string;
    function GetObjectInt(const key: string): Integer;
    function GetObjectLong(const key: string): Int64;
    function GetObjectULong(const key: string): UInt64;
    function GetObjectFloat(const key: string): Double;
    function GetObjectCurrency(const key: string): Currency;
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
    procedure SetObjectCurrency(const key: string; const Value: Currency);
    procedure SetObjectDateTime(const key: string; const Value: TDateTime);
    procedure SetObjectUtcDateTime(const key: string; const Value: TDateTime);
    procedure SetObjectBool(const key: string; const Value: Boolean);
    procedure SetArray(const key: string; const Value: IYAMLSequence);
    procedure SetObject(const key: string; const Value: IYAMLMapping);


    function AddOrSetValue(const key : string; const value : boolean; const tag : string = '') : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddOrSetValue(const key : string; const value : Int32; const tag : string = '') : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Int32; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddOrSetValue(const key : string; const value : UInt32; const tag : string = '') : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : UInt32; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddOrSetValue(const key : string; const value : Int64; const tag : string = '') : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Int64; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddOrSetValue(const key : string; const value : UInt64; const tag : string = '') : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : UInt64; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddOrSetValue(const key : string; const value : single; const tag : string = '') : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : single; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddOrSetValue(const key : string; const value : double; const tag : string = '') : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : double; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddOrSetCurrencyValue(const key : string; const value : Currency; const tag : string = '') : IYAMLValue; overload;
    function AddOrSetCurrencyValue(const key : string; const value : Currency; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;


    function AddOrSetValue(const key : string; const value : string; const tag : string = '') : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : string; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddOrSetValue(const key : string; const value : TDateTime; isUTC : boolean; const tag : string = '') : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : TDateTime; isUTC : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    // Explicitly add a null value. AddOrSetValue(key, '') stores an empty string - a Delphi
    // string cannot be nil, so a null has to be asked for by name.
    function AddOrSetNull(const key : string; const tag : string = '') : IYAMLValue;

    // Add a number from its text, which is written exactly as given in JSON and YAML - for
    // values Int64 and Double cannot hold, e.g. a UInt64 or a SQL DECIMAL(38,10). value must
    // match the JSON (RFC 8259) number grammar, every match of which is also a YAML 1.2 int or
    // float; anything else raises EConvertError. As when parsing, the value is an integer
    // unless the text has a fraction or an exponent.
    function AddOrSetNumber(const key : string; const value : string) : IYAMLValue;

    function AddOrSetSequence(const key : string; const tag : string = '') : IYAMLSequence;overload;
    function AddOrSetSequence(const key : string; const tagInfo : IYAMLTagInfo) : IYAMLSequence;overload;

    function AddOrSetMapping(const key : string; const tag : string = '') : IYAMLMapping;overload;
    function AddOrSetMapping(const key : string; const tagInfo : IYAMLTagInfo) : IYAMLMapping;overload;

    function AddOrSetSet(const key : string; const tag : string = '') : IYAMLSet;overload;
    function AddOrSetSet(const key : string; const tagInfo : IYAMLTagInfo) : IYAMLSet;overload;

    function ContainsKey(const key : string) : boolean;
    function Contains(const key : string) : boolean;//for JSONDataObjects api compat

    property Count : integer read GetCount;
    property Items[const key : string] : IYAMLValue read GetValue; default;
    property Keys[index : integer] : string read GetKey;


    //JSONDataObjects style API
    property S[const key: string]: string read GetObjectString write SetObjectString;        // returns '' if property doesn't exist, auto type-cast except for array/object
    property I[const key: string]: Integer read GetObjectInt write SetObjectInt;             // returns 0 if property doesn't exist, auto type-cast except for array/object
    property L[const key: string]: Int64 read GetObjectLong write SetObjectLong;             // returns 0 if property doesn't exist, auto type-cast except for array/object
    property U[const key: string]: UInt64 read GetObjectULong write SetObjectULong;          // returns 0 if property doesn't exist, auto type-cast except for array/object
    property F[const key: string]: Double read GetObjectFloat write SetObjectFloat;          // returns 0 if property doesn't exist, auto type-cast except for array/object
    property C[const key: string]: Currency read GetObjectCurrency write SetObjectCurrency;          // returns 0 if property doesn't exist, auto type-cast except for array/object
    property D[const key: string]: TDateTime read GetObjectDateTime write SetObjectDateTime; // returns 0 if property doesn't exist, auto type-cast except for array/object
    property DUtc[const key: string]: TDateTime read GetObjectUtcDateTime write SetObjectUtcDateTime; // returns 0 if property doesn't exist, auto type-cast except for array/object
    property B[const key: string]: Boolean read GetObjectBool write SetObjectBool;           // returns false if property doesn't exist, auto type-cast with "<>'true'" and "<>0" except for array/object
    // Used to auto create arrays
    property A[const key: string]: IYAMLSequence read GetArray write SetArray;
    // Used to auto create objects and as default property where no Implicit operator matches
    property O[const key: string]: IYAMLMapping read GetObj write SetObject;


  end;



  IYAMLSequence = interface(IYAMLCollection)
  ['{CDBF0300-5E70-45A7-97B7-BA268F1C57E8}']
    function GetCount : integer;
    function GetItem(Index : integer) : IYAMLValue;

    // JSONDataObjects api
    function GetString(index : integer) : string;
    function GetInt(index: Integer): Integer;
    function GetLong(index: Integer): Int64;
    function GetULong(index: Integer): UInt64;
    function GetFloat(index: Integer): Double;
    function GetCurrency(index: Integer): Currency;
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
    procedure SetCurrency(index: Integer; const value: Currency);
    procedure SetDateTime(index: Integer; const value: TDateTime);
    procedure SetUtcDateTime(index: Integer; const value: TDateTime);
    procedure SetBool(index: Integer; const value: Boolean);
    procedure SetArray(index: Integer; const value: IYAMLSequence);
    procedure SetObject(index: Integer; const value: IYAMLMapping);
    // JSONDataObjects api


    procedure AddValue(const value : IYAMLValue);overload;

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

    function AddValue(const value : single; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : single; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddValue(const value : double; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : double; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddCurrencyValue(const value : Currency; const tag : string = '') : IYAMLValue; overload;
    function AddCurrencyValue(const value : Currency; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddValue(const value : string; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : string; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddValue(const value : TDateTime; isUTC : boolean; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : TDateTime; isUTC : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    // Explicitly add a null value. AddValue('') adds an empty string - a Delphi string cannot
    // be nil, so a null has to be asked for by name.
    function AddNull(const tag : string = '') : IYAMLValue;

    // Add a number from its text - see IYAMLMapping.AddOrSetNumber.
    function AddNumber(const value : string) : IYAMLValue;

    function AddMapping(const tag : string = '') : IYAMLMapping;overload;
    function AddMapping(const tagInfo : IYAMLTagInfo) : IYAMLMapping;overload;

    function AddSequence(const tag : string = '') : IYAMLSequence;overload;
    function AddSequence(const tagInfo : IYAMLTagInfo) : IYAMLSequence;overload;

    function AddSet(const tag : string = '') : IYAMLSet;overload;
    function AddSet(const tagInfo : IYAMLTagInfo) : IYAMLSet;overload;

    property Count : integer read GetCount;
    property Items[Index : integer] : IYAMLValue read GetItem;default;

    property S[index : integer]: string read GetString write SetString;      // returns '' if property doesn't exist, auto type-cast except for array/object
    property I[Index: Integer]: Integer read GetInt write SetInt;
    property L[Index: Integer]: Int64 read GetLong write SetLong;
    property U[Index: Integer]: UInt64 read GetULong write SetULong;
    property F[Index: Integer]: Double read GetFloat write SetFloat;
    property C[Index: Integer]: Currency read GetCurrency write SetCurrency;
    property D[Index: Integer]: TDateTime read GetDateTime write SetDateTime;
    property DUtc[Index: Integer]: TDateTime read GetUtcDateTime write SetUtcDateTime;
    property B[Index: Integer]: Boolean read GetBool write SetBool;
    property A[Index: Integer]: IYAMLSequence read GetArray write SetArray;
    property O[Index: Integer]: IYAMLMapping read GetObj write SetObject;

  end;

  //set is basically a sequence with unique values
  IYAMLSet = interface(IYAMLSequence)
  ['{1FEADB99-E4A3-449F-8F15-9FCEE61DDFA2}']
  end;


  /// <summary>
  ///  Options object that controls how the
  ///  YAML is written
  /// </summary>
  IYAMLEmitOptions = interface
  ['{22849B1C-084B-4D9D-A0B8-205AD03C4F37}']
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
    function GetEscapeNonASCII : boolean;
    procedure SetEscapeNonASCII(const value : boolean);
    function GetBlockScalarStyle : TYAMLBlockScalarStyle;
    procedure SetBlockScalarStyle(value : TYAMLBlockScalarStyle);
    function GetBlockChompingIndicator : TYAMLBlockChompingIndicator;
    procedure SetBlockChompingIndicator(value : TYAMLBlockChompingIndicator);
    function GetJSON5UnquotedKeys : boolean;
    procedure SetJSON5UnquotedKeys(value : boolean);
    function GetJSON5SingleQuotes : boolean;
    procedure SetJSON5SingleQuotes(value : boolean);
    function GetJSON5TrailingCommas : boolean;
    procedure SetJSON5TrailingCommas(value : boolean);

    function Clone : IYAMLEmitOptions;

    //YAML and JSON

    /// <summary>  Setting the Encoding to a non standard encoding will take ownership of the encoding </summary>
    property Encoding : TEncoding read GetEncoding write SetEncoding;
    property Format : TYAMLOutputFormat read GetFormat write SetFormat;
    property IndentSize : UInt32 read GetIndentSize write SetIndentSize;

    //not currently implemented
    property MaxLineLength : UInt32 read GetMaxLineLength write SetMaxLineLength;
    property WriteByteOrderMark : boolean read GetWriteBOM write SetWriteBOM;

    // YAML ONLY
    property QuoteStrings : boolean read GetQuoteStrings write SetQuoteStrings;
    property EmitDocumentMarkers : boolean read GetEmitDocumentMarkers write SetEmitDocumentMarkers;
    property EmitYAMLDirective : boolean read GetEmitYAMLDirective write SetEmitYAMLDirective;
    property EmitTagDirectives : boolean read GetEmitTagDirectives write SetEmitTagDirectives;

    property EmitTags : boolean read GetEmitTags write SetEmitTags;
    property EmitExplicitNull : boolean read GetEmitExplicitNull write SetEmitExplicitNull;
    property BlockScalarStyle : TYAMLBlockScalarStyle read GetBlockScalarStyle write SetBlockScalarStyle;
    property BlockChompingIndicator : TYAMLBlockChompingIndicator read GetBlockChompingIndicator write SetBlockChompingIndicator;

    //JSON only
    property PrettyPrint : boolean read GetPrettyPrint write SetPrettyPrint;

    /// <summary>
    ///  Escapes every character past #126 - DEL and everything outside ASCII - as \uXXXX, a
    ///  character outside the BMP as its two surrogate escapes (RFC 8259 section 7), so the
    ///  output is printable ASCII. Off by default.
    /// </summary>
    property EscapeNonASCII : boolean read GetEscapeNonASCII write SetEscapeNonASCII;

    //JSON5 only (PrettyPrint, IndentSize and EscapeNonASCII apply as for JSON)

    /// <summary>
    ///  Writes keys that are ES5 identifier names (name, $id, _x1) without quotes. On by
    ///  default.
    /// </summary>
    property JSON5UnquotedKeys : boolean read GetJSON5UnquotedKeys write SetJSON5UnquotedKeys;

    /// <summary> Quotes strings and keys with ' rather than ". Off by default. </summary>
    property JSON5SingleQuotes : boolean read GetJSON5SingleQuotes write SetJSON5SingleQuotes;

    /// <summary>
    ///  Writes a comma after the last item of each non-empty object and array when
    ///  PrettyPrint is on. Off by default.
    /// </summary>
    property JSON5TrailingCommas : boolean read GetJSON5TrailingCommas write SetJSON5TrailingCommas;

  end;

  IYAMLVersionDirective = interface
  ['{04670ED9-67B1-44D2-8A05-BDC10E5DB8E6}']
    function GetMajor : integer;
    function GetMinor : integer;
    function ToString : string;
    function IsCompatible(const other : IYAMLVersionDirective) : boolean;
    property Major    : integer read GetMajor;
    property Minor    : integer read GetMinor;
  end;

  IYAMLTagDirective = interface
  ['{2EF8BB4C-6772-41EA-B1F6-817F57F24657}']
    function GetHandle : string;
    function GetPrefix : string;
    function ToString : string;

    property Prefix : string read GetPrefix;
    property Handle : string read GetHandle;
  end;


  IYAMLDocument = interface
  ['{8DEC7D6E-20D7-4312-B527-3C6921D640D8}']

    function GetVersion : IYAMLVersionDirective;
    function GetOptions : IYAMLEmitOptions;
    function GetRoot : IYAMLValue;
    function GetIsMapping : boolean;
    function GetIsSequence : boolean;
    function GetIsSet : boolean;
    function GetIsScalar : boolean;
    function GetIsNull : boolean;
    function GetTagDirectives : TList<IYAMLTagDirective>;
    function GetHasEndComments : boolean;
    function GetEndComments : TArray<string>;
    procedure SetEndComments(const value : TArray<string>);
    procedure AddEndComment(const value : string);
    procedure ClearEndComments;

    /// <summary>
    ///  Writes to a file using the provided encoding, or UTF8 if not provided
    /// </summary>
    procedure WriteToFile(const filename : string);
    function ToYAMLString : string;

    /// <summary>  If the root is a mapping, get typed access to it </summary>
    function AsMapping : IYAMLMapping;

    /// <summary>  If the root is a sequence, get typed access to it </summary>
    function AsSequence : IYAMLSequence;

    function AsSet : IYAMLSet;

    /// <summary>
    /// Executes a JSONPath expression on a collection.
    /// </summary>
    /// <param name="AExpression">the JSONPath expression to run</param>
    /// <returns>A yaml sequence that match this JSONPath expression</returns>
    /// <exception cref="EYAMLPathError">if AExpression is invalid</exception>
    function Query(const AExpression : string) : IYAMLSequence;


    /// <summary>
    /// Executes a JSONPath expression on a document and returns the first match.
    /// </summary>
    /// <param name="AExpression">the JSONPath expression to run</param>
    /// <param name="AMatch">is set to the first match found, or a Null value if no match is found</param>
    /// <returns>True if a match is found or False otherwise</returns>
    /// <exception cref="EYAMLPathError">if AExpression is invalid</exception>
    function QuerySingle(const AExpression : string; out AMatch : IYAMLValue) : boolean;


    property IsMapping : boolean read GetIsMapping;
    property IsSequence : boolean read GetIsSequence;
    property IsSet : boolean read GetIsSet;
    property IsScalar : boolean read GetIsScalar;
    property IsNull : boolean read GetIsNull;
    property Options : IYAMLEmitOptions read GetOptions;
    property Root : IYAMLValue read GetRoot;

    property TagDirectives : TList<IYAMLTagDirective> read GetTagDirectives;

    property Version : IYAMLVersionDirective read GetVersion;

    /// <summary>
    ///  Comments after the root value (other than its same-line Comment), one line each.
    ///  Reading gives a copy, as for IYAMLValue.Comments.
    /// </summary>
    property EndComments : TArray<string> read GetEndComments write SetEndComments;
    property HasEndComments : boolean read GetHasEndComments;
  end;

  IYAMLParserOptions = interface
  ['{193CE904-9AE9-4B02-9F76-58C739C1366D}']
    function GetDuplicateKeyBehavior : TYAMLDuplicateKeyBehavior;
    procedure SetDuplicateKeyBehavior(value : TYAMLDuplicateKeyBehavior);
    function GetJSONMode : boolean;
    procedure SetJSONMode(value : boolean);
    function GetInputFormat : TYAMLInputFormat;
    procedure SetInputFormat(value : TYAMLInputFormat);
    function GetYAML11Compatibility : boolean;
    procedure SetYAML11Compatibility(value : boolean);

    function Clone : IYAMLParserOptions;

    property DuplicateKeyBehavior : TYAMLDuplicateKeyBehavior read GetDuplicateKeyBehavior write SetDuplicateKeyBehavior;

    /// <summary>
    ///  The syntax to read - YAML (the default), strict JSON or JSON5. LoadFromFile and
    ///  LoadAllFromFile read a .json file as JSON and a .json5 file as JSON5 when this is
    ///  YAML; any other setting is kept, so JSON5 options can read a lenient .json file.
    /// </summary>
    property InputFormat : TYAMLInputFormat read GetInputFormat write SetInputFormat;

    /// <summary>
    ///  Shortcut for InputFormat = JSON. Setting it true selects JSON, setting it false
    ///  selects YAML.
    /// </summary>
    property JSONMode : boolean read GetJSONMode write SetJSONMode;

    /// <summary>
    ///  True (the default) reads YAML as YAML 1.2 plus the YAML 1.1 forms VSoft.YAML has always
    ///  read: yes/no/on/off booleans, 0b binary integers, '_' digit separators and ISO 8601
    ///  timestamps as plain scalars, '&lt;&lt;' merge keys, and a block mapping of '? ' keys
    ///  without values as a set. False reads strict YAML 1.2: plain scalars resolve by the core
    ///  schema alone (so those words, numbers and dates are strings), '&lt;&lt;' is an ordinary
    ///  key and '? ' keys make a mapping with null values. The syntax is YAML 1.2's either way.
    /// </summary>
    property YAML11Compatibility : boolean read GetYAML11Compatibility write SetYAML11Compatibility;
  end;


  /// <summary>
  /// Start HERE!
  /// </summary>
  TYAML = record
    /// <summary> Creates a custom ParserOptions object</summary>
    class function CreateParserOptions : IYAMLParserOptions;static;

    /// <summary> Returns the default parser options. </summary>
    class function DefaultParserOptions : IYAMLParserOptions;static;

    /// <summary> Returns the Default Writer options </summary>
    class function DefaultWriterOptions : IYAMLEmitOptions;static;

    /// <summary> Create a custom Writer Options object </summary>
    class function CreateWriterOptions : IYAMLEmitOptions;static;

    /// <summary>  Creates a new document with a Mapping Root node. </summary>
    class function CreateMapping : IYAMLDocument;static;

    /// <summary>  Creates a new document with a Sequence Root node. </summary>
    class function CreateSequence : IYAMLDocument;static;

    /// <summary>  Creates a new document with a Set Root node. </summary>
    class function CreateSet : IYAMLDocument;static;


    /// <summary>
    /// Returns a document if parse successful
    /// If the string contains more than one document, only the first is returned.
    /// Raises exceptions on errors.
    /// </summary>
    class function LoadFromString(const value : string; const parserOptions : IYAMLParserOptions = nil) : IYAMLDocument;static;

    /// <summary>
    ///  Returns an array of documents.
    ///  Raises exceptions on errors.
    /// </summary>
    class function LoadAllFromString(const value : string; const parserOptions : IYAMLParserOptions = nil) : TArray<IYAMLDocument>;static;

    /// <summary>
    /// Returns a document if parse successful
    /// If the file contains more than one document, only the first is returned.
    /// Raises exceptions on errors.
    /// </summary>
    class function LoadFromFile(const fileName : string; const parserOptions : IYAMLParserOptions = nil) : IYAMLDocument;static;

    /// <summary>
    ///  Returns an array of documents.
    ///  Raises exceptions on errors.
    ///  Documents must have document start markers
    /// </summary>
    class function LoadAllFromFile(const fileName : string; const parserOptions : IYAMLParserOptions = nil) : TArray<IYAMLDocument>;static;

    /// <summary>
    /// Returns a document if parse successful
    /// If the stream contains more than one document, only the first is returned.
    /// Raises exceptions on errors.
    /// </summary>
    class function LoadFromStream(const stream : TStream; const parserOptions : IYAMLParserOptions = nil) : IYAMLDocument; static;

    /// <summary>
    ///  Returns an array of documents.
    ///  Raises exceptions on errors.
    ///  Documents must have document start markers
    /// </summary>
    class function LoadAllFromStream(const stream : TStream; const parserOptions : IYAMLParserOptions = nil) : TArray<IYAMLDocument>; static;


    /// <summary>
    ///  Returns the document as a string.
    ///  Uses the documents options to control formatting etc.
    /// </summary>
    class function WriteToString(const doc : IYAMLDocument) : string;overload;static;
    class function WriteToString(const docs : TArray<IYAMLDocument>) : string;overload;static;
    class function WriteToString(const value : IYAMLValue; const options : IYAMLEmitOptions = nil) : string;overload;static;



    class function WriteToJSONString(const doc : IYAMLDocument) : string;overload;static;
    class function WriteToJSONString(const docs : TArray<IYAMLDocument>) : string;overload;static;
    class function WriteToJSONString(const value : IYAMLValue; const options : IYAMLEmitOptions = nil) : string;overload;static;

    class procedure WriteToFile(const doc : IYAMLDocument;const fileName : string);overload;static;
    class procedure WriteToFile(const docs : TArray<IYAMLDocument>;const fileName : string);overload;static;
    class procedure WriteToFile(const value : IYAMLValue; const fileName : string; const options : IYAMLEmitOptions = nil);overload;static;

    class procedure WriteToJSONFile(const doc : IYAMLDocument;const fileName : string);overload;static;
    class procedure WriteToJSONFile(const docs : TArray<IYAMLDocument>;const fileName : string);overload;static;
    class procedure WriteToJSONFile(const value : IYAMLValue; const fileName : string; const options : IYAMLEmitOptions = nil);overload;static;


    class procedure WriteToStream(const doc : IYAMLDocument;const stream : TStream);overload;static;
    class procedure WriteToStream(const docs : TArray<IYAMLDocument>; const stream : TStream);overload;static;
    class procedure WriteToStream(const value : IYAMLValue; const stream : TStream; const options : IYAMLEmitOptions = nil);overload;static;

    class procedure WriteToJSONStream(const doc : IYAMLDocument;const stream : TStream);overload;static;
    class procedure WriteToJSONStream(const docs : TArray<IYAMLDocument>; const stream : TStream);overload;static;
    class procedure WriteToJSONStream(const value : IYAMLValue; const stream : TStream; const options : IYAMLEmitOptions = nil);overload;static;

    /// <summary>
    ///  Writes JSON5 (https://spec.json5.org/). Number text is kept as written (0x1F,
    ///  Infinity, .5) and non-finite floats are written as NaN, Infinity and -Infinity.
    ///  Comments are written as // lines, or /* */ after a value in compact output. The
    ///  JSON5* emit options choose unquoted keys, single quotes and trailing commas; several
    ///  documents are written as an array.
    /// </summary>
    class function WriteToJSON5String(const doc : IYAMLDocument) : string;overload;static;
    class function WriteToJSON5String(const docs : TArray<IYAMLDocument>) : string;overload;static;
    class function WriteToJSON5String(const value : IYAMLValue; const options : IYAMLEmitOptions = nil) : string;overload;static;

    class procedure WriteToJSON5File(const doc : IYAMLDocument; const fileName : string);overload;static;
    class procedure WriteToJSON5File(const docs : TArray<IYAMLDocument>; const fileName : string);overload;static;
    class procedure WriteToJSON5File(const value : IYAMLValue; const fileName : string; const options : IYAMLEmitOptions = nil);overload;static;

    class procedure WriteToJSON5Stream(const doc : IYAMLDocument; const stream : TStream);overload;static;
    class procedure WriteToJSON5Stream(const docs : TArray<IYAMLDocument>; const stream : TStream);overload;static;
    class procedure WriteToJSON5Stream(const value : IYAMLValue; const stream : TStream; const options : IYAMLEmitOptions = nil);overload;static;
  end;

implementation

uses
  System.Math,
  VSoft.YAML.Utils,
  VSoft.YAML.Parser.JSON, VSoft.YAML.Composer, VSoft.YAML.Writer, VSoft.YAML.Writer.JSON, VSoft.YAML.Classes, VSoft.YAML.IO, VSoft.YAML.TagInfo;


var
  _defaultParserOptions : IYAMLParserOptions;
  _defaultWriterOptions : IYAMLEmitOptions;


// When the options say YAML, a .json file is parsed as JSON and a .json5 file as JSON5;
// an explicit JSON or JSON5 setting is kept (JSON5 reads any .json file too). The options
// passed in (or the shared defaults when none are) are never modified - when the format
// has to change, a copy is used so later loads are not affected.
function GetFileParserOptions(const fileName : string; const parserOptions : IYAMLParserOptions) : IYAMLParserOptions;
var
  ext : string;
begin
  if parserOptions = nil then
    result := _defaultParserOptions
  else
    result := parserOptions;

  if result.InputFormat <> TYAMLInputFormat.yifYAML then
    exit;
  ext := ExtractFileExt(fileName);
  if SameText('.json', ext) then
  begin
    result := result.Clone;
    result.InputFormat := TYAMLInputFormat.yifJSON;
  end
  else if SameText('.json5', ext) then
  begin
    result := result.Clone;
    result.InputFormat := TYAMLInputFormat.yifJSON5;
  end;
end;

// True when the options call for the JSON parser (strict JSON or JSON5) rather than the
// YAML parser. json5 says which dialect.
function UseJSONParser(const options : IYAMLParserOptions; out json5 : boolean) : boolean;
begin
  json5 := options.InputFormat = TYAMLInputFormat.yifJSON5;
  result := json5 or (options.InputFormat = TYAMLInputFormat.yifJSON);
end;

function ParseJSON(const reader : IInputReader; const options : IYAMLParserOptions; json5 : boolean) : IYAMLDocument;
var
  parser : TJSONParserImpl;
begin
  parser := TJSONParserImpl.Create(reader, options, json5);
  try
    result := parser.Parse;
  finally
    parser.Free;
  end;
end;

function ParseYAML(const reader : IInputReader; const options : IYAMLParserOptions) : IYAMLDocument;
var
  composer : TYAMLComposer;
begin
  composer := TYAMLComposer.Create(reader, options);
  try
    result := composer.Parse;
  finally
    composer.Free;
  end;
end;

function ParseAllYAML(const reader : IInputReader; const options : IYAMLParserOptions) : TArray<IYAMLDocument>;
var
  composer : TYAMLComposer;
begin
  composer := TYAMLComposer.Create(reader, options);
  try
    result := composer.ParseAll;
  finally
    composer.Free;
  end;
end;


{ TYAML }

class function TYAML.CreateMapping : IYAMLDocument;
var
  root : IYAMLMapping;
begin
  root := TYAMLMapping.Create(nil, '');
  result := TYAMLDocument.Create(root, nil,nil);
end;

class function TYAML.CreateParserOptions : IYAMLParserOptions;
begin
  result := TYAMLParserOptions.Create;
end;

class function TYAML.CreateSequence : IYAMLDocument;
var
  root : IYAMLSequence;
begin
  root := TYAMLSequence.Create(nil, '');
  result := TYAMLDocument.Create(root, nil, nil);
end;

class function TYAML.CreateSet: IYAMLDocument;
var
  root : IYAMLSequence;
begin
  root := TYAMLSet.Create(nil, '');
  result := TYAMLDocument.Create(root, nil, nil);
end;

class function TYAML.CreateWriterOptions: IYAMLEmitOptions;
begin
  result := TYAMLEmitOptions.Create;
end;

class function TYAML.DefaultParserOptions : IYAMLParserOptions;
begin
  result := _defaultParserOptions;
end;

class function TYAML.DefaultWriterOptions: IYAMLEmitOptions;
begin
  result := _defaultWriterOptions;
end;

class function TYAML.LoadAllFromFile(const fileName: string; const parserOptions: IYAMLParserOptions): TArray<IYAMLDocument>;
var
  stream : TStream;
  lOptions : IYAMLParserOptions;
begin
  lOptions := GetFileParserOptions(fileName, parserOptions);
  Stream := TFileStream.Create(FileName, fmOpenRead + fmShareDenyWrite);
  try
    result := LoadAllFromStream(Stream, lOptions);
  finally
    Stream.Free;
  end;

end;

class function TYAML.LoadAllFromStream(const stream: TStream; const parserOptions: IYAMLParserOptions): TArray<IYAMLDocument>;
var
  lOptions : IYAMLParserOptions;
  reader : IInputReader;
  json5 : boolean;
begin
  if parserOptions = nil then
    lOptions := _defaultParserOptions
  else
    lOptions := parserOptions;

  reader := TInputReaderFactory.CreateFromStream(stream);

  // a JSON text holds a single document
  if UseJSONParser(lOptions, json5) then
  begin
    SetLength(result, 1);
    result[0] := ParseJSON(reader, lOptions, json5);
    exit;
  end;
  result := ParseAllYAML(reader, lOptions);
end;

class function TYAML.LoadAllFromString(const value: string; const parserOptions: IYAMLParserOptions): TArray<IYAMLDocument>;
var
  lOptions : IYAMLParserOptions;
  reader : IInputReader;
  json5 : boolean;
begin
  if parserOptions = nil then
    lOptions := _defaultParserOptions
  else
    lOptions := parserOptions;

  reader := TInputReaderFactory.CreateFromString(value);

  // a JSON text holds a single document
  if UseJSONParser(lOptions, json5) then
  begin
    SetLength(result, 1);
    result[0] := ParseJSON(reader, lOptions, json5);
    exit;
  end;
  result := ParseAllYAML(reader, lOptions);
end;

class function TYAML.LoadFromFile(const fileName : string; const parserOptions : IYAMLParserOptions) : IYAMLDocument;
var
  stream : TStream;
  lOptions : IYAMLParserOptions;
begin
  lOptions := GetFileParserOptions(fileName, parserOptions);
  Stream := TFileStream.Create(FileName, fmOpenRead + fmShareDenyWrite);
  try
    result := LoadFromStream(Stream, lOptions);
  finally
    Stream.Free;
  end;
end;

class function TYAML.LoadFromStream(const stream : TStream; const parserOptions : IYAMLParserOptions = nil) : IYAMLDocument;
var
  lOptions : IYAMLParserOptions;
  reader : IInputReader;
  json5 : boolean;
begin
  if parserOptions = nil then
    lOptions := _defaultParserOptions
  else
    lOptions := parserOptions;

  reader := TInputReaderFactory.CreateFromStream(stream);

  if UseJSONParser(lOptions, json5) then
    result := ParseJSON(reader, lOptions, json5)
  else
    result := ParseYAML(reader, lOptions);
end;

class function TYAML.LoadFromString(const value : string; const parserOptions : IYAMLParserOptions) : IYAMLDocument;
var
  lOptions : IYAMLParserOptions;
  reader : IInputReader;
  json5 : boolean;
begin
  if parserOptions = nil then
    lOptions := _defaultParserOptions
  else
    lOptions := parserOptions;

  reader := TInputReaderFactory.CreateFromString(value);

  if UseJSONParser(lOptions, json5) then
    result := ParseJSON(reader, lOptions, json5)
  else
    result := ParseYAML(reader, lOptions);
end;

class procedure TYAML.WriteToFile(const doc : IYAMLDocument;const fileName : string);
var
  writer : TYAMLWriterImpl;
begin
  writer := TYAMLWriterImpl.Create(doc.Options);
  try
    writer.WriteToFile(doc, fileName);
  finally
    writer.Free;
  end;
end;

class procedure TYAML.WriteToFile(const docs : TArray<IYAMLDocument>;const fileName : string);
var
  fileStream : TFileStream;
begin
  if Length(docs) = 0 then
    Exit;
  fileStream := TFileStream.Create(fileName, fmCreate);
  try
    WriteToStream(docs, fileStream);
  finally
    fileStream.Free;
  end;
end;

class function TYAML.WriteToString(const doc : IYAMLDocument) : string;
var
  writer : TYAMLWriterImpl;
begin
  writer := TYAMLWriterImpl.Create(doc.Options);
  try
    result := writer.WriteToString(doc);
  finally
    writer.Free;
  end;
end;

class function TYAML.WriteToJSONString(const docs: TArray<IYAMLDocument>): string;
var
  i : integer;
  writerOptions : IYAMLEmitOptions;
  writer : TJSONWriterImpl;
  sb : TStringBuilder;
begin
  result := '';
  if Length(docs) = 0 then
    Exit;

  // Use the first document's options as default
  writerOptions := docs[0].Options;
  writer := TJSONWriterImpl.Create(writerOptions);
  sb := TStringBuilder.Create(Length(docs) * 512);
  try
    sb.Append('[');
    for i := 0 to Length(docs) - 1 do
    begin
      if i > 0 then
        sb.Append(',');
      sb.Append(writer.WriteToString(docs[i]));
    end;
    sb.Append(']');
    result := sb.ToString;
  finally
    sb.Free;
    writer.Free;
  end;
end;

class function TYAML.WriteToString(const docs : TArray<IYAMLDocument>) : string;
var
  i : integer;
  writerOptions : IYAMLEmitOptions;
  writer : TYAMLWriterImpl;
  sb : TStringBuilder;
begin

  result := '';
  if Length(docs) = 0 then
    Exit;

  // Use the first document's options as default
  writerOptions := docs[0].Options;
  //if more than 1 doc we must write markers
  if Length(docs) > 1 then
    writerOptions.EmitDocumentMarkers := true;
  writer := TYAMLWriterImpl.Create(writerOptions);
  sb := TStringBuilder.Create(Length(docs) * 1024);
  try
    for i := 0 to Length(docs) - 1 do
    begin
      sb.Append(Writer.WriteToString(docs[i]));
      if i < Length(docs) - 1 then
        sb.Append(sLineBreak);
    end;
    result := sb.ToString;
  finally
    sb.Free;
    writer.Free;
  end;
end;

class procedure TYAML.WriteToFile(const value : IYAMLValue; const fileName : string; const options : IYAMLEmitOptions);
var
  Writer : TYAMLWriterImpl;
  opt : IYAMLEmitOptions;
begin
  if options <> nil then
    opt := options
  else
    opt := _defaultWriterOptions;
  Writer := TYAMLWriterImpl.Create(opt);
  try
    Writer.WriteToFile(value, fileName);
  finally
    Writer.Free;
  end;
end;

class procedure TYAML.WriteToJSONFile(const doc: IYAMLDocument; const fileName: string);
var
  writer : TJSONWriterImpl;
begin
  writer := TJSONWriterImpl.Create(doc.Options);
  try
    writer.WriteToFile(doc, fileName);
  finally
    writer.Free;
  end;
end;

class procedure TYAML.WriteToJSONFile(const docs: TArray<IYAMLDocument>; const fileName: string);
var
  fileStream : TFileStream;
begin
  if Length(docs) = 0 then
    Exit;
  fileStream := TFileStream.Create(fileName, fmCreate);
  try
    WriteToJSONStream(docs, fileStream);
  finally
    fileStream.Free;
  end;
end;

class procedure TYAML.WriteToJSONFile(const value: IYAMLValue; const fileName: string; const options: IYAMLEmitOptions);
var
  writer : TJSONWriterImpl;
  opt : IYAMLEmitOptions;
begin
  if options <> nil then
    opt := options
  else
    opt := _defaultWriterOptions;
  writer := TJSONWriterImpl.Create(opt);
  try
    writer.WriteToFile(value, fileName);
  finally
    writer.Free;
  end;
end;

class procedure TYAML.WriteToJSONStream(const docs: TArray<IYAMLDocument>; const stream: TStream);
var
  writerOptions : IYAMLEmitOptions;
  len : integer;
  i: Integer;
  writer : TJSONWriterImpl;
  jsonStr : string;
begin
  len := Length(docs);
  if len = 0 then
    Exit;

  // Use the first document's options to determine encoding
  writerOptions := docs[0].Options;
  writer := TJSONWriterImpl.Create(writerOptions);
  try
    jsonStr := '[';
    for i := 0 to len - 1 do
    begin
      if i > 0 then
        jsonStr := jsonStr + ',';
      jsonStr := jsonStr + writer.WriteToString(docs[i]);
    end;
    jsonStr := jsonStr + ']';
    
    // Write the complete JSON array to stream
    stream.WriteBuffer(writerOptions.Encoding.GetBytes(jsonStr)[0], Length(writerOptions.Encoding.GetBytes(jsonStr)));
  finally
    writer.Free;
  end;
end;

class procedure TYAML.WriteToJSONStream(const doc: IYAMLDocument; const stream: TStream);
var
  writer : TJSONWriterImpl;
begin
  writer := TJSONWriterImpl.Create(doc.Options);
  try
    writer.WriteToStream(doc, stream);
  finally
    writer.Free;
  end;
end;

class procedure TYAML.WriteToJSONStream(const value: IYAMLValue; const stream: TStream; const options: IYAMLEmitOptions);
var
  writer : TJSONWriterImpl;
  opt : IYAMLEmitOptions;
begin
  if options <> nil then
    opt := options
  else
    opt := _defaultWriterOptions;
  writer := TJSONWriterImpl.Create(opt);
  try
    writer.WriteToStream(value, stream);
  finally
    writer.Free;
  end;
end;

class function TYAML.WriteToJSONString(const doc: IYAMLDocument): string;
var
  writer : TJSONWriterImpl;
begin
  writer := TJSONWriterImpl.Create(doc.Options);
  try
    result := writer.WriteToString(doc);
  finally
    writer.Free;
  end;
end;

class function TYAML.WriteToJSONString(const value: IYAMLValue; const options: IYAMLEmitOptions): string;
var
  writer : TJSONWriterImpl;
  opt : IYAMLEmitOptions;
begin
  if options <> nil then
    opt := options
  else
    opt := _defaultWriterOptions;

  writer := TJSONWriterImpl.Create(opt);
  try
    result := writer.WriteToString(value);
  finally
    writer.Free;
  end;
end;

class function TYAML.WriteToJSON5String(const doc : IYAMLDocument) : string;
var
  writer : TJSONWriterImpl;
begin
  writer := TJSONWriterImpl.Create(doc.Options, true);
  try
    result := writer.WriteToString(doc);
  finally
    writer.Free;
  end;
end;

class function TYAML.WriteToJSON5String(const docs : TArray<IYAMLDocument>) : string;
var
  i : integer;
  writer : TJSONWriterImpl;
  sb : TStringBuilder;
begin
  result := '';
  if Length(docs) = 0 then
    Exit;

  // Use the first document's options for all of them
  writer := TJSONWriterImpl.Create(docs[0].Options, true);
  sb := TStringBuilder.Create(Length(docs) * 512);
  try
    sb.Append('[');
    for i := 0 to Length(docs) - 1 do
    begin
      if i > 0 then
        sb.Append(',');
      // a // comment ending the document must not swallow the "," or "]" that follows
      sb.Append(writer.WriteToString(docs[i]));
      if docs[i].HasEndComments or (docs[i].Root.Comment <> '') then
        sb.Append(sLineBreak);
    end;
    sb.Append(']');
    result := sb.ToString;
  finally
    sb.Free;
    writer.Free;
  end;
end;

class function TYAML.WriteToJSON5String(const value : IYAMLValue; const options : IYAMLEmitOptions) : string;
var
  writer : TJSONWriterImpl;
  opt : IYAMLEmitOptions;
begin
  if options <> nil then
    opt := options
  else
    opt := _defaultWriterOptions;
  writer := TJSONWriterImpl.Create(opt, true);
  try
    result := writer.WriteToString(value);
  finally
    writer.Free;
  end;
end;

class procedure TYAML.WriteToJSON5File(const doc : IYAMLDocument; const fileName : string);
var
  writer : TJSONWriterImpl;
begin
  writer := TJSONWriterImpl.Create(doc.Options, true);
  try
    writer.WriteToFile(doc, fileName);
  finally
    writer.Free;
  end;
end;

class procedure TYAML.WriteToJSON5File(const docs : TArray<IYAMLDocument>; const fileName : string);
var
  fileStream : TFileStream;
begin
  if Length(docs) = 0 then
    Exit;
  fileStream := TFileStream.Create(fileName, fmCreate);
  try
    WriteToJSON5Stream(docs, fileStream);
  finally
    fileStream.Free;
  end;
end;

class procedure TYAML.WriteToJSON5File(const value : IYAMLValue; const fileName : string; const options : IYAMLEmitOptions);
var
  writer : TJSONWriterImpl;
  opt : IYAMLEmitOptions;
begin
  if options <> nil then
    opt := options
  else
    opt := _defaultWriterOptions;
  writer := TJSONWriterImpl.Create(opt, true);
  try
    writer.WriteToFile(value, fileName);
  finally
    writer.Free;
  end;
end;

class procedure TYAML.WriteToJSON5Stream(const doc : IYAMLDocument; const stream : TStream);
var
  writer : TJSONWriterImpl;
begin
  writer := TJSONWriterImpl.Create(doc.Options, true);
  try
    writer.WriteToStream(doc, stream);
  finally
    writer.Free;
  end;
end;

class procedure TYAML.WriteToJSON5Stream(const docs : TArray<IYAMLDocument>; const stream : TStream);
var
  text : string;
  bytes : TBytes;
  encoding : TEncoding;
begin
  if Length(docs) = 0 then
    Exit;
  text := WriteToJSON5String(docs);
  encoding := docs[0].Options.Encoding;
  bytes := encoding.GetBytes(text);
  if docs[0].Options.WriteByteOrderMark then
  begin
    if Length(encoding.GetPreamble) > 0 then
      stream.WriteBuffer(encoding.GetPreamble[0], Length(encoding.GetPreamble));
  end;
  if Length(bytes) > 0 then
    stream.WriteBuffer(bytes[0], Length(bytes));
end;

class procedure TYAML.WriteToJSON5Stream(const value : IYAMLValue; const stream : TStream; const options : IYAMLEmitOptions);
var
  writer : TJSONWriterImpl;
  opt : IYAMLEmitOptions;
begin
  if options <> nil then
    opt := options
  else
    opt := _defaultWriterOptions;
  writer := TJSONWriterImpl.Create(opt, true);
  try
    writer.WriteToStream(value, stream);
  finally
    writer.Free;
  end;
end;

class procedure TYAML.WriteToStream(const doc: IYAMLDocument; const stream: TStream);
var
  Writer : TYAMLWriterImpl;
begin
  Writer := TYAMLWriterImpl.Create(doc.Options);
  try
    Writer.WriteToStream(doc, stream);
  finally
    Writer.Free;
  end;
end;

class procedure TYAML.WriteToStream(const docs: TArray<IYAMLDocument>; const stream: TStream);
var
  writerOptions : IYAMLEmitOptions;
  len : integer;
  i: Integer;
  writer : TYAMLWriterImpl;
begin
  len := Length(docs);
  if len = 0 then
    Exit;

  // Use the first document's options to determine encoding
  writerOptions := docs[0].Options;
  if len > 1 then
    writerOptions.EmitDocumentMarkers := true;
  writer := TYAMLWriterImpl.Create(writerOptions);
  try
    for i := 0 to len -1 do
    begin
      writer.WriteToStream(docs[i],stream);
      writer.Options.WriteByteOrderMark := false; //only write first time;
    end;
  finally
    writer.Free;
  end;
end;

class procedure TYAML.WriteToStream(const value: IYAMLValue; const stream: TStream; const options: IYAMLEmitOptions = nil);
var
  writer : TYAMLWriterImpl;
  opt : IYAMLEmitOptions;
begin
  if options <> nil then
    opt := options
  else
    opt := _defaultWriterOptions;
  writer := TYAMLWriterImpl.Create(opt);
  try
    writer.WriteToStream(value, stream);
  finally
    writer.Free;
  end;
end;

class function TYAML.WriteToString(const value : IYAMLValue; const options : IYAMLEmitOptions) : string;
var
  writer : TYAMLWriterImpl;
  opt : IYAMLEmitOptions;
begin
  if options <> nil then
    opt := options
  else
    opt := _defaultWriterOptions;

  writer := TYAMLWriterImpl.Create(opt);
  try
    Result := writer.WriteToString(value);
  finally
    writer.Free;
  end;
end;

constructor EYAMLParseException.Create(const message : string; line : integer; column: integer);
begin
  inherited CreateFmt('%s at line %d, column %d', [message, line, column]);
  FLine := line;
  FColumn := column;
end;


initialization
  _defaultParserOptions := TYAMLParserOptions.Create;
  _defaultWriterOptions := TYAMLEmitOptions.Create;
end.
