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
$.matrix[0][1]         # Nested array access
```

#### Multiple Indices
```
$.items[0,2,4]         # Elements at indices 0, 2, and 4
$.data[1,3,5,7]        # Multiple specific indices
```

#### Array Slicing
```
$.items[1:4]           # Elements from index 1 to 3 (4 exclusive)
$.items[2:]            # Elements from index 2 to end
$.items[:3]            # Elements from start to index 2 (3 exclusive)
$.items[1:10:2]        # Elements from 1 to 9 with step 2 (1,3,5,7,9)
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

The `..` operator recursively searches through all levels of the document:

```
$..name                # All 'name' properties at any level
$..items[0]            # First element of any 'items' array
$.store..price         # All 'price' properties under 'store'
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

#### Root Reference
- `$` - References the root document
- `$.property` - Access root document properties in filter

#### Literals
- `"string"` or `'string'` - String literals
- `123`, `45.67` - Numeric literals
- `true`, `false` - Boolean literals

### Comparison Operators

#### Basic Comparisons
- `==` - Equals
- `!=` - Not equals
- `>` - Greater than
- `>=` - Greater than or equal
- `<` - Less than
- `<=` - Less than or equal

#### String Operations
- `contains` - String contains substring
- `=~` - Regular expression match (planned)

#### Collection Operations
- `size` - Compare collection size
- `empty` - Check if collection is empty
- `in` - Check if value is in collection (planned)
- `nin` - Check if value is not in collection (planned)

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
inStockItems := doc.Query('$.store..inStock[?(@ == true)]');            // All in-stock items

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
