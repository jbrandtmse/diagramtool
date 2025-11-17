# Class Length Guidelines

Status: Active
Scope: All source and test classes in this repo (ObjectScript, IRIS, and any other languages under `src/`)

## Policy

- **Soft limit:** Any single class file that approaches **700 lines** of code (including comments and tests) **must be evaluated for refactoring**.
- **Hard trigger:** Once a class reaches **~750 lines**, refactoring **must be scheduled and tracked** (story, dev notes, or TODO) and executed as soon as practical.
- This applies equally to:
  - Production code (e.g., classes under `src/MALIB/Util/**`, `src/Ens/**` where permitted).
  - Test code (e.g., `src/MALIB/Test/**`).

## Rationale

- Very large classes are:
  - Harder to understand and review.
  - More error‑prone when making changes (merge conflicts, duplicated helpers, dead code).
  - Difficult for tools and language servers to handle cleanly.
- Keeping classes under ~700 lines encourages:
  - Clear separation of concerns.
  - Focused, composable helpers.
  - Easier unit testing and refactoring.

## Refactoring Expectations

When a class approaches or exceeds 700 lines:

1. **Identify logical groupings**
   - Group methods by responsibility (e.g., parsing, data load, correlation, orchestration, test helpers).
   - Look for natural seams (e.g., feature stories, AC groupings, or public API vs internal helpers).

2. **Extract coherent sub‑classes or modules**
   - For production code:
     - Prefer extracting well‑named utility/helper classes under the same package.
     - Keep public APIs stable; move implementation details behind the façade.
   - For test code:
     - Split into multiple `*Test` classes along feature/story boundaries (e.g., `*SessionSpecTest`, `*LoaderTest`, `*CorrelationTest`, `*ST006Test`).

3. **Preserve behavior with tests**
   - Ensure existing tests are moved, not deleted.
   - Re‑run the full test suite after splitting to confirm no regressions.

4. **Document the split**
   - Add a brief note in the relevant story/dev notes or hand‑off explaining:
     - Which class was split.
     - New class names and responsibilities.
     - Any known follow‑ups.

## Process Hooks

- During code review, any class near or beyond 700 lines should trigger a **refactor discussion**.
- Automated or manual checks may flag such classes for future work (e.g., TODO comments, QA gates, or dedicated refactor stories).

## DiagramTool Specific Note

- `MALIB.Test.DiagramToolTest` has now crossed this threshold and **must be split into multiple test classes** (by story/feature) as part of ongoing DiagramTool work.
