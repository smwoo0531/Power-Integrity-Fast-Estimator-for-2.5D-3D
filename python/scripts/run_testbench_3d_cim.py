import argparse
import os
import sys

# Allow running the script directly without installing the package.
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from pdn import run_3d_cim


def main():
    parser = argparse.ArgumentParser(description="Run Excel-driven 3D CIM PDN simulation")
    parser.add_argument("--excel", required=True, help="Path to tb_inputs.xlsx")
    parser.add_argument("--output", default="./results", help="Output directory for results")
    parser.add_argument("--system-sheet", default="system")
    parser.add_argument("--chip-sheet", default="chip")
    parser.add_argument("--block-sheet", default="block_layout_specs")
    parser.add_argument("--bridge-flag", type=int, default=0)
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)
    run_3d_cim(
        args.excel,
        output_dir=args.output,
        system_sheet=args.system_sheet,
        chip_sheet=args.chip_sheet,
        block_sheet=args.block_sheet,
        bridge_flag=args.bridge_flag,
    )


if __name__ == "__main__":
    main()
