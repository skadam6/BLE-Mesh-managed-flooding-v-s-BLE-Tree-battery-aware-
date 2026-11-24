# File manifest and paper correspondence

## Data used directly in the five-page letter

- Fig. 2: baseline energy and PDR (`Fig02a_*`, `Fig02b_*`)
- Fig. 3: crossover map and geometry/hop sensitivity (`Fig03a_*`, `Fig03b_*`)
- Fig. 4: relay-fraction sensitivity (`Fig04_*`)
- Fig. 5: communication-model sensitivity (`Fig05_*`)
- Fig. 6: failure persistence and Tree recovery (`Fig06a_*`, `Fig06b_*`)
- Fig. 7: receiver-duty and load-aware crossover (`Fig07a_*`, `Fig07b_*`)
- Table I: simulation configuration
- Table II: reliability-target sensitivity
- Table III(a): dynamic network energy per round
- Table III(b): forwarding-policy sensitivity

## Reproduction levels

1. **Inspect exact values** — read the CSV files under `data/`.
2. **Regenerate plots** — run scripts under `scripts/`; no Monte Carlo rerun is needed.
3. **Rerun simulations** — run the drivers under `simulations/`.
4. **Audit supporting checks** — inspect `data/supplementary_validation/`.

The MAT files under `data/checkpoints/` are saved checkpoints from the full sensitivity runs and are included for convenience.
