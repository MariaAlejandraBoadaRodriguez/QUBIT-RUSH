# External blockers

Items that need the owner or an external service. Everything independent of them is implemented.

## 1. GitHub write access from this session (BLOCKED)
- `git push -u origin claude/intelligent-wozniak-l6gr6q` → `403`: "Claude doesn't have GitHub access to MariaAlejandraBoadaRodriguez/QUBIT-RUSH for your organization".
- GitHub API `create_branch` → `403 Resource not accessible by integration` (read access works).
- Effect: commits exist only in this session's local clone; the emulator workflow (Gate E) cannot run because nothing reaches GitHub.
- Re-checked after the final commit: still `403`.
- Owner action: connect GitHub at https://claude.ai/connect-github and install the Claude GitHub App on the repository with write access, then push the branch (or start a new session with write access and push).
- Fallback: the session produced a git bundle of every commit on this branch (`qubit-rush-branch.bundle`, in the session scratchpad). To publish it from any clone of the repository:
  `git fetch /path/to/qubit-rush-branch.bundle claude/intelligent-wozniak-l6gr6q:claude/intelligent-wozniak-l6gr6q && git push -u origin claude/intelligent-wozniak-l6gr6q`
  The push triggers `.github/workflows/android-emulator.yml`.

## 2. Android emulator / device run (Gate E runtime) — BLOCKED / NOT VERIFIED
- No KVM in this container, so no local emulator. `.github/workflows/android-emulator.yml` runs the emulator smoke test on GitHub Actions, but it cannot be triggered until blocker 1 is resolved.
- Physical-device testing is done by the owner.

## 3. AdMob production configuration — owner action
- Needs: AdMob app ID, rewarded ad unit ID, Play Console target-audience decision (Families policy). Supply as build-time environment variables (see `docs/ADS_INTEGRATION.md`). Never commit them.

## 4. Release signing — owner action
- Upload keystore and passwords for the signed AAB (Play App Signing). See README "Release AAB".

## 5. Play Console, privacy policy URL, Data safety form, legal review — owner action
- See `docs/PLAY_SUBMISSION_CHECKLIST.md`.
