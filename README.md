# VSoft.YAML

## A YAML 1.2 and JSON parser and emitter library for Delphi XE2+.

## Features

### ✅ YAML 1.2 
- **YAML 1.2 Specification Compliance** - Attempting full support for YAML 1.2
- **Complete Value Type System** - Handles all 9 YAML value types:
  - Scalars: null, boolean, integer, float, string, timestampx
  - Collections: sequence (arrays), mapping (objects), set (unique values array)
  - References: alias (anchor references)
- **Number Formats** - Support for decimal, hexadecimal (0x), octal (0o), and binary (0b) number literals
- **ISO 8601 Timestamps** - Full date/time parsing with timezone support.
- **Anchor & Alias System** - Complete YAML reference support for data reuse

### 🔄 YAML 1.1 Compatibility
VSoft.YAML provides **selective backward compatibility** for common YAML 1.1 features:
- **Boolean values**: Supports `yes/no/on/off` for easier migration
- **Modern approach**: Does not support ambiguous single-letter `y/n` booleans
- **Numeric formats**: Uses YAML 1.2 standards (no `0XX` octal prefix), underscores are allowed
- **Merge Keys** - Support for YAML merge key (`<<`) operations

For full YAML Feature details see - [YAML Features](/docs/YAML-Features-Implementation.md)

### JSON Support

VSoft.YAML can parse and write JSON (since YAML 1.2 is a superset of JSON):
- **JSON Parsing** - Full JSON input support with strict validation
- **JSON Output** - Export to JSON format with compact or pretty-print formatting
- **Bidirectional Conversion** - Convert between YAML and JSON formats

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
- **[JSONPath Queries](/docs/JSONPath-Syntax.md)** - JSONPath-style querying with `Query()` and `QuerySingle()` methods
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

### Core Components
- **VSoft.YAML.pas** - Main entry point with `TYAML` static factory methods for all operations
- **VSoft.YAML.Writer.pas** - YAML output writer with multiple formatting options
- **VSoft.YAML.Writer.JSON.pas** - JSON output writer with pretty-print support

## Compatibility

- **Delphi XE2+** -  compatible with Delphi XE2 or later
- **Win32/Win64** - may work on other platforms (does not use WinAPI.*), but not tested .
- **No External Dependencies** - Pure Delphi implementation

## Installing

### [DPM](https://delphi.dev)

Install VSoft.YAML in the DPM IDE plugin,  or 
```
dpm install VSoft.YAML .\yourproject.dproj
```
### Manually

Clone the repository, add the Source folder to your project search path, or your IDE search path. Alternatively you can open and build the VSoft.YMLR.dproj in the Packages folder use the dcu files. 
