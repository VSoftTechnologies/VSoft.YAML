unit VSoft.YAML.Tests.JSON5.Writer;

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  [TestFixture]
  TJSON5WriterTests = class
  private
    function Parse(const text : string) : IYAMLDocument;
    function Compact : IYAMLEmitOptions;
  public
    [Test]
    procedure RoundTrip_Pretty;

    [Test]
    procedure RoundTrip_TrailingCommas;

    [Test]
    procedure RoundTrip_Compact;

    [Test]
    procedure Keys_UnquotedWhenIdentifier;

    [Test]
    procedure Keys_QuotedOption;

    [Test]
    procedure SingleQuotes;

    [Test]
    procedure Escaping;

    [Test]
    procedure EscapeNonASCII;

    [Test]
    procedure Numbers_TextIsKept;

    [Test]
    procedure Numbers_FromYAML;

    [Test]
    procedure Comments_Compact;

    [Test]
    procedure Comments_TextWithLineBreak;

    [Test]
    procedure JSONWriter_ConvertsJSON5Numbers;

    [Test]
    procedure YAMLWriter_KeepsComments;

    [Test]
    procedure Documents_Array;

    [Test]
    procedure FileAndStream;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils;

const
  LB = sLineBreak;
  BS = '\'; // escapes are built as BS + 'u2028' rather than written out

{ TJSON5WriterTests }

function TJSON5WriterTests.Parse(const text : string) : IYAMLDocument;
var
  options : IYAMLParserOptions;
begin
  options := TYAML.CreateParserOptions;
  options.InputFormat := TYAMLInputFormat.yifJSON5;
  result := TYAML.LoadFromString(text, options);
end;

function TJSON5WriterTests.Compact : IYAMLEmitOptions;
begin
  result := TYAML.CreateWriterOptions;
  result.PrettyPrint := false;
end;

procedure TJSON5WriterTests.RoundTrip_Pretty;
var
  text : string;
begin
  text :=
    '// header' + LB +
    '{' + LB +
    '  // lead a' + LB +
    '  a: 1, // same a' + LB +
    '  hex: 0x1F,' + LB +
    '  neg: -0x1f,' + LB +
    '  inf: Infinity,' + LB +
    '  ninf: -Infinity,' + LB +
    '  nan: NaN,' + LB +
    '  plus: +1,' + LB +
    '  half: .5,' + LB +
    '  trail: 5.,' + LB +
    '  big: 123456789012345678901234567890,' + LB +
    '  "quoted key": "text",' + LB +
    '  "1st": true,' + LB +
    '  list: [' + LB +
    '    1,' + LB +
    '    // before two' + LB +
    '    "two", // after two' + LB +
    '    null' + LB +
    '  ],' + LB +
    '  empty: {},' + LB +
    '  emptyList: [],' + LB +
    '  withComment: {' + LB +
    '    // nothing here' + LB +
    '  }' + LB +
    '  // end of root' + LB +
    '}' + LB +
    '// footer';
  Assert.AreEqual(text, TYAML.WriteToJSON5String(Parse(text)));
end;

procedure TJSON5WriterTests.RoundTrip_TrailingCommas;
var
  text : string;
  doc : IYAMLDocument;
begin
  text :=
    '{' + LB +
    '  a: [' + LB +
    '    1,' + LB +
    '    2,' + LB +
    '  ],' + LB +
    '  b: {' + LB +
    '    c: "x",' + LB +
    '  },' + LB +
    '}';
  doc := Parse(text);
  doc.Options.JSON5TrailingCommas := true;
  Assert.AreEqual(text, TYAML.WriteToJSON5String(doc));
  // compact output never has them
  Assert.AreEqual('{a:[1,2],b:{c:"x"}}', TYAML.WriteToJSON5String(doc.Root, Compact));
end;

procedure TJSON5WriterTests.RoundTrip_Compact;
var
  text : string;
begin
  text := '{a:1,b:[true,null,"s",[]],c:{},d:{e:-2.5e-3}}';
  Assert.AreEqual(text, TYAML.WriteToJSON5String(Parse(text).Root, Compact));
end;

procedure TJSON5WriterTests.Keys_UnquotedWhenIdentifier;
begin
  Assert.AreEqual('{"a b":1,"1x":2,$ok:3,_:4,null:5,"":6,"a-b":7}',
    TYAML.WriteToJSON5String(Parse('{"a b":1,"1x":2,"$ok":3,"_":4,"null":5,"":6,"a-b":7}').Root, Compact));
end;

procedure TJSON5WriterTests.Keys_QuotedOption;
var
  options : IYAMLEmitOptions;
begin
  options := Compact;
  options.JSON5UnquotedKeys := false;
  Assert.AreEqual('{"a":1}', TYAML.WriteToJSON5String(Parse('{a:1}').Root, options));
end;

procedure TJSON5WriterTests.SingleQuotes;
var
  options : IYAMLEmitOptions;
begin
  options := Compact;
  options.JSON5SingleQuotes := true;
  Assert.AreEqual('{a:''it\''s "x"'',''b c'':1}',
    TYAML.WriteToJSON5String(Parse('{"a":"it''s \"x\"","b c":1}').Root, options));
end;

procedure TJSON5WriterTests.Escaping;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue('k', 'a"b''\' + #10#13#9#8#12 + #1 + #$2028 + 'x' + #$2029 + #$7F + #$00E9);
  Assert.AreEqual('{k:"a\"b''\\\n\r\t\b\f' + BS + 'u0001' + BS + 'u2028x' + BS + 'u2029' + #$7F + #$00E9 + '"}',
    TYAML.WriteToJSON5String(doc.Root, Compact));
end;

procedure TJSON5WriterTests.EscapeNonASCII;
var
  doc : IYAMLDocument;
  options : IYAMLEmitOptions;
begin
  doc := TYAML.CreateMapping;
  doc.AsMapping.AddOrSetValue(#$00FC + 'ber', #$00E9);
  doc.AsMapping.AddOrSetValue('plain', 'x');
  options := Compact;
  options.EscapeNonASCII := true;
  Assert.AreEqual('{"' + BS + 'u00FCber":"' + BS + 'u00E9",plain:"x"}', TYAML.WriteToJSON5String(doc.Root, options));
  // without it the name is an identifier
  Assert.AreEqual('{' + #$00FC + 'ber:"' + #$00E9 + '",plain:"x"}', TYAML.WriteToJSON5String(doc.Root, Compact));
end;

procedure TJSON5WriterTests.Numbers_TextIsKept;
var
  text : string;
begin
  text := '[0x1F,-0X1f,+1,.5,5.,1e5,+.5e-3,Infinity,-Infinity,NaN,+NaN,-0]';
  Assert.AreEqual(text, TYAML.WriteToJSON5String(Parse(text).Root, Compact));
end;

procedure TJSON5WriterTests.Numbers_FromYAML;
var
  doc : IYAMLDocument;
begin
  doc := TYAML.LoadFromString('a: 0o17' + LB + 'b: .inf' + LB + 'c: -.inf' + LB + 'd: .nan' + LB + 'e: 0x1F' + LB + 'f: 1.5' + LB);
  Assert.AreEqual('{a:15,b:Infinity,c:-Infinity,d:NaN,e:0x1F,f:1.5}', TYAML.WriteToJSON5String(doc.Root, Compact));
end;

procedure TJSON5WriterTests.Comments_Compact;
var
  text, expected, output : string;
  doc : IYAMLDocument;
begin
  text :=
    '// head' + LB +
    '{a: 1, // c' + LB +
    '// lead b' + LB +
    'b: [2 /* x */], // d' + LB +
    '/* end */' + LB +
    '}' + LB +
    '// tail';
  expected :=
    '// head' + LB +
    '{a:1, /* c */' + LB +
    '// lead b' + LB +
    'b:[2 /* x */] /* d */' + LB +
    '// end' + LB +
    '}' + LB +
    '// tail';
  doc := Parse(text);
  doc.Options.PrettyPrint := false;
  output := TYAML.WriteToJSON5String(doc);
  Assert.AreEqual(expected, output);
  // and the comments come back in the same places
  doc := Parse(output);
  doc.Options.PrettyPrint := false;
  Assert.AreEqual(expected, TYAML.WriteToJSON5String(doc));
end;

procedure TJSON5WriterTests.Comments_TextWithLineBreak;
var
  doc : IYAMLDocument;
  value : IYAMLValue;
begin
  doc := TYAML.CreateMapping;
  value := doc.AsMapping.AddOrSetValue('a', 1);
  value.Comment := 'one' + #10 + 'two';
  value.AddComment('x' + #10 + 'y');
  Assert.AreEqual('{' + LB + '  // x y' + LB + '  a: 1 // one two' + LB + '}', TYAML.WriteToJSON5String(doc));
  // a comment holding */ cannot be a block comment
  value.ClearComments;
  value.Comment := 'a */ b';
  Assert.AreEqual('{a:1 // a */ b' + LB + '}', TYAML.WriteToJSON5String(doc.Root, Compact));
end;

procedure TJSON5WriterTests.JSONWriter_ConvertsJSON5Numbers;
begin
  Assert.AreEqual('{"a":31,"b":-16,"c":1,"d":0.5,"e":null,"f":5}',
    TYAML.WriteToJSONString(Parse('{a:0x1F,b:-0x10,c:+1,d:.5,e:Infinity,f:5.}').Root, Compact));
end;

procedure TJSON5WriterTests.YAMLWriter_KeepsComments;
var
  text : string;
begin
  text :=
    '// head' + LB +
    '{' + LB +
    '  // lead' + LB +
    '  a: 1, // same' + LB +
    '  // end' + LB +
    '}' + LB +
    '// tail';
  Assert.AreEqual('# head' + LB + '# lead' + LB + 'a: 1 # same' + LB + '# end' + LB + '# tail' + LB,
    TYAML.WriteToString(Parse(text)));
end;

procedure TJSON5WriterTests.Documents_Array;
var
  docs : TArray<IYAMLDocument>;
begin
  SetLength(docs, 2);
  docs[0] := Parse('1');
  docs[1] := Parse('{a:2}');
  docs[0].Options.PrettyPrint := false;
  Assert.AreEqual('[1,{a:2}]', TYAML.WriteToJSON5String(docs));
end;

procedure TJSON5WriterTests.FileAndStream;
var
  doc, readBack : IYAMLDocument;
  fileName : string;
  stream : TMemoryStream;
  options : IYAMLParserOptions;
  expected : string;
begin
  doc := Parse('// c' + LB + '{a:0x10, b:''text'', c:[Infinity,],}');
  expected := TYAML.WriteToJSON5String(doc);

  fileName := TPath.Combine(TPath.GetTempPath, 'vsoft_yaml_test_' + IntToStr(Random(MaxInt)) + '.json5');
  try
    TYAML.WriteToJSON5File(doc, fileName);
    readBack := TYAML.LoadFromFile(fileName);
    Assert.AreEqual(expected, TYAML.WriteToJSON5String(readBack), 'file');
  finally
    if TFile.Exists(fileName) then
      TFile.Delete(fileName);
  end;

  stream := TMemoryStream.Create;
  try
    TYAML.WriteToJSON5Stream(doc, stream);
    stream.Position := 0;
    options := TYAML.CreateParserOptions;
    options.InputFormat := TYAMLInputFormat.yifJSON5;
    readBack := TYAML.LoadFromStream(stream, options);
    Assert.AreEqual(expected, TYAML.WriteToJSON5String(readBack), 'stream');
  finally
    stream.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TJSON5WriterTests);

end.
