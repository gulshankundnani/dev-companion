# Patterns playbook

## Sequences and numbers
Differences (1st, 2nd), ratios, modulo/periodicity, known families (arithmetic, geometric, Fibonacci-like, polynomial). A rule must explain all given terms; predict the next term and say how confident.

## Text and regex
Collect 10-20 real samples incl. edge cases; write the narrowest regex that matches all positives and none of the negatives; test it on both sets; anchor it; avoid catastrophic backtracking (nested quantifiers).

## Repetition in data or logs
Normalise variable parts (ids, numbers, timestamps -> placeholders), then group and count templates; look at periodicity by hour/day; bursts vs steady rate.

## Design patterns and structures in code
Name the pattern only with evidence (classes/roles that match); note where the code deviates and whether that matters. Repeated hand-written blocks = candidate for extraction (`code-reuse`).

## Report
The pattern, how many cases it covers, the exceptions, and a test that would falsify it.
