import argparse
import os
import sys

# Allow running the script directly without installing the package.
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from pdn import run_3dhi_phase1_2d_from_config


def main():
    parser = argparse.ArgumentParser(description="Run 3DHI phase1 2D PDN simulation from YAML config")
    parser.add_argument(
        "--config",
        default="./configs/3dhi_phase1_2d.yaml",
        help="Path to YAML config file",
    )
    parser.add_argument("--output", default="./results_3dhi_phase1_2d", help="Output directory for results")
    parser.add_argument("--bridge-flag", type=int, default=None, help="Optional override for bridge FLAG")
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)
    run_3dhi_phase1_2d_from_config(
        args.config,
        output_dir=args.output,
        bridge_flag=args.bridge_flag,
    )


if __name__ == "__main__":
    main()
