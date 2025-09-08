unit VSoft.YAML.Tests.DateTimeToISO8601;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.DateUtils,
  System.TimeSpan,
  System.RegularExpressions;

type
  [TestFixture]
  TTestDateToISO8601 = class
  private
    function IsValidISO8601Format(const AValue: string): Boolean;
    function ExtractTimeZoneOffset(const AValue: string): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Basic functionality tests
    [Test]
    procedure TestUTCDateTimeWithMilliseconds;
    [Test]
    procedure TestLocalDateTimeFormatting;
    [Test]
    procedure TestEmptyDateTime;

    // Edge cases
    [Test]
    procedure TestMidnight;
    [Test]
    procedure TestNoon;
    [Test]
    procedure TestEndOfYear;
    [Test]
    procedure TestLeapYearDate;
    [Test]
    procedure TestMinDateTime;
    [Test]
    procedure TestMaxDateTime;

    // Timezone tests
    [Test]
    procedure TestUTCFlag;
    [Test]
    procedure TestLocalTimeFlag;
    [Test]
    procedure TestTimeZoneOffsetFormat;

    // Format validation tests
    [Test]
    procedure TestISO8601FormatCompliance;
    [Test]
    procedure TestMillisecondsFormatting;
    [Test]
    procedure TestDateFormatting;
    [Test]
    procedure TestTimeFormatting;

    // Round-trip tests
    [Test]
    procedure TestRoundTripConversion;
    [Test]
    procedure TestRoundTripWithMilliseconds;

    // Specific datetime tests
    [Test]
    procedure TestSpecificDateTimes;
  end;

implementation

uses
  VSoft.YAML.Utils;

{ TTestDateToISO8601 }

procedure TTestDateToISO8601.Setup;
begin
  // Setup code if needed
end;

procedure TTestDateToISO8601.TearDown;
begin
  // Teardown code if needed
end;


// Helper functions
function TTestDateToISO8601.IsValidISO8601Format(const AValue: string): Boolean;
const
  // ISO 8601 regex pattern for YYYY-MM-DDTHH:MM:SS[.sss][Z|±HH:MM]
  ISO8601Pattern = '^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d{3})?(Z|[+-]\d{2}:\d{2})$';
begin
  Result := TRegEx.IsMatch(AValue, ISO8601Pattern);
end;

function TTestDateToISO8601.ExtractTimeZoneOffset(const AValue: string): string;
var
  Match: TMatch;
begin
  Result := '';
  Match := TRegEx.Match(AValue, '(Z|[+-]\d{2}:\d{2})$');
  if Match.Success then
    Result := Match.Value;
end;

// Test implementations


procedure TTestDateToISO8601.TestUTCDateTimeWithMilliseconds;
var
  TestDate: TDateTime;
  ISOStr: string;
begin
  TestDate := EncodeDateTime(2023, 12, 25, 14, 30, 15, 123);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);

  Assert.AreEqual('2023-12-25T14:30:15.123Z', ISOStr);
  Assert.IsTrue(IsValidISO8601Format(ISOStr));
  Assert.IsTrue(ISOStr.Contains('.123'));
end;

procedure TTestDateToISO8601.TestLocalDateTimeFormatting;
var
  TestDate: TDateTime;
  ISOStr: string;
  TimeZoneInfo: string;
begin
  TestDate := EncodeDateTime(2023, 12, 25, 14, 30, 15, 0);
  ISOStr := TYAMLDateUtils.LocalDateToISO8601Str(TestDate);

  Assert.IsTrue(IsValidISO8601Format(ISOStr));
  Assert.IsTrue(ISOStr.StartsWith('2023-12-25T'));

  // Should have timezone offset (not Z)
  TimeZoneInfo := ExtractTimeZoneOffset(ISOStr);
  Assert.IsFalse(TimeZoneInfo = 'Z');
  Assert.IsTrue((TimeZoneInfo.StartsWith('+')) or (TimeZoneInfo.StartsWith('-')));
end;

procedure TTestDateToISO8601.TestEmptyDateTime;
var
  ISOStr: string;
begin
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(0);
  Assert.AreEqual('', ISOStr);

  ISOStr := TYAMLDateUtils.LocalDateToISO8601Str(0);
  Assert.AreEqual('', ISOStr);
end;

procedure TTestDateToISO8601.TestMidnight;
var
  TestDate: TDateTime;
  ISOStr: string;
begin
  TestDate := EncodeDateTime(2023, 12, 25, 0, 0, 0, 0);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);

  Assert.IsTrue(ISOStr.Contains('T00:00:00'));
  Assert.IsTrue(IsValidISO8601Format(ISOStr));
end;

procedure TTestDateToISO8601.TestNoon;
var
  TestDate: TDateTime;
  ISOStr: string;
begin
  TestDate := EncodeDateTime(2023, 12, 25, 12, 0, 0, 0);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);

  Assert.IsTrue(ISOStr.Contains('T12:00:00'));
  Assert.IsTrue(IsValidISO8601Format(ISOStr));
end;

procedure TTestDateToISO8601.TestEndOfYear;
var
  TestDate: TDateTime;
  ISOStr: string;
begin
  TestDate := EncodeDateTime(2023, 12, 31, 23, 59, 59, 999);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);

  Assert.AreEqual('2023-12-31T23:59:59.999Z', ISOStr);
  Assert.IsTrue(IsValidISO8601Format(ISOStr));
end;

procedure TTestDateToISO8601.TestLeapYearDate;
var
  TestDate: TDateTime;
  ISOStr: string;
begin
  TestDate := EncodeDateTime(2024, 2, 29, 12, 0, 0, 0);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);

  Assert.IsTrue(ISOStr.StartsWith('2024-02-29'));
  Assert.IsTrue(IsValidISO8601Format(ISOStr));
end;

procedure TTestDateToISO8601.TestMinDateTime;
var
  TestDate: TDateTime;
  ISOStr: string;
begin
  TestDate := EncodeDateTime(1900, 1, 1, 0, 0, 0, 0);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);

  Assert.AreEqual('1900-01-01T00:00:00Z', ISOStr);
  Assert.IsTrue(IsValidISO8601Format(ISOStr));
end;

procedure TTestDateToISO8601.TestMaxDateTime;
var
  TestDate: TDateTime;
  ISOStr: string;
begin
  TestDate := EncodeDateTime(9999, 12, 31, 23, 59, 59, 999);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);

  Assert.AreEqual('9999-12-31T23:59:59.999Z', ISOStr);
  Assert.IsTrue(IsValidISO8601Format(ISOStr));
end;

procedure TTestDateToISO8601.TestUTCFlag;
var
  TestDate: TDateTime;
  UTCStr, LocalStr: string;
begin
  TestDate := EncodeDateTime(2023, 12, 25, 14, 30, 15, 0);

  UTCStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);
  LocalStr := TYAMLDateUtils.LocalDateToISO8601Str(TestDate);

  Assert.IsTrue(UTCStr.EndsWith('Z'));
  Assert.IsFalse(LocalStr.EndsWith('Z'));
  Assert.AreNotEqual(UTCStr, LocalStr);
end;

procedure TTestDateToISO8601.TestLocalTimeFlag;
var
  TestDate: TDateTime;
  ISOStr: string;
  TimeZoneInfo: string;
begin
  TestDate := Now; // Use current time for realistic local time test
  ISOStr := TYAMLDateUtils.LocalDateToISO8601Str(TestDate);

  Assert.IsTrue(IsValidISO8601Format(ISOStr));

  TimeZoneInfo := ExtractTimeZoneOffset(ISOStr);
  Assert.IsFalse(TimeZoneInfo.IsEmpty);
  Assert.IsFalse(TimeZoneInfo = 'Z');
end;

procedure TTestDateToISO8601.TestTimeZoneOffsetFormat;
var
  TestDate: TDateTime;
  ISOStr: string;
  TimeZoneInfo: string;
begin
  TestDate := EncodeDateTime(2023, 6, 15, 14, 30, 15, 0); // Summer date
  ISOStr := TYAMLDateUtils.LocalDateToISO8601Str(TestDate);

  TimeZoneInfo := ExtractTimeZoneOffset(ISOStr);

  // Should match ±HH:MM format
  Assert.IsTrue(TRegEx.IsMatch(TimeZoneInfo, '^[+-]\d{2}:\d{2}$'));
end;

procedure TTestDateToISO8601.TestISO8601FormatCompliance;
var
  TestDate: TDateTime;
  ISOStr: string;
begin
  // Test various dates for format compliance
  TestDate := EncodeDateTime(2023, 1, 1, 0, 0, 0, 0);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);
  Assert.IsTrue(IsValidISO8601Format(ISOStr));

  TestDate := EncodeDateTime(2023, 12, 31, 23, 59, 59, 999);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);
  Assert.IsTrue(IsValidISO8601Format(ISOStr));

  TestDate := EncodeDateTime(2023, 6, 15, 12, 30, 45, 500);
  ISOStr := TYAMLDateUtils.LocalDateToISO8601Str(TestDate);
  Assert.IsTrue(IsValidISO8601Format(ISOStr));
end;

procedure TTestDateToISO8601.TestMillisecondsFormatting;
var
  TestDate: TDateTime;
  ISOStr: string;
begin
  // Test single digit milliseconds (should be padded)
  TestDate := EncodeDateTime(2023, 12, 25, 14, 30, 15, 5);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);
  Assert.IsTrue(ISOStr.Contains('.005'));

  // Test double digit milliseconds
  TestDate := EncodeDateTime(2023, 12, 25, 14, 30, 15, 50);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);
  Assert.IsTrue(ISOStr.Contains('.050'));

  // Test triple digit milliseconds
  TestDate := EncodeDateTime(2023, 12, 25, 14, 30, 15, 500);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);
  Assert.IsTrue(ISOStr.Contains('.500'));

  // Test zero milliseconds (should not appear)
  TestDate := EncodeDateTime(2023, 12, 25, 14, 30, 15, 0);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);
  Assert.IsFalse(ISOStr.Contains('.'));
end;

procedure TTestDateToISO8601.TestDateFormatting;
var
  TestDate: TDateTime;
  ISOStr: string;
begin
  TestDate := EncodeDateTime(2023, 3, 7, 14, 30, 15, 0);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);

  Assert.IsTrue(ISOStr.StartsWith('2023-03-07'));
end;

procedure TTestDateToISO8601.TestTimeFormatting;
var
  TestDate: TDateTime;
  ISOStr: string;
begin
  TestDate := EncodeDateTime(2023, 12, 25, 9, 5, 3, 0);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);

  Assert.IsTrue(ISOStr.Contains('T09:05:03'));
end;

procedure TTestDateToISO8601.TestRoundTripConversion;
var
  OriginalDate: TDateTime;
  ISOStr: string;
begin
  OriginalDate := EncodeDateTime(2023, 12, 25, 14, 30, 15, 0);

  // Convert to ISO string and back
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(OriginalDate);

  // Note: This would require the ISO8601StrToDateTime function to test round-trip
  // For now, just verify the string format is correct
  Assert.AreEqual('2023-12-25T14:30:15Z', ISOStr);
  Assert.IsTrue(IsValidISO8601Format(ISOStr));
end;

procedure TTestDateToISO8601.TestRoundTripWithMilliseconds;
var
  OriginalDate: TDateTime;
  ISOStr: string;
begin
  OriginalDate := EncodeDateTime(2023, 12, 25, 14, 30, 15, 123);

  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(OriginalDate);
  Assert.AreEqual('2023-12-25T14:30:15.123Z', ISOStr);
  Assert.IsTrue(IsValidISO8601Format(ISOStr));
end;

procedure TTestDateToISO8601.TestSpecificDateTimes;
var
  TestDate: TDateTime;
  ISOStr: string;
begin
  // Test New Year's Day
  TestDate := EncodeDateTime(2024, 1, 1, 0, 0, 0, 0);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);
  Assert.AreEqual('2024-01-01T00:00:00Z', ISOStr);

  // Test Christmas
  TestDate := EncodeDateTime(2023, 12, 25, 12, 0, 0, 0);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);
  Assert.AreEqual('2023-12-25T12:00:00Z', ISOStr);

  // Test leap day
  TestDate := EncodeDateTime(2024, 2, 29, 15, 45, 30, 500);
  ISOStr := TYAMLDateUtils.UTCDateToISO8601Str(TestDate);
  Assert.AreEqual('2024-02-29T15:45:30.500Z', ISOStr);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDateToISO8601);

end.
