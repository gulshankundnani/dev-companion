# Mathematics playbook

1. **Restate**: knowns, unknowns, constraints, domain (integers? reals? positive?), units.
2. **Plan**: name the method (substitution, induction, contradiction, algebraic manipulation, calculus, linear algebra, probability rules, numeric method).
3. **Work**: show each step with the rule used; keep exact forms until the end, then round with stated precision.
4. **Verify**:
   - Substitute the answer back.
   - Edge cases: 0, 1, negatives, empty, limits, division by zero, domain boundaries.
   - Dimensional/unit check; order-of-magnitude estimate.
   - Numeric spot check with a script (`[math]::`, PowerShell, or Python if available) for 2-3 random inputs.
5. **Proofs**: state what is proven and under which assumptions; for a false claim give a counter-example.
6. **Statistics**: state the model and assumptions (independence, distribution), sample size, uncertainty (interval, not just a point).

Report: answer first, then the working, then checks performed.
