# JSONPath Syntax Reference for VSoft.YAML

VSoft.YAML provides powerful JSONPath-style querying capabilities for navigating and filtering YAML documents. This implementation is inspired by the JSONPath specification but adapted specifically for YAML data structures.

The YAMLPathProcessor desgin borrows heavily from [Neslib.JSON](https://github.com/neslib/Neslib.Json) - extended to support JSonPath style filters.

## Table of Contents
- [Getting Started](#getting-started)
- [Basic Syntax](#basic-syntax)
- [Core Operators](#core-operators)
- [Filter Expressions](#filter-expressions)
- [Advanced Features](#advanced-features)
- [Examples](#examples)
- [Error Handling](#error-handling)

## Getting Started

### Usage Methods

JSONPath queries are executed using the public interface methods on `IYAMLDocument` and `IYAMLCollection`:

1. **Document-Level Queries**:
```pascal
var
  doc: IYAMLDocument;
  matches: IYAMLSequence;
  result: IYAMLValue;
  found: Boolean;
begin
  doc := TYAML.LoadFromString(yamlContent);
  
  // Returns all matches as IYAMLSequence
  matches := doc.Query('$.name');
  
  // Returns first match only
  found := doc.QuerySingle('$.name', result);
end;
```

2. **Collection-Level Queries**:
```pascal
var
  doc: IYAMLDocument;
  products: IYAMLSequence;
  matches: IYAMLSequence;
begin
  doc := TYAML.LoadFromString(yamlContent);
  products := doc.Root.AsMapping.Items['products'].AsSequence;
  
  // Query within a specific collection
  matches := products.Query('$[?(@.price > 100)]');
end;
```

### Method Signatures

Both `IYAMLDocument` and `IYAMLCollection` provide:

- **`Query(const AExpression: string): IYAMLSequence`**  
  Returns all matching values as a sequence
  
- **`QuerySingle(const AExpression: string; out AMatch: IYAMLValue): Boolean`**  
  Returns the first match and a boolean indicating success

- **`QueryMatches(const AExpression: string): TArray<TYAMLPathMatch>`**  
  Returns all matches, in the same order as `Query`, each with where it is: `Value` (the node), `Parent` (the mapping or sequence it is in, nil for the root), `Key` (for a mapping member, otherwise `''`), `Index` (for a sequence item, otherwise -1) and `Path`, its [RFC 9535 normalized path](https://www.rfc-editor.org/rfc/rfc9535#section-2.7), such as `$['store']['book'][0]`. The location comes from the path the query took, so it is right for a node that an alias shares.

`TYAMLPathProcessor` (in `VSoft.YAML.Path`) has the same three methods, as static class functions that take the root and the expression, and on a processor created with an expression, which can run it many times (call `Cleanup` when done).

## Basic Syntax

All JSONPath expressions must start with the root operator `$`.

### Root Access
- `$` - Returns the root document itself

### Property Access
- `$.property` - Access a property by name
- `$.nested.property` - Access nested properties
- `$['property']` - Access property using bracket notation
- `$["property"]` - Access property using double quotes

## Core Operators

### 1. Child Access

#### Dot Notation
```
$.name                  # Access 'name' property
$.person.address.city   # Access nested properties
```

#### Bracket Notation
```
$['name']              # Single-quoted property name
$["name"]              # Double-quoted property name
$['special-key']       # Properties with special characters
$["key with spaces"]   # Properties with spaces
```

### 2. Array/Sequence Access

#### Index Access
```
$.items[0]             # First element (0-based indexing)
$.items[1]             # Second element
$.items[-1]            # Last element (a negative index counts from the end)
$.items[-2]            # Second last element
$.matrix[0][1]         # Nested array access
```
An index out of range, negative or not, selects nothing. It is not an error.

#### Multiple Indices
```
$.items[0,2,4]         # Elements at indices 0, 2, and 4
$.data[1,3,5,7]        # Multiple specific indices
$.items[0,-1]          # First and last elements
```

#### Array Slicing
Slices work as [RFC 9535](https://www.rfc-editor.org/rfc/rfc9535#section-2.3.4) defines them: a negative start or end counts from the end, the step can be negative to go backwards, and a step of 0 selects nothing.
```
$.items[1:4]           # Elements from index 1 to 3 (4 exclusive)
$.items[2:]            # Elements from index 2 to end
$.items[:3]            # Elements from start to index 2 (3 exclusive)
$.items[1:10:2]        # Elements from 1 to 9 with step 2 (1,3,5,7,9)
$.items[0:-1]          # All elements but the last
$.items[-2:]           # The last two elements
$.items[::-1]          # All elements, last first
$.items[5:1:-2]        # Elements 5 and 3
```

### 3. Wildcard Operator

#### Property Wildcard
```
$.*                    # All direct properties
$.person.*             # All properties of person object
```

#### Array Wildcard
```
$.items[*]             # All array elements
$.*[*]                 # All elements of all arrays
```

#### Bracket Wildcard
```
$['*']                 # All properties (quoted wildcard)
$["*"]                 # All properties (double-quoted wildcard)
```

### 4. Recursive Descent

The `..` operator recursively searches through all levels of the document. The selector after it - a name, `*` or a bracketed selector - is applied to the node, then to each of its descendants in document order, as [RFC 9535](https://www.rfc-editor.org/rfc/rfc9535#section-2.5.2) defines. A node's own matches come before those inside it, and the search goes on inside a match.

```
$..name                # All 'name' properties at any level
$..items[0]            # First element of any 'items' array
$.store..price         # All 'price' properties under 'store'
$..*                   # Every value and item below the root
$..[0]                 # The first item of every sequence
$..['name']            # As $..name
$..[?(@.price > 10)]   # Every item or property value, at any level, with a price over 10
```

## Filter Expressions

Filter expressions allow conditional selection using the syntax `[?(...)]`.

### Basic Structure
```
$.array[?(condition)]
```

### Operand Types

#### Current Item Reference
- `@` - References the current item being evaluated
- `@.property` - Access property of current item
- `@.nested.property` - Access nested properties of current item
- `@[0]`, `@.tags[-1]` - Access items of the current item

#### Root Reference
- `$` - References the root document
- `$.property`, `$[0]` - Access root document properties and items in filter

#### Literals
- `"string"` or `'string'` - String literals; a string ends at the quote it started with, so `"it's"` is a string
- `123`, `-5`, `45.67`, `1e3` - Numeric literals; a number is an integer unless it has a fraction or an exponent
- `true`, `false` - Boolean literals (in any case)
- `null` - The null literal. `null` is equal only to null - not to `''`
- A word without quotes, such as `fred`, is a string
- `[literal, literal, ...]` - A list of literals, for `in` and `nin`

### Comparison Operators

#### Basic Comparisons
- `==` - Equals
- `!=` - Not equals
- `>` - Greater than
- `>=` - Greater than or equal
- `<` - Less than
- `<=` - Less than or equal

#### String Operations
- `contains` - Text contains a substring, or a sequence contains an item equal to the right operand: `@.name contains 'pp'`, `@.tags contains 'sale'`
- `=~` - Regular expression match: `@.name =~ /app.*/i`. The pattern must match the whole value, as in Jayway JsonPath, so `/app/` does not match `apple` - write `/.*app.*/` to look for it anywhere. A `\/` in the pattern is a `/`. The flags are `i` (ignore case), `m` (multi-line), `s` (`.` matches line breaks) and `x` (ignore white space in the pattern). The pattern can also be a string: `@.name =~ 'app.*'`. Only scalars match; null and collections never do. An invalid pattern raises `EYAMLPathError` when the expression is parsed.

#### Collection Operations
- `size` - Compare the number of items of a collection, or of characters of a scalar's text: `@.orders size 0`, `@.reviews size > 5`. `size` alone compares with `==`; `==`, `!=`, `>`, `>=`, `<` and `<=` can follow it.
- `empty` - Check if collection is empty
- `in` - The value is equal to an item of a list: `@.size in ['S', 'M']`, or `@.colour in $.allowed` for a sequence in the document. When the right operand is not a sequence, `in` is false.
- `nin` - The value is equal to no item of the list: `not in`

### Logical Operators

#### Boolean Logic
- `&&` - Logical AND
- `||` - Logical OR
- `!` - Logical NOT

#### Grouping
- `(...)` - Parentheses for grouping expressions

### Filter Examples

#### Basic Filters
```
$.products[?(@.price > 100)]                    # Products over $100
$.items[?(@.category == "Electronics")]         # Electronics items
$.users[?(@.active == true)]                    # Active users
$.books[?(@.rating >= 4.5)]                     # Highly rated books
```

#### Logical Combinations
```
$.products[?(@.price > 50 && @.inStock == true)]           # Expensive in-stock items
$.items[?(@.category == "Books" || @.category == "Media")]  # Books or Media
$.users[?(!(@.status == "inactive"))]                       # Not inactive users
```

#### Complex Expressions
```
$.products[?(@.category == "Electronics" && (@.price < 100 || @.rating > 4.5))]
# Electronics items that are either cheap or highly rated

$.items[?(@.tags contains "sale" && @.discount > 0.1)]
# Items on sale with significant discount
```

#### Collection Size Filters
```
$.users[?(@.orders size 0)]          # Users with no orders
$.categories[?(@.items empty true)]   # Empty categories
$.products[?(@.reviews size > 5)]     # Products with many reviews
```

## Advanced Features

### Case Sensitivity
All property names are case-sensitive:
```
$.Name    # Different from $.name
$.USER    # Different from $.user
```

### Special Characters in Property Names
Use bracket notation with quotes for special characters:
```
$["special-key"]           # Hyphenated keys
$["key with spaces"]       # Keys with spaces  
$["key.with.dots"]         # Keys with dots
$["key[with]brackets"]     # Keys with brackets
```

### Complex Path Combinations
```
$.store..book[?(@.price < 10)].title        # Titles of cheap books anywhere in store
$.users[*].orders[?(@.total > 100)].items   # Items from expensive orders of all users
```

### Truthiness Evaluation
Filters can evaluate truthiness without explicit operators:
```
$.items[?(@.featured)]        # Items where featured is truthy
$.users[?(@.email)]           # Users with non-empty email
$.products[?(@.discount)]     # Products with any discount
```

## Examples

### Sample YAML Document
```yaml
store:
  books:
    - title: "The Great Gatsby"
      author: "F. Scott Fitzgerald"
      price: 12.99
      category: "Fiction"
      inStock: true
      rating: 4.5
    - title: "To Kill a Mockingbird"
      author: "Harper Lee"
      price: 14.99
      category: "Fiction"
      inStock: false
      rating: 4.8
  electronics:
    - name: "Laptop"
      price: 899.99
      category: "Computing"
      inStock: true
      rating: 4.2
    - name: "Mouse"
      price: 25.50
      category: "Accessories"
      inStock: true
      rating: 3.8

customers:
  - name: "John Doe"
    email: "john@example.com"
    active: true
    orders:
      - id: 1
        total: 150.50
      - id: 2
        total: 75.25
  - name: "Jane Smith"
    email: "jane@example.com"
    active: false
    orders: []
```

### Query Examples

#### Basic Queries
```pascal
// Load the YAML document
doc := TYAML.LoadFromString(yamlContent);

// Basic property access
rootValue := doc.Query('$');                            // Root document
storeValue := doc.Query('$.store');                     // Store object  
books := doc.Query('$.store.books');                    // All books
firstBook := doc.Query('$.store.books[0]');             // First book
title := doc.Query('$.store.books[0].title');           // Title of first book
names := doc.Query('$.customers[*].name');              // All customer names
```

#### Filtering Queries  
```pascal
// Price-based filtering
cheapBooks := doc.Query('$.store.books[?(@.price < 15)]');              // Cheap books
inStockElectronics := doc.Query('$.store.electronics[?(@.inStock == true)]'); // In-stock electronics

// Status filtering
activeCustomers := doc.Query('$.customers[?(@.active == true)]');        // Active customers
inStockItems := doc.Query('$.store..[?(@.inStock == true)]');           // All in-stock items

// Collection size filtering  
customersWithOrders := doc.Query('$.customers[?(@.orders size > 0)]');   // Customers with orders
```

#### Complex Queries
```pascal
// Multi-criteria filtering
highRatedTitles := doc.Query('$..books[?(@.rating > 4.6)].title');      // Titles of highly-rated books

// Logical combinations
activeMultiOrderCustomers := doc.Query('$.customers[?(@.active && @.orders size > 1)].name'); // Active customers with multiple orders

// Recursive search with filtering
expensiveItems := doc.Query('$.store..*[?(@.price > 100)]');            // All expensive items in store
```

## Error Handling

### Common Errors

#### Invalid Root
- **Error**: `EYAMLPathError` - "A YAML path must start with a root ($) operator"
- **Cause**: Path doesn't start with `$`
- **Fix**: Always begin paths with `$`

#### Missing Operators
- **Error**: `EYAMLPathError` - "Operator in YAML path must start with dot (.) or bracket ([)"
- **Cause**: Invalid character after root or property
- **Fix**: Use `.` for properties or `[...]` for indexing

#### Bracket Syntax Errors
- **Error**: `EYAMLPathError` - "Missing close bracket (]) in YAML path"
- **Cause**: Unmatched brackets
- **Fix**: Ensure all `[` have corresponding `]`

#### Quote Mismatches
- **Error**: `EYAMLPathError` - "Quote mismatch in YAML path"
- **Cause**: Mixed or unmatched quotes in bracket notation
- **Fix**: Use consistent quote types (`'...'` or `"..."`)

#### Filter Expression Errors
- **Error**: `EYAMLPathError` - "Invalid filter expression in YAML path"
- **Cause**: Malformed filter syntax
- **Fix**: Check filter syntax and parentheses balance

### Best Practices

1. **Always start with `$`** - Root operator is mandatory
2. **Use quotes for special characters** - `$["special-key"]` not `$.special-key`
3. **Test complex filters incrementally** - Build up complex expressions step by step
4. **Handle empty results** - Check sequence count before accessing items
5. **Use QuerySingle for single values** - More efficient when you only need the first match
6. **Cache document references** - Reuse IYAMLDocument instances when possible

### Performance Considerations

- **Document.Query() vs Collection.Query()**: Use Collection.Query() to search within specific collections
- **QuerySingle vs Query**: Use QuerySingle when you only need the first result
- **Simple paths**: Faster than complex filter expressions  
- **Specific indices**: More efficient than wildcards when possible
- **Early filtering**: Apply filters early to reduce processing scope

### Working with Results

```pascal
var
  doc: IYAMLDocument;
  matches: IYAMLSequence;
  singleResult: IYAMLValue;
  found: Boolean;
begin
  doc := TYAML.LoadFromString(yamlContent);
  
  // Multiple results
  matches := doc.Query('$.products[*].name');
  for i := 0 to matches.Count - 1 do
    WriteLn(matches.Items[i].AsString);
  
  // Single result
  found := doc.QuerySingle('$.products[0].name', singleResult);
  if found then
    WriteLn('First product: ' + singleResult.AsString)
  else
    WriteLn('No products found');
end;
```

---
