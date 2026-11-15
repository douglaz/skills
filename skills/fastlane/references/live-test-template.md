# Live test: <project>

A live test exercises the deployed system the way a real user would, from start to finish.
Fill in each section once per project and reuse it on every fast-lane iteration. Change it only
when the owner's goal changes. Get the owner's OK before the first run if it spends money or
touches anything shared.

## Who the user is and what they want

One or two sentences: who the user is, what they're trying to get done, and where they start.
Example: "A first-time visitor opens the page on a desktop browser, types a goal, pays the
invoice and expects a working server at the end."

## The journey

Number each step the user takes, in order, and give what they should see after each one.
Use the user's own actions (open, type, click, pay, wait, read), not internal calls.

1. ...
2. ...

## Where it runs and how the candidate gets there

- The environment: a URL, a host, a fresh install directory, a package registry.
- How to deploy a commit, in exact commands or a script path.
- How to confirm the deployed artefacts are the commit's own, for example by hashes.
- How to roll back.

## How it's driven

- The driver script's path and how to run it as a unit.
- It must use the paths a user hits: a real browser, the real binary, the real API, real
  backends. List anything that can't be driven that way, and why.
- Where its progress and evidence land, and what it must never capture, such as secrets or
  raw credentials.

## Perfect means

- Every journey step completes.
- Everything the user sees is right: wording, no debug-looking or unreadable messages, no
  extra clicks, reasonable waits.
- Any project-specific checks, such as "the server answers on its own address" or "the
  receipt shows the amount paid".

## Cost, limits and cleanup

- Money or credit spent per run, and the caps across all runs.
- What each run creates (servers, accounts, credit) and how to delete it afterwards.
- Anything off-limits, such as production systems or shared resources.

## Expected duration

Give a wall-clock estimate. Over 20 minutes, make it faster before iterating (owner's iteration rule).

## Spec-only projects

There is no live test. Write "spec-only: the focus is writing it" here and skip the sections above.
