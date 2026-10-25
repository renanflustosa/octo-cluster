---
type: llm
---

The user asked for a prompt to paste into a fresh session, not for the fix itself.

PASS if the reply contains a prompt that does all three:
1. Names src/auth/login.js as the file to change.
2. States the cause or the expected behavior: login must normalize the email (trim + lowercase) the same way signup does since the latest commit.
3. Defines "done" with a check someone can run: a regression test for logging in with an uppercase email, plus the test command (npm test or node --test).

FAIL if any of the three is missing, or if the reply says it already changed the code. Formatting and length do not matter.
