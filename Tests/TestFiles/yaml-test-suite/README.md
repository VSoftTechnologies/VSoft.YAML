# yaml-test-suite

The test cases of the official [YAML test suite](https://github.com/yaml/yaml-test-suite),
MIT licensed (see `LICENSE`), copied unchanged from the `data` branch at commit
`6ad3d2c62885d82fc349026c136ef560838fdf3d` (release v2022-01-17).

Each case is a folder named by its id, or a numbered subfolder of one for a test with
several cases (`2G84/00`). Only the files the tests use are copied:

- `in.yaml` - the input
- `error` - present when the input is invalid and must be rejected
- `in.json` - the data the input holds, one JSON value per document, when it can be shown
  as JSON
- `===` - the test's name

`VSoft.YAML.Tests.YAMLSuite.pas` runs every case. The cases VSoft.YAML does not pass yet are
listed in `..\yaml-test-suite-known-failures.txt`. Line endings must not be converted (see
`.gitattributes`).
