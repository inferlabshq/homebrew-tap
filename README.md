# inferlabshq/tap

Homebrew formulae for [Inferlabs](https://inferlabs.com.au) projects.

## Akasha

A local credential vault your AI agent uses one operation at a time.
Source, docs and threat model: https://github.com/inferlabshq/akasha

```bash
brew install inferlabshq/tap/akasha
akasha setup
```

macOS (Apple Silicon and Intel) and Linux (x86_64 and arm64). The formula
installs the same verified release binary and signed provider bundle that
`curl -sSL https://getakasha.dev/install | sh` does; both read their checksums
from the release's `SHA256SUMS`.

`Formula/akasha.rb` is generated. It is rendered by
[`scripts/brew-formula.sh`](https://github.com/inferlabshq/akasha/blob/main/scripts/brew-formula.sh)
in the main repository and pushed here by the release workflow on every tag,
so please do not send pull requests against it. Report problems with the
formula at https://github.com/inferlabshq/akasha/issues.
