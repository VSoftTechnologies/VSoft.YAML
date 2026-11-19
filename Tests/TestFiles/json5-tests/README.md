# json5-tests

The parse test cases of [json5/json5-tests](https://github.com/json5/json5-tests), MIT
licensed (see `LICENSE.md`), copied unchanged from commit
`ceb24d4080137d70833f86c25659c1331b80a387`.

The file extension gives the expected result:

- `.json` - valid JSON, so also valid JSON5
- `.json5` - valid JSON5 (but not JSON)
- `.js` - valid ECMAScript 5 that JSON5 does not allow, must be rejected
- `.txt` - invalid, must be rejected

`comments/irregular-block-comment.json` is labelled as JSON but holds a `/* */` comment, so a
strict JSON parser rejects it; the tests treat it as JSON5 only.

Used by `VSoft.YAML.Tests.JSONSuites.pas`. Line endings must not be converted (see
`.gitattributes`).
