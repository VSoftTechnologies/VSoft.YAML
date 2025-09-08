unit VSoft.YAML.Tests.SequenceProperties;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  VSoft.YAML;

type
  [TestFixture]
  TYAMLSequencePropertiesTests = class
  private
    function CreateTestSequence: IYAMLSequence;
  public
    [Test]
    procedure TestStringProperty_Getter;
    [Test]
    procedure TestStringProperty_Setter;
    [Test]
    procedure TestStringProperty_OutOfBounds;
    
    [Test]
    procedure TestIntegerProperty_Getter;
    [Test]
    procedure TestIntegerProperty_Setter;
    [Test]
    procedure TestIntegerProperty_OutOfBounds;
    
    [Test]
    procedure TestLongProperty_Getter;
    [Test]
    procedure TestLongProperty_Setter;
    [Test]
    procedure TestLongProperty_OutOfBounds;

    [Test]
    procedure TestULongProperty_Getter;
    [Test]
    procedure TestULongProperty_Setter;
    [Test]
    procedure TestULongProperty_OutOfBounds;

    [Test]
    procedure TestFloatProperty_Getter;
    [Test]
    procedure TestFloatProperty_Setter;
    [Test]
    procedure TestFloatProperty_OutOfBounds;

    [Test]
    procedure TestDateTimeProperty_Getter;
    [Test]
    procedure TestDateTimeProperty_Setter;
    [Test]
    procedure TestDateTimeProperty_OutOfBounds;
    
    [Test]
    procedure TestUtcDateTimeProperty_Getter;
    [Test]
    procedure TestUtcDateTimeProperty_Setter;
    [Test]
    procedure TestUtcDateTimeProperty_OutOfBounds;
    
    [Test]
    procedure TestBooleanProperty_Getter;
    [Test]
    procedure TestBooleanProperty_Setter;
    [Test]
    procedure TestBooleanProperty_OutOfBounds;
    
    [Test]
    procedure TestArrayProperty_Getter;
    [Test]
    procedure TestArrayProperty_Setter;
    [Test]
    procedure TestArrayProperty_OutOfBounds;
    
    [Test]
    procedure TestObjectProperty_Getter;
    [Test]
    procedure TestObjectProperty_Setter;
    [Test]
    procedure TestObjectProperty_OutOfBounds;
    
    [Test]
    procedure TestEmptySequence_AllProperties;
    [Test]
    procedure TestNegativeIndex_AllProperties;
    [Test]
    procedure TestTypeConversion_StringToNumber;
    [Test]
    procedure TestTypeConversion_NumberToString;
    [Test]
    procedure TestSequenceAfterModification;
    [Test]
    procedure TestNestedArrayAccess;
    [Test]
    procedure TestNestedObjectAccess;
  end;

implementation

{ TYAMLSequencePropertiesTests }

function TYAMLSequencePropertiesTests.CreateTestSequence: IYAMLSequence;
var
  doc: IYAMLDocument;
  sequence: IYAMLSequence;
  nestedArray: IYAMLSequence;
  nestedObject: IYAMLMapping;
  testDateTime: TDateTime;
begin
  doc := TYAML.CreateSequence;
  sequence := doc.AsSequence;
  
  testDateTime := EncodeDate(2023, 12, 25) + EncodeTime(15, 30, 45, 500);
  
  sequence.AddValue('Hello World');           // Index 0 - String
  sequence.AddValue(42);                      // Index 1 - Integer
  sequence.AddValue(Int64(9876543210));       // Index 2 - Int64
  sequence.AddValue(UInt64(18446744073709551615)); // Index 3 - UInt64
  sequence.AddValue(3.14159);                 // Index 4 - Double
  sequence.AddValue(testDateTime, false);     // Index 5 - DateTime (local)
  sequence.AddValue(testDateTime, true);      // Index 6 - DateTime (UTC)
  sequence.AddValue(true);                    // Index 7 - Boolean
  
  nestedArray := sequence.AddSequence;        // Index 8 - Nested Array
  nestedArray.AddValue('nested1');
  nestedArray.AddValue('nested2');
  
  nestedObject := sequence.AddMapping;        // Index 9 - Nested Object
  nestedObject.AddOrSetValue('key1', 'value1');
  nestedObject.AddOrSetValue('key2', 123);
  
  result := sequence;
end;

procedure TYAMLSequencePropertiesTests.TestStringProperty_Getter;
var
  sequence: IYAMLSequence;
  value: string;
begin
  sequence := CreateTestSequence;
  value := sequence.S[0];
  Assert.AreEqual('Hello World', value, 'String property should return correct value');
end;

procedure TYAMLSequencePropertiesTests.TestStringProperty_Setter;
var
  sequence: IYAMLSequence;
  originalValue, newValue: string;
begin
  sequence := CreateTestSequence;
  originalValue := sequence.S[0];
  Assert.AreEqual('Hello World', originalValue, 'Original value should be Hello World');
  
  sequence.S[0] := 'Updated String';
  newValue := sequence.S[0];
  Assert.AreEqual('Updated String', newValue, 'String property should be updated');
end;

procedure TYAMLSequencePropertiesTests.TestStringProperty_OutOfBounds;
var
  sequence: IYAMLSequence;
begin
  sequence := CreateTestSequence;
  
  Assert.WillRaise(
    procedure
    begin
      sequence.S[100]; // Access out of bounds index
    end,
    EArgumentOutOfRangeException,
    'Accessing out of bounds index should raise exception'
  );
end;

procedure TYAMLSequencePropertiesTests.TestIntegerProperty_Getter;
var
  sequence: IYAMLSequence;
  value: Integer;
begin
  sequence := CreateTestSequence;
  value := sequence.I[1];
  Assert.AreEqual(42, value, 'Integer property should return correct value');
end;

procedure TYAMLSequencePropertiesTests.TestIntegerProperty_Setter;
var
  sequence: IYAMLSequence;
  originalValue, newValue: Integer;
begin
  sequence := CreateTestSequence;
  originalValue := sequence.I[1];
  Assert.AreEqual(42, originalValue, 'Original value should be 42');
  
  sequence.I[1] := 999;
  newValue := sequence.I[1];
  Assert.AreEqual(999, newValue, 'Integer property should be updated');
end;

procedure TYAMLSequencePropertiesTests.TestIntegerProperty_OutOfBounds;
var
  sequence: IYAMLSequence;
begin
  sequence := CreateTestSequence;
  
  Assert.WillRaise(
    procedure
    begin
      sequence.I[100]; // Access out of bounds index
    end,
    EArgumentOutOfRangeException,
    'Accessing out of bounds index should raise exception'
  );
end;

procedure TYAMLSequencePropertiesTests.TestLongProperty_Getter;
var
  sequence: IYAMLSequence;
  value: Int64;
begin
  sequence := CreateTestSequence;
  value := sequence.L[2];
  Assert.AreEqual(Int64(9876543210), value, 'Long property should return correct value');
end;

procedure TYAMLSequencePropertiesTests.TestLongProperty_Setter;
var
  sequence: IYAMLSequence;
  originalValue, newValue: Int64;
begin
  sequence := CreateTestSequence;
  originalValue := sequence.L[2];
  Assert.AreEqual(Int64(9876543210), originalValue, 'Original value should be 9876543210');
  
  sequence.L[2] := Int64(1234567890123456);
  newValue := sequence.L[2];
  Assert.AreEqual(Int64(1234567890123456), newValue, 'Long property should be updated');
end;

procedure TYAMLSequencePropertiesTests.TestLongProperty_OutOfBounds;
var
  sequence: IYAMLSequence;
begin
  sequence := CreateTestSequence;
  
  Assert.WillRaise(
    procedure
    begin
      sequence.L[100]; // Access out of bounds index
    end,
    EArgumentOutOfRangeException,
    'Accessing out of bounds index should raise exception'
  );
end;

procedure TYAMLSequencePropertiesTests.TestULongProperty_Getter;
var
  sequence: IYAMLSequence;
  value: UInt64;
begin
  sequence := CreateTestSequence;
  value := sequence.U[3];
  Assert.AreEqual<UInt64>(18446744073709551615, value, 'ULong property should return correct value');
end;

procedure TYAMLSequencePropertiesTests.TestULongProperty_Setter;
var
  sequence: IYAMLSequence;
  originalValue, newValue: UInt64;
begin
  sequence := CreateTestSequence;
  originalValue := sequence.U[3];
  Assert.AreEqual<UInt64>(18446744073709551615, originalValue, 'Original value should be max UInt64');
  
  sequence.U[3] := UInt64(9876543210123456789);
  newValue := sequence.U[3];
  Assert.AreEqual<UInt64>(9876543210123456789, newValue, 'ULong property should be updated');
end;

procedure TYAMLSequencePropertiesTests.TestULongProperty_OutOfBounds;
var
  sequence: IYAMLSequence;
begin
  sequence := CreateTestSequence;

  Assert.WillRaise(
    procedure
    begin
      sequence.U[100]; // Access out of bounds index
    end,
    EArgumentOutOfRangeException,
    'Accessing out of bounds index should raise exception'
  );
end;

procedure TYAMLSequencePropertiesTests.TestFloatProperty_Getter;
var
  sequence: IYAMLSequence;
  value: Double;
begin
  sequence := CreateTestSequence;
  value := sequence.F[4];
  Assert.AreEqual(3.14159, value, 0.00001, 'Float property should return correct value');
end;

procedure TYAMLSequencePropertiesTests.TestFloatProperty_Setter;
var
  sequence: IYAMLSequence;
  originalValue, newValue: Double;
begin
  sequence := CreateTestSequence;
  originalValue := sequence.F[4];
  Assert.AreEqual(3.14159, originalValue, 0.00001, 'Original value should be 3.14159');
  
  sequence.F[4] := 2.71828;
  newValue := sequence.F[4];
  Assert.AreEqual(2.71828, newValue, 0.00001, 'Float property should be updated');
end;

procedure TYAMLSequencePropertiesTests.TestFloatProperty_OutOfBounds;
var
  sequence: IYAMLSequence;
begin
  sequence := CreateTestSequence;

  Assert.WillRaise(
    procedure
    begin
      sequence.F[100]; // Access out of bounds index
    end,
    EArgumentOutOfRangeException,
    'Accessing out of bounds index should raise exception'
  );
end;

procedure TYAMLSequencePropertiesTests.TestDateTimeProperty_Getter;
var
  sequence: IYAMLSequence;
  value: TDateTime;
  expectedDateTime: TDateTime;
begin
  sequence := CreateTestSequence;
  expectedDateTime := EncodeDate(2023, 12, 25) + EncodeTime(15, 30, 45, 500);
  value := sequence.D[5];
  // Use a tolerance for datetime comparison since timezone conversion may affect precision
  Assert.IsTrue(Abs(value - expectedDateTime) < 1.0, // Within 1 day tolerance
    Format('DateTime property should return correct value. Expected: %s, Got: %s', 
    [DateTimeToStr(expectedDateTime), DateTimeToStr(value)]));
end;

procedure TYAMLSequencePropertiesTests.TestDateTimeProperty_Setter;
var
  sequence: IYAMLSequence;
  newDateTime, retrievedDateTime: TDateTime;
begin
  sequence := CreateTestSequence;
  newDateTime := EncodeDate(2024, 1, 1) + EncodeTime(12, 0, 0, 0);
  
  sequence.D[5] := newDateTime;
  retrievedDateTime := sequence.D[5];
  Assert.IsTrue(Abs(retrievedDateTime - newDateTime) < 1.0, // Within 1 day tolerance
    Format('DateTime property should be updated. Expected: %s, Got: %s',
    [DateTimeToStr(newDateTime), DateTimeToStr(retrievedDateTime)]));
end;

procedure TYAMLSequencePropertiesTests.TestDateTimeProperty_OutOfBounds;
var
  sequence: IYAMLSequence;
begin
  sequence := CreateTestSequence;

  Assert.WillRaise(
    procedure
    begin
      sequence.D[100]; // Access out of bounds index
    end,
    EArgumentOutOfRangeException,
    'Accessing out of bounds index should raise exception'
  );
end;

procedure TYAMLSequencePropertiesTests.TestUtcDateTimeProperty_Getter;
var
  sequence: IYAMLSequence;
  value: TDateTime;
  expectedDateTime: TDateTime;
begin
  sequence := CreateTestSequence;
  expectedDateTime := EncodeDate(2023, 12, 25) + EncodeTime(15, 30, 45, 500);
  value := sequence.DUtc[6];
  Assert.IsTrue(Abs(value - expectedDateTime) < 0.001, 'UTC DateTime property should return correct value');
end;

procedure TYAMLSequencePropertiesTests.TestUtcDateTimeProperty_Setter;
var
  sequence: IYAMLSequence;
  newDateTime, retrievedDateTime: TDateTime;
begin
  sequence := CreateTestSequence;
  newDateTime := EncodeDate(2024, 6, 15) + EncodeTime(18, 45, 30, 0);
  
  sequence.DUtc[6] := newDateTime;
  retrievedDateTime := sequence.DUtc[6];
  Assert.IsTrue(Abs(retrievedDateTime - newDateTime) < 0.001, 'UTC DateTime property should be updated');
end;

procedure TYAMLSequencePropertiesTests.TestUtcDateTimeProperty_OutOfBounds;
var
  sequence: IYAMLSequence;
begin
  sequence := CreateTestSequence;
  
  Assert.WillRaise(
    procedure
    begin
      sequence.DUtc[100]; // Access out of bounds index
    end,
    EArgumentOutOfRangeException,
    'Accessing out of bounds index should raise exception'
  );
end;

procedure TYAMLSequencePropertiesTests.TestBooleanProperty_Getter;
var
  sequence: IYAMLSequence;
  value: Boolean;
begin
  sequence := CreateTestSequence;
  value := sequence.B[7];
  Assert.IsTrue(value, 'Boolean property should return correct value');
end;

procedure TYAMLSequencePropertiesTests.TestBooleanProperty_Setter;
var
  sequence: IYAMLSequence;
  originalValue, newValue: Boolean;
begin
  sequence := CreateTestSequence;
  originalValue := sequence.B[7];
  Assert.IsTrue(originalValue, 'Original value should be true');
  
  sequence.B[7] := false;
  newValue := sequence.B[7];
  Assert.IsFalse(newValue, 'Boolean property should be updated to false');
end;

procedure TYAMLSequencePropertiesTests.TestBooleanProperty_OutOfBounds;
var
  sequence: IYAMLSequence;
begin
  sequence := CreateTestSequence;
  
  Assert.WillRaise(
    procedure
    begin
      sequence.B[100]; // Access out of bounds index
    end,
    EArgumentOutOfRangeException,
    'Accessing out of bounds index should raise exception'
  );
end;

procedure TYAMLSequencePropertiesTests.TestArrayProperty_Getter;
var
  sequence: IYAMLSequence;
  nestedArray: IYAMLSequence;
begin
  sequence := CreateTestSequence;
  nestedArray := sequence.A[8];
  Assert.IsNotNull(nestedArray, 'Array property should return valid sequence');
  Assert.AreEqual(2, nestedArray.Count, 'Nested array should have 2 elements');
  Assert.AreEqual('nested1', nestedArray.S[0], 'First nested element should be correct');
  Assert.AreEqual('nested2', nestedArray.S[1], 'Second nested element should be correct');
end;

procedure TYAMLSequencePropertiesTests.TestArrayProperty_Setter;
var
  sequence: IYAMLSequence;
  newArray: IYAMLSequence;
  doc: IYAMLDocument;
  retrievedArray: IYAMLSequence;
begin
  sequence := CreateTestSequence;
  
  doc := TYAML.CreateSequence;
  newArray := doc.AsSequence;
  newArray.AddValue('replaced1');
  newArray.AddValue('replaced2');
  newArray.AddValue('replaced3');
  
  sequence.A[8] := newArray;
  retrievedArray := sequence.A[8];
  
  Assert.IsNotNull(retrievedArray, 'Replaced array should be valid');
  Assert.AreEqual(3, retrievedArray.Count, 'Replaced array should have 3 elements');
  Assert.AreEqual('replaced1', retrievedArray.S[0], 'First replaced element should be correct');
end;

procedure TYAMLSequencePropertiesTests.TestArrayProperty_OutOfBounds;
var
  sequence: IYAMLSequence;
begin
  sequence := CreateTestSequence;
  
  Assert.WillRaise(
    procedure
    begin
      sequence.A[100]; // Access out of bounds index
    end,
    EArgumentOutOfRangeException,
    'Accessing out of bounds index should raise exception'
  );
end;

procedure TYAMLSequencePropertiesTests.TestObjectProperty_Getter;
var
  sequence: IYAMLSequence;
  nestedObject: IYAMLMapping;
begin
  sequence := CreateTestSequence;
  nestedObject := sequence.O[9];
  Assert.IsNotNull(nestedObject, 'Object property should return valid mapping');
  Assert.AreEqual(2, nestedObject.Count, 'Nested object should have 2 keys');
  Assert.AreEqual('value1', nestedObject.S['key1'], 'First nested key should be correct');
  Assert.AreEqual(123, nestedObject.I['key2'], 'Second nested key should be correct');
end;

procedure TYAMLSequencePropertiesTests.TestObjectProperty_Setter;
var
  sequence: IYAMLSequence;
  newObject: IYAMLMapping;
  doc: IYAMLDocument;
  retrievedObject: IYAMLMapping;
begin
  sequence := CreateTestSequence;
  
  doc := TYAML.CreateMapping;
  newObject := doc.AsMapping;
  newObject.AddOrSetValue('newKey1', 'newValue1');
  newObject.AddOrSetValue('newKey2', 456);
  newObject.AddOrSetValue('newKey3', true);
  
  sequence.O[9] := newObject;
  retrievedObject := sequence.O[9];
  
  Assert.IsNotNull(retrievedObject, 'Replaced object should be valid');
  Assert.AreEqual(3, retrievedObject.Count, 'Replaced object should have 3 keys');
  Assert.AreEqual('newValue1', retrievedObject.S['newKey1'], 'First replaced key should be correct');
  Assert.AreEqual(456, retrievedObject.I['newKey2'], 'Second replaced key should be correct');
end;

procedure TYAMLSequencePropertiesTests.TestObjectProperty_OutOfBounds;
var
  sequence: IYAMLSequence;
begin
  sequence := CreateTestSequence;
  
  Assert.WillRaise(
    procedure
    begin
      sequence.O[100]; // Access out of bounds index
    end,
    EArgumentOutOfRangeException,
    'Accessing out of bounds index should raise exception'
  );
end;

procedure TYAMLSequencePropertiesTests.TestEmptySequence_AllProperties;
var
  doc: IYAMLDocument;
  emptySequence: IYAMLSequence;
begin
  doc := TYAML.CreateSequence;
  emptySequence := doc.AsSequence;
  
  Assert.WillRaise(
    procedure
    begin
      emptySequence.S[0];
    end,
    EArgumentOutOfRangeException,
    'Accessing empty sequence should raise EArgumentOutOfRangeException'
  );
  
  Assert.WillRaise(
    procedure
    begin
      emptySequence.I[0];
    end,
    EArgumentOutOfRangeException,
    'Accessing empty sequence should raise EArgumentOutOfRangeException'
  );
  
  Assert.WillRaise(
    procedure
    begin
      emptySequence.B[0];
    end,
    EArgumentOutOfRangeException,
    'Accessing empty sequence should raise EArgumentOutOfRangeException'
  );
end;

procedure TYAMLSequencePropertiesTests.TestNegativeIndex_AllProperties;
var
  sequence: IYAMLSequence;
begin
  sequence := CreateTestSequence;
  
  Assert.WillRaise(
    procedure
    begin
      sequence.S[-1];
    end,
    EArgumentOutOfRangeException,
    'Negative index should raise EArgumentOutOfRangeException'
  );
  
  Assert.WillRaise(
    procedure
    begin
      sequence.I[-1];
    end,
    EArgumentOutOfRangeException,
    'Negative index should raise EArgumentOutOfRangeException'
  );
  
  Assert.WillRaise(
    procedure
    begin
      sequence.B[-1];
    end,
    EArgumentOutOfRangeException,
    'Negative index should raise EArgumentOutOfRangeException'
  );
end;

procedure TYAMLSequencePropertiesTests.TestTypeConversion_StringToNumber;
var
  sequence: IYAMLSequence;
  stringValue: string;
  intValue: Integer;
begin
  sequence := CreateTestSequence;
  
  stringValue := sequence.S[1]; // This is actually an integer (42)
  Assert.AreEqual('42', stringValue, 'Integer should convert to string');

  Assert.WillRaise(
    procedure
    begin
      intValue := sequence.I[0]; // This is actually a string ('Hello World')
    end,
    Exception
  );
end;

procedure TYAMLSequencePropertiesTests.TestTypeConversion_NumberToString;
var
  sequence: IYAMLSequence;
  stringFromInt: string;
  stringFromFloat: string;
begin
  sequence := CreateTestSequence;
  
  stringFromInt := sequence.S[1]; // Integer 42 as string
  Assert.AreEqual('42', stringFromInt, 'Integer should convert to string correctly');
  
  stringFromFloat := sequence.S[4]; // Float 3.14159 as string
  Assert.IsTrue(stringFromFloat.Contains('3.14'), 'Float should convert to string containing expected digits');
end;

procedure TYAMLSequencePropertiesTests.TestSequenceAfterModification;
var
  sequence: IYAMLSequence;
  originalCount: Integer;
  newValue: string;
begin
  sequence := CreateTestSequence;
  originalCount := sequence.Count;
  
  sequence.AddValue('New Element');
  Assert.AreEqual(originalCount + 1, sequence.Count, 'Sequence count should increase after adding');
  
  newValue := sequence.S[sequence.Count - 1];
  Assert.AreEqual('New Element', newValue, 'Newly added element should be accessible via property');
  
  sequence.S[sequence.Count - 1] := 'Modified Element';
  newValue := sequence.S[sequence.Count - 1];
  Assert.AreEqual('Modified Element', newValue, 'Modified element should be updated');
end;

procedure TYAMLSequencePropertiesTests.TestNestedArrayAccess;
var
  sequence: IYAMLSequence;
  nestedArray: IYAMLSequence;
  deepValue: string;
begin
  sequence := CreateTestSequence;
  nestedArray := sequence.A[8];
  
  deepValue := nestedArray.S[0];
  Assert.AreEqual('nested1', deepValue, 'Nested array access should work');
  
  nestedArray.S[0] := 'modified_nested1';
  deepValue := nestedArray.S[0];
  Assert.AreEqual('modified_nested1', deepValue, 'Nested array modification should work');
end;

procedure TYAMLSequencePropertiesTests.TestNestedObjectAccess;
var
  sequence: IYAMLSequence;
  nestedObject: IYAMLMapping;
  deepValue: string;
begin
  sequence := CreateTestSequence;
  nestedObject := sequence.O[9];
  
  deepValue := nestedObject.S['key1'];
  Assert.AreEqual('value1', deepValue, 'Nested object access should work');
  
  nestedObject.S['key1'] := 'modified_value1';
  deepValue := nestedObject.S['key1'];
  Assert.AreEqual('modified_value1', deepValue, 'Nested object modification should work');
end;

initialization
TDUnitX.RegisterTestFixture(TYAMLSequencePropertiesTests);

end.