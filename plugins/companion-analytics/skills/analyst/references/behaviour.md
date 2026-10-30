# Behaviour and root-cause playbook (systems, programs, users)

1. **Observed vs expected**: exact symptom, where, since when, how often, who is affected. Expected behaviour and its source (spec, previous version, user).
2. **Timeline**: events, deploys, config/data changes, logs, around the first occurrence. Use timestamps in one time zone.
3. **States and transitions**: draw the state machine or request flow; mark where actual and expected diverge.
4. **Reproduce**: smallest steps/data that show it; note what does not reproduce it (environment, user, data, timing).
5. **Hypotheses**: list candidates; for each, the evidence that would confirm or refute it; test the cheapest decisive one first.
6. **Root cause**: 5 whys until a cause you can act on; for multiple factors a fault tree (AND/OR). Distinguish trigger, root cause and contributing factors.
7. **Verify**: the fix or explanation predicts the observations, including the cases that did not fail.

User behaviour: funnels, cohorts, before/after a change; check sample size and seasonality before calling a difference real.

Report: cause with confidence, evidence chain, reproduction, fix and prevention, open questions.
