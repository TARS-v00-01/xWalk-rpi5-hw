# Documentation tool

`doc-tool` owns the executable tooling for the developer-note wiki. Documentation content and navigation remain
under `devloper-note`; generated environments and HTML remain under the ignored
`build-devloper-note-wiki` directory.

Run commands from the repository root:

```bash
scripts/integration/doc-tool/wiki.sh local
```

```bash
scripts/integration/doc-tool/wiki.sh server --site-url https://docs.example.edu/xwalk/
```

```bash
scripts/integration/doc-tool/wiki.sh github
```

```bash
scripts/integration/doc-tool/wiki.sh verify
```

The launcher provides `local`, `server`, and `github` access profiles plus `verify`, `setup`, and `clean`
maintenance operations. It never publishes directly or selects hardware tests.

During staging, checkout-relative links from developer notes to other tracked repository files become GitHub
source links. GitHub Actions selects the exact deployed commit, while local builds default to the integrated
`master` branch. Verification tests the rewrite behavior, rejects missing repository targets, and checks every
rendered same-site link and asset before publication.
