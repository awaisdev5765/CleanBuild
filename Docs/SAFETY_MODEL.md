# Safety Model

- **Safe** means positively identified generated output with low consequence. It still requires selection and confirmation.
- **Review** means regenerable or archival data with meaningful rebuild, download, distribution, or symbolication consequences. It is never preselected and requires acknowledgement.
- **Protected** means user data, an active or ambiguous resource, or a forbidden root. It cannot be selected.

Canonical paths are checked against `/`, `/System`, `/Library`, `/Applications`, and the home root. Symlink entries are skipped while scanning. Nested targets are deduplicated. Before cleanup, existence and allocated size must match the scan. A changed target fails closed and requires a new scan.

