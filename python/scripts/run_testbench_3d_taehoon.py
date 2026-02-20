import argparse
import os
import sys

# Allow running the script directly without installing the package.
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from pdn import run_3d_taehoon


def main():
    parser = argparse.ArgumentParser(description="Run testbench_3D_Taehoon MATLAB-equivalent PDN simulation")
    parser.add_argument(
        "--excel",
        default="../3D_PDN_Taehoon+Madison/inputs/tb_inputs_RESNET_3D_22nm.xlsx",
        help="Path to tb_inputs_RESNET_3D_22nm.xlsx",
    )
    parser.add_argument("--output", default="./results", help="Output directory for results")
    parser.add_argument("--system-sheet", default="system")
    parser.add_argument("--chip-sheet", default="chip")
    parser.add_argument("--block-sheet", default="block_layout_specs")
    parser.add_argument("--bridge-flag", type=int, default=0)
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)
    run_3d_taehoon(
        args.excel,
        output_dir=args.output,
        system_sheet=args.system_sheet,
        chip_sheet=args.chip_sheet,
        block_sheet=args.block_sheet,
        bridge_flag=args.bridge_flag,
    )


if __name__ == "__main__":
    main()
