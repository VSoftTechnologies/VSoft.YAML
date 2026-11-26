# VSoft.YAML

## A YAML 1.2, JSON and JSON5 parser and emitter library for Delphi XE2+.

## Features

### ✅ YAML 1.2 
- **YAML 1.2 Specification Compliance** - Attempting full support for YAML 1.2
- **Complete Value Type System** - Handles all 9 YAML value types:
  - Scalars: null, boolean, integer, float, string, timestampx
  - Collections: sequence (arrays), mapping (objects), set (unique values array)
  - References: alias (anchor references)
- **Number Formats** - Support for decimal, hexadecimal (0x) and octal (0o) number literals
- **ISO 8601 Timestamps** - Full date/time parsing with timezone support.
- **Anchor & Alias System** - Complete YAML reference support for data reuse

### 🔄 YAML 1.1 Compatibility
VSoft.YAML provides **selective backward compatibility** for common YAML 1.1 features. They are on by default, and `IYAMLParserOptions.YAML11Compatibility := false` turns them off to read strict YAML 1.2:
- **Boolean values**: Supports `yes/no/on/off` for easier migration
- **Modern approach**: Does not support ambiguous single-letter `y/n` booleans
- **Numeric formats**: Uses YAML 1.2 standards (no `0XX` octal prefix), but binary (`0b`) literals and underscores (`1_000`) are allowed
- **Timestamps**: ISO 8601 dates and times are read as timestamps
- **Merge Keys** - Support for YAML merge key (`<<`) operations, with a mapping or a sequence of mappings
- **Sets** - A block mapping of `? ` keys with no values is read as a set

With `YAML11Compatibility` off, plain scalars resolve by the YAML 1.2 core schema alone (so `yes`, `0b101`, `1_000` and dates are strings), `<<` is an ordinary key, and `? ` keys make a mapping with null values. The option only changes what values mean: the syntax is YAML 1.2's either way.

For full YAML Feature details see - [YAML Features](/docs/YAML-Features-Implementation.md)

**Conformance:** the tests run the official [YAML test suite](https://github.com/yaml/yaml-test-suite), with `YAML11Compatibility` off. All 402 of its cases pass.

### JSON Support

VSoft.YAML can parse and write JSON (since YAML 1.2 is a superset of JSON):
- **JSON Parsing** - Full JSON input support with strict validation
- **JSON Output** - Export to JSON format with compact or pretty-print formatting
- **Bidirectional Conversion** - Convert between YAML and JSON formats
- **Exact Numbers** - Numbers are written digit for digit, whatever their size: UInt64, Currency, and decimals added from their text with `AddOrSetNumber`
- **ASCII-only Output** - Optionally escape every non-ASCII character as `\uXXXX`

### JSON5 Support

[JSON5](https://spec.json5.org/) files - JSON with comments, unquoted keys, single quotes, trailing commas, hex numbers, `Infinity` and `NaN` - can be read and written:
- **JSON5 Parsing** - A dedicated parser for the whole JSON5 1.0.0 grammar, selected with `InputFormat`, or by a `.json5` file extension
- **JSON5 Output** - `WriteToJSON5String/File/Stream`, with options for unquoted keys, single quotes and trailing commas
- **Lossless Round Trips** - Values, key order, the original number text (`0x1F`, `+1`, `.5`, `Infinity`) and comments all survive reading and writing a JSON5 file

### Parsing & Writing
- **Multiple Input Sources** - Load from string, file, or stream
- **Flexible Output Options**:
  - Block style (human-readable, indented)
  - Flow style (compact, JSON-like)
  - Mixed style formatting
  - **JSON Output** - Export YAML documents to JSON format with pretty-print support
- **Encoding** - Automatic encoding detection - default is UTF-8
- **Error Handling** - Detailed parse error reporting with line/column information

### Advanced Features
- **Multiple Documents** - Full support for multi-document YAML files with `LoadAllFromString/File()` and `WriteAllToString/File()`
- **YAML Directives** - Complete support for `%YAML` version and `%TAG` custom handle directives
- **Comprehensive Tag System** - Full implementation of all YAML 1.2 tag types (Standard, Local, Custom, Verbatim, Global)
- **[JSONPath Queries](/docs/JSONPath-Syntax.md)** - JSONPath-style querying with `Query()` and `QuerySingle()` methods, and `QueryMatches()`, which also gives where each match is
- **Editing** - Remove keys, delete and insert sequence items, move nodes between collections and documents, and make deep copies with `Clone`
- **Complex Keys** - Flow-style complex key support
- **Comment Preservation** - Proper comment handling during parsing


## Quick Start

### Loading YAML
```pascal
uses VSoft.YAML;

var
  doc: IYAMLDocument;
  yaml: string;
begin
  yaml := 'name: John Doe' + sLineBreak +
          'age: 30' + sLineBreak +
          'city: New York';
          
  doc := TYAML.LoadFromString(yaml);
  
  WriteLn('Name: ', doc.Root.Values['name'].AsString);
  WriteLn('Age: ', doc.Root.Values['age'].AsInteger);
end;
```

### Creating YAML Documents
```pascal
var
  doc: IYAMLDocument;
  person: IYAMLMapping;
begin
  doc := TYAML.CreateMapping;
  person := doc.Root.AsMapping;
  
  person.AddOrSetValue('name', 'Jane Smith');
  person.AddOrSetValue('age', 25);
  
  WriteLn(TYAML.WriteToString(doc));
end;
```

### Working with Collections
```pascal
var
  doc: IYAMLDocument;
  fruits: IYAMLSequence;
begin
  yaml := 'fruits:' + sLineBreak +
          '  - apple' + sLineBreak +
          '  - banana' + sLineBreak +
          '  - orange';
          
  doc := TYAML.LoadFromString(yaml);
  fruits := doc.Root.Values['fruits'].AsSequence;
  
  for i := 0 to fruits.Count - 1 do
    WriteLn('Fruit: ', fruits.Items[i].AsString);
end;
```

### Editing Documents
```pascal
var
  doc, other: IYAMLDocument;
  items: IYAMLSequence;
  item: IYAMLValue;
begin
  doc := TYAML.LoadFromString(
    'name: demo' + sLineBreak +
    'debug: true' + sLineBreak +
    'items: [a, b, c]');

  doc.AsMapping.Remove('debug');                // False if the key is not there
  items := doc.AsMapping['items'].AsSequence;
  items.Delete(0);                              // [b, c]
  items.InsertValue(0, 'first');                // [first, b, c]
  items.InsertValue(items.Count, 42);           // index = Count adds at the end
  items.InsertMapping(1).AddOrSetValue('k', 'v');

  // Move a node: take it out of its collection, then add it to another one
  other := TYAML.CreateMapping;
  item := items[2];
  items.Delete(2);
  other.AsMapping.AddOrSetValue('moved', item);

  // Copy a node: Clone makes a deep copy that is in no collection
  other.AsMapping.AddOrSetValue('copy', doc.AsMapping['items'].Clone);
end;
```
- `IYAMLMapping.Remove(key)` removes a key and its value, and returns `False` if the key is not there. The other keys keep their order.
- `IYAMLSequence.Delete(index)` removes an item. An index outside `0..Count - 1` raises `EArgumentOutOfRangeException`.
- `IYAMLSequence.InsertValue(index, value)` has overloads for `string`, `Int64`, `Double`, `Boolean` and `IYAMLValue`. `InsertNull`, `InsertNumber`, `InsertMapping` and `InsertSequence` work as the `Add` methods of the same names. `index` is `0..Count`, and `Count` adds at the end; any other index raises `EArgumentOutOfRangeException`. A set does not insert a value it already has.
- `IYAMLMapping.AddOrSetValue(key, node)`, `IYAMLSequence.AddValue(node)` and `IYAMLSequence.InsertValue(index, node)` put an existing node of any kind into a collection, and make the collection its `Parent`. On an existing key, `AddOrSetValue` replaces the value in the same position, as the other overloads do.
- The node must be in no collection, so its `Parent` must be nil. A node that `Remove` or `Delete` took out, a `Clone` and the root of a document are such nodes. A node that is still in a collection raises `EArgumentException`, and so does a collection added to itself or to a collection inside it. `nil` raises `EArgumentNilException`.
- `IYAMLValue.Clone` returns a deep copy whose `Parent` is nil. The copy keeps the value type, the text (so `0x1F` and `1.50` are written as they were read), the tags and the comments. A node that an alias shares is copied each time it occurs, so the copies are independent.
- The `A[]` and `O[]` setters did not change. They put the collection in as it is and do not change its `Parent`.

### Where a Query Matched
`QueryMatches` runs a JSONPath query as `Query` does, and gives each match with the place it is in the document. It is on `IYAMLDocument` and `IYAMLCollection`, and `TYAMLPathProcessor` has a static and a compiled form. The matches are in the same order as `Query` returns them.
```pascal
var
  doc: IYAMLDocument;
  matches: TArray<TYAMLPathMatch>;
  i: integer;
begin
  doc := TYAML.LoadFromString(
    'books:' + sLineBreak +
    '  - {title: A, price: 8}' + sLineBreak +
    '  - {title: B, price: 12}' + sLineBreak +
    '  - {title: C, price: 20}');

  matches := doc.QueryMatches('$.books[?(@.price > 10)]');
  for i := 0 to Length(matches) - 1 do
    WriteLn(matches[i].Path);
  // Output:
  // $['books'][1]
  // $['books'][2]

  // Delete the matches. Start with the last one, so the indexes of the others stay right.
  for i := Length(matches) - 1 downto 0 do
    matches[i].Parent.AsSequence.Delete(matches[i].Index);
end;
```
Each `TYAMLPathMatch` has these fields:

| Field | Root (`$`) | Mapping member | Sequence item |
|-------|------------|----------------|---------------|
| `Value` | the node | the node | the node |
| `Parent` | nil | the mapping | the sequence |
| `Key` | `''` | the key | `''` |
| `Index` | -1 | -1 | the index |
| `Path` | `$` | `$['books']` | `$['books'][1]` |

`Path` is the [RFC 9535](https://www.rfc-editor.org/rfc/rfc9535#section-2.7) normalized path. A name is in single quotes, with `'` and `\` escaped by a `\`. A control character is written as `\b`, `\t`, `\n`, `\f`, `\r`, or `\u00` and two hex digits. An index is the position from the start, also when the query used a negative index.

The location comes from the path that the query took. A node that an alias shares is in more than one place, but its own `Parent` names only one of them. The match gives the place where the query found the node.

A negative index counts from the end of a sequence, as RFC 9535 says: `$.books[-1]` is the last book, and `$.books[0,-1]` the first and the last. An index out of range selects nothing; it does not raise an error.

### Multiple Documents
```pascal
var
  documents: TArray<IYAMLDocument>;
  doc1, doc2: IYAMLDocument;
  yamlContent: string;
begin
  // Create multiple documents
  doc1 := TYAML.CreateMapping;
  doc1.AsMapping.AddOrSetValue('name', 'Config 1');
  doc1.AsMapping.AddOrSetValue('version', 1);
  
  doc2 := TYAML.CreateMapping;
  doc2.AsMapping.AddOrSetValue('name', 'Config 2');
  doc2.AsMapping.AddOrSetValue('version', 2);
  
  // Write multiple documents
  SetLength(documents, 2);
  documents[0] := doc1;
  documents[1] := doc2;
  
  yamlContent := TYAML.WriteAllToString(documents);
  WriteLn('Multi-document YAML:');
  WriteLn(yamlContent);
  
  // Load multiple documents
  documents := TYAML.LoadAllFromString(yamlContent);
  WriteLn('Loaded ', Length(documents), ' documents');
end;
```

### Working with Tags
```pascal
var
  doc: IYAMLDocument;
  root: IYAMLMapping;
begin
  doc := TYAML.CreateMapping;
  root := doc.AsMapping;
  
  // Add values with explicit tags
  root.AddOrSetValue('port', '8080', '!!int');     // Force integer type
  root.AddOrSetValue('name', 'server', '!!str');   // Force string type
  root.AddOrSetValue('config', configData, '!app!config'); // Custom tag
  
  WriteLn(TYAML.WriteToString(doc));
end;
```

### Writing to JSON
```pascal
var
  doc: IYAMLDocument;
  person: IYAMLMapping;
  jsonOutput: string;
begin
  // Create a YAML document
  doc := TYAML.CreateMapping;
  person := doc.Root.AsMapping;
  
  person.AddOrSetValue('name', 'John Doe');
  person.AddOrSetValue('age', 30);
  person.AddOrSetValue('city', 'New York');
  
  // Export to compact JSON
  doc.Options.PrettyPrint := false;
  jsonOutput := TYAML.WriteToJSONString(doc);
  WriteLn('Compact JSON: ', jsonOutput);
  // Output: {"name":"John Doe","age":30,"city":"New York"}
  
  // Export to pretty-printed JSON
  doc.Options.PrettyPrint := true;
  doc.Options.IndentSize := 2;
  jsonOutput := TYAML.WriteToJSONString(doc);
  WriteLn('Pretty JSON:');
  WriteLn(jsonOutput);
  // Output:
  // {
  //   "name": "John Doe",
  //   "age": 30,
  //   "city": "New York"
  // }
  
  // Write JSON to file
  TYAML.WriteToJSONFile(doc, 'output.json');
end;
```

### Converting YAML to JSON
```pascal
var
  yamlDoc: IYAMLDocument;
  yamlContent: string;
  jsonOutput: string;
begin
  // Load YAML content
  yamlContent := 'employees:' + sLineBreak +
                 '  - name: Alice' + sLineBreak +
                 '    role: Developer' + sLineBreak +
                 '  - name: Bob' + sLineBreak +
                 '    role: Designer';
                 
  yamlDoc := TYAML.LoadFromString(yamlContent);
  
  // Convert to JSON with pretty printing
  yamlDoc.Options.PrettyPrint := true;
  jsonOutput := TYAML.WriteToJSONString(yamlDoc);
  
  WriteLn('YAML to JSON conversion:');
  WriteLn(jsonOutput);
  // Output:
  // {
  //   "employees": [
  //     {
  //       "name": "Alice",
  //       "role": "Developer"
  //     },
  //     {
  //       "name": "Bob",
  //       "role": "Designer"
  //     }
  //   ]
  // }
end;
```

### Exact Numbers
Numbers are written exactly as they were read or added, in JSON and YAML, rather than going through Int64 or Double. For values that no Delphi type holds, such as a SQL `DECIMAL(38,10)`, add the number from its text with `AddOrSetNumber` (on a sequence, `AddNumber`). The text must be a JSON number (`-`, digits, an optional fraction and an optional exponent), or `EConvertError` is raised. Like a parsed number, it is an integer unless it has a fraction or an exponent.
```pascal
var
  doc: IYAMLDocument;
  row: IYAMLMapping;
  price: Currency;
begin
  doc := TYAML.CreateMapping;
  row := doc.AsMapping;
  price := 19.99;

  row.AddOrSetValue('id', UInt64(High(UInt64)));
  row.AddOrSetCurrencyValue('price', price);
  row.AddOrSetNumber('total', '1234567890123456789012345678.9012345678');
  row.AddOrSetValue('note', '');   // an empty string
  row.AddOrSetNull('discount');    // a null

  doc.Options.PrettyPrint := false;
  WriteLn(TYAML.WriteToJSONString(doc));
  // Output: {"id":18446744073709551615,"price":19.99,"total":1234567890123456789012345678.9012345678,"note":"","discount":null}
end;
```

### ASCII-only JSON
Set `EscapeNonASCII` to write every character past `~` (#126) as a `\uXXXX` escape, and a character outside the Basic Multilingual Plane (an emoji, say) as its two surrogate escapes, as RFC 8259 specifies. The output is then printable ASCII. It affects JSON output only.
```pascal
  doc.Options.EscapeNonASCII := true;
  // 'café' is written as "caf\u00E9", and U+1F600 (an emoji) as "\uD83D\uDE00"
```

### Reading and writing JSON5
Set `InputFormat` to JSON5 to read JSON5 text. `LoadFromFile` and `LoadAllFromFile` read a `.json5` file as JSON5 without being told (and a `.json` file as JSON) when the options say YAML, the default. Any other setting is kept, so passing JSON5 options reads a `.json` file that has comments or trailing commas, such as a VS Code settings file.
```pascal
var
  options: IYAMLParserOptions;
  doc: IYAMLDocument;
begin
  options := TYAML.CreateParserOptions;
  options.InputFormat := TYAMLInputFormat.yifJSON5;
  doc := TYAML.LoadFromString(
    '// server settings' + sLineBreak +
    '{' + sLineBreak +
    '  host: ''localhost'',' + sLineBreak +
    '  port: 0x1F90, // 8080' + sLineBreak +
    '  timeout: .5,' + sLineBreak +
    '}', options);

  WriteLn(doc.AsMapping.Items['port'].AsInteger); // 8080

  WriteLn(TYAML.WriteToJSON5String(doc));
  // Output:
  // // server settings
  // {
  //   host: "localhost",
  //   port: 0x1F90, // 8080
  //   timeout: .5
  // }
end;
```
Numbers keep the text they were written with, so `0x1F90`, `+1`, `.5`, `5.`, `Infinity` and `NaN` are written back unchanged. `AsInteger` and `AsFloat` read all of them. Written as JSON, the JSON5-only forms are converted (`0x1F90` becomes `8080`, `.5` becomes `0.5`), and `NaN` and `Infinity` become `null`. Written as YAML, they become `.nan` and `.inf`.

The JSON5 writer uses the document's options, or the options passed to it:
- `JSON5UnquotedKeys` (on by default) writes keys that are identifiers, such as `name`, `$id` or `_x1`, without quotes.
- `JSON5SingleQuotes` quotes strings and keys with `'`.
- `JSON5TrailingCommas` puts a comma after the last item of each object and array, when `PrettyPrint` is on.
- `PrettyPrint`, `IndentSize` and `EscapeNonASCII` work as they do for JSON.

**Comments** are kept where they were:
- Comments on the lines before a value go to its `Comments`; for an object member, that includes the comments before its key.
- A comment that starts on the line where a value ends, before or after its comma, goes to the value's `Comment`.
- Comments before a closing `]` or `}` go to the collection's `EndComments`.
- Comments after the root value go to the document's `EndComments`.

The `//` or `/* */` markers and the whitespace after `//` are dropped. A block comment is trimmed and kept as one entry per line. The JSON5 writer writes every comment as `//`, except a comment after a value in compact output, which it writes as `/* */`. The YAML writer writes the comments as `#` lines, so a JSON5 file converted to YAML keeps them.

JSON (`JSONMode`) is read by the same parser in its strict RFC 8259 mode, which is 1.5 to 2 times as fast as the YAML parser was at reading JSON.

### Core Components
- **VSoft.YAML.pas** - Main entry point with `TYAML` static factory methods for all operations
- **VSoft.YAML.Scanner.pas** - YAML 1.2 scanner, which splits the input into tokens
- **VSoft.YAML.Composer.pas** - YAML 1.2 parser, which builds the documents from the tokens
- **VSoft.YAML.Parser.JSON.pas** - JSON and JSON5 parser
- **VSoft.YAML.Writer.pas** - YAML output writer with multiple formatting options
- **VSoft.YAML.Writer.JSON.pas** - JSON and JSON5 output writer with pretty-print support

## Compatibility

- **Delphi XE2+** -  compatible with Delphi XE2 or later
- **Win32/Win64** - may work on other platforms (does not use WinAPI.*), but not tested .
- **No External Dependencies** - Pure Delphi implementation

## Behaviour changes in 3.1.0

- **`IYAMLSequence.AddValue(IYAMLValue)` sets the node's `Parent`, and refuses a node that is in a collection.** It used to add the node as it was: the node kept its old `Parent` and could be in two collections at once. Now the sequence becomes the node's `Parent`. A node whose `Parent` is set raises `EArgumentException`: take it out of its collection first (`Remove` or `Delete`), or add `node.Clone`. A sequence added to itself, or to a collection inside it, also raises `EArgumentException`. On a set, a value the set already has is still not added, and its `Parent` is not set.
- **`AddValue(nil)` on a set raises `EArgumentNilException`,** as it already did on a sequence. It did nothing.
- **Negative JSONPath indexes count from the end.** `$.a[-1]` and `$.a[0,-1]` raised `EYAMLPathError` ("Negative array index..."). Now `-1` is the last item, as RFC 9535 says, and an index out of range selects nothing. The `RS_YAML_PATH_NEGATIVE_ARRAY_INDEX` resource string is no longer used.
- **New interface members.** These were added:
  - `IYAMLValue.Clone`
  - `IYAMLMapping.AddOrSetValue(key, IYAMLValue)` and `IYAMLMapping.Remove`
  - `IYAMLSequence.Delete`, `InsertValue` (for `IYAMLValue`, `string`, `Int64`, `Double` and `Boolean`), `InsertNull`, `InsertNumber`, `InsertMapping` and `InsertSequence`
  - `IYAMLCollection.QueryMatches` and `IYAMLDocument.QueryMatches`, with the `TYAMLPathMatch` record and `TYAMLPathProcessor.QueryMatches`

  Only code that implements these interfaces itself needs updating.
- **Code that builds trees with the `VSoft.YAML.Classes` unit** and relied on `AddValue` to share a node (as an alias does) should add the node with `TYAMLSequence.AddItem` or `IYAMLMappingPrivate.AddOrSetValue`. These add a node as it is, without the checks, and are what the parsers use.

## Behaviour changes in 3.0.0

- **YAML has a new parser.** YAML is read by a new parser written to the YAML 1.2 specification: a scanner (`VSoft.YAML.Scanner`) and a parser that builds the documents (`VSoft.YAML.Composer`). It passes all 402 cases of the [YAML test suite](https://github.com/yaml/yaml-test-suite), where the old one passed 195, and reads YAML 6 to 30% faster. The YAML 1.1 forms VSoft.YAML has always read are kept, behind the new `YAML11Compatibility` option (on by default - see YAML 1.1 Compatibility above). Its error messages differ. The old lexer and parser units, `VSoft.YAML.Lexer` and `VSoft.YAML.Parser`, are gone.
  - **Now read:**
    - explicit keys (`? `), and keys that are collections - such a key is stored under its text in flow style, as `[a, b]`;
    - anchors and tags on keys and on empty values, and aliases as keys;
    - keys of a flow mapping that span lines;
    - plain and quoted scalars over several lines, folded as YAML 1.2 says;
    - the block scalar cases the old parser got wrong: chomping, indentation indicators, more-indented and whitespace-only lines, and a tab in the content.
  - **Now rejected,** as YAML 1.2 requires:
    - an implicit key straight after another one, as in `a: b: c`;
    - a line of a quoted scalar, or of a flow collection inside a block collection, that is not indented more than that block collection - including the line with the closing `]` or `}`;
    - a tab before a block indicator (`- `, `? `, `: `) or before a key that starts a block mapping;
    - a `#` comment with no white space before it, as in `"a"#c`;
    - anything but a comment after `...` on its line, and directives with no `---` after them;
    - a `%YAML` or `%TAG` directive after a document that has no `...` end marker;
    - a tag whose handle no `%TAG` directive in its own document declares - a directive applies to the document after it only.
  - **A more-indented line goes on with the plain scalar before it.** In `a: 1` followed by `  - x`, the value of `a` is `1 - x`. That used to be an error.
  - **No checks beyond the specification.** The old parser rejected a plain scalar that started like a key with no colon (`foo bar` as a document) or that was mostly punctuation. Those are valid plain scalars. `@` and `` ` `` still cannot start one.
  - **A single quoted scalar has no escapes.** A `\` in it is kept, and a `\` at the end of a line does not join the lines; only double quoted scalars have escapes.
  - **Local tags keep their `!`.** The tag of `!mytag value` is `!mytag`, as for a tag added in code, so the YAML writer writes it back as a tag. It was `mytag`, which the writer wrote as part of the value.
  - **Tag handles are resolved.** A `%TAG` handle gives the tag's `TagInfo.ResolvedTag`, and a tag whose handle resolves to `tag:yaml.org,2002:` is a standard tag. `!!` given another prefix no longer converts the value, so `!!int 1 - 3` under such a directive is a string. `IYAMLTagDirective.Handle` and `Prefix` returned each other's value; they are now the right way round.
  - **`LoadAll` of an empty stream gives no documents.** A stream that is empty or holds only comments has no documents, so `LoadAllFromString` and the other `LoadAll` methods return an empty array where they returned one null document. `LoadFromString` still returns a null document.
  - **The end of the input ends a block scalar's last line.** In `k: |` followed by `  a` with no final line break, the value is `a\n`, as if the line break were there.
  - **Comments go where they are.** A comment on a line of its own is no longer taken as the same-line comment of the value before it, and comments after the root value go to the document's `EndComments`.
- **JSON has its own parser.** JSON (`JSONMode`, or a `.json` file) is read by the new JSON/JSON5 parser rather than by the YAML parser in a JSON mode. It is 1.5 to 2 times as fast and passes all 318 files of [JSONTestSuite](https://github.com/nst/JSONTestSuite). Its error messages differ, and it rejects some input the old path accepted:
  - empty input, or input that is only whitespace or a byte order mark (RFC 8259 requires a value);
  - a NUL character straight after a number;
  - objects and arrays nested more than 1000 deep.
- **Block scalar line breaks are line feeds.** The text of a literal (`|`) or folded (`>`) block scalar had the platform's line break between its lines, which is CRLF on Windows. It now has `\n` (LF), as YAML 1.2 requires, whatever line breaks the file uses. Code that compares such text with `sLineBreak`, or splits it on CRLF, needs updating. JSON output of block scalars has `\n` where it had `\r\n`.
- **Tabs are accepted as separation.** A tab is still an error where it would be indentation, such as before a block mapping key. It is now accepted where YAML 1.2 allows it as separation white space:
  - on a blank or comment-only line;
  - before a flow collection that is the document's root, or that is indented past the block it is in;
  - inside a flow collection, once the line has the indentation the collection needs.
- **A space-separated timestamp ends at its line.** A plain `2024-01-15 10:30:00` used to run on into the next line: the line break, and any blank lines or the start of the next key after it, ended up in the value. The JSON writer also escapes timestamps now, as it does other strings.
- **Comments are string arrays, on every value.** `Comments`, and the new `EndComments`, are a `TArray<string>` with one line each, where `Comments` was a `TStrings`. A string list for each commented value cost about 250 bytes and 230 ns, where an array costs about 25 bytes and 40 ns.
  - Reading the property gives a copy, so change comments with `AddComment` and `ClearComments`, or by setting the property; for end comments, `AddEndComment` and `ClearEndComments`.
  - Code written for the `TStrings` needs updating: `Comments.Count` becomes `Length(Comments)`, and `Comments.Add(s)` becomes `AddComment(s)`.
  - `Comments`, `HasComments`, `AddComment`, `ClearComments` and `SetComments` moved from `IYAMLCollection` to `IYAMLValue`; code that calls them on a collection still compiles.
  - The YAML parser still only sets them on collections.
- **Documents are smaller and faster to free.** A mapping with more than 8 keys finds them through a small hash table of its own rather than a `TDictionary`, and freeing a collection no longer visits each child to detach it.
  - On the benchmark files the trees are up to 30% smaller (benchmark_large.yaml, 20 MB: 88 MB down to 63 MB), and freeing a document takes 25 to 60% less time.
  - A node taken out of a collection - replaced, or removed by `Clear` - no longer reports that collection as its `Parent`. One still referenced after its collection is freed reports nil, as before.
- **The YAML writer writes more comments.** It writes leading comments on scalar values, the new `EndComments` of collections and documents, and the comments of a mapping that is an item of a sequence. It used to drop those.
- **Signed hex converts.** `AsInteger`, and the JSON and YAML writers, read a sign before a `0x`, `0o` or `0b` prefix, as in JSON5's `-0x1F`. YAML still reads `-0x1F` as a string.
- **`AsFloat` reads `Infinity`, `-Infinity` and `NaN`**, as well as YAML's `.inf` and `.nan`.
- **New interface members.** These were added:
  - `IYAMLParserOptions.InputFormat`
  - `IYAMLEmitOptions.JSON5UnquotedKeys`, `JSON5SingleQuotes` and `JSON5TrailingCommas`
  - `EndComments`, `HasEndComments`, `AddEndComment` and `ClearEndComments` on `IYAMLCollection` and `IYAMLDocument`
  - `IYAMLParserOptions.YAML11Compatibility`

  Only code that implements these interfaces itself needs updating.
- **`JSONMode` is now a shortcut for `InputFormat`.** Setting it true selects JSON, and setting it false selects YAML.

## Behaviour changes in 2.4.0

- **Loading a `.json` file no longer changes parser options.** `LoadFromFile` and `LoadAllFromFile` still parse a `.json` file as JSON, but they now switch on JSON mode on a copy of the options. Before, they set `JSONMode` on the options you passed in, or on the shared default options when you passed none, so every later load without options was parsed as JSON and plain YAML was rejected.
- **JSON mode rejects `#` comments.** A line such as `"x": 1 # note` was accepted. JSON has no comments, and `//` and `/* */` were already rejected.
- **YAML flow collections accept a trailing comma.** `[1, 2, ]` and `{a: 1, }` now parse, as YAML 1.2 allows; they raised an error. An empty entry such as `[1, , 2]` is still an error, and JSON mode still rejects trailing commas.
- **New interface member.** `IYAMLParserOptions.Clone` was added. Only code that implements `IYAMLParserOptions` itself needs updating.


## Behaviour changes in 2.3.0

- **Reading a missing key no longer adds it.** `S[]`, `I[]`, `L[]`, `U[]`, `F[]`, `C[]`, `D[]`, `DUtc[]` and `B[]` return `''`, `0` or `False` for a missing key and leave the mapping unchanged, as JsonDataObjects does. `F[]`, `C[]`, `D[]` and `DUtc[]` used to raise on a missing key (and still add it). `A[]` and `O[]` still create the key, as documented, so builder code such as `doc.O['a'].S['b'] := 'x'` keeps working.
- **The getters convert between scalar types, as their comments say.** On mappings and sequences:
  - `I[]`, `L[]` and `U[]` accept floats (truncated), booleans (0 or 1) and numeric strings.
  - `F[]` and `C[]` accept integers, booleans and numeric strings.
  - `B[]` reads a number as true when it isn't zero, and a string as its YAML boolean value (`true`, `True`, `yes`, `ON`...); any other string is `False`.
  - `D[]` and `DUtc[]` accept ISO 8601 strings.
  - A null reads as `''`, `0` or `False`.
  - Text that is not a number still raises, now `EConvertError` (it was a plain `Exception`).
- **`C[]` reads Currency exactly.** It went through Double, so `922337203685477.5807` came back as `-922337203685477.5808`.

## Behaviour changes in 2.1.0

These change what existing code produces, so check them when upgrading from 2.0 or earlier.

- **`AddOrSetValue(key, '')` stores an empty string, not null.** JSON gets `""` and YAML `''`, as `AddValue('')` on a sequence and `S[key] := ''` already did. To write a null, call `AddOrSetNull(key)`, or `AddNull` on a sequence.
- **Numbers are written as they were read or added.** When a number's text is already a valid JSON number, both writers emit it unchanged instead of converting it through Int64 or Double. A parsed `1.23e4` stays `1.23e4` (it was written as `12300`), `1.50` stays `1.50` (was `1.5`), and `-0.0` stays `-0.0`.
- **Currency keeps all four decimals.** `922337203685477.5807` was written as `922337203685478`.
- **UInt64 values above `High(Int64)` are written.** They raised `EConvertError`.
- **Hex, octal and binary integers convert exactly, at any size.** They are written as decimal, so `0xFFFFFFFFFFFFFFFF` comes out as `18446744073709551615`; it raised before. `AsInteger` returns the right value for hex of 32 bits or more (`0xFFFFFFFF` was -1, and `0x100000000` raised), and raises `EConvertError` for any value past `High(Int64)` where octal and binary silently wrapped around.
- **A whole-number float is written to YAML with `.0`.** `AddOrSetValue(key, 2.0)` writes `2.0`, because `2` would be read back as an integer. JSON output is unchanged (`2`).
- **`!!int` accepts integers of any size, and the 0o, 0x and 0b forms.** `!!int 3000000000` and `!!int 0o17` were rejected.
- **Merge keys (`<<`) copy values exactly.** Merging a mapping that holds an integer past Int64 raised a parse error, and merged floats lost digits.
- **Plain values follow the YAML 1.2 core schema's spellings.** Each word is read in its lower-case, capitalised and upper-case spellings only. `NULL`, `TRUE`, `FALSE` and `No` now read as null and booleans (they read as strings), and other mixes of case such as `nO`, `YeS`, `OfF` and `.nAn` now read as strings (they read as booleans and floats). `.5`, `+.5`, `1.` and `1.e5` are floats, and `0X1F`, `0O17` and `0B101` are strings, because YAML only has the lower-case prefixes.
- **Strings are quoted whenever they would read back as something else.** The writer left strings such as `True`, `YES`, `.inf`, `0o17`, `1_000` and `2026-10-22` unquoted, so they came back as booleans, numbers or timestamps. It now quotes exactly the text the parser would not read as a string, so every string round trips. Delphi-only number forms such as `$FF`, which YAML reads as strings, are no longer quoted.
- **New interface members.** `IYAMLMapping.AddOrSetNumber`, `IYAMLSequence.AddNumber` and `IYAMLEmitOptions.EscapeNonASCII` were added. Only code that implements these interfaces itself needs updating.

## Installing

### [DPM](https://delphi.dev)

Install VSoft.YAML in the DPM IDE plugin,  or 
```
dpm install VSoft.YAML .\yourproject.dproj
```
### Manually

Clone the repository, add the Source folder to your project search path, or your IDE search path. Alternatively you can open and build the VSoft.YMLR.dproj in the Packages folder use the dcu files. 
