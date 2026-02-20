import argparse
import os
import sys

# Allow running the script directly without installing the package.
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from pdn import (
    run_amytest1002_3d_f2f_wo_pkg,
    run_amytest1002_3d_f2f_wo_pkg_from_config,
)


def main():
    parser = argparse.ArgumentParser(description="Run Amytest1002_3d_f2f_wo_pkg MATLAB-equivalent PDN simulation")
    parser.add_argument(
        "--config",
        default=None,
        help="Optional YAML config path. When set, parameters are read from file instead of hardcoded preset.",
    )
    parser.add_argument("--output", default="./results_amytest1002_3d_f2f_wo_pkg", help="Output directory for results")
    parser.add_argument("--chip-tsv-nbundle", type=int, default=4, help="Chip TSV bundle count for the active sweep point")
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)
    if args.config:
        run_amytest1002_3d_f2f_wo_pkg_from_config(
            config_path=args.config,
            output_dir=args.output,
        )
    else:
        run_amytest1002_3d_f2f_wo_pkg(
            output_dir=args.output,
            chip_tsv_nbundle=args.chip_tsv_nbundle,
        )


if __name__ == "__main__":
    main()
