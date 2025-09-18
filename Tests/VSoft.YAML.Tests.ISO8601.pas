unit VSoft.YAML.Tests.ISO8601;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.DateUtils;

type
  [TestFixture]
  TTestISO8601DateTime = class
  private
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Basic date parsing tests
    [Test]
    procedure TestBasicDateOnly;
    [Test]
    procedure TestCompactDateFormat;
    [Test]
    procedure TestDateTimeWithT;
    [Test]
    procedure TestDateTimeWithSpace;

    // Time parsing tests
    [Test]
    procedure TestTimeWithColons;
    [Test]
    procedure TestTimeCompact;
    [Test]
    procedure TestTimeWithMilliseconds;
    [Test]
    procedure TestTimeWithCommaMilliseconds;

    // Timezone tests
    [Test]
    procedure TestUTCTimeZone;
    [Test]
    procedure TestPositiveTimeZone;
    [Test]
    procedure TestNegativeTimeZone;
    [Test]
    procedure TestCompactTimeZone;
    [Test]
    procedure TestTimeZoneConversion;

    // Edge cases
    [Test]
    procedure TestEmptyString;
    [Test]
    procedure TestLeapYear;
    [Test]
    procedure TestEndOfYear;
    [Test]
    procedure TestMidnight;
    [Test]
    procedure TestNoon;

    // Error cases
    [Test]
    procedure TestInvalidDate;
    [Test]
    procedure TestInvalidTime;
    [Test]
    procedure TestInvalidFormat;
    [Test]
    procedure TestInvalidMonth;
    [Test]
    procedure TestInvalidDay;

    // Complex formats
    [Test]
    procedure TestComplexISO8601Formats;
    [Test]
    procedure TestFractionalSecondsVariations;

    // Round-trip conversion tests
    [Test]
    procedure TestRoundTrip_LocalDateTime_ToISO8601AndBack;
    [Test]
    procedure TestRoundTrip_UTCDateTime_ToISO8601AndBack;
    [Test]
    procedure TestRoundTrip_LocalToUTC_Conversion;
    [Test]
    procedure TestRoundTrip_UTCToLocal_Conversion;
    [Test]
    procedure TestRoundTrip_MultipleDateTimeValues;
    [Test]
    procedure TestRoundTrip_EdgeCaseDates;
    [Test]
    procedure TestRoundTrip_PreservePrecision;
  end;

implementation

uses
  VSoft.YAML.Utils, VSoft.YAML.Classes;

{ TTestISO8601DateTime }

procedure TTestISO8601DateTime.Setup;
begin
  // Setup code if needed
end;

procedure TTestISO8601DateTime.TearDown;
begin
  // Teardown code if needed
end;


// Test implementations

procedure TTestISO8601DateTime.TestBasicDateOnly;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-12-25');
  Assert.AreEqual(2023, YearOf(dt));
  Assert.AreEqual(12, MonthOf(dt));
  Assert.AreEqual(25, DayOf(dt));
  Assert.AreEqual(0, HourOf(dt));
  Assert.AreEqual(0, MinuteOf(dt));
  Assert.AreEqual(0, SecondOf(dt));
end;

procedure TTestISO8601DateTime.TestCompactDateFormat;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('20231225');
  Assert.AreEqual(2023, YearOf(dt));
  Assert.AreEqual(12, MonthOf(dt));
  Assert.AreEqual(25, DayOf(dt));
end;

procedure TTestISO8601DateTime.TestDateTimeWithT;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-12-25T14:30:15');
  Assert.AreEqual(2023, YearOf(dt));
  Assert.AreEqual(12, MonthOf(dt));
  Assert.AreEqual(25, DayOf(dt));
  Assert.AreEqual(14, HourOf(dt));
  Assert.AreEqual(30, MinuteOf(dt));
  Assert.AreEqual(15, SecondOf(dt));
end;

procedure TTestISO8601DateTime.TestDateTimeWithSpace;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-12-25 14:30:15');
  Assert.AreEqual(14, HourOf(dt));
  Assert.AreEqual(30, MinuteOf(dt));
  Assert.AreEqual(15, SecondOf(dt));
end;

procedure TTestISO8601DateTime.TestTimeWithColons;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-01-01T08:45:30');
  Assert.AreEqual(8, HourOf(dt));
  Assert.AreEqual(45, MinuteOf(dt));
  Assert.AreEqual(30, SecondOf(dt));
end;

procedure TTestISO8601DateTime.TestTimeCompact;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-01-01T084530');
  Assert.AreEqual(8, HourOf(dt));
  Assert.AreEqual(45, MinuteOf(dt));
  Assert.AreEqual(30, SecondOf(dt));
end;

procedure TTestISO8601DateTime.TestTimeWithMilliseconds;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-01-01T14:30:15.123');
  Assert.AreEqual(14, HourOf(dt));
  Assert.AreEqual(30, MinuteOf(dt));
  Assert.AreEqual(15, SecondOf(dt));
  Assert.AreEqual(123, MilliSecondOf(dt));
end;

procedure TTestISO8601DateTime.TestTimeWithCommaMilliseconds;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-01-01T14:30:15,456');
  Assert.AreEqual(456, MilliSecondOf(dt));
end;

procedure TTestISO8601DateTime.TestUTCTimeZone;
var
  dt1, dt2: TDateTime;
  timezoneOffset: Double;
begin
  dt1 := TYAMLDateUtils.ISO8601StrToUTCDateTime('2023-12-25T14:30:15Z');
  dt2 := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-12-25T14:30:15Z');
  
  // dt1 should be UTC time, dt2 should be local time converted from UTC
  // The difference should equal the local timezone offset
  timezoneOffset := Abs(dt2 - dt1);
  Assert.IsTrue(timezoneOffset <= 14 / 24, 'Timezone offset should be within ±14 hours');
  
  // Verify that dt1 is the UTC time we expect
  Assert.AreEqual(14, HourOf(dt1), 'UTC time should preserve the hour from Z string');
  Assert.AreEqual(30, MinuteOf(dt1), 'UTC time should preserve the minute from Z string');
end;

procedure TTestISO8601DateTime.TestPositiveTimeZone;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToUTCDateTime('2023-12-25T14:30:15+05:30');
  // Should convert to UTC by subtracting 5:30
  Assert.AreEqual(9, HourOf(dt));  // 14:30 - 5:30 = 09:00
  Assert.AreEqual(0, MinuteOf(dt));
end;

procedure TTestISO8601DateTime.TestNegativeTimeZone;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToUTCDateTime('2023-12-25T14:30:15-08:00');
  // Should convert to UTC by adding 8:00
  Assert.AreEqual(22, HourOf(dt));  // 14:30 + 8:00 = 22:30
  Assert.AreEqual(30, MinuteOf(dt));
end;

procedure TTestISO8601DateTime.TestCompactTimeZone;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToUTCDateTime('2023-12-25T14:30:15+0530');
  Assert.AreEqual(9, HourOf(dt));   // 14:30 - 5:30 = 09:00
  Assert.AreEqual(0, MinuteOf(dt));
end;

procedure TTestISO8601DateTime.TestTimeZoneConversion;
var
  dtUTC, dtLocal: TDateTime;
begin
  dtUTC := TYAMLDateUtils.ISO8601StrToUTCDateTime('2023-12-25T14:30:15+02:00');
  dtLocal := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-12-25T14:30:15+02:00');

  // UTC should be 2 hours earlier
  Assert.AreEqual(12, HourOf(dtUTC));   // 14:30 - 2:00 = 12:30
  Assert.AreEqual(30, MinuteOf(dtUTC));

  // Local should preserve the original time for round-trip behavior
  Assert.AreEqual(14, HourOf(dtLocal)); // 14:30 preserved
  Assert.AreEqual(30, MinuteOf(dtLocal));
end;

procedure TTestISO8601DateTime.TestEmptyString;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('');
  Assert.AreEqual<TDateTime>(0, dt);
end;

procedure TTestISO8601DateTime.TestLeapYear;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2024-02-29');
  Assert.AreEqual(2024, YearOf(dt));
  Assert.AreEqual(2, MonthOf(dt));
  Assert.AreEqual(29, DayOf(dt));
end;

procedure TTestISO8601DateTime.TestEndOfYear;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-12-31T23:59:59');
  Assert.AreEqual(2023, YearOf(dt));
  Assert.AreEqual(12, MonthOf(dt));
  Assert.AreEqual(31, DayOf(dt));
  Assert.AreEqual(23, HourOf(dt));
  Assert.AreEqual(59, MinuteOf(dt));
  Assert.AreEqual(59, SecondOf(dt));
end;

procedure TTestISO8601DateTime.TestMidnight;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-12-25T00:00:00');
  Assert.AreEqual(0, HourOf(dt));
  Assert.AreEqual(0, MinuteOf(dt));
  Assert.AreEqual(0, SecondOf(dt));
end;

procedure TTestISO8601DateTime.TestNoon;
var
  dt: TDateTime;
begin
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-12-25T12:00:00');
  Assert.AreEqual(12, HourOf(dt));
  Assert.AreEqual(0, MinuteOf(dt));
  Assert.AreEqual(0, SecondOf(dt));
end;

procedure TTestISO8601DateTime.TestInvalidDate;
begin
  Assert.WillRaise(
    procedure
    begin
      TYAMLDateUtils.ISO8601StrToLocalDateTime('invalid-date');
    end,
    Exception
  );
end;

procedure TTestISO8601DateTime.TestInvalidTime;
begin
  Assert.WillRaise(
    procedure
    begin
      TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-12-25T25:30:15');
    end,
    Exception
  );
end;

procedure TTestISO8601DateTime.TestInvalidFormat;
begin
  Assert.WillRaise(
    procedure
    begin
      TYAMLDateUtils.ISO8601StrToLocalDateTime('2023/12/25');
    end,
    Exception
  );
end;

procedure TTestISO8601DateTime.TestInvalidMonth;
begin
  Assert.WillRaise(
    procedure
    begin
      TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-13-25');
    end,
    Exception
  );
end;

procedure TTestISO8601DateTime.TestInvalidDay;
begin
  Assert.WillRaise(
    procedure
    begin
      TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-02-30');
    end,
    Exception
  );
end;

procedure TTestISO8601DateTime.TestComplexISO8601Formats;
var
  dt: TDateTime;
begin
  // Test various complex but valid formats
  dt := TYAMLDateUtils.ISO8601StrToUTCDateTime('2023-12-25T14:30:15.123Z');
  Assert.AreEqual(123, MilliSecondOf(dt));

  dt := TYAMLDateUtils.ISO8601StrToUTCDateTime('20231225T143015Z');
  Assert.AreEqual(2023, YearOf(dt));
  Assert.AreEqual(14, HourOf(dt));

  dt := TYAMLDateUtils.ISO8601StrToUTCDateTime('2023-12-25T14:30:15-05:00');
  Assert.AreEqual(19, HourOf(dt)); // 14 + 5 = 19
end;

procedure TTestISO8601DateTime.TestFractionalSecondsVariations;
var
  dt: TDateTime;
begin
  // Single digit
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-01-01T12:00:00.1');
  Assert.AreEqual(100, MilliSecondOf(dt));

  // Two digits
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-01-01T12:00:00.12');
  Assert.AreEqual(120, MilliSecondOf(dt));

  // Three digits
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-01-01T12:00:00.123');
  Assert.AreEqual(123, MilliSecondOf(dt));

  // More than three digits (should truncate)
  dt := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-01-01T12:00:00.123456');
  Assert.AreEqual(123, MilliSecondOf(dt));
end;

procedure TTestISO8601DateTime.TestRoundTrip_LocalDateTime_ToISO8601AndBack;
var
  originalDateTime, convertedDateTime: TDateTime;
  iso8601String: string;
begin
  // Test local datetime -> ISO8601 string -> local datetime round trip
  originalDateTime := EncodeDate(2023, 6, 15) + EncodeTime(14, 30, 45, 123);
  
  // Convert to ISO8601 string as local time
  iso8601String := TYAMLDateUtils.LocalDateToISO8601Str(originalDateTime);
  
  // Convert back to local datetime
  convertedDateTime := TYAMLDateUtils.ISO8601StrToLocalDateTime(iso8601String);
  
  // Should be identical within 1 second (allowing for timezone precision)
  Assert.AreEqual(originalDateTime, convertedDateTime, 1 / (24 * 60 * 60), 'Local round-trip failed');
  
  // Test with different time
  originalDateTime := EncodeDate(2024, 12, 31) + EncodeTime(23, 59, 59, 999);
  iso8601String := TYAMLDateUtils.LocalDateToISO8601Str(originalDateTime);
  convertedDateTime := TYAMLDateUtils.ISO8601StrToLocalDateTime(iso8601String);
  
  Assert.AreEqual(originalDateTime, convertedDateTime, 1 / (24 * 60 * 60), 'Local round-trip failed for end of year');
end;

procedure TTestISO8601DateTime.TestRoundTrip_UTCDateTime_ToISO8601AndBack;
var
  originalDateTime, convertedDateTime: TDateTime;
  iso8601String: string;
begin
  // Test UTC datetime -> ISO8601 string -> UTC datetime round trip
  originalDateTime := EncodeDate(2023, 3, 21) + EncodeTime(10, 15, 30, 500);
  
  // Convert to ISO8601 string as UTC time
  iso8601String := TYAMLDateUtils.UTCDateToISO8601Str(originalDateTime);
  
  // Verify it has 'Z' suffix for UTC
  Assert.IsTrue(Copy(iso8601String, Length(iso8601String), 1) = 'Z', 'UTC ISO8601 string should end with Z');
  
  // Convert back to UTC datetime
  convertedDateTime := TYAMLDateUtils.ISO8601StrToUTCDateTime(iso8601String);
  
  // Should be identical
  Assert.AreEqual(originalDateTime, convertedDateTime, 1 / (24 * 60 * 60), 'UTC round-trip failed');
  
  // Test midnight UTC
  originalDateTime := EncodeDate(2023, 1, 1) + EncodeTime(0, 0, 0, 0);
  iso8601String := TYAMLDateUtils.UTCDateToISO8601Str(originalDateTime);
  convertedDateTime := TYAMLDateUtils.ISO8601StrToUTCDateTime(iso8601String);
  
  Assert.AreEqual(originalDateTime, convertedDateTime, 1 / (24 * 60 * 60), 'UTC midnight round-trip failed');
end;

procedure TTestISO8601DateTime.TestRoundTrip_LocalToUTC_Conversion;
var
  localDateTime, utcDateTime: TDateTime;
  localISO8601: string;
  timezoneOffset: Double;
begin
  // Test that local datetime conversion to UTC works consistently
  localDateTime := EncodeDate(2023, 7, 4) + EncodeTime(16, 45, 0, 0);
  
  // Convert local to ISO8601 local string (includes timezone offset)
  localISO8601 := TYAMLDateUtils.LocalDateToISO8601Str(localDateTime);
  
  // Parse the local ISO8601 string as UTC (applies the timezone conversion)
  utcDateTime := TYAMLDateUtils.ISO8601StrToUTCDateTime(localISO8601);
  
  // Verify the timezone offset is reasonable
  timezoneOffset := Abs(localDateTime - utcDateTime);
  Assert.IsTrue(timezoneOffset <= 14 / 24, 'Timezone offset should be within ±14 hours');
  
  // Verify that parsing the same string as local time gives back the original
  Assert.AreEqual(localDateTime, TYAMLDateUtils.ISO8601StrToLocalDateTime(localISO8601), 
    1 / (24 * 60 * 60), 'Local ISO8601 string should parse back to original local time');
  
  // Verify the ISO8601 string contains timezone offset (not just 'Z')
  Assert.IsFalse(Copy(localISO8601, Length(localISO8601), 1) = 'Z', 'Local ISO8601 string should not end with Z');
  // Check for + or - (but - must be after position 10 to avoid date separators)
  if Pos('+', localISO8601) = 0 then
    Assert.IsTrue(Pos('-', localISO8601) > 10, 'Local ISO8601 string should contain timezone offset');
end;

procedure TTestISO8601DateTime.TestRoundTrip_UTCToLocal_Conversion;
var
  utcDateTime, localDateTime, backToLocal: TDateTime;
  utcISO8601, localISO8601: string;
  timezoneOffset: Double;
  isoStr : string;
begin
  // Test that UTC datetime conversion to local works consistently
  utcDateTime := EncodeDate(2023, 11, 11) + EncodeTime(11, 11, 11, 0);

  // Convert UTC to ISO8601 UTC string (should end with 'Z')
  utcISO8601 := TYAMLDateUtils.UTCDateToISO8601Str(utcDateTime);

  // Parse UTC string as local time (should convert to machine local time)
  localDateTime := TYAMLDateUtils.ISO8601StrToLocalDateTime(utcISO8601);

  // Verify the timezone offset is reasonable
  timezoneOffset := Abs(localDateTime - utcDateTime);
  Assert.IsTrue(timezoneOffset <= 14 / 24, 'Timezone offset should be within ±14 hours');

  // Verify that parsing the same UTC string as UTC gives back the original
  Assert.AreEqual(utcDateTime, TYAMLDateUtils.ISO8601StrToUTCDateTime(utcISO8601),
    1 / (24 * 60 * 60), 'UTC ISO8601 string should parse back to original UTC time');

  // Verify the ISO8601 string ends with 'Z' for UTC
  Assert.IsTrue(Copy(utcISO8601, Length(utcISO8601), 1) = 'Z', 'UTC ISO8601 string should end with Z');

  localDateTime := EncodeDate(2023, 11, 11) + EncodeTime(11, 11, 11, 0);
  Log('localDateTime -> FormatDateTime : ' +DateTimeToStr(localDateTime, YAMLFormatSettings));

  //local to iso
  localISO8601 := TYAMLDateUtils.LocalDateToISO8601Str(localDateTime);
  Log('localISO8601 -> LocalDateToISO8601Str : ' + localISO8601);
  //iso to utc
  utcDateTime := TYAMLDateUtils.ISO8601StrToUTCDateTime(localISO8601);
  Log('FormatDateTime - > utcDateTime : ' +DateTimeToStr(utcDateTime, YAMLFormatSettings));

  //utc to iso
  isoStr := TYAMLDateUtils.UTCDateToISO8601Str(utcDateTime);
  Log('UTCDateToISO8601Str -> isoStr : ' + isoStr);

  backToLocal := TYAMLDateUtils.ISO8601StrToLocalDateTime(isoStr);
  Log('ISO8601StrToLocalDateTime(isoStr) -> backToLocal : -> formatDateTime ' +DateTimeToStr(backToLocal, YAMLFormatSettings));


  Assert.AreEqual(localDateTime, backToLocal,  1 / (24 * 60 * 60), 'local -> iso -> utc -> local should be the same');




end;

procedure TTestISO8601DateTime.TestRoundTrip_MultipleDateTimeValues;
var
  testDates: array[0..4] of TDateTime;
  i: Integer;
  originalDateTime, convertedDateTime: TDateTime;
  iso8601String: string;
begin
  // Test multiple different datetime values for robustness
  testDates[0] := EncodeDate(2020, 2, 29) + EncodeTime(12, 0, 0, 0);   // Leap year
  testDates[1] := EncodeDate(2023, 12, 31) + EncodeTime(23, 59, 59, 999); // End of year
  testDates[2] := EncodeDate(2024, 1, 1) + EncodeTime(0, 0, 0, 0);     // New year
  testDates[3] := EncodeDate(2023, 6, 21) + EncodeTime(6, 30, 15, 750); // Summer solstice
  testDates[4] := EncodeDate(2023, 12, 21) + EncodeTime(18, 45, 30, 250); // Winter solstice
  
  for i := Low(testDates) to High(testDates) do
  begin
    originalDateTime := testDates[i];
    
    // Test local round-trip
    iso8601String := TYAMLDateUtils.LocalDateToISO8601Str(originalDateTime);
    convertedDateTime := TYAMLDateUtils.ISO8601StrToLocalDateTime(iso8601String);
    Assert.AreEqual(originalDateTime, convertedDateTime, 1 / (24 * 60 * 60), 
      Format('Local round-trip failed for test date %d', [i]));
    
    // Test UTC round-trip
    iso8601String := TYAMLDateUtils.UTCDateToISO8601Str(originalDateTime);
    convertedDateTime := TYAMLDateUtils.ISO8601StrToUTCDateTime(iso8601String);
    Assert.AreEqual(originalDateTime, convertedDateTime, 1 / (24 * 60 * 60), 
      Format('UTC round-trip failed for test date %d', [i]));
  end;
end;

procedure TTestISO8601DateTime.TestRoundTrip_EdgeCaseDates;
var
  originalDateTime, convertedDateTime: TDateTime;
  iso8601String: string;
begin
  // Test minimum representable date
  originalDateTime := EncodeDate(1900, 1, 1) + EncodeTime(0, 0, 0, 0);
  iso8601String := TYAMLDateUtils.LocalDateToISO8601Str(originalDateTime);
  convertedDateTime := TYAMLDateUtils.ISO8601StrToLocalDateTime(iso8601String);
  Assert.AreEqual(originalDateTime, convertedDateTime, 1 / (24 * 60 * 60), 'Min date local round-trip failed');
  
  iso8601String := TYAMLDateUtils.UTCDateToISO8601Str(originalDateTime);
  convertedDateTime := TYAMLDateUtils.ISO8601StrToUTCDateTime(iso8601String);
  Assert.AreEqual(originalDateTime, convertedDateTime, 1 / (24 * 60 * 60), 'Min date UTC round-trip failed');
  
  // Test far future date
  originalDateTime := EncodeDate(2099, 12, 31) + EncodeTime(23, 59, 59, 0);
  iso8601String := TYAMLDateUtils.LocalDateToISO8601Str(originalDateTime);
  convertedDateTime := TYAMLDateUtils.ISO8601StrToLocalDateTime(iso8601String);
  Assert.AreEqual(originalDateTime, convertedDateTime, 1 / (24 * 60 * 60), 'Far future local round-trip failed');
  
  iso8601String := TYAMLDateUtils.UTCDateToISO8601Str(originalDateTime);
  convertedDateTime := TYAMLDateUtils.ISO8601StrToUTCDateTime(iso8601String);
  Assert.AreEqual(originalDateTime, convertedDateTime, 1 / (24 * 60 * 60), 'Far future UTC round-trip failed');
end;

procedure TTestISO8601DateTime.TestRoundTrip_PreservePrecision;
var
  originalDateTime, convertedDateTime: TDateTime;
  iso8601String: string;
begin
  // Test that millisecond precision is preserved in round-trips
  originalDateTime := EncodeDate(2023, 5, 5) + EncodeTime(5, 5, 5, 555);
  
  // Local round-trip with milliseconds
  iso8601String := TYAMLDateUtils.LocalDateToISO8601Str(originalDateTime);
  Assert.Contains(iso8601String, '.555', 'Local ISO8601 should contain milliseconds');
  convertedDateTime := TYAMLDateUtils.ISO8601StrToLocalDateTime(iso8601String);
  Assert.AreEqual(555, MilliSecondOf(convertedDateTime), 'Local round-trip should preserve milliseconds');
  
  // UTC round-trip with milliseconds
  iso8601String := TYAMLDateUtils.UTCDateToISO8601Str(originalDateTime);
  Assert.Contains(iso8601String, '.555', 'UTC ISO8601 should contain milliseconds');
  convertedDateTime := TYAMLDateUtils.ISO8601StrToUTCDateTime(iso8601String);
  Assert.AreEqual(555, MilliSecondOf(convertedDateTime), 'UTC round-trip should preserve milliseconds');
  
  // Test zero milliseconds (should not include fractional part)
  originalDateTime := EncodeDate(2023, 5, 5) + EncodeTime(5, 5, 5, 0);
  iso8601String := TYAMLDateUtils.UTCDateToISO8601Str(originalDateTime);
  Assert.DoesNotContain(iso8601String, '.', 'ISO8601 should not contain fractional part when milliseconds are zero');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestISO8601DateTime);

end.
