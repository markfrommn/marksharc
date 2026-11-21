# Memory index

This `memory/MEMORY.md` index is the only memory read by default. Read a note only when its entry
matches the work; never read notes in bulk or from `memory/archive/`. Memory is
experience, not authority. Harvest only durable experience; usually nothing is written.
A record of activity is never written: the pull request and the tracker hold that history. Place each lesson by scope and lifetime: a transient, repository-scope lesson becomes a note, unless it concerns only one repository-local plan — then that plan or its specification takes it instead; a permanent, repository-scope lesson goes to the repository's own guidance; a transient, global lesson goes to the global plan; a permanent, global lesson goes to the shared `Memory-Theme` theme list. A note whose `retire_when` is met is archived.
When a lesson does become a note, extend a
matching note (create one only when none matches) and update its index entry. For a defect lesson,
file an issue and record its retirement condition in the note. If a budget blocks harvest, review
affected notes; never shorten an unrelated entry to make room. Children follow these rules; a
parent names a known-relevant note in its delegation packet.
Use `cwf ai memory list --json` for notes and retirement issue keys; check conditions manually. On `ai.memory.format: 2`, create notes with `cwf ai memory new <name>` and the required --description, --applies-to, --retire-when flags plus --body-file (or stdin); it writes frontmatter and the index together. After editing an existing note run `cwf ai memory index`. Before adoption maintain retained notes and their legacy index entries directly. Archive with `cwf ai memory retire <name>...`; it maintains either index format.

Keep this index under 200 lines and 20480 bytes: Claude auto-loads at
most the first 25 KB / 200 lines, and `cwf ai lint` fails above either
budget (bytes configurable via ai.lint.memory_index_max_bytes). Each
bullet is a one-line hook, not a story: put the detail in the linked
note and keep bullets under 600 characters
(ai.lint.memory_hook_max_chars).

## Index

- [perl-mdf-root-move](perl-mdf-root-move.md) — move-unit perl one-liners: `\Q$MDF_ROOT\E` interpolates to an empty pattern and shreds files; escape the `$`, re-copy fresh, then grep for leftovers and `config/zsh` hand-edit cases. Retire when DEV-43/DEV-44 are merged.
