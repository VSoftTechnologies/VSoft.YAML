# JSONTestSuite

The `test_parsing` files of [nst/JSONTestSuite](https://github.com/nst/JSONTestSuite) by
Nicolas Seriot, MIT licensed (see `LICENSE`), copied unchanged from commit
`1ef36fa01286573e846ac449e8683f8833c5b26a`.

The first letter of each file name gives the expected result for an RFC 8259 parser:

- `y_` - valid JSON, must be accepted
- `n_` - invalid JSON, must be rejected
- `i_` - implementation defined (huge numbers, lone surrogates, invalid UTF-8, BOMs)

Used by `VSoft.YAML.Tests.JSONSuites.pas`. Line endings must not be converted (see
`.gitattributes`).
