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
  // Every value in a document is a heap object, so the node classes are kept small:
  // fields most nodes never use live in this record, allocated on first use, and each
  // class lists only the interfaces it adds (each listing costs 8 bytes per object).
  PYAMLValueExtra = ^TYAMLValueExtra;
  TYAMLValueExtra = record
    Tag : string;  // Keep for backward compatibility
    TagInfo : IYAMLTagInfo;
    Comment : string;       // same line, after the value
    Comments : TArray<string>; // lines before the value
    EndComments : TArray<string>; // collections only: before the closing bracket
  end;

  // A sequence's items, held in the sequence object itself rather than in a separate
  // TList. Out-of-range access raises as TList<T> did.
  TYAMLValueList = record
  private
    FValues : TArray<IYAMLValue>;
    FCount : integer;
    function GetItem(index : integer) : IYAMLValue;inline;
    procedure SetItem(index : integer; const value : IYAMLValue);inline;
    procedure RaiseOutOfRange;
    procedure Grow;
  public
    procedure Add(const value : IYAMLValue);
    // puts value at index (0..Count); the items from index on move up one
    procedure Insert(index : integer; const value : IYAMLValue);
    // removes the item at index; the items after it move down one
    procedure Delete(index : integer);
    // sets item index to value; the value it held forgets owner as its parent
    procedure Replace(index : integer; const value : IYAMLValue; owner : TObject);
    procedure Clear;
    property Count : integer read FCount;
    property Items[index : integer] : IYAMLValue read GetItem write SetItem; default;
  end;

  TYAMLMappingEntry = record
    Key : string;
    Value : IYAMLValue;
  end;

{$IF defined(AUTOREFCOUNT) or not defined(XE3PLUS)}
  TYAMLNodeBase = class(TInterfacedObject)
  protected
    FValueType : TYAMLValueType;
  end;
{$ELSE}
  // TInterfacedObject's behaviour without its separate IInterface slot (IInterface is
  // answered with IYAMLValue) and with the value type packed beside the reference
  // count: 16 bytes less per node.
  TYAMLNodeBase = class(TObject)
  protected
    FRefCount : integer;
    FValueType : TYAMLValueType;
    function QueryInterface(const IID : TGUID; out Obj) : HResult; stdcall;
    function _AddRef : integer; stdcall;
    function _Release : integer; stdcall;
  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    class function NewInstance : TObject; override;
  end;
{$IFEND}

  TYAMLValue = class(TYAMLNodeBase, IYAMLValue)
  private
    FRawValue : string;
    FParent : Pointer;
    FExtra : PYAMLValueExtra;
    function Extra : PYAMLValueExtra;
  protected
    function GetComment : string;
    procedure SetComment(const value : string);
    function GetHasComments : boolean;inline;
    function GetComments : TArray<string>;
    procedure SetComments(const value : TArray<string>);
    procedure AddComment(const value : string);
    procedure ClearComments;
    function GetCount : integer;virtual;
    function GetParent : IYAMLValue;
    function FindRoot : IYAMLValue;
    function GetNodes(Index : integer) : IYAMLValue;virtual;
    function GetValue(const key : string) : IYAMLValue;virtual;
    function IsTaggedAs(const TagName : string) : boolean;inline;
    procedure ApplyTagConversion;


    function GetRawValue : string;inline;
    function GetTag : string;inline;
    function GetTagInfo : IYAMLTagInfo;inline;
    function GetValueType : TYAMLValueType;inline;

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
    function IsScalar : boolean;inline;
    // Value conversion methods
    function AsBoolean : boolean;
    function AsInteger : Int64;
    function AsFloat : Double;
    function AsCurrency : Currency;
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

    function Clone : IYAMLValue;
    // copies the tag and the comments to target, which has none of its own yet
    procedure CopyExtraTo(target : TYAMLValue);
    // checks that value can go into this collection: it must not be nil, must not be in a
    // collection already, and must not be this collection or one it is in
    procedure CheckDetached(const value : IYAMLValue);

  public
    // a deep copy of this node with parent as its Parent - Clone gives nil
    function CloneNode(const parent : IYAMLValue) : IYAMLValue;virtual;
    constructor Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue : string = ''; const tag : string = ''); overload;
    constructor Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue : string; const tagInfo : IYAMLTagInfo); overload;
    constructor CreateNull;
    destructor Destroy; override;
    // String representation
    function ToString : string; override;
  end;

  TYAMLCollection = class(TYAMLValue, IYAMLCollection)
  protected
    function GetHasEndComments : boolean;inline;
    function GetEndComments : TArray<string>;
    procedure SetEndComments(const value : TArray<string>);
    procedure AddEndComment(const value : string);
    procedure ClearEndComments;
    procedure Clear;virtual;abstract;
    function Query(const AExpression : string) : IYAMLSequence;
    function QuerySingle(const AExpression : string; out AMatch : IYAMLValue) : boolean;
    function QueryMatches(const AExpression : string) : TArray<TYAMLPathMatch>;

  public
    constructor Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue : string = ''; const tag : string = ''); overload;
    constructor Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue : string; const tagInfo : IYAMLTagInfo); overload;
  end;

  TYAMLSequence = class(TYAMLCollection, IYAMLSequence)
  private
    FItems : TYAMLValueList;
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
    function AddCurrencyValue(const value : Currency; const tag : string = '') : IYAMLValue; overload;
    function AddCurrencyValue(const value : Currency; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddValue(const value : string; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : string; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddValue(const value : TDateTime; isUTC : boolean; const tag : string = '') : IYAMLValue; overload;
    function AddValue(const value : TDateTime; isUTC : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddNull(const tag : string = '') : IYAMLValue;
    function AddNumber(const value : string) : IYAMLValue;

    function AddMapping(const tag : string = '') : IYAMLMapping;overload;
    function AddMapping(const tagInfo : IYAMLTagInfo) : IYAMLMapping;overload;
    function AddSequence(const tag : string = '') : IYAMLSequence;overload;
    function AddSequence(const tagInfo : IYAMLTagInfo) : IYAMLSequence;overload;
    function AddSet(const tag : string = '') : IYAMLSet;overload;
    function AddSet(const tagInfo : IYAMLTagInfo) : IYAMLSet;overload;

    procedure Delete(index : integer);virtual;
    procedure InsertValue(index : integer; const value : IYAMLValue); overload;
    function InsertValue(index : integer; const value : string; const tag : string = '') : IYAMLValue; overload;
    function InsertValue(index : integer; const value : Int64; const tag : string = '') : IYAMLValue; overload;
    function InsertValue(index : integer; const value : Double; const tag : string = '') : IYAMLValue; overload;
    function InsertValue(index : integer; const value : Boolean; const tag : string = '') : IYAMLValue; overload;
    function InsertNull(index : integer; const tag : string = '') : IYAMLValue;
    function InsertNumber(index : integer; const value : string) : IYAMLValue;
    function InsertMapping(index : integer; const tag : string = '') : IYAMLMapping;
    function InsertSequence(index : integer; const tag : string = '') : IYAMLSequence;
    // raises EArgumentOutOfRangeException unless index is 0..Count
    procedure CheckInsertIndex(index : integer);
    // add or insert a value made with this sequence as its parent
    procedure AddCreated(const value : IYAMLValue);
    procedure InsertCreated(index : integer; const value : IYAMLValue);
    // the A[] and O[] setters
    procedure SetCollectionAt(index : integer; const value : IYAMLValue);

    procedure Clear;override;

  public
    constructor Create(const parent : IYAMLValue; const tag : string);overload;virtual;
    constructor Create(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo);overload;virtual;
    destructor Destroy; override;

    function CloneNode(const parent : IYAMLValue) : IYAMLValue;override;

    // For the parsers and the value classes: adds value at the end as it is, without the
    // checks AddValue makes and without changing its Parent - an alias adds the node its
    // anchor names, which stays in the collection it was parsed in. False when a set already
    // has the value, which is then not added.
    function AddItem(const value : IYAMLValue) : boolean;virtual;
    // as AddItem, at index (0..Count)
    function InsertItem(index : integer; const value : IYAMLValue) : boolean;virtual;
  end;

  TYAMLSequenceClass = class of TYAMLSequence;


  TYAMLSet = class(TYAMLSequence, IYAMLSet)
  private
    FValues : TStringList; // For fast duplicate checking using string representations
  protected
    class function GetNodeValueType : TYAMLValueType;override;
    procedure Delete(index : integer);override;
    procedure Clear;override;

  public
    constructor Create(const parent : IYAMLValue; const tag : string);override;
    constructor Create(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo);override;
    destructor Destroy; override;

    function CloneNode(const parent : IYAMLValue) : IYAMLValue;override;
    function AddItem(const value : IYAMLValue) : boolean;override;
    function InsertItem(index : integer; const value : IYAMLValue) : boolean;override;
  end;

  IYAMLMappingPrivate = interface
  ['{F14352DD-0C83-4BDE-988B-C007D0FE93AC}']
    // For the parsers: puts value under key as it is, without the checks the public
    // IYAMLMapping.AddOrSetValue(key, IYAMLValue) makes and without changing its Parent - an
    // alias, and a merged (<<) collection, put in the node they name, which stays in the
    // collection it was parsed in.
    procedure AddOrSetValue(const key : string; const value : IYAMLValue);
    procedure MergeMapping(const ASourceMapping : IYAMLMapping);
    // value by insertion index, so iterating Keys[i] needs no per-key lookup
    function ValueAt(index : integer) : IYAMLValue;
  end;

  TYAMLMapping = class(TYAMLCollection, IYAMLMapping, IYAMLMappingPrivate)
  private
    // Insertion-ordered entries. Most mappings are small, so lookups are a linear scan (the
    // parser interns keys, so most comparisons stop at the pointer). From cIndexThreshold
    // keys on there is an index as well, in one array: an open-addressing table of
    // slotCount slots (a power of two, at most half full), each entry index + 1 or 0 for an
    // empty slot, followed by the hashes of the first slotCount div 2 keys.
    FEntries : TArray<TYAMLMappingEntry>;
    FCount : integer;
    FIndex : TArray<Cardinal>;
    function IndexOfKey(const key : string) : integer;inline;
    // as IndexOfKey; hash is the key's hash when the mapping is indexed
    function FindKey(const key : string; out hash : Cardinal) : integer;
    procedure BuildIndex(slotCount : integer);
    procedure IndexInsert(index, slotCount : integer);
    procedure GrowEntries;
    // the value for key, or nil when there is none - nothing is created or added
    function ValueOrNil(const key : string) : IYAMLValue;
  protected
    function ValueAt(index : integer) : IYAMLValue;
    function GetCount : integer;override;
    function GetNodes(Index : integer) : IYAMLValue;override;

    function GetKey(Index : integer) : string;
    function GetValue(const key : string) : IYAMLValue;override;


    // IYAMLMappingPrivate.AddOrSetValue: value goes in as it is
    procedure IYAMLMappingPrivate.AddOrSetValue = AddOrSetEntry;
    procedure AddOrSetEntry(const key : string; const value : IYAMLValue);
    // IYAMLMapping.AddOrSetValue: value must be detached, and gets this mapping as its parent
    procedure AddOrSetValue(const key : string; const value : IYAMLValue);overload;
    function Remove(const key : string) : boolean;

    function AddOrSetValue(const key : string; const value : boolean) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Int32) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : UInt32) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Int64) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : UInt64) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Single) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Double) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : Currency) : IYAMLValue; overload;
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
    function AddOrSetCurrencyValue(const key : string; const value : Currency; const tag : string) : IYAMLValue; overload;
    function AddOrSetCurrencyValue(const key : string; const value : Currency; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : string; const tag : string) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : string; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : TDateTime; isUTC : boolean; const tag : string) : IYAMLValue; overload;
    function AddOrSetValue(const key : string; const value : TDateTime; isUTC : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue; overload;

    function AddOrSetNull(const key : string; const tag : string = '') : IYAMLValue;
    function AddOrSetNumber(const key : string; const value : string) : IYAMLValue;

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

    procedure Clear;override;

  public
    constructor Create(const parent : IYAMLValue; const tag : string);overload;
    constructor Create(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo);overload;
    destructor Destroy; override;

    function CloneNode(const parent : IYAMLValue) : IYAMLValue;override;
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
    FEscapeNonASCII : boolean;
    FBlockScalarStyle : TYAMLBlockScalarStyle;
    {$WARN SYMBOL_DEPRECATED OFF} // the deprecated option is still kept, and does nothing
    FBlockChompingIndicator : TYAMLBlockChompingIndicator;
    {$WARN SYMBOL_DEPRECATED DEFAULT}
    FJSON5UnquotedKeys : boolean;
    FJSON5SingleQuotes : boolean;
    FJSON5TrailingCommas : boolean;
  protected
    function GetJSON5UnquotedKeys : boolean;
    procedure SetJSON5UnquotedKeys(value : boolean);
    function GetJSON5SingleQuotes : boolean;
    procedure SetJSON5SingleQuotes(value : boolean);
    function GetJSON5TrailingCommas : boolean;
    procedure SetJSON5TrailingCommas(value : boolean);
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
    function GetPrettyPrint : boolean;inline;
    procedure SetPrettyPrint(const value : boolean);
    function GetEscapeNonASCII : boolean;
    procedure SetEscapeNonASCII(const value : boolean);
    function GetBlockScalarStyle : TYAMLBlockScalarStyle;
    procedure SetBlockScalarStyle(value : TYAMLBlockScalarStyle);
    {$WARN SYMBOL_DEPRECATED OFF}
    function GetBlockChompingIndicator : TYAMLBlockChompingIndicator;
    procedure SetBlockChompingIndicator(value : TYAMLBlockChompingIndicator);
    {$WARN SYMBOL_DEPRECATED DEFAULT}

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
    constructor Create(const handle : string; const prefix : string);
    function ToString : string;override;
  end;

  TYAMLDocument = class(TInterfacedObject, IYAMLDocument)
  private
    FRoot : IYAMLValue;
    FOptions : IYAMLEmitOptions;
    FYAMLVersion : IYAMLVersionDirective;
    FTagDirectives : TList<IYAMLTagDirective>;
    FEndComments : TArray<string>;
  protected
    function GetHasEndComments : boolean;
    function GetEndComments : TArray<string>;
    procedure SetEndComments(const value : TArray<string>);
    procedure AddEndComment(const value : string);
    procedure ClearEndComments;
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
    function QueryMatches(const expression : string) : TArray<TYAMLPathMatch>;
  public
    constructor Create;overload;
    constructor Create(const ARoot : IYAMLValue; const yamlVersion : IYAMLVersionDirective; const tagDirectives : TList<IYAMLTagDirective>);overload;
    destructor Destroy;override;
  end;


  TYAMLParserOptions = class(TInterfacedObject, IYAMLParserOptions)
  private
    FDuplicateKeyBehavior : TYAMLDuplicateKeyBehavior;
    FInputFormat : TYAMLInputFormat;
    FYAML11Compatibility : boolean;
  protected
    procedure SetDuplicateKeyBehavior(value : TYAMLDuplicateKeyBehavior);
    function GetDuplicateKeyBehavior : TYAMLDuplicateKeyBehavior;
    function GetJSONMode : boolean;inline;
    procedure SetJSONMode(value : boolean);
    function GetInputFormat : TYAMLInputFormat;inline;
    procedure SetInputFormat(value : TYAMLInputFormat);
    function GetYAML11Compatibility : boolean;
    procedure SetYAML11Compatibility(value : boolean);
    function Clone : IYAMLParserOptions;

  public
    constructor Create;
    constructor CreateClone(const source : IYAMLParserOptions);
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

/// <summary>
///  Converts a Double to its YAML string representation. Unlike FloatToStr, this
///  emits the canonical YAML tokens for the non-finite values (.nan / .inf / -.inf)
///  rather than the RTL specific 'NAN'/'INF' text - the latter is not round-trippable
///  and StrToFloat on XE2 cannot parse it.
/// </summary>
function YAMLFloatToStr(const value : Double) : string;

/// <summary>
///  Fast path for re-emitting a float's raw text. Returns true when raw is a plain
///  decimal ([-]digits.digits, no exponent, at most 15 significant digits) and sets
///  text to exactly what FloatToStr(StrToFloat(raw, YAMLFormatSettings), YAMLFormatSettings)
///  would produce, without either conversion. Returns false for anything else.
/// </summary>
function YAMLCanonicalFloatText(const raw : string; out text : string) : boolean;

/// <summary>
///  True when value is a number in the JSON (RFC 8259 section 6) grammar:
///  -?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)? with nothing before or after. Every such
///  text is also a YAML 1.2 int (no fraction or exponent) or float, so the writers can emit
///  it as is. isFloat is set when it has a fraction or an exponent.
/// </summary>
function IsJSONNumber(const value : string) : boolean;overload;
function IsJSONNumber(const value : string; out isFloat : boolean) : boolean;overload;

/// <summary>
///  True when value is a number in the JSON5 grammar, with nothing before or after: an
///  optional + or -, then Infinity, NaN, 0x/0X hex digits, or a decimal with no leading
///  zero, a '.' that may have digits on only one side, and an optional exponent. The JSON5
///  writer emits such text as is.
/// </summary>
function IsJSON5Number(const value : string) : boolean;

/// <summary>
///  Converts YAML integer text of any size to decimal - an optional '-' then digits with no
///  leading zero, which is also a JSON integer. Takes decimal digits or a 0x hex, 0o octal
///  or 0b binary run (the forms the parser reads as integers), each with an optional sign
///  (JSON5 allows -0x1F), and returns false for anything else.
/// </summary>
function YAMLIntegerToDecimalText(const raw : string; out text : string) : boolean;

/// <summary>
///  The type the parser gives a plain (unquoted) scalar. That is the YAML 1.2 core schema,
///  each word in just its three spellings - null Null NULL ~, true True TRUE, false False
///  FALSE, decimal, 0o octal and 0x hex integers, floats including .nan .NaN .NAN and
///  [-+]? .inf .Inf .INF - plus the YAML 1.1 forms VSoft.YAML also reads: yes, no, on and off
///  in the same three spellings, 0b binary integers and ISO 8601 timestamps. Empty text is
///  null and anything else a string. The writer quotes any string this would not call one.
/// </summary>
function YAMLResolvePlainScalar(const value : string) : TYAMLValueType;

/// <summary>
///  The type a plain scalar has in the YAML 1.2 core schema (10.3.2) alone - null Null NULL ~
///  and empty, true True TRUE false False FALSE, decimal, 0o octal and 0x hex integers and
///  floats including .nan and [-+].inf in their three spellings. Anything else is a string,
///  including the YAML 1.1 forms YAMLResolvePlainScalar also reads. The parser uses it when
///  YAML11Compatibility is off.
/// </summary>
function YAMLResolveCoreScalar(const value : string) : TYAMLValueType;

/// <summary>
///  Makes parent the parent of value - for the parser, which can build a node before it knows
///  which collection the node goes in.
/// </summary>
procedure YAMLSetParent(const value : IYAMLValue; const parent : IYAMLValue);

implementation

uses
  System.Math,
  System.StrUtils,
  VSoft.YAML.Utils,
  VSoft.YAML.Writer,
  VSoft.YAML.Path;

function YAMLCanonicalFloatText(const raw : string; out text : string) : boolean;
var
  len, i, intStart, intLen, fracStart, fracLen, fracZeros, sigDigits : integer;
begin
  result := false;
  len := Length(raw);
  i := 1;
  if (len > 0) and (raw[1] = '-') then
    Inc(i);
  intStart := i;
  while (i <= len) and (raw[i] >= '0') and (raw[i] <= '9') do
    Inc(i);
  intLen := i - intStart;
  // need digits, no leading zero, then a '.'
  if (intLen = 0) or ((intLen > 1) and (raw[intStart] = '0')) or (i > len) or (raw[i] <> '.') then
    exit;
  Inc(i);
  fracStart := i;
  while (i <= len) and (raw[i] >= '0') and (raw[i] <= '9') do
    Inc(i);
  if (i <= len) or (i = fracStart) then // exponent / trailing junk, or no fraction digits
    exit;
  fracLen := i - fracStart;
  while (fracLen > 0) and (raw[fracStart + fracLen - 1] = '0') do
    Dec(fracLen);

  if (intLen = 1) and (raw[intStart] = '0') then
  begin
    if fracLen = 0 then
    begin
      if intStart > 1 then // -0.0 : leave signed zero to the RTL
        exit;
      text := '0';
      exit(true);
    end;
    fracZeros := 0;
    while raw[fracStart + fracZeros] = '0' do
      Inc(fracZeros);
    // FloatToStr switches to exponent form for small magnitudes
    if fracZeros > 2 then
      exit;
    sigDigits := fracLen - fracZeros;
  end
  else
    sigDigits := intLen + fracLen;
  if sigDigits > 15 then
    exit;

  if fracLen = 0 then
    text := Copy(raw, 1, fracStart - 2)
  else if fracStart + fracLen - 1 = len then
    text := raw
  else
    text := Copy(raw, 1, fracStart + fracLen - 1);
  result := true;
end;

function IsJSONNumber(const value : string) : boolean;
var
  isFloat : boolean;
begin
  result := IsJSONNumber(value, isFloat);
end;

function IsJSONNumber(const value : string; out isFloat : boolean) : boolean;
var
  len, i, digitStart : integer;
begin
  result := false;
  isFloat := false;
  len := Length(value);
  i := 1;
  if (len > 0) and (value[1] = '-') then
    Inc(i);
  // int : a lone 0, or digits that do not start with 0
  if (i > len) or (value[i] < '0') or (value[i] > '9') then
    exit;
  if value[i] = '0' then
    Inc(i)
  else
    while (i <= len) and (value[i] >= '0') and (value[i] <= '9') do
      Inc(i);
  // frac : '.' and at least one digit
  if (i <= len) and (value[i] = '.') then
  begin
    Inc(i);
    digitStart := i;
    while (i <= len) and (value[i] >= '0') and (value[i] <= '9') do
      Inc(i);
    if i = digitStart then
      exit;
    isFloat := true;
  end;
  // exp : 'e' or 'E', an optional sign and at least one digit
  if (i <= len) and ((value[i] = 'e') or (value[i] = 'E')) then
  begin
    Inc(i);
    if (i <= len) and ((value[i] = '+') or (value[i] = '-')) then
      Inc(i);
    digitStart := i;
    while (i <= len) and (value[i] >= '0') and (value[i] <= '9') do
      Inc(i);
    if i = digitStart then
      exit;
    isFloat := true;
  end;
  result := i > len;
end;

function IsJSON5Number(const value : string) : boolean;
var
  len, i, digitStart : integer;
  hasIntPart : boolean;
begin
  result := false;
  len := Length(value);
  i := 1;
  if (len > 0) and ((value[1] = '-') or (value[1] = '+')) then
    Inc(i);
  if i > len then
    exit;
  case value[i] of
    'I' : exit(Copy(value, i, len) = 'Infinity');
    'N' : exit(Copy(value, i, len) = 'NaN');
  end;
  // hex : 0x or 0X and at least one hex digit
  if (value[i] = '0') and (i < len) and ((value[i + 1] = 'x') or (value[i + 1] = 'X')) then
  begin
    Inc(i, 2);
    digitStart := i;
    while (i <= len) and CharInSet(value[i], ['0'..'9', 'a'..'f', 'A'..'F']) do
      Inc(i);
    exit((i > digitStart) and (i > len));
  end;
  // int : a lone 0, or digits that do not start with 0 - may be absent before a '.'
  hasIntPart := (value[i] >= '0') and (value[i] <= '9');
  if hasIntPart then
  begin
    if value[i] = '0' then
      Inc(i)
    else
      while (i <= len) and (value[i] >= '0') and (value[i] <= '9') do
        Inc(i);
  end;
  // frac : '.' then digits, which may be absent after an int part
  if (i <= len) and (value[i] = '.') then
  begin
    Inc(i);
    digitStart := i;
    while (i <= len) and (value[i] >= '0') and (value[i] <= '9') do
      Inc(i);
    if (not hasIntPart) and (i = digitStart) then
      exit; // a lone '.'
  end
  else if not hasIntPart then
    exit;
  // exp : 'e' or 'E', an optional sign and at least one digit
  if (i <= len) and ((value[i] = 'e') or (value[i] = 'E')) then
  begin
    Inc(i);
    if (i <= len) and ((value[i] = '+') or (value[i] = '-')) then
      Inc(i);
    digitStart := i;
    while (i <= len) and (value[i] >= '0') and (value[i] <= '9') do
      Inc(i);
    if i = digitStart then
      exit;
  end;
  result := i > len;
end;

function YAMLIntegerToDecimalText(const raw : string; out text : string) : boolean;
var
  len, i, j, k, radix, digit, carry, count : integer;
  negative : boolean;
  digits : TArray<Byte>; // the value in decimal, least significant digit first
begin
  result := false;
  len := Length(raw);
  if len = 0 then
    exit;
  negative := false;
  radix := 10;
  i := 1;
  if (raw[1] = '-') or (raw[1] = '+') then
  begin
    if len = 1 then
      exit;
    negative := raw[1] = '-';
    i := 2;
  end;
  // a radix prefix needs at least one digit after it; JSON5 allows a sign before 0x
  if (len - i >= 2) and (raw[i] = '0') and CharInSet(raw[i + 1], ['x', 'X', 'o', 'O', 'b', 'B']) then
  begin
    case raw[i + 1] of
      'x', 'X' : radix := 16;
      'o', 'O' : radix := 8;
    else
      radix := 2;
    end;
    Inc(i, 2);
  end;

  // two decimal digits per input digit is enough even for hex, as 16 < 100
  SetLength(digits, 2 * (len - i + 1));
  count := 0;
  for j := i to len do
  begin
    case raw[j] of
      '0'..'9' : digit := Ord(raw[j]) - Ord('0');
      'a'..'f' : digit := Ord(raw[j]) - Ord('a') + 10;
      'A'..'F' : digit := Ord(raw[j]) - Ord('A') + 10;
    else
      digit := radix; // not a digit at all
    end;
    if digit >= radix then
      exit;
    // value := value * radix + digit, leading zeros leaving it at zero
    carry := digit;
    for k := 0 to count - 1 do
    begin
      carry := carry + digits[k] * radix;
      digits[k] := carry mod 10;
      carry := carry div 10;
    end;
    while carry > 0 do
    begin
      digits[count] := carry mod 10;
      carry := carry div 10;
      Inc(count);
    end;
  end;

  if count = 0 then
    text := '0'
  else
  begin
    if negative then
    begin
      SetLength(text, count + 1);
      text[1] := '-';
      i := 2;
    end
    else
    begin
      SetLength(text, count);
      i := 1;
    end;
    for j := count - 1 downto 0 do
    begin
      text[i] := Char(Ord('0') + digits[j]);
      Inc(i);
    end;
  end;
  result := true;
end;

// YYYY-MM-DD, optionally followed by 'T' or a space and HH:MM or HH:MM:SS, with an optional
// Z, +HH:MM or +HH zone.
function IsYAMLTimestamp(const value : string) : boolean;
var
  len : integer;
  year, month, day, hour, min, sec : integer;
  timeStart : integer;
  timeEnd : integer;
begin
  result := False;
  len := Length(value);

  // Must be at least 10 characters for YYYY-MM-DD
  if len < 10 then
    Exit;

  // Quick validation: YYYY-MM-DD pattern
  // Characters 1-4 must be digits (year)
  if not (TCharClassHelper.IsDigit(value[1]) and
          TCharClassHelper.IsDigit(value[2]) and
          TCharClassHelper.IsDigit(value[3]) and
          TCharClassHelper.IsDigit(value[4])) then
    Exit;

  // Character 5 must be '-'
  if value[5] <> '-' then
    Exit;

  // Characters 6-7 must be digits (month)
  if not (TCharClassHelper.IsDigit(value[6]) and
          TCharClassHelper.IsDigit(value[7])) then
    Exit;

  // Character 8 must be '-'
  if value[8] <> '-' then
    Exit;

  // Characters 9-10 must be digits (day)
  if not (TCharClassHelper.IsDigit(value[9]) and
          TCharClassHelper.IsDigit(value[10])) then
    Exit;

  // Parse and validate date components
  year := (Ord(value[1]) - Ord('0')) * 1000 + (Ord(value[2]) - Ord('0')) * 100 +
          (Ord(value[3]) - Ord('0')) * 10 + (Ord(value[4]) - Ord('0'));
  month := (Ord(value[6]) - Ord('0')) * 10 + (Ord(value[7]) - Ord('0'));
  day := (Ord(value[9]) - Ord('0')) * 10 + (Ord(value[10]) - Ord('0'));

  // Basic range validation
  if not ((year >= 100) and (year <= 2400) and
          (month >= 1) and (month <= 12) and
          (day >= 1) and (day <= 31)) then
    Exit;

  // If exactly 10 characters, valid date-only timestamp
  if len = 10 then
  begin
    result := True;
    Exit;
  end;

  // Check for time separator (T or space)
  if (len < 11) or not ((value[11] = 'T') or (value[11] = ' ')) then
    Exit;

  timeStart := 12;
  timeEnd := len;

  // Strip timezone suffix: Z, +HH:MM, -HH:MM
  if value[len] = 'Z' then
    Dec(timeEnd)
  else if (len >= 16) and CharInSet(value[len - 5], ['+', '-']) and (value[len - 2] = ':') then
    timeEnd := len - 6
  else if (len >= 13) and CharInSet(value[len - 2], ['+', '-']) then
    timeEnd := len - 3;

  // Need at least HH:MM (5 chars)
  if (timeEnd - timeStart + 1) < 5 then
    Exit;

  // Validate time format: HH:MM or HH:MM:SS
  // Characters timeStart and timeStart+1 must be digits (hour)
  if (timeStart + 1 > timeEnd) or
     not (TCharClassHelper.IsDigit(value[timeStart]) and
          TCharClassHelper.IsDigit(value[timeStart + 1])) then
    Exit;

  // Character timeStart+2 must be ':'
  if (timeStart + 2 > timeEnd) or (value[timeStart + 2] <> ':') then
    Exit;

  // Characters timeStart+3 and timeStart+4 must be digits (minute)
  if (timeStart + 4 > timeEnd) or
     not (TCharClassHelper.IsDigit(value[timeStart + 3]) and
          TCharClassHelper.IsDigit(value[timeStart + 4])) then
    Exit;

  // Parse hour and minute
  hour := (Ord(value[timeStart]) - Ord('0')) * 10 + (Ord(value[timeStart + 1]) - Ord('0'));
  min := (Ord(value[timeStart + 3]) - Ord('0')) * 10 + (Ord(value[timeStart + 4]) - Ord('0'));

  if not ((hour >= 0) and (hour <= 23) and (min >= 0) and (min <= 59)) then
    Exit;

  // If we have just HH:MM, we're done
  if (timeEnd - timeStart + 1) = 5 then
  begin
    result := True;
    Exit;
  end;

  // Check for seconds if present
  if (timeEnd - timeStart + 1) >= 8 then
  begin
    // Character timeStart+5 must be ':'
    if value[timeStart + 5] <> ':' then
      Exit;

    // Characters timeStart+6 and timeStart+7 must be digits (second)
    if not (TCharClassHelper.IsDigit(value[timeStart + 6]) and
            TCharClassHelper.IsDigit(value[timeStart + 7])) then
      Exit;

    // Parse seconds
    sec := (Ord(value[timeStart + 6]) - Ord('0')) * 10 + (Ord(value[timeStart + 7]) - Ord('0'));

    if (sec >= 0) and (sec <= 59) then
      result := True;
  end;
end;

// True when value is a '0x' hex, '0o' octal or '0b' binary integer - the prefix, in lower
// case as both YAML 1.2 and 1.1 have it, followed by one or more digits of that radix and
// nothing else. A plain scalar that merely starts like one ('0x1F.png', '0b101.txt') is a
// string.
function IsYAMLRadixInteger(const value : string) : boolean;
var
  len, i : integer;
  ch : Char;
begin
  result := False;
  len := Length(value);
  if (len < 3) or (value[1] <> '0') then
    Exit;
  for i := 3 to len do
  begin
    ch := value[i];
    case value[2] of
      'x' : result := TCharClassHelper.IsHexDigit(ch);
      'o' : result := TCharClassHelper.IsOctalDigit(ch);
      'b' : result := TCharClassHelper.IsBinaryDigit(ch);
    else
      result := False;
    end;
    if not result then
      Exit;
  end;
end;

// The YAML 1.2 core schema decimal int [-+]?[0-9]+ and float
// [-+]?(\.[0-9]+|[0-9]+(\.[0-9]*)?)([eE][-+]?[0-9]+)? - isFloat is set for a float.
function IsYAMLDecimalNumber(const value : string; out isFloat : boolean) : boolean;
var
  len, i, digitStart, digitCount : integer;
begin
  result := false;
  isFloat := false;
  len := Length(value);
  i := 1;
  if (len > 0) and ((value[1] = '+') or (value[1] = '-')) then
    Inc(i);
  digitStart := i;
  while (i <= len) and (value[i] >= '0') and (value[i] <= '9') do
    Inc(i);
  digitCount := i - digitStart;
  if (i <= len) and (value[i] = '.') then
  begin
    isFloat := true;
    Inc(i);
    digitStart := i;
    while (i <= len) and (value[i] >= '0') and (value[i] <= '9') do
      Inc(i);
    Inc(digitCount, i - digitStart);
  end;
  // a digit before or after the point
  if digitCount = 0 then
    exit;
  if (i <= len) and ((value[i] = 'e') or (value[i] = 'E')) then
  begin
    isFloat := true;
    Inc(i);
    if (i <= len) and ((value[i] = '+') or (value[i] = '-')) then
      Inc(i);
    digitStart := i;
    while (i <= len) and (value[i] >= '0') and (value[i] <= '9') do
      Inc(i);
    if i = digitStart then
      exit;
  end;
  result := i > len;
end;

function YAMLResolvePlainScalar(const value : string) : TYAMLValueType;
var
  isFloat : boolean;
begin
  if value = '' then
    exit(TYAMLValueType.vtNull);

  // The words, each in just its three spellings - 'nULL' and 'tRUE' are strings
  case value[1] of
    '~' :
      if Length(value) = 1 then
        exit(TYAMLValueType.vtNull);
    'n', 'N' :
      if (value = 'null') or (value = 'Null') or (value = 'NULL') then
        exit(TYAMLValueType.vtNull)
      else if (value = 'no') or (value = 'No') or (value = 'NO') then
        exit(TYAMLValueType.vtBoolean);
    't', 'T' :
      if (value = 'true') or (value = 'True') or (value = 'TRUE') then
        exit(TYAMLValueType.vtBoolean);
    'f', 'F' :
      if (value = 'false') or (value = 'False') or (value = 'FALSE') then
        exit(TYAMLValueType.vtBoolean);
    'y', 'Y' :
      if (value = 'yes') or (value = 'Yes') or (value = 'YES') then
        exit(TYAMLValueType.vtBoolean);
    'o', 'O' :
      if (value = 'on') or (value = 'On') or (value = 'ON') or
         (value = 'off') or (value = 'Off') or (value = 'OFF') then
        exit(TYAMLValueType.vtBoolean);
    '.' :
      if (value = '.nan') or (value = '.NaN') or (value = '.NAN') or
         (value = '.inf') or (value = '.Inf') or (value = '.INF') then
        exit(TYAMLValueType.vtFloat);
    '+' :
      if (value = '+.inf') or (value = '+.Inf') or (value = '+.INF') then
        exit(TYAMLValueType.vtFloat);
    '-' :
      if (value = '-.inf') or (value = '-.Inf') or (value = '-.INF') then
        exit(TYAMLValueType.vtFloat);
  end;

  if IsYAMLTimestamp(value) then
    result := TYAMLValueType.vtTimestamp
  else if IsYAMLRadixInteger(value) then
    result := TYAMLValueType.vtInteger
  else if IsYAMLDecimalNumber(value, isFloat) then
  begin
    if isFloat then
      result := TYAMLValueType.vtFloat
    else
      result := TYAMLValueType.vtInteger;
  end
  else
    result := TYAMLValueType.vtString;
end;

function YAMLResolveCoreScalar(const value : string) : TYAMLValueType;
var
  isFloat : boolean;
begin
  if value = '' then
    exit(TYAMLValueType.vtNull);

  case value[1] of
    '~' :
      if Length(value) = 1 then
        exit(TYAMLValueType.vtNull);
    'n', 'N' :
      if (value = 'null') or (value = 'Null') or (value = 'NULL') then
        exit(TYAMLValueType.vtNull);
    't', 'T' :
      if (value = 'true') or (value = 'True') or (value = 'TRUE') then
        exit(TYAMLValueType.vtBoolean);
    'f', 'F' :
      if (value = 'false') or (value = 'False') or (value = 'FALSE') then
        exit(TYAMLValueType.vtBoolean);
    '.' :
      if (value = '.nan') or (value = '.NaN') or (value = '.NAN') or
         (value = '.inf') or (value = '.Inf') or (value = '.INF') then
        exit(TYAMLValueType.vtFloat);
    '+' :
      if (value = '+.inf') or (value = '+.Inf') or (value = '+.INF') then
        exit(TYAMLValueType.vtFloat);
    '-' :
      if (value = '-.inf') or (value = '-.Inf') or (value = '-.INF') then
        exit(TYAMLValueType.vtFloat);
  end;

  // 0o octal and 0x hex - not YAML 1.1's 0b binary
  if (Length(value) > 2) and (value[1] = '0') and ((value[2] = 'o') or (value[2] = 'x')) and IsYAMLRadixInteger(value) then
    result := TYAMLValueType.vtInteger
  else if IsYAMLDecimalNumber(value, isFloat) then
  begin
    if isFloat then
      result := TYAMLValueType.vtFloat
    else
      result := TYAMLValueType.vtInteger;
  end
  else
    result := TYAMLValueType.vtString;
end;

function YAMLFloatToStr(const value : Double) : string;
begin
  if IsNan(value) then
    result := '.nan'
  else if IsInfinite(value) then
  begin
    if value < 0 then
      result := '-.inf'
    else
      result := '.inf';
  end
  else
    result := FloatToStr(value, YAMLFormatSettings);
end;

{$IF not (defined(AUTOREFCOUNT) or not defined(XE3PLUS))}

{ TYAMLNodeBase }

const
  // System.ObjCastGUID, which 'intf as TObject' asks for (declared in System's
  // implementation section)
  cObjCastGUID : TGUID = '{CEDF24DE-80A4-447D-8C75-EB871DC121FD}';
  cDestroying = Integer($80000000);

function TYAMLNodeBase.QueryInterface(const IID : TGUID; out Obj) : HResult;
begin
  // checked first: collections cast every child this way when they are destroyed
  if IsEqualGUID(IID, cObjCastGUID) then
  begin
    Pointer(Obj) := Pointer(Self);
    exit(S_OK);
  end;
  if GetInterface(IID, Obj) then
    exit(S_OK);
  // no slot of its own (see the class comment): any interface the node has will do
  if IsEqualGUID(IID, IInterface) and GetInterface(IYAMLValue, Obj) then
    exit(S_OK);
  result := E_NOINTERFACE;
end;

function TYAMLNodeBase._AddRef : integer;
begin
  result := AtomicIncrement(FRefCount);
end;

var
  // Collections in the middle of releasing their children (BeginReleasingChildren), in any
  // thread.
  _releasingCollections : integer = 0;

// A node still referenced elsewhere when the collection it is in goes must forget its
// parent. Rather than each collection checking every child as it goes, a child that is
// released while some collection is releasing its children checks whether its own parent is
// the one going - which is only ever the case for a child that outlives its parent.
procedure ForgetDestroyedParent(node : TYAMLNodeBase);
var
  parent : Pointer;
  parentObj : TObject;
begin
  parent := TYAMLValue(node).FParent;
  if parent = nil then
    exit;
  // the parent is held as its IYAMLValue; asking it for the object adds no reference
  if IInterface(parent).QueryInterface(cObjCastGUID, parentObj) <> S_OK then
    exit;
  if TYAMLNodeBase(parentObj).FRefCount = cDestroying then
    TYAMLValue(node).FParent := nil;
end;

function TYAMLNodeBase._Release : integer;
begin
  result := AtomicDecrement(FRefCount);
  if result = 0 then
  begin
    // so that any refcounting during destruction cannot get back to zero
    FRefCount := cDestroying;
    Destroy;
  end
  else if (_releasingCollections > 0) and (result > 0) then
    ForgetDestroyedParent(Self);
end;

// A collection's destructor releases its children between these two, so that any that
// outlive it forget it as their parent (see ForgetDestroyedParent).
procedure BeginReleasingChildren;inline;
begin
  AtomicIncrement(_releasingCollections);
end;

procedure EndReleasingChildren;inline;
begin
  AtomicDecrement(_releasingCollections);
end;

procedure ReleaseChildren(var children : TArray<IYAMLValue>);
begin
  BeginReleasingChildren;
  try
    children := nil;
  finally
    EndReleasingChildren;
  end;
end;

procedure TYAMLNodeBase.AfterConstruction;
begin
  // release the constructor's implicit reference
  AtomicDecrement(FRefCount);
end;

procedure TYAMLNodeBase.BeforeDestruction;
begin
  if (FRefCount <> 0) and (FRefCount <> cDestroying) then
    System.Error(reInvalidPtr);
end;

class function TYAMLNodeBase.NewInstance : TObject;
begin
  // a reference held during construction, so refcounting there cannot free the node
  result := inherited NewInstance;
  TYAMLNodeBase(result).FRefCount := 1;
end;

{$IFEND}

{ TYAMLValueList }

procedure TYAMLValueList.RaiseOutOfRange;
begin
  raise EArgumentOutOfRangeException.Create('Argument out of range');
end;

function TYAMLValueList.GetItem(index : integer) : IYAMLValue;
begin
  if Cardinal(index) >= Cardinal(FCount) then
    RaiseOutOfRange;
  result := FValues[index];
end;

procedure TYAMLValueList.SetItem(index : integer; const value : IYAMLValue);
begin
  if Cardinal(index) >= Cardinal(FCount) then
    RaiseOutOfRange;
  FValues[index] := value;
end;

procedure TYAMLValueList.Grow;
begin
  if FCount = 0 then
    SetLength(FValues, 4)
  else
    SetLength(FValues, FCount * 2);
end;

procedure TYAMLValueList.Add(const value : IYAMLValue);
begin
  if FCount = Length(FValues) then
    Grow;
  FValues[FCount] := value;
  Inc(FCount);
end;

procedure TYAMLValueList.Insert(index : integer; const value : IYAMLValue);
begin
  if Cardinal(index) > Cardinal(FCount) then
    RaiseOutOfRange;
  if FCount = Length(FValues) then
    Grow;
  if index < FCount then
  begin
    // the references move as they are; the slot left at index is cleared, not released
    Move(FValues[index], FValues[index + 1], (FCount - index) * SizeOf(IYAMLValue));
    Pointer(FValues[index]) := nil;
  end;
  FValues[index] := value;
  Inc(FCount);
end;

procedure TYAMLValueList.Delete(index : integer);
begin
  if Cardinal(index) >= Cardinal(FCount) then
    RaiseOutOfRange;
  FValues[index] := nil;
  Dec(FCount);
  if index < FCount then
  begin
    // the references move as they are; the last slot, now a duplicate, is cleared
    Move(FValues[index + 1], FValues[index], (FCount - index) * SizeOf(IYAMLValue));
    Pointer(FValues[FCount]) := nil;
  end;
end;

procedure TYAMLValueList.Clear;
begin
  FValues := nil;
  FCount := 0;
end;

procedure YAMLSetParent(const value : IYAMLValue; const parent : IYAMLValue);
var
  obj : TObject;
begin
  if value = nil then
    exit;
  obj := value as TObject;
  if obj is TYAMLValue then
    TYAMLValue(obj).FParent := Pointer(parent);
end;

{$IF defined(AUTOREFCOUNT) or not defined(XE3PLUS)}
// Children hold a raw pointer to their collection, so one still referenced elsewhere
// must forget it when the collection goes. (With TYAMLNodeBase's own reference counting,
// ReleaseChildren does this for just the children that outlive their collection.)
procedure DetachFromParent(const value : IYAMLValue);
var
  obj : TObject;
begin
  if value = nil then
    exit;
  obj := value as TObject;
  if obj is TYAMLValue then
    TYAMLValue(obj).FParent := nil;
end;
{$IFEND}

// old is being replaced in owner by value: unless value is the same node, old forgets owner
// as its parent, so that it never holds a parent that has gone. (Nodes are compared as
// objects - one node can be held through different interfaces.)
procedure DetachReplaced(const old, value : IYAMLValue; owner : TObject);
var
  obj : TObject;
  parent : Pointer;
begin
  if old = nil then
    exit;
  obj := old as TObject;
  if (value <> nil) and ((value as TObject) = obj) then
    exit;
  if not (obj is TYAMLValue) then
    exit;
  parent := TYAMLValue(obj).FParent;
  if (parent <> nil) and ((IYAMLValue(parent) as TObject) = owner) then
    TYAMLValue(obj).FParent := nil;
end;

procedure TYAMLValueList.Replace(index : integer; const value : IYAMLValue; owner : TObject);
begin
  if Cardinal(index) >= Cardinal(FCount) then
    RaiseOutOfRange;
  DetachReplaced(FValues[index], value, owner);
  FValues[index] := value;
end;

// A number node holding value exactly as given, typed as the parser would type it.
function CreateNumberValue(const parent : IYAMLValue; const value : string) : IYAMLValue;
var
  isFloat : boolean;
begin
  if not IsJSONNumber(value, isFloat) then
    raise EConvertError.CreateFmt('Invalid number "%s" - the text must be a JSON (RFC 8259) number', [value]);
  if isFloat then
    result := TYAMLValue.Create(parent, TYAMLValueType.vtFloat, value)
  else
    result := TYAMLValue.Create(parent, TYAMLValueType.vtInteger, value);
end;

// Conversions for the JsonDataObjects-style getters (I[], F[], B[] ...), which read a scalar
// of any type as JsonDataObjects does. nil (a missing key) and a null read as the default; a
// collection, or text that is not a number, raises.

function ScalarToInt64(const value : IYAMLValue) : Int64;
var
  text : string;
begin
  if value = nil then
    exit(0);
  case value.ValueType of
    TYAMLValueType.vtNull :
      result := 0;
    TYAMLValueType.vtFloat :
      result := Trunc(value.AsFloat);
    TYAMLValueType.vtBoolean :
      result := Ord(value.AsBoolean);
    TYAMLValueType.vtString :
    begin
      text := value.AsString;
      if not TryStrToInt64(text, result) then
        result := Trunc(StrToFloat(text, YAMLFormatSettings));
    end;
    TYAMLValueType.vtTimestamp :
      result := Trunc(value.AsLocalDateTime);
  else
    result := value.AsInteger; // an integer; a collection raises
  end;
end;

function ScalarToUInt64(const value : IYAMLValue) : UInt64;
var
  decimalText : string;
  signedValue : Int64;
begin
  if value = nil then
    exit(0);
  // integer text converts exactly, so a value past High(Int64) can be read - from a numeric
  // string too
  if value.IsInteger and YAMLIntegerToDecimalText(Trim(value.RawValue), decimalText) then
  begin
    if not TryStrToUInt64(decimalText, result) then
      raise EConvertError.CreateFmt('Cannot convert "%s" to UInt64', [value.RawValue]);
    exit;
  end;
  if value.IsString and TryStrToUInt64(Trim(value.AsString), result) then
    exit;
  signedValue := ScalarToInt64(value);
  if signedValue < 0 then
    raise EConvertError.CreateFmt('Cannot convert "%s" to UInt64', [value.RawValue]);
  result := UInt64(signedValue);
end;

function ScalarToFloat(const value : IYAMLValue) : Double;
var
  decimalText : string;
begin
  if value = nil then
    exit(0);
  case value.ValueType of
    TYAMLValueType.vtNull :
      result := 0;
    TYAMLValueType.vtInteger :
      // through the decimal text, so an integer past Int64 converts too
      if YAMLIntegerToDecimalText(Trim(value.RawValue), decimalText) then
        result := StrToFloat(decimalText, YAMLFormatSettings)
      else
        result := value.AsInteger;
    TYAMLValueType.vtBoolean :
      result := Ord(value.AsBoolean);
    TYAMLValueType.vtString :
      result := StrToFloat(value.AsString, YAMLFormatSettings);
    TYAMLValueType.vtTimestamp :
      result := value.AsLocalDateTime;
  else
    result := value.AsFloat; // a float; a collection raises
  end;
end;

function ScalarToCurrency(const value : IYAMLValue) : Currency;
begin
  if value = nil then
    exit(0);
  case value.ValueType of
    TYAMLValueType.vtNull :
      result := 0;
    TYAMLValueType.vtBoolean :
      result := Ord(value.AsBoolean);
    TYAMLValueType.vtString :
      result := StrToCurr(value.AsString, YAMLFormatSettings);
    TYAMLValueType.vtTimestamp :
      result := value.AsLocalDateTime;
  else
    // integers and floats from their text, not through Double, so all four decimals are
    // exact; a collection raises
    result := value.AsCurrency;
  end;
end;

function ScalarToBoolean(const value : IYAMLValue) : boolean;
var
  text : string;
begin
  if value = nil then
    exit(false);
  case value.ValueType of
    TYAMLValueType.vtNull :
      result := false;
    TYAMLValueType.vtInteger :
      if YAMLIntegerToDecimalText(Trim(value.RawValue), text) then
        result := text <> '0'
      else
        result := value.AsInteger <> 0;
    TYAMLValueType.vtFloat :
      result := value.AsFloat <> 0;
    TYAMLValueType.vtString :
    begin
      // text that reads as a YAML boolean has that value; any other string is False
      text := value.AsString;
      result := (YAMLResolvePlainScalar(text) = TYAMLValueType.vtBoolean) and
                (SameText(text, 'true') or SameText(text, 'yes') or SameText(text, 'on'));
    end;
    TYAMLValueType.vtTimestamp :
      result := value.AsLocalDateTime <> 0;
  else
    result := value.AsBoolean; // a boolean; a collection raises
  end;
end;

function ScalarToDateTime(const value : IYAMLValue; utc : boolean) : TDateTime;
begin
  if value = nil then
    exit(0);
  case value.ValueType of
    TYAMLValueType.vtNull :
      result := 0;
    TYAMLValueType.vtString :
      if utc then
        result := TYAMLDateUtils.ISO8601StrToUTCDateTime(value.AsString)
      else
        result := TYAMLDateUtils.ISO8601StrToLocalDateTime(value.AsString);
    TYAMLValueType.vtInteger,
    TYAMLValueType.vtFloat :
      result := ScalarToFloat(value);
  else
    // a timestamp; anything else raises
    if utc then
      result := value.AsUTCDateTime
    else
      result := value.AsLocalDateTime;
  end;
end;

{ TYAMLValue }

//TODO : handle !yaml! style tags
procedure TYAMLValue.ApplyTagConversion;
var
  decimalText : string;
  int64Value : Int64;
begin
  // Apply type conversion based on tag
  if GetTag <> '' then
  begin
    if IsTaggedAs('!!str') then
      FValueType := TYAMLValueType.vtString
    else if IsTaggedAs('!!int') then
    begin
      FValueType := TYAMLValueType.vtInteger;
      // !!int is arbitrary size (YAML 1.2.2 section 10.2.1.3), so decimal, 0o octal and 0x hex
      // (and YAML 1.1 0b binary) of any length are valid - the writers emit them exactly.
      // Anything else must convert to an Int64.
      if not (YAMLIntegerToDecimalText(FRawValue, decimalText) or TryStrToInt64(FRawValue, int64Value)) then
        raise Exception.CreateFmt('Invalid integer value "%s" for !!int tag', [FRawValue]);
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
  result := nil; // GetInterface overwrites without releasing
  GetInterface(IYAMLCollection, result);
end;

function TYAMLValue.AsCurrency: Currency;
var
  trimmedValue : string;
begin
  if not (IsFloat or IsInteger) then
    raise Exception.Create('Value is not numeric');

  trimmedValue := Trim(FRawValue);

  // Handle special YAML float values
  if SameText(trimmedValue, '.nan') or SameText(trimmedValue, '.NaN') or SameText(trimmedValue, '.NAN') then
    result := 0 //currency doesn't support NaN
  else if SameText(trimmedValue, '.inf') or SameText(trimmedValue, '.Inf') or SameText(trimmedValue, '.INF') or
          SameText(trimmedValue, '+.inf') or SameText(trimmedValue, '+.Inf') or SameText(trimmedValue, '+.INF') then
    result := 0 // or infinity
  else if SameText(trimmedValue, '-.inf') or SameText(trimmedValue, '-.Inf') or SameText(trimmedValue, '-.INF') then
    result := 0
  else if IsInteger then
    result := AsInteger
  else
    result := StrToCurr(trimmedValue, YAMLFormatSettings);
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
  len : integer;
begin
  if not IsFloat then
    raise Exception.Create('Value is not a float');

  // Common case: an ordinary number with no surrounding whitespace. The special
  // values below all start with '.', '+' or '-.', so they never take this path.
  len := Length(FRawValue);
  if (len > 0) and (FRawValue[len] > ' ') and
     (CharInSet(FRawValue[1], ['0'..'9']) or
      ((len > 1) and (FRawValue[1] = '-') and CharInSet(FRawValue[2], ['0'..'9']))) then
    exit(StrToFloat(FRawValue, YAMLFormatSettings));

  trimmedValue := Trim(FRawValue);

  // Handle special YAML float values, and the JSON5 spellings (exact case)
  if SameText(trimmedValue, '.nan') or SameText(trimmedValue, '.NaN') or SameText(trimmedValue, '.NAN') then
    result := NaN
  else if SameText(trimmedValue, '.inf') or SameText(trimmedValue, '.Inf') or SameText(trimmedValue, '.INF') or
          SameText(trimmedValue, '+.inf') or SameText(trimmedValue, '+.Inf') or SameText(trimmedValue, '+.INF') then
    result := Infinity
  else if SameText(trimmedValue, '-.inf') or SameText(trimmedValue, '-.Inf') or SameText(trimmedValue, '-.INF') then
    result := NegInfinity
  else if (trimmedValue = 'Infinity') or (trimmedValue = '+Infinity') then
    result := Infinity
  else if trimmedValue = '-Infinity' then
    result := NegInfinity
  else if (trimmedValue = 'NaN') or (trimmedValue = '+NaN') or (trimmedValue = '-NaN') then
    result := NaN
  else
    result := StrToFloat(trimmedValue, YAMLFormatSettings);
end;

function TYAMLValue.AsInteger : Int64;
var
  trimmedValue: string;
  decimalText : string;
  uInt64Value : UInt64;
  prefixAt : integer;
begin
  if not IsInteger then
    raise Exception.Create('Value is not an integer');

  trimmedValue := Trim(FRawValue);

  //safety
  if Length(trimmedValue) = 0 then
    exit(0);


  // Hexadecimal (0x), octal (0o) and binary (0b), converted exactly - with an optional sign,
  // as JSON5 allows -0x1F. As for a decimal, a value past High(Int64) is an error rather
  // than a wrapped-around number.
  if CharInSet(trimmedValue[1], ['-', '+']) then
    prefixAt := 2
  else
    prefixAt := 1;
  if (Length(trimmedValue) > prefixAt + 1) and (trimmedValue[prefixAt] = '0') and
     CharInSet(trimmedValue[prefixAt + 1], ['x', 'X', 'o', 'O', 'b', 'B']) then
  begin
    if not YAMLIntegerToDecimalText(trimmedValue, decimalText) then
      raise EConvertError.CreateFmt('Invalid integer value "%s"', [FRawValue]);
    if not TryStrToInt64(decimalText, result) then
      raise EConvertError.CreateFmt('Value "%s" is too large for Int64', [trimmedValue]);
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
      begin
        if uInt64Value <= UInt64(High(Int64)) then
          Exit(Int64(uInt64Value))
        else
          raise EConvertError.CreateFmt('Value "%s" is too large for Int64', [trimmedValue]);
      end;
    end;
    result := StrToInt64(trimmedValue);
  end;
end;

function TYAMLValue.AsMapping : IYAMLMapping;
begin
  if not IsMapping then
    raise Exception.Create('Value is not a mapping : ');
  result := nil; // GetInterface overwrites without releasing
  GetInterface(IYAMLMapping, result);
end;

function TYAMLValue.AsSequence : IYAMLSequence;
begin
  //todo : a set is a sequence too - should we allow it here
  if not IsSequence then
    raise Exception.Create('Value is not a sequence');
  result := nil; // GetInterface overwrites without releasing
  GetInterface(IYAMLSequence, result);
end;

function TYAMLValue.AsSet : IYAMLSet;
begin
  if not IsSet then
    raise Exception.Create('Value is not a set');
  result := nil; // GetInterface overwrites without releasing
  GetInterface(IYAMLSet, result);
end;

function TYAMLValue.AsString : string;
begin
  if IsNull then
    result := ''
  else
    result := FRawValue;
end;

constructor TYAMLValue.Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue, tag : string);
begin
  inherited Create;
  FParent := Pointer(parent);
  FValueType := valueType;
  FRawValue := rawValue;

  // Create tag info from string
  if tag <> '' then
  begin
    SetTag(tag);
    ApplyTagConversion;
  end;
end;

constructor TYAMLValue.Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue : string; const tagInfo : IYAMLTagInfo);
begin
  inherited Create;
  FParent := Pointer(parent);
  FValueType := valueType;
  FRawValue := rawValue;

  // Set backward compatible string tag
  if tagInfo <> nil then
  begin
    SetTagInfo(tagInfo);
    ApplyTagConversion;
  end;
end;

constructor TYAMLValue.CreateNull;
begin
  Create(nil, TYAMLValueType.vtNull, '','');
end;

destructor TYAMLValue.Destroy;
begin
  if FExtra <> nil then
    Dispose(FExtra);
  inherited;
end;

function TYAMLValue.Extra : PYAMLValueExtra;
begin
  if FExtra = nil then
    New(FExtra); // initialises the managed fields
  result := FExtra;
end;

// Comment lines are kept in arrays of exactly their length - a value rarely has more than a
// few. The getters return copies, so a caller cannot change a node's comments by accident.
procedure AppendLine(var lines : TArray<string>; const value : string);
var
  count : integer;
begin
  count := Length(lines);
  SetLength(lines, count + 1);
  lines[count] := value;
end;

function TYAMLValue.GetHasComments : boolean;
begin
  result := (FExtra <> nil) and (Length(FExtra^.Comments) > 0);
end;

function TYAMLValue.GetComments : TArray<string>;
begin
  if FExtra <> nil then
    result := Copy(FExtra^.Comments)
  else
    result := nil;
end;

procedure TYAMLValue.SetComments(const value : TArray<string>);
begin
  if Length(value) > 0 then
    Extra^.Comments := Copy(value)
  else if FExtra <> nil then
    FExtra^.Comments := nil;
end;

procedure TYAMLValue.AddComment(const value : string);
begin
  AppendLine(Extra^.Comments, value);
end;

procedure TYAMLValue.ClearComments;
begin
  if FExtra <> nil then
    FExtra^.Comments := nil;
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
  if FExtra <> nil then
    result := FExtra^.Comment
  else
    result := '';
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
  if FExtra <> nil then
    result := FExtra^.Tag
  else
    result := '';
end;

function TYAMLValue.GetTagInfo : IYAMLTagInfo;
begin
  if FExtra <> nil then
    result := FExtra^.TagInfo
  else
    result := nil;
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
  if (FExtra <> nil) and (FExtra^.TagInfo <> nil) then
    result := SameText(FExtra^.TagInfo.ResolvedTag, TagName) or SameText(FExtra^.TagInfo.OriginalText, TagName)
  else
    result := SameText(GetTag, TagName);
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
  if (value <> '') or (FExtra <> nil) then
    Extra^.Comment := value;
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
  if GetTag <> '' then
    result := GetTag + ' ' + result;
end;

function TYAMLValue.TryGetValue(const key : string; out value : IYAMLValue) : boolean;
begin
  raise Exception.Create('Cannot access values on non-mapping type');
end;

// Tag modification methods

procedure TYAMLValue.SetTag(const tag : string);
begin
  if (tag = '') and (FExtra = nil) then
    exit;
  Extra^.Tag := tag;
  if tag <> '' then
    FExtra^.TagInfo := TYAMLTagInfoFactory.ParseTag(tag)
  else
    FExtra^.TagInfo := nil; //TYAMLTagInfoFactory.CreateUnresolvedTag();
end;

procedure TYAMLValue.SetTagInfo(const tagInfo : IYAMLTagInfo);
begin
  if (tagInfo = nil) and (FExtra = nil) then
    exit;
  Extra^.TagInfo := tagInfo;
  if tagInfo <> nil then
    FExtra^.Tag := tagInfo.ToString
  else
    FExtra^.Tag := '';
end;

procedure TYAMLValue.ClearTag;
begin
  if FExtra <> nil then
  begin
    FExtra^.Tag := '';
    FExtra^.TagInfo := nil; //TYAMLTagInfoFactory.CreateUnresolvedTag();
  end;
end;

function TYAMLValue.Clone : IYAMLValue;
begin
  result := CloneNode(nil);
end;

function TYAMLValue.CloneNode(const parent : IYAMLValue) : IYAMLValue;
var
  node : TYAMLValue;
begin
  // the type and text as they are - no tag conversion, which the original has had
  node := TYAMLValue.Create(parent, FValueType, FRawValue, '');
  result := node;
  CopyExtraTo(node);
end;

procedure TYAMLValue.CopyExtraTo(target : TYAMLValue);
var
  extra : PYAMLValueExtra;
begin
  if FExtra = nil then
    exit;
  extra := target.Extra;
  extra^.Tag := FExtra^.Tag;
  extra^.TagInfo := FExtra^.TagInfo; // tag info cannot be changed, so it can be shared
  extra^.Comment := FExtra^.Comment;
  extra^.Comments := Copy(FExtra^.Comments);
  extra^.EndComments := Copy(FExtra^.EndComments);
end;

procedure TYAMLValue.CheckDetached(const value : IYAMLValue);
var
  valueObj, ancestorObj : TObject;
  ancestor : Pointer;
begin
  if value = nil then
    raise EArgumentNilException.Create('Cannot add nil to a collection');
  if value.Parent <> nil then
    raise EArgumentException.Create('The value is already in a collection - remove it from there first, or add a Clone of it');
  // going up from this collection must not reach value, or the tree would hold itself
  valueObj := value as TObject;
  ancestorObj := Self;
  while true do
  begin
    if ancestorObj = valueObj then
      raise EArgumentException.Create('A collection cannot hold itself or a collection it is in');
    if not (ancestorObj is TYAMLValue) then
      break;
    ancestor := TYAMLValue(ancestorObj).FParent;
    if ancestor = nil then
      break;
    ancestorObj := IYAMLValue(ancestor) as TObject;
  end;
end;

{ TYAMLSequence }

function TYAMLSequence.AddMapping(const tag : string) : IYAMLMapping;
begin
  result := TYAMLMapping.Create(Self, tag);
  AddCreated(result);
end;

function TYAMLSequence.AddCurrencyValue(const value: Currency; const tagInfo: IYAMLTagInfo): IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, CurrToStr(value, YAMLFormatSettings), tagInfo);
  AddCreated(result);
end;

function TYAMLSequence.AddCurrencyValue(const value: Currency; const tag: string): IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, CurrToStr(value, YAMLFormatSettings), tag);
  AddCreated(result);
end;

function TYAMLSequence.AddMapping(const tagInfo : IYAMLTagInfo) : IYAMLMapping;
begin
  result := TYAMLMapping.Create(Self, tagInfo);
  AddCreated(result);
end;


function TYAMLSequence.AddSequence(const tag : string) : IYAMLSequence;
begin
  result := TYAMLSequence.Create(Self, tag);
  AddCreated(result);
end;

function TYAMLSequence.AddSequence(const tagInfo : IYAMLTagInfo) : IYAMLSequence;
begin
  result := TYAMLSequence.Create(Self, tagInfo);
  AddCreated(result);
end;


function TYAMLSequence.AddSet(const tag : string) : IYAMLSet;
begin
  result := TYAMLSet.Create(Self, tag);
  AddCreated(result);
end;

function TYAMLSequence.AddSet(const tagInfo : IYAMLTagInfo) : IYAMLSet;
begin
  result := TYAMLSet.Create(Self, tagInfo);
  AddCreated(result);
end;




// Tag-aware AddValue implementations

function TYAMLSequence.AddValue(const value : boolean; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtBoolean, LowerCase(BoolToStr(value, true)), tag);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtBoolean, LowerCase(BoolToStr(value, true)), tagInfo);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : Int32; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tag);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : Int32; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tagInfo);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : UInt32; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tag);
  AddCreated(result);
end;

procedure TYAMLSequence.AddValue(const value : IYAMLValue);
begin
  CheckDetached(value);
  if AddItem(value) then
    YAMLSetParent(value, Self);
end;

function TYAMLSequence.AddItem(const value : IYAMLValue) : boolean;
begin
  FItems.Add(value);
  result := true;
end;

function TYAMLSequence.InsertItem(index : integer; const value : IYAMLValue) : boolean;
begin
  FItems.Insert(index, value);
  result := true;
end;

// value was made with this sequence as its parent. A set that already has the value does not
// take it, so it is left in no collection.
procedure TYAMLSequence.AddCreated(const value : IYAMLValue);
begin
  if not AddItem(value) then
    YAMLSetParent(value, nil);
end;

procedure TYAMLSequence.InsertCreated(index : integer; const value : IYAMLValue);
begin
  if not InsertItem(index, value) then
    YAMLSetParent(value, nil);
end;

// The A[] and O[] setters: as AddOrSetValue(key, IYAMLValue) on a mapping. nil writes a null,
// as JsonDataObjects does, and the node the item already is changes nothing.
procedure TYAMLSequence.SetCollectionAt(index : integer; const value : IYAMLValue);
begin
  if (index < 0) or (index >= FItems.Count) then
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
  if value = nil then
  begin
    FItems.Replace(index, TYAMLValue.Create(Self, TYAMLValueType.vtNull, ''), Self);
    exit;
  end;
  if (FItems.FValues[index] <> nil) and ((FItems.FValues[index] as TObject) = (value as TObject)) then
    exit;
  CheckDetached(value);
  YAMLSetParent(value, Self);
  FItems.Replace(index, value, Self);
end;

procedure TYAMLSequence.CheckInsertIndex(index : integer);
begin
  if (index < 0) or (index > FItems.Count) then
    raise EArgumentOutOfRangeException.CreateFmt('Cannot insert at index %d - it must be 0 to %d', [index, FItems.Count]);
end;

procedure TYAMLSequence.Delete(index : integer);
begin
  if (index < 0) or (index >= FItems.Count) then
    raise EArgumentOutOfRangeException.CreateFmt('Cannot delete index %d - the sequence has %d items', [index, FItems.Count]);
  // the item, if it is still referenced elsewhere, must not keep this sequence as its parent
  DetachReplaced(FItems.FValues[index], nil, Self);
  FItems.Delete(index);
end;

procedure TYAMLSequence.InsertValue(index : integer; const value : IYAMLValue);
begin
  CheckInsertIndex(index);
  CheckDetached(value);
  if InsertItem(index, value) then
    YAMLSetParent(value, Self);
end;

function TYAMLSequence.InsertValue(index : integer; const value : string; const tag : string) : IYAMLValue;
begin
  CheckInsertIndex(index);
  result := TYAMLValue.Create(Self, TYAMLValueType.vtString, value, tag);
  InsertCreated(index, result);
end;

function TYAMLSequence.InsertValue(index : integer; const value : Int64; const tag : string) : IYAMLValue;
begin
  CheckInsertIndex(index);
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tag);
  InsertCreated(index, result);
end;

function TYAMLSequence.InsertValue(index : integer; const value : Double; const tag : string) : IYAMLValue;
begin
  CheckInsertIndex(index);
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, YAMLFloatToStr(value), tag);
  InsertCreated(index, result);
end;

function TYAMLSequence.InsertValue(index : integer; const value : Boolean; const tag : string) : IYAMLValue;
begin
  CheckInsertIndex(index);
  result := TYAMLValue.Create(Self, TYAMLValueType.vtBoolean, LowerCase(BoolToStr(value, true)), tag);
  InsertCreated(index, result);
end;

function TYAMLSequence.InsertNull(index : integer; const tag : string) : IYAMLValue;
begin
  CheckInsertIndex(index);
  result := TYAMLValue.Create(Self, TYAMLValueType.vtNull, '', tag);
  InsertCreated(index, result);
end;

function TYAMLSequence.InsertNumber(index : integer; const value : string) : IYAMLValue;
begin
  CheckInsertIndex(index);
  result := CreateNumberValue(Self, value);
  InsertCreated(index, result);
end;

function TYAMLSequence.InsertMapping(index : integer; const tag : string) : IYAMLMapping;
begin
  CheckInsertIndex(index);
  result := TYAMLMapping.Create(Self, tag);
  InsertCreated(index, result);
end;

function TYAMLSequence.InsertSequence(index : integer; const tag : string) : IYAMLSequence;
begin
  CheckInsertIndex(index);
  result := TYAMLSequence.Create(Self, tag);
  InsertCreated(index, result);
end;

function TYAMLSequence.CloneNode(const parent : IYAMLValue) : IYAMLValue;
var
  node : TYAMLSequence;
  i : integer;
begin
  // the same class, so a set stays a set
  node := TYAMLSequenceClass(ClassType).Create(parent, '');
  result := node;
  CopyExtraTo(node);
  for i := 0 to FItems.Count - 1 do
    node.FItems.Add(TYAMLValue(FItems.FValues[i] as TObject).CloneNode(result));
end;

function TYAMLSequence.AddValue(const value : UInt32; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tagInfo);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : Int64; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tag);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : Int64; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tagInfo);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : UInt64; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tag);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : UInt64; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tagInfo);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : Single; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, YAMLFloatToStr(value), tag);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : Single; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, YAMLFloatToStr(value), tagInfo);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : Double; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, YAMLFloatToStr(value), tag);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : Double; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, YAMLFloatToStr(value), tagInfo);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : string; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtString, value, tag);
  AddCreated(result);
end;

function TYAMLSequence.AddNull(const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtNull, '', tag);
  AddCreated(result);
end;

function TYAMLSequence.AddNumber(const value : string) : IYAMLValue;
begin
  result := CreateNumberValue(Self, value);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : string; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtString, value, tagInfo);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : TDateTime; isUTC : boolean; const tag : string) : IYAMLValue;
begin
  if isUTC then
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.UTCDateToISO8601Str(value), tag)
  else
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.LocalDateToISO8601Str(value), tag);
  AddCreated(result);
end;

function TYAMLSequence.AddValue(const value : TDateTime; isUTC : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  if isUTC then
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.UTCDateToISO8601Str(value), tagInfo)
  else
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.LocalDateToISO8601Str(value), tagInfo);
  AddCreated(result);
end;


constructor TYAMLSequence.Create(const parent : IYAMLValue; const tag : string);
var
  vt : TYAMLValueType;
begin
  vt := GetNodeValueType;
  inherited Create(parent, vt, '', tag);
end;

procedure TYAMLSequence.Clear;
var
  i : integer;
begin
  // items still referenced elsewhere must not keep this sequence as their parent
  for i := 0 to FItems.Count - 1 do
    DetachReplaced(FItems.FValues[i], nil, Self);
  FItems.Clear;
  ClearComments;
  ClearEndComments;
end;

constructor TYAMLSequence.Create(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo);
var
  vt : TYAMLValueType;
begin
  vt := GetNodeValueType;
  inherited Create(parent, vt, '', tagInfo);
end;


destructor TYAMLSequence.Destroy;
{$IF defined(AUTOREFCOUNT) or not defined(XE3PLUS)}
var
  i : integer;
begin
  for i := 0 to FItems.Count - 1 do
    DetachFromParent(FItems.FValues[i]);
  inherited;
end;
{$ELSE}
begin
  ReleaseChildren(FItems.FValues);
  FItems.FCount := 0;
  inherited;
end;
{$IFEND}


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
    result := ScalarToBoolean(FItems[index])
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

function TYAMLSequence.GetCount : integer;
begin
  result := FItems.Count;
end;

function TYAMLSequence.GetCurrency(index: Integer): Currency;
begin
  if (index >= 0) and (index < FItems.Count) then
    result := ScalarToCurrency(FItems[index])
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

function TYAMLSequence.GetDateTime(index: Integer): TDateTime;
begin
  if (index >= 0) and (index < FItems.Count) then
    result := ScalarToDateTime(FItems[index], false)
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

function TYAMLSequence.GetFloat(index: Integer): Double;
begin
  if (index >= 0) and (index < FItems.Count) then
    result := ScalarToFloat(FItems[index])
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

function TYAMLSequence.GetInt(index: Integer): Integer;
begin
  if (index >= 0) and (index < FItems.Count) then
    result := Integer(ScalarToInt64(FItems[index]))
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));

end;

function TYAMLSequence.GetItem(Index : integer) : IYAMLValue;
begin
  if (index >= 0) and (index < FItems.Count) then
    result := FItems[index]
  else
    // a null that is in no collection, as it is not in this one
    result := TYAMLValue.Create(nil, TYAMLValueType.vtNull, '', '');
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
    result := ScalarToInt64(FItems[index])
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
    result := ScalarToUInt64(FItems[index])
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

function TYAMLSequence.GetUtcDateTime(index: Integer): TDateTime;
begin
  if (index >= 0) and (index < FItems.Count) then
    result := ScalarToDateTime(FItems[index], true)
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

function TYAMLSequence.GetValue(const key : string) : IYAMLValue;
begin
  raise Exception.Create('Cannot access Values on sequence type. Use Nodes[index] instead.');
end;


procedure TYAMLSequence.SetArray(index: Integer; const value: IYAMLSequence);
begin
  SetCollectionAt(index, value);
end;

procedure TYAMLSequence.SetBool(index: Integer; const value: Boolean);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems.Replace(index, TYAMLValue.Create(Self, TYAMLValueType.vtBoolean, LowerCase(BoolToStr(value,true))), Self)
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

procedure TYAMLSequence.SetCurrency(index: Integer; const value: Currency);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems.Replace(index, TYAMLValue.Create(Self, TYAMLValueType.vtFloat, CurrToStr(value, YAMLFormatSettings)), Self)
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

procedure TYAMLSequence.SetDateTime(index: Integer; const value: TDateTime);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems.Replace(index, TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.LocalDateToISO8601Str(value)), Self)
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

procedure TYAMLSequence.SetFloat(index: Integer; const value: double);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems.Replace(index, TYAMLValue.Create(Self, TYAMLValueType.vtFloat, YAMLFloatToStr(value)), Self)
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
    FItems.Replace(index, TYAMLValue.Create(Self, TYAMLValueType.vtString, value), Self)
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

procedure TYAMLSequence.SetLong(index: Integer; const value: Int64);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems.Replace(index, TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value)), Self)
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;


procedure TYAMLSequence.SetObject(index: Integer; const value: IYAMLMapping);
begin
  SetCollectionAt(index, value);
end;

procedure TYAMLSequence.SetULong(index: Integer; const value: UInt64);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems.Replace(index, TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value)), Self)
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

procedure TYAMLSequence.SetUtcDateTime(index: Integer; const value: TDateTime);
begin
  if (index >= 0) and (index < FItems.Count) then
    FItems.Replace(index, TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.UTCDateToISO8601Str(value)), Self)
  else
    raise EArgumentOutOfRangeException.Create('Index > ' + IntToStr(FItems.Count));
end;

{ TYAMLMapping }

function TYAMLMapping.AddOrSetMapping(const key : string; const tag : string = '') : IYAMLMapping;
begin
  result := TYAMLMapping.Create(Self, tag);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetMapping(const key : string;  const tagInfo : IYAMLTagInfo) : IYAMLMapping;
begin
  result := TYAMLMapping.Create(Self, tagInfo);
  AddOrSetEntry(key, result);
end;


function TYAMLMapping.AddOrSetSequence(const key : string; const tag : string = '') : IYAMLSequence;
begin
  result := TYAMLSequence.Create(Self, tag);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetSequence(const key : string; const tagInfo : IYAMLTagInfo) : IYAMLSequence;
begin
  result := TYAMLSequence.Create(Self, tagInfo);
  AddOrSetEntry(key, result);
end;


function TYAMLMapping.AddOrSetSet(const key : string; const tag : string = '') : IYAMLSet;
begin
  result := TYAMLSet.Create(Self, tag);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetSet(const key : string; const tagInfo : IYAMLTagInfo) : IYAMLSet;
begin
  result := TYAMLSet.Create(Self, tagInfo);
  AddOrSetEntry(key, result);
end;


function TYAMLMapping.AddOrSetValue(const key : string; const value : Single) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, YAMLFloatToStr(value));
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Double) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, YAMLFloatToStr(value));
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key, value : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtString,value);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetNull(const key : string; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtNull, '', tag);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetNumber(const key : string; const value : string) : IYAMLValue;
begin
  result := CreateNumberValue(Self, value);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : TDateTime; isUTC : boolean) : IYAMLValue;
begin
  if isUTC then
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.UTCDateToISO8601Str(value), '!!timestamp')
  else
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.LocalDateToISO8601Str(value), '!!timestamp');
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : UInt64) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value));
  AddOrSetEntry(key, result);
end;

const
  cIndexThreshold = 8;

{$IFOPT Q+}{$DEFINE YAML_KEYHASH_Q}{$Q-}{$ENDIF} // the hash wraps on purpose
function KeyHash(const key : string) : Cardinal;
var
  i : integer;
  p : PChar;
begin
  // FNV-1a, as the string interner
  result := 2166136261;
  p := PChar(Pointer(key));
  for i := 0 to Length(key) - 1 do
    result := (result xor Ord(p[i])) * 16777619;
end;
{$IFDEF YAML_KEYHASH_Q}{$Q+}{$UNDEF YAML_KEYHASH_Q}{$ENDIF}

function TYAMLMapping.FindKey(const key : string; out hash : Cardinal) : integer;
var
  slotCount, mask, slot : integer;
  entry : Cardinal;
begin
  if FIndex <> nil then
  begin
    hash := KeyHash(key);
    slotCount := (Length(FIndex) div 3) * 2;
    mask := slotCount - 1;
    slot := integer(hash and Cardinal(mask));
    while true do
    begin
      entry := FIndex[slot];
      if entry = 0 then
        exit(-1);
      result := integer(entry) - 1;
      if (FIndex[slotCount + result] = hash) and (FEntries[result].Key = key) then
        exit;
      slot := (slot + 1) and mask;
    end;
  end;
  hash := 0;
  for result := 0 to FCount - 1 do
    if FEntries[result].Key = key then
      exit;
  result := -1;
end;

function TYAMLMapping.IndexOfKey(const key : string) : integer;
var
  hash : Cardinal;
begin
  result := FindKey(key, hash);
end;

// Puts entry index into the index's table, by the hash the index holds for it.
procedure TYAMLMapping.IndexInsert(index, slotCount : integer);
var
  mask, slot : integer;
begin
  mask := slotCount - 1;
  slot := integer(FIndex[slotCount + index] and Cardinal(mask));
  while FIndex[slot] <> 0 do
    slot := (slot + 1) and mask;
  FIndex[slot] := Cardinal(index + 1);
end;

// (Re)builds the index with slotCount slots for the first FCount keys. Their hashes come from
// the index being replaced where it has them, and are worked out for the rest.
procedure TYAMLMapping.BuildIndex(slotCount : integer);
var
  old : TArray<Cardinal>;
  oldSlotCount, known, i : integer;
begin
  old := FIndex;
  oldSlotCount := (Length(old) div 3) * 2;
  known := oldSlotCount div 2;
  FIndex := nil;
  SetLength(FIndex, slotCount + slotCount div 2); // all 0
  for i := 0 to FCount - 1 do
  begin
    if i < known then
      FIndex[slotCount + i] := old[oldSlotCount + i]
    else
      FIndex[slotCount + i] := KeyHash(FEntries[i].Key);
    IndexInsert(i, slotCount);
  end;
end;

// Doubles the entries' capacity. The first time (4 to 8) the entries go to a new array of
// just that size: growing a small array in place has the memory manager leave room for it to
// grow again, which for the many small mappings of a document adds up to a lot. A larger
// array grows in place, where that room saves copying it each time it doubles.
procedure TYAMLMapping.GrowEntries;
var
  grown : TArray<TYAMLMappingEntry>;
begin
  if Length(FEntries) = 0 then
    SetLength(FEntries, 4)
  else if Length(FEntries) = 4 then
  begin
    SetLength(grown, 8);
    // the references move as they are: the old array is cleared rather than released
    Move(FEntries[0], grown[0], FCount * SizeOf(TYAMLMappingEntry));
    FillChar(FEntries[0], FCount * SizeOf(TYAMLMappingEntry), 0);
    FEntries := grown;
  end
  else
    SetLength(FEntries, Length(FEntries) * 2);
end;

procedure TYAMLMapping.AddOrSetValue(const key : string; const value : IYAMLValue);
var
  idx : integer;
  hash : Cardinal;
begin
  // setting a key to the node it already holds changes nothing
  if value <> nil then
  begin
    idx := FindKey(key, hash);
    if (idx >= 0) and (FEntries[idx].Value <> nil) and ((FEntries[idx].Value as TObject) = (value as TObject)) then
      exit;
  end;
  CheckDetached(value);
  YAMLSetParent(value, Self);
  AddOrSetEntry(key, value);
end;

function TYAMLMapping.Remove(const key : string) : boolean;
var
  idx, slotCount, i : integer;
  hash : Cardinal;
begin
  idx := FindKey(key, hash);
  if idx < 0 then
    exit(false);
  // the value, if it is still referenced elsewhere, must not keep this mapping as its parent
  DetachReplaced(FEntries[idx].Value, nil, Self);
  FEntries[idx].Key := '';
  FEntries[idx].Value := nil;
  Dec(FCount);
  if idx < FCount then
  begin
    // the entries after it move down as they are; the last slot, now a duplicate, is cleared
    Move(FEntries[idx + 1], FEntries[idx], (FCount - idx) * SizeOf(TYAMLMappingEntry));
    FillChar(FEntries[FCount], SizeOf(TYAMLMappingEntry), 0);
  end;
  if FIndex <> nil then
  begin
    if FCount > cIndexThreshold then
    begin
      // the index holds each key's hash at the key's position: move them down too, then
      // rebuild the table from them
      slotCount := (Length(FIndex) div 3) * 2;
      for i := idx to FCount - 1 do
        FIndex[slotCount + i] := FIndex[slotCount + i + 1];
      BuildIndex(slotCount);
    end
    else
      FIndex := nil; // few enough keys to scan
  end;
  result := true;
end;

function TYAMLMapping.CloneNode(const parent : IYAMLValue) : IYAMLValue;
var
  node : TYAMLMapping;
  i : integer;
begin
  node := TYAMLMapping.Create(parent, '');
  result := node;
  CopyExtraTo(node);
  for i := 0 to FCount - 1 do
    node.AddOrSetEntry(FEntries[i].Key, TYAMLValue(FEntries[i].Value as TObject).CloneNode(result));
end;

procedure TYAMLMapping.AddOrSetEntry(const key : string; const value : IYAMLValue);
var
  idx, slotCount : integer;
  hash : Cardinal;
begin
  idx := FindKey(key, hash);
  if idx >= 0 then
  begin
    DetachReplaced(FEntries[idx].Value, value, Self);
    FEntries[idx].Value := value;
    exit;
  end;
  if FCount = Length(FEntries) then
    GrowEntries;
  FEntries[FCount].Key := key;
  FEntries[FCount].Value := value;
  Inc(FCount);
  if FIndex <> nil then
  begin
    slotCount := (Length(FIndex) div 3) * 2;
    if FCount * 2 > slotCount then
      BuildIndex(slotCount * 2)
    else
    begin
      FIndex[slotCount + FCount - 1] := hash;
      IndexInsert(FCount - 1, slotCount);
    end;
  end
  else if FCount > cIndexThreshold then
  begin
    slotCount := 16;
    while slotCount < FCount * 2 do
      slotCount := slotCount * 2;
    BuildIndex(slotCount);
  end;
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : boolean) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtBoolean, LowerCase(BoolToStr(value, true)));
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Int32) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value));
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : UInt32) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value));
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Int64) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value));
  AddOrSetEntry(key, result);
end;

// Tag-aware AddOrSetValue implementations

function TYAMLMapping.AddOrSetValue(const key : string; const value : boolean; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtBoolean, LowerCase(BoolToStr(value, true)), tag);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtBoolean, LowerCase(BoolToStr(value, true)), tagInfo);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Int32; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tag);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Int32; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tagInfo);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : UInt32; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tag);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : UInt32; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tagInfo);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Int64; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tag);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Int64; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, IntToStr(value), tagInfo);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : UInt64; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tag);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : UInt64; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtInteger, UIntToStr(value), tagInfo);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Single; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, YAMLFloatToStr(value), tag);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Single; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, YAMLFloatToStr(value), tagInfo);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Double; const tag : string) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, YAMLFloatToStr(value), tag);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : Double; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, YAMLFloatToStr(value), tagInfo);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : string; const tag : string) : IYAMLValue;
begin
  // '' is an empty string, as AddValue('') is on a sequence - AddOrSetNull writes a null
  result := TYAMLValue.Create(Self, TYAMLValueType.vtString, value, tag);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : string; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtString, value, tagInfo);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : TDateTime; isUTC : boolean; const tag : string) : IYAMLValue;
begin
  if isUTC then
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.UTCDateToISO8601Str(value), tag)
  else
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.LocalDateToISO8601Str(value), tag);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key : string; const value : TDateTime; isUTC : boolean; const tagInfo : IYAMLTagInfo) : IYAMLValue;
begin
  if isUTC then
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.UTCDateToISO8601Str(value), tagInfo)
  else
    result := TYAMLValue.Create(Self, TYAMLValueType.vtTimestamp, TYAMLDateUtils.LocalDateToISO8601Str(value), tagInfo);
  AddOrSetEntry(key, result);
end;


function TYAMLMapping.AddOrSetCurrencyValue(const key: string; const value: Currency; const tagInfo: IYAMLTagInfo): IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, CurrToStr(value, YAMLFormatSettings), tagInfo);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetCurrencyValue(const key: string; const value: Currency; const tag: string): IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, CurrToStr(value, YAMLFormatSettings), tag);
  AddOrSetEntry(key, result);
end;

function TYAMLMapping.AddOrSetValue(const key: string; const value: Currency): IYAMLValue;
begin
  result := TYAMLValue.Create(Self, TYAMLValueType.vtFloat, CurrToStr(value, YAMLFormatSettings));
  AddOrSetEntry(key, result);
end;

procedure TYAMLMapping.Clear;
var
  i : integer;
begin
  // values still referenced elsewhere must not keep this mapping as their parent
  for i := 0 to FCount - 1 do
    DetachReplaced(FEntries[i].Value, nil, Self);
  FEntries := nil;
  FIndex := nil;
  FCount := 0;
  if FExtra <> nil then
  begin
    FExtra^.Comments := nil;
    FExtra^.EndComments := nil;
    FExtra^.Comment := '';
  end;
end;

function TYAMLMapping.Contains(const key: string): boolean;
begin
  result := IndexOfKey(key) >= 0;
end;

function TYAMLMapping.ContainsKey(const key : string) : boolean;
begin
  result := IndexOfKey(key) >= 0;
end;

constructor TYAMLMapping.Create(const parent : IYAMLValue; const tag : string);
begin
  inherited Create(parent, TYAMLValueType.vtMapping, '', tag);
end;

constructor TYAMLMapping.Create(const parent : IYAMLValue; const tagInfo : IYAMLTagInfo);
begin
  inherited Create(parent, TYAMLValueType.vtMapping, '', tagInfo);
end;


destructor TYAMLMapping.Destroy;
{$IF defined(AUTOREFCOUNT) or not defined(XE3PLUS)}
var
  i : integer;
begin
  for i := 0 to FCount - 1 do
    DetachFromParent(FEntries[i].Value);
  inherited Destroy;
end;
{$ELSE}
begin
  BeginReleasingChildren;
  try
    FEntries := nil;
  finally
    EndReleasingChildren;
  end;
  inherited Destroy;
end;
{$IFEND}

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
  result := FCount;
end;

function TYAMLMapping.GetKey(Index : integer) : string;
begin
  if (Index < 0) or (Index >= FCount) then
    raise EArgumentOutOfRangeException.Create('Index out of range');
  result := FEntries[index].Key
end;

function TYAMLMapping.ValueAt(index : integer) : IYAMLValue;
begin
  if (index < 0) or (index >= FCount) then
    raise EArgumentOutOfRangeException.Create('Index out of range');
  result := FEntries[index].Value;
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

// The scalar getters read a missing key as the default without adding it, as JsonDataObjects
// does - only A[] and O[] create what they are asked for.

function TYAMLMapping.ValueOrNil(const key : string) : IYAMLValue;
var
  idx : integer;
begin
  idx := IndexOfKey(key);
  if idx >= 0 then
    result := FEntries[idx].Value
  else
    result := nil;
end;

function TYAMLMapping.GetObjectBool(const key: string): Boolean;
begin
  result := ScalarToBoolean(ValueOrNil(key));
end;

function TYAMLMapping.GetObjectCurrency(const key: string): Currency;
begin
  result := ScalarToCurrency(ValueOrNil(key));
end;

function TYAMLMapping.GetObjectDateTime(const key: string): TDateTime;
begin
  result := ScalarToDateTime(ValueOrNil(key), false);
end;

function TYAMLMapping.GetObjectFloat(const key: string): Double;
begin
  result := ScalarToFloat(ValueOrNil(key));
end;

function TYAMLMapping.GetObjectInt(const key: string): Integer;
begin
  result := Integer(ScalarToInt64(ValueOrNil(key)));
end;

function TYAMLMapping.GetObjectLong(const key: string): Int64;
begin
  result := ScalarToInt64(ValueOrNil(key));
end;

function TYAMLMapping.GetObjectString(const key: string): string;
var
  value : IYAMLValue;
begin
  value := ValueOrNil(key);
  if value <> nil then
    result := value.AsString
  else
    result := '';
end;

function TYAMLMapping.GetObjectULong(const key: string): UInt64;
begin
  result := ScalarToUInt64(ValueOrNil(key));
end;

function TYAMLMapping.GetObjectUtcDateTime(const key: string): TDateTime;
begin
  result := ScalarToDateTime(ValueOrNil(key), true);
end;

function TYAMLMapping.GetValue(const key : string) : IYAMLValue;
var
  idx : integer;
begin
  idx := IndexOfKey(key);
  if idx >= 0 then
    result := FEntries[idx].Value
  else
    // a null that is in no collection, as it is not in this one
    result := TYAMLValue.Create(nil, TYAMLValueType.vtNull,'');
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
      // Copy scalars to avoid shared ownership issues - the text, type and tag as they are,
      // since re-making them from AsInteger / AsFloat cannot hold every value
      if value.IsScalar then
        copiedValue := TYAMLValue.Create(Self, value.ValueType, value.RawValue, value.TagInfo)
      else
        // For complex types like mappings and sequences, reference the original
        // (this is safe as long as the source mapping outlives the target)
        //TODO : replace this with a deeep copy
        copiedValue := value;

      AddOrSetEntry(key, copiedValue);
    end;
  end;

end;

// A[] and O[] work as AddOrSetValue(key, IYAMLValue); nil writes a null, as JsonDataObjects
// does
procedure TYAMLMapping.SetArray(const key: string; const Value: IYAMLSequence);
begin
  if Value = nil then
    AddOrSetNull(key)
  else
    AddOrSetValue(key, IYAMLValue(Value));
end;

procedure TYAMLMapping.SetObject(const key: string; const Value: IYAMLMapping);
begin
  if Value = nil then
    AddOrSetNull(key)
  else
    AddOrSetValue(key, IYAMLValue(Value));
end;

procedure TYAMLMapping.SetObjectBool(const key: string; const Value: Boolean);
begin
  AddOrSetValue(key,Value);
end;

procedure TYAMLMapping.SetObjectCurrency(const key: string; const Value: Currency);
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
var
  idx : integer;
begin
  idx := IndexOfKey(key);
  result := idx >= 0;
  if result then
    value := FEntries[idx].Value
  else
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

function TYAMLDocument.GetEndComments : TArray<string>;
begin
  result := Copy(FEndComments);
end;

procedure TYAMLDocument.SetEndComments(const value : TArray<string>);
begin
  FEndComments := Copy(value);
end;

procedure TYAMLDocument.AddEndComment(const value : string);
begin
  AppendLine(FEndComments, value);
end;

procedure TYAMLDocument.ClearEndComments;
begin
  FEndComments := nil;
end;

function TYAMLDocument.GetHasEndComments : boolean;
begin
  result := Length(FEndComments) > 0;
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

function TYAMLDocument.QueryMatches(const expression : string) : TArray<TYAMLPathMatch>;
begin
  result := TYAMLPathProcessor.QueryMatches(FRoot, expression);
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
  FMaxLineLength := 0; // no folding
  FWriteBOM := false;
  FEmitTags := true;
  FEmitExplicitNull := false;
  FEmitDocumentMarkers := false;
  FEmitTagDirectives := false;
  FEmitYAMLDirective := false;
  FPrettyPrint := true;
  FEscapeNonASCII := false;
  FBlockScalarStyle := TYAMLBlockScalarStyle.bssNone;
  {$WARN SYMBOL_DEPRECATED OFF}
  FBlockChompingIndicator := TYAMLBlockChompingIndicator.bciClip;
  {$WARN SYMBOL_DEPRECATED DEFAULT}
  FJSON5UnquotedKeys := true;
  FJSON5SingleQuotes := false;
  FJSON5TrailingCommas := false;
end;

constructor TYAMLEmitOptions.CreateClone(const source: IYAMLEmitOptions);
begin
  inherited Create;
  // Deep copy non-standard encodings to prevent double-free in destructor
  if (source.Encoding <> nil) and (not TEncoding.IsStandardEncoding(source.Encoding)) then
    FEncoding := TEncoding.GetEncoding(source.Encoding.CodePage)
  else
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
  FEscapeNonASCII := source.EscapeNonASCII;
  FBlockScalarStyle := source.BlockScalarStyle;
  // deprecated, but still kept, so a copy reads back what was set
  {$WARN SYMBOL_DEPRECATED OFF}
  FBlockChompingIndicator := source.BlockChompingIndicator;
  {$WARN SYMBOL_DEPRECATED DEFAULT}
  FJSON5UnquotedKeys := source.JSON5UnquotedKeys;
  FJSON5SingleQuotes := source.JSON5SingleQuotes;
  FJSON5TrailingCommas := source.JSON5TrailingCommas;
end;

function TYAMLEmitOptions.GetJSON5SingleQuotes : boolean;
begin
  result := FJSON5SingleQuotes;
end;

function TYAMLEmitOptions.GetJSON5TrailingCommas : boolean;
begin
  result := FJSON5TrailingCommas;
end;

function TYAMLEmitOptions.GetJSON5UnquotedKeys : boolean;
begin
  result := FJSON5UnquotedKeys;
end;

procedure TYAMLEmitOptions.SetJSON5SingleQuotes(value : boolean);
begin
  FJSON5SingleQuotes := value;
end;

procedure TYAMLEmitOptions.SetJSON5TrailingCommas(value : boolean);
begin
  FJSON5TrailingCommas := value;
end;

procedure TYAMLEmitOptions.SetJSON5UnquotedKeys(value : boolean);
begin
  FJSON5UnquotedKeys := value;
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
  // 0 is no limit
  FMaxLineLength := value;
end;

procedure TYAMLEmitOptions.SetPrettyPrint(const value: boolean);
begin
  FPrettyPrint := value;
end;

function TYAMLEmitOptions.GetEscapeNonASCII : boolean;
begin
  result := FEscapeNonASCII;
end;

procedure TYAMLEmitOptions.SetEscapeNonASCII(const value : boolean);
begin
  FEscapeNonASCII := value;
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

function TYAMLEmitOptions.GetBlockScalarStyle : TYAMLBlockScalarStyle;
begin
  result := FBlockScalarStyle;
end;

procedure TYAMLEmitOptions.SetBlockScalarStyle(value : TYAMLBlockScalarStyle);
begin
  FBlockScalarStyle := value;
end;

{$WARN SYMBOL_DEPRECATED OFF}
// deprecated: kept so that code which sets it compiles, but the writer does not use it
function TYAMLEmitOptions.GetBlockChompingIndicator : TYAMLBlockChompingIndicator;
begin
  result := FBlockChompingIndicator;
end;

procedure TYAMLEmitOptions.SetBlockChompingIndicator(value : TYAMLBlockChompingIndicator);
begin
  FBlockChompingIndicator := value;
end;
{$WARN SYMBOL_DEPRECATED DEFAULT}

{ TYAMLParserOptions }

function TYAMLParserOptions.Clone : IYAMLParserOptions;
begin
  result := TYAMLParserOptions.CreateClone(Self);
end;

constructor TYAMLParserOptions.Create;
begin
  FDuplicateKeyBehavior := TYAMLDuplicateKeyBehavior.dkOverwrite;
  FInputFormat := TYAMLInputFormat.yifYAML;
  FYAML11Compatibility := true;
end;

constructor TYAMLParserOptions.CreateClone(const source : IYAMLParserOptions);
begin
  inherited Create;
  FDuplicateKeyBehavior := source.DuplicateKeyBehavior;
  FInputFormat := source.InputFormat;
  FYAML11Compatibility := source.YAML11Compatibility;
end;

function TYAMLParserOptions.GetYAML11Compatibility : boolean;
begin
  result := FYAML11Compatibility;
end;

procedure TYAMLParserOptions.SetYAML11Compatibility(value : boolean);
begin
  FYAML11Compatibility := value;
end;

function TYAMLParserOptions.GetDuplicateKeyBehavior : TYAMLDuplicateKeyBehavior;
begin
  result := FDuplicateKeyBehavior;
end;

function TYAMLParserOptions.GetInputFormat : TYAMLInputFormat;
begin
  result := FInputFormat;
end;

function TYAMLParserOptions.GetJSONMode: boolean;
begin
  result := FInputFormat = TYAMLInputFormat.yifJSON;
end;

procedure TYAMLParserOptions.SetDuplicateKeyBehavior(value : TYAMLDuplicateKeyBehavior);
begin
  FDuplicateKeyBehavior := value;
end;

procedure TYAMLParserOptions.SetInputFormat(value : TYAMLInputFormat);
begin
  FInputFormat := value;
end;

procedure TYAMLParserOptions.SetJSONMode(value: boolean);
begin
  if value then
    FInputFormat := TYAMLInputFormat.yifJSON
  else
    FInputFormat := TYAMLInputFormat.yifYAML;
end;

{ TYAMLSet }

function TYAMLSet.AddItem(const value : IYAMLValue) : boolean;
var
  valueStr : string;
begin
  // Check for duplicates using string representation
  valueStr := value.AsString;
  result := FValues.IndexOf(valueStr) < 0;
  if result then
  begin
    FValues.Add(valueStr);
    FItems.Add(value);
  end;
end;

function TYAMLSet.InsertItem(index : integer; const value : IYAMLValue) : boolean;
var
  valueStr : string;
begin
  valueStr := value.AsString;
  result := FValues.IndexOf(valueStr) < 0;
  if result then
  begin
    FItems.Insert(index, value);
    FValues.Add(valueStr);
  end;
end;

procedure TYAMLSet.Delete(index : integer);
var
  valueIndex : integer;
begin
  if (index >= 0) and (index < FItems.Count) then
  begin
    // so the value can be added again
    valueIndex := FValues.IndexOf(FItems.FValues[index].AsString);
    if valueIndex >= 0 then
      FValues.Delete(valueIndex);
  end;
  inherited;
end;

function TYAMLSet.CloneNode(const parent : IYAMLValue) : IYAMLValue;
begin
  result := inherited CloneNode(parent);
  TYAMLSet(result as TObject).FValues.AddStrings(FValues);
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

procedure TYAMLCollection.ClearEndComments;
begin
  if FExtra <> nil then
    FExtra^.EndComments := nil;
end;

procedure TYAMLCollection.AddEndComment(const value : string);
begin
  AppendLine(Extra^.EndComments, value);
end;

constructor TYAMLCollection.Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue : string; const tag : string);
begin
  inherited Create(parent, valueType,rawValue, tag);
end;

constructor TYAMLCollection.Create(const parent : IYAMLValue; valueType : TYAMLValueType; const rawValue : string; const tagInfo : IYAMLTagInfo);
begin
  inherited Create(parent, valueType, rawValue, tagInfo);
end;

function TYAMLCollection.GetEndComments : TArray<string>;
begin
  if FExtra <> nil then
    result := Copy(FExtra^.EndComments)
  else
    result := nil;
end;

function TYAMLCollection.GetHasEndComments : boolean;
begin
  result := (FExtra <> nil) and (Length(FExtra^.EndComments) > 0);
end;

function TYAMLCollection.Query(const AExpression: string): IYAMLSequence;
begin
  result := TYAMLPathProcessor.Query(Self, AExpression);
end;

function TYAMLCollection.QuerySingle(const AExpression: string; out AMatch: IYAMLValue): boolean;
begin
  result := TYAMLPathProcessor.QuerySingle(Self, AExpression, AMatch);
end;

function TYAMLCollection.QueryMatches(const AExpression : string) : TArray<TYAMLPathMatch>;
begin
  result := TYAMLPathProcessor.QueryMatches(Self, AExpression);
end;

procedure TYAMLCollection.SetEndComments(const value : TArray<string>);
begin
  if Length(value) > 0 then
    Extra^.EndComments := Copy(value)
  else
    ClearEndComments;
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

constructor TYAMLTagDirective.Create(const handle, prefix: string);
begin
  FHandle := handle;
  FPrefix := prefix;
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
  result := FHandle + ' ' + FPrefix;
end;




end.
