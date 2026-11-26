unit VSoft.YAML.Tests.Documents;

// Writing and reading several documents: the writers leave the options of the documents
// alone, WriteToJSONStream honours WriteByteOrderMark, and LoadAll error messages give the
// position once.

interface

uses
  DUnitX.TestFramework,
  VSoft.YAML;

type
  [TestFixture]
  TYAMLDocumentsTests = class
  private
    function TwoDocuments : TArray<IYAMLDocument>;
  public
    [Test]
    procedure WriteToString_LeavesTheOptionsAlone;
    [Test]
    procedure WriteToStream_LeavesTheOptionsAlone;
    [Test]
    procedure WriteToFile_LeavesTheOptionsAlone;
    [Test]
    procedure WriteToJSONStream_WritesTheByteOrderMark;
    [Test]
    procedure WriteToJSONStream_NoByteOrderMarkByDefault;
    [Test]
    procedure LoadAll_ErrorGivesThePositionOnce;
    [Test]
    procedure LoadAll_ErrorInALaterDocument;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  System.IOUtils;

function CountOf(const subText, text : string) : integer;
var
  offset : integer;
begin
  result := 0;
  offset := Pos(subText, text);
  while offset > 0 do
  begin
    Inc(result);
    offset := PosEx(subText, text, offset + Length(subText));
  end;
end;

function TYAMLDocumentsTests.TwoDocuments : TArray<IYAMLDocument>;
begin
  SetLength(result, 2);
  result[0] := TYAML.CreateMapping;
  result[0].AsMapping.AddOrSetValue('a', 1);
  result[1] := TYAML.CreateMapping;
  result[1].AsMapping.AddOrSetValue('b', 2);
end;

procedure TYAMLDocumentsTests.WriteToString_LeavesTheOptionsAlone;
var
  docs : TArray<IYAMLDocument>;
  text : string;
begin
  docs := TwoDocuments;
  text := TYAML.WriteToString(docs);
  Assert.AreEqual(2, CountOf('---', text), 'several documents are written with markers');
  Assert.IsFalse(docs[0].Options.EmitDocumentMarkers, 'the first document''s options are unchanged');
  Assert.AreEqual('a: 1' + sLineBreak, TYAML.WriteToString(docs[0]));
  Assert.AreEqual(2, Integer(Length(TYAML.LoadAllFromString(text))));
end;

procedure TYAMLDocumentsTests.WriteToStream_LeavesTheOptionsAlone;
var
  docs : TArray<IYAMLDocument>;
  stream : TStringStream;
begin
  docs := TwoDocuments;
  docs[0].Options.WriteByteOrderMark := true;
  stream := TStringStream.Create('', TEncoding.UTF8);
  try
    TYAML.WriteToStream(docs, stream);
    Assert.AreEqual(2, CountOf('---', stream.DataString));
  finally
    stream.Free;
  end;
  Assert.IsFalse(docs[0].Options.EmitDocumentMarkers);
  Assert.IsTrue(docs[0].Options.WriteByteOrderMark);
end;

procedure TYAMLDocumentsTests.WriteToFile_LeavesTheOptionsAlone;
var
  docs : TArray<IYAMLDocument>;
  fileName : string;
begin
  docs := TwoDocuments;
  fileName := TPath.GetTempFileName; // in the TEMP directory; written over below
  try
    TYAML.WriteToFile(docs, fileName);
    Assert.AreEqual(2, Integer(Length(TYAML.LoadAllFromFile(fileName))));
  finally
    if FileExists(fileName) then
      DeleteFile(fileName);
  end;
  Assert.IsFalse(docs[0].Options.EmitDocumentMarkers);
end;

procedure TYAMLDocumentsTests.WriteToJSONStream_WritesTheByteOrderMark;
var
  docs : TArray<IYAMLDocument>;
  stream : TBytesStream;
  bytes, expected : TBytes;
begin
  docs := TwoDocuments;
  docs[0].Options.WriteByteOrderMark := true;
  docs[0].Options.PrettyPrint := false;
  stream := TBytesStream.Create;
  try
    TYAML.WriteToJSONStream(docs, stream);
    bytes := Copy(stream.Bytes, 0, Integer(stream.Size));
  finally
    stream.Free;
  end;
  expected := TEncoding.UTF8.GetPreamble;
  Assert.IsTrue(Length(bytes) > 3);
  Assert.AreEqual(Integer(expected[0]), Integer(bytes[0]));
  Assert.AreEqual(Integer(expected[1]), Integer(bytes[1]));
  Assert.AreEqual(Integer(expected[2]), Integer(bytes[2]));
  Assert.AreEqual(TYAML.WriteToJSONString(docs), TEncoding.UTF8.GetString(bytes, 3, Length(bytes) - 3));
end;

procedure TYAMLDocumentsTests.WriteToJSONStream_NoByteOrderMarkByDefault;
var
  docs : TArray<IYAMLDocument>;
  stream : TBytesStream;
begin
  docs := TwoDocuments;
  stream := TBytesStream.Create;
  try
    TYAML.WriteToJSONStream(docs, stream);
    Assert.AreEqual(Integer(Ord('[')), Integer(stream.Bytes[0]));
  finally
    stream.Free;
  end;
end;

procedure TYAMLDocumentsTests.LoadAll_ErrorGivesThePositionOnce;
var
  message : string;
begin
  message := '';
  try
    TYAML.LoadAllFromString('a: [1');
  except
    on E : EYAMLParseException do
    begin
      message := E.Message;
      Assert.AreEqual(1, E.Line);
      Assert.AreEqual(6, E.Column);
    end;
  end;
  Assert.IsTrue(Pos('Error in document 1: ', message) = 1, message);
  Assert.AreEqual(1, CountOf(' at line 1, column 6', message), message);
end;

procedure TYAMLDocumentsTests.LoadAll_ErrorInALaterDocument;
var
  message : string;
begin
  message := '';
  try
    TYAML.LoadAllFromString('a: 1' + sLineBreak + '---' + sLineBreak + 'b: [1');
  except
    on E : EYAMLParseException do
      message := E.Message;
  end;
  Assert.IsTrue(Pos('Error in document 2: ', message) = 1, message);
  Assert.AreEqual(1, CountOf(' at line 3, column 6', message), message);
end;

initialization
  TDUnitX.RegisterTestFixture(TYAMLDocumentsTests);

end.
