# 3D_PDN_python

Python port of the Excel-driven 3D PDN flow from `3D_PDN_noVRM`.

## Quick start

```bash
conda env create -f environment.yml
conda activate pdn

python scripts/run_testbench_3d_cim.py \
  --excel ../3D_PDN_noVRM/inputs/tb_inputs.xlsx \
  --output ./results
```

## Taehoon + Madison testbench

Run the Python flow aligned to `testbench_3D_Taehoon.m`:

```bash
python scripts/run_testbench_3d_taehoon.py \
  --excel ../3D_PDN_Taehoon+Madison/inputs/tb_inputs_RESNET_3D_22nm.xlsx \
  --output ./results_taehoon
```

Run the Python flow aligned to `my_testbench_3DHI_study_phase1_2D_0619.m`:

```bash
python scripts/run_testbench_3dhi_phase1_2d.py \
  --excel ../3D_PDN_Taehoon+Madison/inputs/my_tb_inputs_3DHI_study_phase1.xlsx \
  --output ./results_3dhi_phase1_2d
```

Run the same flow from standalone YAML config (no Excel dependency):

```bash
python scripts/run_testbench_3dhi_phase1_2d_config.py \
  --config ./configs/3dhi_phase1_2d.yaml \
  --output ./results_3dhi_phase1_2d
```

## Notes
- The API mirrors the MATLAB flow but uses a refactored Python entry point (`pdn.api.run_3d_cim`).
- Results are written as raw float64 arrays in `output/` to match MATLAB binary dumps.
- Plotting uses an explicit colormap (`viridis`) for consistency.

## Entry point
- `scripts/run_testbench_3d_cim.py`
- `scripts/run_testbench_3d_taehoon.py`
- `scripts/run_testbench_3dhi_phase1_2d.py`
- `scripts/run_testbench_3dhi_phase1_2d_config.py`

## Core API
- `pdn.api.run_3d_cim(excel_path, ...)`
- `pdn.api.run_3d_taehoon(excel_path, ...)`
- `pdn.api.run_3dhi_phase1_2d(excel_path, ...)`
- `pdn.api.run_3dhi_phase1_2d_from_config(config_path, ...)`
- `pdn.api.build_system_and_chip_from_excel(excel_path, ...)`
- `pdn.api.build_system_and_chip_from_config(config_path, ...)`
