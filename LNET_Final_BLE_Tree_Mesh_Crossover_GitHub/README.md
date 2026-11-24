# Reproducibility package: BLE Tree vs managed-flooding BLE Mesh

This repository contains the MATLAB simulation code, frozen numerical outputs, editable MATLAB figures, and plotting scripts associated with the letter:

**When Is Managed-Flooding BLE Mesh Better Than BLE Tree? An Energy–Reliability Crossover Study for Multi-Hop IoT Networks**

The folder names and file names follow the numbering used in the revised letter so that each reported result can be traced directly to its numerical data and plotting script.

## Requirements

- MATLAB R2025b (the simulations were executed with R2025b)
- No specialized toolbox is required by the simulation drivers
- Random-number generator: Twister, base seed 17 with deterministic offsets

## Quick reproduction from frozen numerical outputs

The fastest way to reproduce the manuscript figures is to use the included CSV files:

```matlab
run('scripts/plot_all_manuscript_figures.m')
```

The regenerated panels are written to `figures/generated/` in PDF, PNG, and editable FIG formats.

## Full simulation workflow

The three standalone simulation drivers are under `simulations/`:

1. `01_baseline_simulation.m` — baseline network-size, forwarding-unavailability, and crossover data.
2. `02_validation_simulation.m` — energy-event audit, relay-fraction sensitivity, reliability-target sensitivity, high-trial boundary refinement, and shared/common failure-mask checks.
3. `03_sensitivity_simulation.m` — communication-model, persistent/correlated unavailability, Tree recovery, receiver-duty, load-aware crossover, geometry/propagation, and forwarding-policy sensitivity.

`run_all_simulations.m` executes the three campaigns sequentially. Fresh outputs are written under the `simulations/` folder (`results/`, `validation_results/`, and `sensitivity_results/`). The repository already contains the frozen numerical outputs used in the paper, so rerunning the simulations is not required to inspect or replot the reported results.

## Manuscript figure mapping

| Manuscript item | Data file(s) | Plotting script |
|---|---|---|
| Fig. 2(a), energy vs. network size | `data/Fig02a_energy_vs_nodes.csv` | `scripts/plot_Fig02_baseline.m` |
| Fig. 2(b), PDR vs. forwarding unavailability | `data/Fig02b_pdr_vs_unavailability.csv` | `scripts/plot_Fig02_baseline.m` |
| Fig. 3(a), baseline crossover map | `data/Fig03a_*` | `scripts/plot_Fig03_crossover_geometry.m` |
| Fig. 3(b), geometry/hop-count dependence | `data/Fig03b_geometry_hop_sensitivity.csv` | `scripts/plot_Fig03_crossover_geometry.m` |
| Fig. 4(a,b), relay-fraction sensitivity | `data/Fig04_relay_fraction_sensitivity.csv` | `scripts/plot_Fig04_relay_fraction.m` |
| Fig. 5(a,b), communication-model sensitivity | `data/Fig05_communication_model_sensitivity.csv` | `scripts/plot_Fig05_communication_model.m` |
| Fig. 6(a), failure-model sensitivity | `data/Fig06a_failure_model_sensitivity.csv` | `scripts/plot_Fig06_failure_recovery.m` |
| Fig. 6(b), Tree retry/reconstruction | `data/Fig06b_tree_retry_reconstruction.csv` | `scripts/plot_Fig06_failure_recovery.m` |
| Fig. 7(a), receiver-duty sensitivity | `data/Fig07a_receiver_duty_cycle_sensitivity.csv` | `scripts/plot_Fig07_duty_load.m` |
| Fig. 7(b), load-aware crossover | `data/Fig07b_load_failure_crossover.csv` | `scripts/plot_Fig07_duty_load.m` |

Fig. 1 is the conceptual topology illustration and does not require simulation data.

## Manuscript table mapping

- `data/Table01_simulation_configuration.csv` — Table I.
- `data/Table02_reliability_target_sensitivity.csv` — Table II.
- `data/Table03a_energy_accounting.csv` — Table III(a), exact values printed in the letter.
- `data/Table03b_forwarding_policy_sensitivity.csv` — Table III(b), exact values printed in the letter.

The raw forwarding-policy outputs underlying Table III(b), including confidence intervals and event counts, are stored in `data/supplementary_validation/`.

## Additional validation retained for independent checking

`data/supplementary_validation/` contains additional validation results that support the reported conclusions but are not all printed in the five-page letter:

- `CommonMask_validation_across_N.csv` — common physical unavailability masks for N = 40, 80, 120, 160, and 200 at p_f = 0.10 and 0.15.
- `CommonMask_baseline_N80.csv` — baseline common-mask validation at N = 80.
- `EventCount_energy_audit.csv` — transmit/receive event accounting used to verify the large energy gap.
- `Tree_boundary_refinement_300_trials.csv` — high-trial Tree PDR boundary results.
- Raw Tree-parent, Mesh-relay-selection, TTL, and relay-retransmission sensitivity files.

## Notes on the models

The study compares an advertising-based single-parent BLE Tree with managed-flooding BLE Mesh under matched topology, channel, traffic, and radio-energy assumptions. The collision-correlation and receiver-local contention models are sensitivity brackets rather than a bit-exact BLE controller/RF implementation. Directed forwarding and Friend/Low Power Node operation are outside the evaluated managed-flooding baseline.

The `figures/editable/` directory contains MATLAB FIG files for manual formatting. Matching PDF and PNG previews are provided under `figures/pdf/` and `figures/png/`.
