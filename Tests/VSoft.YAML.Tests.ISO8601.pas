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
  end;

implementation

uses
  VSoft.YAML.Utils;

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
begin
  dt1 := TYAMLDateUtils.ISO8601StrToUTCDateTime('2023-12-25T14:30:15Z');
  dt2 := TYAMLDateUtils.ISO8601StrToLocalDateTime('2023-12-25T14:30:15Z');
  // Both should be the same since Z indicates UTC
  Assert.AreEqual(dt1, dt2, 0.0001); // Small tolerance for floating point comparison
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

initialization
  TDUnitX.RegisterTestFixture(TTestISO8601DateTime);

end.
