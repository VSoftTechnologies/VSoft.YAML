unit VSoft.YAML.Utils;

interface

{$I 'VSoft.YAML.inc'}


uses
  System.SysUtils;

type
  TYAMLDateUtils = class
    //The RTL implementation is incorrect
    class function LocalDateToISO8601Str(const date: TDateTime): string;static;
    class function UTCDateToISO8601Str(const date: TDateTime): string;static;

    class function ISO8601StrToLocalDateTime(const value: string): TDateTime;static;
    class function ISO8601StrToUTCDateTime(const value: string): TDateTime;static;
  end;

  TYAMLCharUtils = record
    class function IsDigit(c : Char) : boolean;static;inline;
    class function IsDigitOrUnderScore(c : Char) : boolean;static;inline;
    class function IsAlphaNumeric(C: Char): boolean; inline;static;
    class function IsAlpha(C: Char): boolean; static;inline;
    class function IsHexidecimal(c : Char) : boolean;inline;static;
    class function EscapeStringForJSON(const value : string) : string;static;
  end;

{$IFDEF XE5SDOWN}
function TryStrToUInt64(const S: string; out Value: UInt64): Boolean;
{$ENDIF}


implementation

uses
  System.Classes,
  System.Character,
  System.TimeSpan,
  System.DateUtils;


class function TYAMLCharUtils.IsAlphaNumeric(C: Char): Boolean;
begin
{$IF CompilerVersion > 24.0}
  result := C.IsLetterOrDigit or (C = '_');
{$ELSE}
  result := TCharacter.IsLetterOrDigit(C) or (C = '_');
{$IFEND}
end;

class function TYAMLCharUtils.EscapeStringForJSON(const value: string): string;
var
  i : integer;
  charCode : Word;
  highSurrogate, lowSurrogate : Word;
begin
  result := '';
  {$HIGHCHARUNICODE ON}
  i := 1;
  while i <= Length(value) do
  begin
    charCode := Ord(value[i]);
    case value[i] of
      '"': result := result + '\"';       // Double quote
      '\': result := result + '\\';       // Backslash
      #8: result := result + '\b';        // Backspace
      #12: result := result + '\f';       // Form feed
      #10: result := result + '\n';       // Line feed
      #13: result := result + '\r';       // Carriage return
      #9: result := result + '\t';        // Horizontal tab
      #0..#7, #11, #14..#31:              // Other control characters (U+0000 through U+001F)
        result := result + '\u' + IntToHex(charCode, 4);
      else
      begin
        // Check for surrogate pairs
        if (charCode >= $D800) and (charCode <= $DBFF) then // High surrogate
        begin
          if (i < Length(value)) then
          begin
            highSurrogate := charCode;
            lowSurrogate := Ord(value[i + 1]);
            if (lowSurrogate >= $DC00) and (lowSurrogate <= $DFFF) then // Valid low surrogate
            begin
              // Escape surrogate pairs as individual \uXXXX sequences (JSON standard)
              result := result + '\u' + IntToHex(highSurrogate, 4) + '\u' + IntToHex(lowSurrogate, 4);
              Inc(i, 2); // Skip both characters in the pair
              Continue;
            end
            else
            begin
              // Unpaired high surrogate - escape it
              result := result + '\u' + IntToHex(charCode, 4);
            end;
          end
          else
          begin
            // High surrogate at end of string - escape it
            result := result + '\u' + IntToHex(charCode, 4);
          end;
        end
        else if (charCode >= $DC00) and (charCode <= $DFFF) then // Unpaired low surrogate
        begin
          // Escape unpaired low surrogate
          result := result + '\u' + IntToHex(charCode, 4);
        end
        else
        begin
          // Regular Unicode character - preserve as-is
          result := result + value[i];
        end;
      end;
    end;
    Inc(i);
  end;
  {$HIGHCHARUNICODE OFF}
end;

class function TYAMLCharUtils.IsAlpha(C: Char): Boolean;
begin
{$IF CompilerVersion > 24.0}
  result := C.IsLetter;
{$ELSE}
  result := TCharacter.IsLetter(C);
{$IFEND}
end;

class function TYAMLCharUtils.IsDigit(c : Char) : boolean;
begin
  result := (c >= '0') and (c <= '9');
end;

class function TYAMLCharUtils.IsDigitOrUnderScore(c : Char) : boolean;
begin
  result := (c = '_') or (c >= '0') and (c <= '9') ;
end;


class function TYAMLCharUtils.IsHexidecimal(c : Char) : boolean;
begin
  Result := IsDigit(c) or ((c >= 'A') and (c <= 'F')) or ((c >= 'a') and (c <= 'f'));
end;



function DateToISO8601Str(const date: TDateTime; inputIsUTC: Boolean): string;
var
  y, m, d, h, mo, sec, ms : Word;
  timeZoneOffset: integer;
  offsetHours, offsetMinutes: integer;
  offsetSign: Char;
begin
  if date = 0 then
    exit('');
  // Extract date and time components
  DecodeDate(date, y, mo, d);
  DecodeTime(date, h, m, sec, ms);
  if ms <> 0 then
    Result := Format('%.4d-%.2d-%.2dT%.2d:%.2d:%.2d.%.3d', [y, mo, d, h, m, sec, ms])
  else
    Result := Format('%.4d-%.2d-%.2dT%.2d:%.2d:%.2d', [y, mo, d, h, m, sec]);

  // Handle timezone part
  if not inputIsUTC then
  begin
    // Get the timezone offset for the original local time
    timeZoneOffset := Trunc(TTimeZone.Local.GetUTCOffset(date).TotalMinutes);

    if timeZoneOffset <> 0 then
    begin
      if timeZoneOffset >= 0 then
        offsetSign := '+'
      else
      begin
        offsetSign := '-';
        timeZoneOffset := Abs(timeZoneOffset);
      end;

      offsetHours := timeZoneOffset div 60;
      offsetMinutes := timeZoneOffset mod 60;
      result := Format('%s%s%.02d:%.02d', [result, offsetSign, offsetHours, offsetMinutes]);
    end;
  end
  else
    result := result + 'Z';
end;

function ISO8601StrToDateTime(const value: string; returnUTC: boolean): TDateTime;
var
  s: string;
  year, month, day, hour, minute, second, millisecond: integer;
  tzOffset: integer;
  hasTimeZone: Boolean;
  isNegativeTZ: Boolean;
  tzHours, tzMinutes: integer;
  i, dotPos, tPos, tzPos: integer;
  dateStr, timeStr, tzStr: string;
  dt : TDateTime;
begin
  Result := 0;

  if value = '' then
    Exit;

  s := Trim(value);

  // Initialize values
//  year := 0; month := 1; day := 1;
  hour := 0; minute := 0; second := 0; millisecond := 0;
  tzOffset := 0;
  hasTimeZone := False;
//  isNegativeTZ := False;
  // Find timezone indicator (Z, +, or -)
  tzPos := 0;
  for i := Length(s) downto 1 do
  begin
    if CharInSet(s[i], ['Z', '+', '-']) then
    begin
      // Make sure it's not a date separator (-)
      if (s[i] = '-') and (i <= 10) then
        Continue;
      tzPos := i;
      Break;
    end;
  end;

  // Split into date/time and timezone parts
  if tzPos > 0 then
  begin
    hasTimeZone := True;
    tzStr := Copy(s, tzPos, Length(s));
    s := Copy(s, 1, tzPos - 1);

    // Parse timezone
    if tzStr = 'Z' then
      tzOffset := 0
    else
    begin
      isNegativeTZ := tzStr[1] = '-';
      tzStr := Copy(tzStr, 2, Length(tzStr)); // Remove +/- sign

      if Pos(':', tzStr) > 0 then
      begin
        tzHours := StrToIntDef(Copy(tzStr, 1, Pos(':', tzStr) - 1), 0);
        tzMinutes := StrToIntDef(Copy(tzStr, Pos(':', tzStr) + 1, 2), 0);
      end
      else
      begin
        if Length(tzStr) >= 2 then
          tzHours := StrToIntDef(Copy(tzStr, 1, 2), 0)
        else
          tzHours := StrToIntDef(tzStr, 0);

        if Length(tzStr) >= 4 then
          tzMinutes := StrToIntDef(Copy(tzStr, 3, 2), 0)
        else
          tzMinutes := 0;
      end;

      tzOffset := tzHours * 60 + tzMinutes;
      if isNegativeTZ then
        tzOffset := -tzOffset;
    end;
  end;

  // Find T separator for date/time split
  tPos := Pos('T', UpperCase(s));
  if tPos = 0 then
    tPos := Pos(' ', s); // Also accept space as separator

  if tPos > 0 then
  begin
    dateStr := Copy(s, 1, tPos - 1);
    timeStr := Copy(s, tPos + 1, Length(s));
  end
  else
  begin
    // Only date provided
    dateStr := s;
    timeStr := '';
  end;

  // Parse date part (YYYY-MM-DD or YYYYMMDD)
  if Pos('-', dateStr) > 0 then
  begin
    // YYYY-MM-DD format
    year := StrToIntDef(Copy(dateStr, 1, 4), 0);
    month := StrToIntDef(Copy(dateStr, 6, 2), 1);
    day := StrToIntDef(Copy(dateStr, 9, 2), 1);
  end
  else if Length(dateStr) = 8 then
  begin
    // YYYYMMDD format
    year := StrToIntDef(Copy(dateStr, 1, 4), 0);
    month := StrToIntDef(Copy(dateStr, 5, 2), 1);
    day := StrToIntDef(Copy(dateStr, 7, 2), 1);
  end
  else
    raise Exception.Create('Invalid ISO 8601 date format: ' + value);

  // Parse time part if present
  if timeStr <> '' then
  begin
    // Handle fractional seconds
    dotPos := Pos('.', timeStr);
    if dotPos = 0 then
      dotPos := Pos(',', timeStr); // ISO 8601 allows comma as decimal separator

    if dotPos > 0 then
    begin
      // Extract fractional part
      millisecond := 0;
      if dotPos < Length(timeStr) then
      begin
        // Take up to 3 digits for milliseconds
        i := 1;
        while (dotPos + i <= Length(timeStr)) and (i <= 3) and CharInSet(timeStr[dotPos + i],['0'..'9']) do
        begin
          millisecond := millisecond * 10 + (Ord(timeStr[dotPos + i]) - Ord('0'));
          Inc(i);
        end;
        // Pad to milliseconds if needed
        while i <= 3 do
        begin
          millisecond := millisecond * 10;
          Inc(i);
        end;
      end;

      timeStr := Copy(timeStr, 1, dotPos - 1);
    end;

    // Parse HH:MM:SS or HHMMSS
    if Pos(':', timeStr) > 0 then
    begin
      // HH:MM:SS format
      hour := StrToIntDef(Copy(timeStr, 1, 2), 0);
      if Length(timeStr) >= 5 then
        minute := StrToIntDef(Copy(timeStr, 4, 2), 0);
      if Length(timeStr) >= 8 then
        second := StrToIntDef(Copy(timeStr, 7, 2), 0);
    end
    else
    begin
      // HHMMSS format
      hour := StrToIntDef(Copy(timeStr, 1, 2), 0);
      if Length(timeStr) >= 4 then
        minute := StrToIntDef(Copy(timeStr, 3, 2), 0);
      if Length(timeStr) >= 6 then
        second := StrToIntDef(Copy(timeStr, 5, 2), 0);
    end;
  end;

  // Validate ranges
  if (year < 1) or (month < 1) or (month > 12) or (day < 1) or (day > 31) or
     (hour < 0) or (hour > 23) or (minute < 0) or (minute > 59) or
     (second < 0) or (second > 59) or (millisecond < 0) or (millisecond > 999) then
    raise Exception.Create('Invalid date/time values in ISO 8601 string: ' + value);

  // Create TDateTime
  try
    dt := EncodeDate(year, month, day);
    if (hour <> 0) or (minute <> 0) or (second <> 0) or (millisecond <> 0) then
      dt := dt + EncodeTime(hour, minute, second, millisecond);

    // Apply timezone conversion if needed
    if hasTimeZone then
    begin
      if returnUTC then
      begin
        // Convert from the specified timezone to UTC
        // tzOffset is positive for +HH:MM and negative for -HH:MM
        // To convert to UTC: subtract the offset
        // Example: "15:30:45-11:00" (tzOffset = -660) -> dt - (-660/1440) = dt + 11 hours
        dt := dt - (tzOffset / (24 * 60)); // Convert minutes to fraction of day
      end
      else
      begin
        // When returnUTC is False, convert to local time
        if tzOffset = 0 then
        begin
          // Input is UTC (Z suffix), convert from UTC to local time
          tzOffset := Trunc(TTimeZone.Local.GetUTCOffset(dt).TotalMinutes);
          dt := dt + (tzOffset / (24 * 60)); // Add local offset to UTC time
        end
        else
        begin
          // Input has explicit timezone offset, preserve for round-trip scenarios
          // The datetime value already represents the correct local time
          // No conversion needed - this preserves round-trip behavior
        end;
      end;
    end
    else
    begin
      // No timezone information in the string
      if returnUTC then
      begin
        // Treat the datetime as local time and convert to UTC
        // Get the local timezone offset for this specific datetime
        tzOffset := Trunc(TTimeZone.Local.GetUTCOffset(dt).TotalMinutes);
        dt := dt - (tzOffset / (24 * 60)); // Convert from local to UTC
      end;
      // If returnUTC is False, treat as local time (no conversion needed)
    end;

    Result := dt;

  except
    on E: Exception do
      raise Exception.Create('Error creating datetime from ISO 8601 string "' + value + '": ' + E.Message);
  end;
end;



class function TYAMLDateUtils.ISO8601StrToLocalDateTime(const value: string): TDateTime;
begin
  result := ISO8601StrToDateTime(value, false);
end;

class function TYAMLDateUtils.ISO8601StrToUTCDateTime(const value: string): TDateTime;
begin
  result := ISO8601StrToDateTime(value, true);
end;

class function TYAMLDateUtils.LocalDateToISO8601Str(const date: TDateTime): string;
begin
  result := DateToISO8601Str(date, false);
end;

class function TYAMLDateUtils.UTCDateToISO8601Str(const date: TDateTime): string;
begin
  result := DateToISO8601Str(date, true);
end;

{$IFDEF HAS_DIRECTIVE_ZEROBASEDSTRINGS}
  {$ZEROBASEDSTRINGS OFF}
{$ENDIF}


function _ValUInt64(const s: string; var code: Integer): UInt64;
const
  FirstIndex = 1;
var
  i: Integer;
  dig: Integer;
  sign: Boolean;
  empty: Boolean;
begin
  i := FirstIndex;
  Result := 0;
  if s = '' then
  begin
    code := 1;
    exit;
  end;
  while s[i] = Char(' ') do
    Inc(i);
  sign := False;
  if s[i] =  Char('-') then
  begin
    sign := True;
    Inc(i);
  end
  else if s[i] =  Char('+') then
    Inc(i);
  empty := True;
  if (s[i] =  Char('$')) or (Upcase(s[i]) =  Char('X'))
    or ((s[i] =  Char('0')) and (I < Length(S)) and (Upcase(s[i+1]) =  Char('X'))) then
  begin
    if s[i] =  Char('0') then
      Inc(i);
    Inc(i);
    while True do
    begin
      case   Char(s[i]) of
       Char('0').. Char('9'): dig := Ord(s[i]) -  Ord('0');
       Char('A').. Char('F'): dig := Ord(s[i]) - (Ord('A') - 10);
       Char('a').. Char('f'): dig := Ord(s[i]) - (Ord('a') - 10);
      else
        break;
      end;
      if Result > (High(UInt64) shr 4) then
        Break;
      if sign and (dig <> 0) then
        Break;
      Result := Result shl 4 + Cardinal(dig);
      Inc(i);
      empty := False;
    end;
  end
  else
  begin
    while True do
    begin
      case  Char(s[i]) of
        Char('0').. Char('9'): dig := Ord(s[i]) - Ord('0');
      else
        break;
      end;
                // 18446744073709551615
      if Result >= 1844674407370955161 then
      begin
        if (Result > 1844674407370955161) or (High(UInt64) - Result*10 < dig) then
          Break
      end;
      if sign and (dig <> 0) then
        Break;
      Result := Result*10 + Cardinal(dig);
      Inc(i);
      empty := False;
    end;
  end;
  if (s[i] <> Char(#0)) or empty then
    code := i + 1 - FirstIndex
  else
    code := 0;
end;

function TryStrToUInt64(const S: string; out Value: UInt64): Boolean;
var
  E: Integer;
begin
  Value := _ValUInt64(S, E);
  Result := E = 0;
end;

end.
