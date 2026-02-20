from types import SimpleNamespace
from typing import List, Optional

import numpy as np
import yaml

from .excel import ExcelBook
from .legacy import logic_power_map_gen, power_noise_sim


def ns(**kwargs):
    return SimpleNamespace(**kwargs)


def _ensure_attr(obj, name, default=None):
    if not hasattr(obj, name):
        setattr(obj, name, default if default is not None else SimpleNamespace())
    return getattr(obj, name)


def _coerce_per_die(values, die_count: int) -> np.ndarray:
    arr = np.asarray(values, dtype=float).reshape(-1)
    arr = arr[~np.isnan(arr)]
    if arr.size == 0:
        return np.zeros(die_count, dtype=float)
    if arr.size >= die_count:
        return arr[:die_count]
    pad = np.full(die_count - arr.size, arr[-1], dtype=float)
    return np.concatenate([arr, pad])


def _prepare_uniform_two_die_setup(system, chip):
    # Match Taehoon-family testbenches that use uniform die-wide current injection.
    system.version = 0
    system.TOV = 0
    system.drawP = 1
    system.clamp = 0
    system.background_last_die_half_area = 0

    chip.Tr = _coerce_per_die(chip.Tr, chip.N)
    chip.Tf = _coerce_per_die(chip.Tf, chip.N)
    chip.Tc = _coerce_per_die(chip.Tc, chip.N)
    chip.power = _coerce_per_die(chip.power, chip.N)

    chip.blk_num = np.zeros(chip.N, dtype=int)
    chip.map = np.zeros((0, 6), dtype=float)
    chip.blk_name = [""] * 1

    chip.Metal.N = np.array([4, 4], dtype=float)
    chip.Metal.p = np.array([18e-9, 18e-9], dtype=float)
    metal_ar_4 = np.array([1.8, 1.8, 1.8, 0.4], dtype=float)
    chip.Metal.ar = np.concatenate([metal_ar_4, metal_ar_4])

    metal_pitch_4 = np.array([160e-9, 560e-9, 560e-9, 39.5e-6], dtype=float) * 2
    chip.Metal.pitch = np.concatenate([metal_pitch_4, metal_pitch_4])

    metal_thick_4 = np.array([144e-9, 144e-9, 324e-9, 7e-6], dtype=float)
    chip.Metal.thick = np.concatenate([metal_thick_4, metal_thick_4])

    via_R_4 = np.array([0.4253, 0.4253, 0.1890, 0.0], dtype=float) * 45
    chip.Via.R = np.concatenate([via_R_4, via_R_4])

    via_N_4 = np.array([4e9, 4e9, 8e8, 1e5], dtype=float) / 45
    chip.Via.N = np.concatenate([via_N_4, via_N_4])


def _config_to_object(value):
    if isinstance(value, dict):
        return ns(**{k: _config_to_object(v) for k, v in value.items()})
    if isinstance(value, list):
        if len(value) == 0:
            return np.array([], dtype=float)
        if all(isinstance(v, (int, float, bool, np.integer, np.floating)) for v in value):
            return np.asarray(value, dtype=float)
        if all(isinstance(v, list) for v in value):
            try:
                return np.asarray(value, dtype=float)
            except (TypeError, ValueError):
                pass
        return [_config_to_object(v) if isinstance(v, dict) else v for v in value]
    if isinstance(value, (np.integer, np.floating)):
        return float(value)
    return value


def build_system_and_chip_from_config(
    config_path: str,
    bridge_flag: Optional[int] = None,
):
    with open(config_path, "r", encoding="utf-8") as f:
        cfg = yaml.safe_load(f)

    if not isinstance(cfg, dict):
        raise ValueError(f"Config file must contain a mapping: {config_path}")
    if "system" not in cfg or "chip" not in cfg:
        raise ValueError("Config must contain top-level keys: 'system' and 'chip'")

    system = _config_to_object(cfg["system"])
    chip = _config_to_object(cfg["chip"])

    if not hasattr(system, "chip"):
        system.chip = ns()
    if not hasattr(system.chip, "N"):
        system.chip.N = 1
    system.chip.N = int(system.chip.N)

    if system.chip.N != 1:
        raise ValueError("Config loader currently supports one-chip flows (system.chip.N == 1).")

    if not hasattr(system, "type"):
        system.type = ns(P=1, G=2)
    if not hasattr(system, "bridge"):
        system.bridge = ns(FLAG=0)
    if bridge_flag is not None:
        system.bridge.FLAG = int(bridge_flag)
    else:
        system.bridge.FLAG = int(getattr(system.bridge, "FLAG", 0))

    if not hasattr(system, "Vdd"):
        system.Vdd = ns()
    if not hasattr(system, "box"):
        system.box = ns()

    if not hasattr(chip, "HB"):
        chip.HB = ns(R=0.0)

    chip.N = int(chip.N)
    chip.meshlvl = int(chip.meshlvl)
    chip.xl = float(getattr(chip, "xl", (system.pkg.Xsize - chip.Xsize) / 2))
    chip.yb = float(getattr(chip, "yb", (system.pkg.Ysize - chip.Ysize) / 2))

    chip.map = np.asarray(chip.map, dtype=float)
    if chip.map.size == 0:
        chip.map = np.zeros((0, 6), dtype=float)
    elif chip.map.ndim == 1:
        chip.map = chip.map.reshape(1, -1)

    chip.blk_num = np.asarray(chip.blk_num, dtype=int)
    chip.power = np.asarray(chip.power, dtype=float)
    chip.cap_per = np.asarray(chip.cap_per, dtype=float)
    chip.cap_th = np.asarray(chip.cap_th, dtype=float)
    chip.tsv_map = np.asarray(chip.tsv_map, dtype=float)
    chip.Tr = _coerce_per_die(chip.Tr, chip.N)
    chip.Tf = _coerce_per_die(chip.Tf, chip.N)
    chip.Tc = _coerce_per_die(chip.Tc, chip.N)

    chip.Metal.N = np.asarray(chip.Metal.N, dtype=float)
    chip.Metal.p = np.asarray(chip.Metal.p, dtype=float)
    chip.Metal.ar = np.asarray(chip.Metal.ar, dtype=float)
    chip.Metal.pitch = np.asarray(chip.Metal.pitch, dtype=float)
    chip.Metal.thick = np.asarray(chip.Metal.thick, dtype=float)
    chip.Via.R = np.asarray(chip.Via.R, dtype=float)
    chip.Via.N = np.asarray(chip.Via.N, dtype=float)

    system.board.decap = np.asarray(system.board.decap, dtype=float)
    if system.board.decap.ndim == 1:
        system.board.decap = system.board.decap.reshape(1, -1)
    system.pkg.decap = np.asarray(system.pkg.decap, dtype=float)
    system.range = np.asarray(system.range, dtype=float)

    if hasattr(system, "connect"):
        system.connect = np.asarray(system.connect, dtype=float)
        if system.connect.size == 0:
            system.connect = np.zeros((0, 6), dtype=float)
        elif system.connect.ndim == 1:
            system.connect = system.connect.reshape(1, -1)
    else:
        system.connect = np.zeros((0, 6), dtype=float)

    chip_list = [chip]
    return system, chip_list


def build_system_and_chip_from_excel(
    excel_path: str,
    system_sheet: str = "system",
    chip_sheet: str = "chip",
    block_sheet: str = "block_layout_specs",
    bridge_flag: int = 0,
):
    book = ExcelBook(excel_path)

    system = ns()
    system.type = ns(P=1, G=2)
    system.bridge = ns(FLAG=bridge_flag)
    system.chip = ns()
    system.pkg = ns()
    system.board = ns()
    system.BGA = ns()
    system.TSV = ns()
    system.Vdd = ns()
    system.box = ns()

    # core system parameters
    period = book.read_scalar(system_sheet, "E3:E3")
    edge = book.read_scalar(system_sheet, "E4:E4")
    system.bridge_ground = book.read_scalar(system_sheet, "E5:E5")
    system.bridge_power = book.read_scalar(system_sheet, "E6:E6")
    system.chip.N = int(book.read_scalar(system_sheet, "E7:E7"))

    chip_list: List[SimpleNamespace] = []
    for _ in range(system.chip.N):
        chip_list.append(ns())

    # chip(1) base params
    chip = chip_list[0]
    chip.N = int(book.read_scalar(chip_sheet, "E5:E5"))
    chip.Xsize = book.read_scalar(chip_sheet, "E7:E7")
    chip.Ysize = book.read_scalar(chip_sheet, "E8:E8")

    chip.Metal = ns()
    chip.Metal.N = book.read_vector(chip_sheet, "E10:F10")
    chip.Metal.p = book.read_vector(chip_sheet, "E11:F11")
    chip.Metal.ar = book.read_vector(chip_sheet, "E12:L12")
    chip.Metal.pitch = book.read_vector(chip_sheet, "E13:L13") * 2
    chip.Metal.thick = book.read_vector(chip_sheet, "E14:L14")

    chip.Via = ns()
    chip.Via.R = book.read_vector(chip_sheet, "E16:L16") * 450
    chip.Via.N = book.read_vector(chip_sheet, "E17:L17") / 45

    chip.cap_per = book.read_vector(chip_sheet, "E19:F19")
    chip.cap_th = book.read_vector(chip_sheet, "E20:F20")

    chip.power = book.read_vector(chip_sheet, "E22:F22")
    _ = book.read_vector(chip_sheet, "E55:F55")

    chip.map = np.zeros((0, 6))
    chip.tsv_map = book.read_vector(chip_sheet, "E26:J26")

    chip.Tp = period
    chip.Tr = book.read_vector(chip_sheet, "E52:F52")
    chip.Tf = book.read_vector(chip_sheet, "E53:F53")
    chip.Tc = book.read_vector(chip_sheet, "E54:F54")

    chip.blk_name = [""] * 65
    chip.name = "stacked memory"
    chip.blk_num = book.read_vector(chip_sheet, "E51:F51")

    chip.TSV = ns()
    chip.TSV.d = book.read_scalar(chip_sheet, "E27:E27")
    chip.TSV.contact = book.read_scalar(chip_sheet, "E28:E28")
    chip.TSV.liner = book.read_scalar(chip_sheet, "E29:E29")
    chip.TSV.mu = book.read_scalar(chip_sheet, "E30:E30")
    chip.TSV.rou = book.read_scalar(chip_sheet, "E31:E31")
    chip.TSV.thick = book.read_scalar(chip_sheet, "E32:E32")
    chip.TSV.Nbundle = 1

    chip.ubump = ns()
    chip.ubump.rou = book.read_scalar(chip_sheet, "E34:E34")
    chip.ubump.d = book.read_scalar(chip_sheet, "E35:E35")
    chip.ubump.h = book.read_scalar(chip_sheet, "E36:E36")
    chip.ubump.px = book.read_scalar(chip_sheet, "E37:E37")
    chip.ubump.py = book.read_scalar(chip_sheet, "E38:E38")
    chip.ubump.mu = book.read_scalar(chip_sheet, "E39:E39")
    chip.ubump.scale = book.read_scalar(chip_sheet, "E40:E40")

    chip.c4 = ns()
    chip.c4.rou = book.read_scalar(chip_sheet, "E42:E42")
    chip.c4.d = book.read_scalar(chip_sheet, "E43:E43")
    chip.c4.h = book.read_scalar(chip_sheet, "E44:E44")
    chip.c4.px = book.read_scalar(chip_sheet, "E45:E45")
    chip.c4.py = book.read_scalar(chip_sheet, "E46:E46")
    chip.c4.mu = book.read_scalar(chip_sheet, "E47:E47")
    chip.c4.scale = book.read_scalar(chip_sheet, "E48:E48")
    chip.c4.Nbundle = book.read_scalar(chip_sheet, "E49:E49")

    chip.meshlvl = int(book.read_scalar(chip_sheet, "E50:E50"))

    chip.HB = ns(R=0.0)

    # package parameters
    system.pkg.Xsize = book.read_scalar(system_sheet, "E8:E8")
    system.pkg.Ysize = book.read_scalar(system_sheet, "E9:E9")
    system.pkg.wire_p = book.read_scalar(system_sheet, "E10:E10")
    system.pkg.N = book.read_scalar(system_sheet, "E11:E11")
    system.pkg.wire_thick = book.read_scalar(system_sheet, "E12:E12")
    system.pkg.decap = book.read_vector(system_sheet, "E13:G13")
    system.pkg.Rs = book.read_scalar(system_sheet, "E14:E14")
    system.pkg.Ls = book.read_scalar(system_sheet, "E15:E15")
    system.pkg.ViaR = book.read_scalar(system_sheet, "E16:E16")
    system.pkg.ViaN = book.read_scalar(system_sheet, "E17:E17")
    system.pkg.mu = book.read_scalar(system_sheet, "E18:E18")

    # board parameters
    system.board.Rs = book.read_scalar(system_sheet, "E19:E19")
    system.board.Ls = book.read_scalar(system_sheet, "E20:E20")
    system.board.decap = book.read_vector(system_sheet, "E21:G21").reshape(1, -1)

    # BGA parameters
    system.BGA.rou = book.read_scalar(system_sheet, "E22:E22")
    system.BGA.d = book.read_scalar(system_sheet, "E23:E23")
    system.BGA.h = book.read_scalar(system_sheet, "E24:E24")
    system.BGA.px = book.read_scalar(system_sheet, "E25:E25")
    system.BGA.py = book.read_scalar(system_sheet, "E26:E26")
    system.BGA.mu = book.read_scalar(system_sheet, "E27:E27")
    system.BGA.scale = book.read_scalar(system_sheet, "E28:E28")

    chip.xl = (system.pkg.Xsize - chip.Xsize) / 2
    chip.yb = (system.pkg.Ysize - chip.Ysize) / 2

    if system.bridge.FLAG == 0 or system.chip.N < 2:
        system.connect = np.zeros((0, 6))
    else:
        # These bridge configurations assume chip(2) exists; guard for N>1
        chip2 = chip_list[1]
        if system.bridge.FLAG == 1:
            system.connect = np.array([[chip2.xl + chip2.Xsize - edge, chip2.yb + 0.2e-3, edge * 5 + 0.5e-3, 9.6e-3, 0, 0]])
        elif system.bridge.FLAG == 2:
            system.connect = np.array([
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 1.5e-3, edge * 2 + 0.5e-3, 3e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 5.5e-3, edge * 2 + 0.5e-3, 3e-3, 0, 0],
            ])
        elif system.bridge.FLAG == 3:
            system.connect = np.array([
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 1e-3, edge * 2 + 0.5e-3, 2e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 4e-3, edge * 2 + 0.5e-3, 2e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 7e-3, edge * 2 + 0.5e-3, 2e-3, 0, 0],
            ])
        elif system.bridge.FLAG == 4:
            system.connect = np.array([
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 0.8e-3, edge * 2 + 0.5e-3, 1.5e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 3.1e-3, edge * 2 + 0.5e-3, 1.5e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 5.4e-3, edge * 2 + 0.5e-3, 1.5e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 7.7e-3, edge * 2 + 0.5e-3, 1.5e-3, 0, 0],
            ])
        elif system.bridge.FLAG == 5:
            system.connect = np.array([
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 0.6e-3, edge * 2 + 0.5e-3, 1.2e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 2.5e-3, edge * 2 + 0.5e-3, 1.2e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 4.4e-3, edge * 2 + 0.5e-3, 1.2e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 6.3e-3, edge * 2 + 0.5e-3, 1.2e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 8.2e-3, edge * 2 + 0.5e-3, 1.2e-3, 0, 0],
            ])
        else:
            system.connect = np.array([
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 0.5e-3, edge * 2 + 0.5e-3, 1e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 2.1e-3, edge * 2 + 0.5e-3, 1e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 3.7e-3, edge * 2 + 0.5e-3, 1e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 5.3e-3, edge * 2 + 0.5e-3, 1e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 6.9e-3, edge * 2 + 0.5e-3, 1e-3, 0, 0],
                [chip2.xl + chip2.Xsize - edge, chip2.yb + 8.5e-3, edge * 2 + 0.5e-3, 1e-3, 0, 0],
            ])

    system.bridge_decap = book.read_scalar(system_sheet, "E29:E29")
    system.inter = book.read_scalar(system_sheet, "E30:E30")
    system.emib = book.read_scalar(system_sheet, "E31:E31")
    system.emib_via = book.read_scalar(system_sheet, "E32:E32")
    system.stacked_die = book.read_scalar(system_sheet, "E33:E33")

    system.TSV.Nbundle = book.read_scalar(system_sheet, "E34:E34")
    system.TSV.d = book.read_scalar(system_sheet, "E35:E35")
    system.TSV.px = book.read_scalar(system_sheet, "E36:E36")
    system.TSV.py = book.read_scalar(system_sheet, "E37:E37")
    system.TSV.contact = book.read_scalar(system_sheet, "E38:E38")
    system.TSV.liner = book.read_scalar(system_sheet, "E39:E39")
    system.TSV.mu = book.read_scalar(system_sheet, "E40:E40")
    system.TSV.rou = book.read_scalar(system_sheet, "E41:E41")
    system.TSV.thick = book.read_scalar(system_sheet, "E42:E42")

    system.tran = int(book.read_scalar(system_sheet, "E43:E43"))
    system.write = int(book.read_scalar(system_sheet, "E44:E44"))
    system.gif = int(book.read_scalar(system_sheet, "E45:E45"))
    system.draw = int(book.read_scalar(system_sheet, "E46:E46"))
    system.tranplot = int(book.read_scalar(system_sheet, "E47:E47"))
    system.drawP = int(book.read_scalar(system_sheet, "E48:E48"))
    system.drawC = int(book.read_scalar(system_sheet, "E49:E49"))
    system.drawM = int(book.read_scalar(system_sheet, "E50:E50"))
    system.clamp = int(book.read_scalar(system_sheet, "E51:E51"))
    system.range = book.read_vector(system_sheet, "E52:F52")
    system.skip = int(book.read_scalar(system_sheet, "E53:E53"))
    system.TR_FLAG = int(book.read_scalar(system_sheet, "E54:E54"))
    system.T = book.read_scalar(system_sheet, "E55:E55")
    system.dt = book.read_scalar(system_sheet, "E56:E56")
    system.Vdd.val = book.read_scalar(system_sheet, "E57:E57")

    # defaults for missing fields
    system.version = getattr(system, "version", 0)
    system.embeddedchip = getattr(system, "embeddedchip", 1)
    system.RDL = getattr(system, "RDL", 0)
    system.TOV = getattr(system, "TOV", 0)

    # block layout specs
    substrate_thick = book.read_scalar(block_sheet, "C5:C5")
    tsv_diameter = np.array([10]) * 1e-6

    chip_size = book.read_scalar(block_sheet, "C9:C9")
    x_TSV = book.read_scalar(block_sheet, "C10:C10")
    pwr_logic = book.read_scalar(block_sheet, "C11:C11")
    pwr_mem = book.read_scalar(block_sheet, "C12:C12")

    x_margin_adc = book.read_scalar(block_sheet, "C16:C16")
    y_margin_adc = book.read_scalar(block_sheet, "C17:C17")
    nADC = int(book.read_scalar(block_sheet, "C18:C18"))
    nyADC = int(book.read_scalar(block_sheet, "C19:C19"))
    nxADC = int(book.read_scalar(block_sheet, "C20:C20"))
    block_dimension_adc = book.read_scalar(block_sheet, "C21:C21")
    y_pitch_adc = book.read_scalar(block_sheet, "C22:C22")
    x_pitch_adc = book.read_scalar(block_sheet, "C23:C23")
    per_ADC_power = book.read_scalar(block_sheet, "C24:C24")
    x_dim_adc = book.read_scalar(block_sheet, "C25:C25")
    pool_gb_xsize_adc = book.read_scalar(block_sheet, "C26:C26")
    y_dim_pool = book.read_scalar(block_sheet, "C27:C27")
    y_dim_gb = book.read_scalar(block_sheet, "C28:C28")
    tsv_xsize_adc = book.read_scalar(block_sheet, "C29:C29")
    pool_power = book.read_scalar(block_sheet, "C30:C30")
    gb_power = book.read_scalar(block_sheet, "C31:C31")

    x_margin_MEM = book.read_scalar(block_sheet, "C34:C34")
    y_margin_MEM = book.read_scalar(block_sheet, "C35:C35")
    nMEM = int(book.read_scalar(block_sheet, "C36:C36"))
    nyMEM = int(book.read_scalar(block_sheet, "C37:C37"))
    nxMEM = int(book.read_scalar(block_sheet, "C38:C38"))
    block_dimension_mem = book.read_scalar(block_sheet, "C39:C39")
    y_pitch_mem = book.read_scalar(block_sheet, "C40:C40")
    x_pitch_mem = book.read_scalar(block_sheet, "C41:C41")
    per_MEM_power = book.read_scalar(block_sheet, "C42:C42")
    tsv_xsize_mem = book.read_scalar(block_sheet, "C43:C43")
    x_dim_mem = book.read_scalar(block_sheet, "C44:C44")

    # extra sweep parameters
    ubump_pitch = np.array([36]) * 1e-6
    ubump_dia = np.array([18]) * 1e-6
    c4_pitch = np.array([200]) * 1e-6
    c4_dia = np.array([50]) * 1e-6

    # stash for run
    block_specs = dict(
        tsv_diameter=tsv_diameter,
        chip_size=chip_size,
        pwr_logic=pwr_logic,
        pwr_mem=pwr_mem,
        x_margin_adc=x_margin_adc,
        y_margin_adc=y_margin_adc,
        nADC=nADC,
        nyADC=nyADC,
        nxADC=nxADC,
        block_dimension_adc=block_dimension_adc,
        y_pitch_adc=y_pitch_adc,
        x_pitch_adc=x_pitch_adc,
        per_ADC_power=per_ADC_power,
        x_dim_adc=x_dim_adc,
        pool_gb_xsize_adc=pool_gb_xsize_adc,
        y_dim_pool=y_dim_pool,
        y_dim_gb=y_dim_gb,
        tsv_xsize_adc=tsv_xsize_adc,
        pool_power=pool_power,
        gb_power=gb_power,
        x_margin_MEM=x_margin_MEM,
        y_margin_MEM=y_margin_MEM,
        nMEM=nMEM,
        nyMEM=nyMEM,
        nxMEM=nxMEM,
        block_dimension_mem=block_dimension_mem,
        y_pitch_mem=y_pitch_mem,
        x_pitch_mem=x_pitch_mem,
        per_MEM_power=per_MEM_power,
        tsv_xsize_mem=tsv_xsize_mem,
        x_dim_mem=x_dim_mem,
        x_TSV=x_TSV,
        ubump_pitch=ubump_pitch,
        ubump_dia=ubump_dia,
        c4_pitch=c4_pitch,
        c4_dia=c4_dia,
    )

    return system, chip_list, block_specs


def run_3d_cim(
    excel_path: str,
    output_dir: str = "./results",
    system_sheet: str = "system",
    chip_sheet: str = "chip",
    block_sheet: str = "block_layout_specs",
    bridge_flag: int = 0,
):
    system, chip_list, specs = build_system_and_chip_from_excel(
        excel_path, system_sheet=system_sheet, chip_sheet=chip_sheet, block_sheet=block_sheet, bridge_flag=bridge_flag
    )
    system.output_dir = output_dir

    chip = chip_list[0]
    for i, tsv_diam in enumerate(specs["tsv_diameter"]):
        chip.Xsize = specs["chip_size"]
        chip.Ysize = specs["chip_size"]
        chip.xl = (system.pkg.Xsize - chip.Xsize) / 2
        chip.yb = (system.pkg.Ysize - chip.Ysize) / 2
        chip.TSV.d = tsv_diam
        chip.TSV.px = tsv_diam * 10

        chip.ubump.px = specs["ubump_pitch"][i]
        chip.ubump.py = specs["ubump_pitch"][i]
        chip.ubump.d = specs["ubump_dia"][i]
        chip.ubump.h = specs["ubump_dia"][i]

        chip.c4.px = specs["c4_pitch"][i]
        chip.c4.py = specs["c4_pitch"][i]
        chip.c4.d = specs["c4_dia"][i]
        chip.c4.h = specs["c4_dia"][i]

        # Memory (chip 1) power map
        chip.power = np.array([specs["pwr_mem"], specs["pwr_logic"]], dtype=float)
        die1_map = logic_power_map_gen(
            specs["x_margin_MEM"],
            specs["y_margin_MEM"],
            specs["nyMEM"],
            specs["nxMEM"],
            specs["block_dimension_mem"],
            specs["y_pitch_mem"],
            specs["x_pitch_mem"],
            specs["per_MEM_power"],
        )
        B = logic_power_map_gen(
            (specs["x_dim_mem"] / 2 + specs["tsv_xsize_mem"] + specs["x_margin_MEM"]),
            specs["y_margin_MEM"],
            specs["nyMEM"],
            specs["nxMEM"],
            specs["block_dimension_mem"],
            specs["y_pitch_mem"],
            specs["x_pitch_mem"],
            specs["per_MEM_power"],
        )
        die1_map = np.vstack([die1_map, B])
        chip.blk_name = [""] * (specs["nMEM"] * 2)

        # Logic (chip 2) power map
        die2_map = logic_power_map_gen(
            specs["x_margin_adc"],
            specs["y_margin_adc"],
            specs["nyADC"],
            specs["nxADC"],
            specs["block_dimension_adc"],
            specs["y_pitch_adc"],
            specs["x_pitch_adc"],
            specs["per_ADC_power"],
        )
        A = logic_power_map_gen(
            (specs["x_dim_adc"] / 2 + specs["pool_gb_xsize_adc"] + specs["tsv_xsize_adc"] + specs["x_margin_adc"]),
            specs["y_margin_adc"],
            specs["nyADC"],
            specs["nxADC"],
            specs["block_dimension_adc"],
            specs["y_pitch_adc"],
            specs["x_pitch_adc"],
            specs["per_ADC_power"],
        )
        die2_map = np.vstack([die2_map, A])
        P1 = [specs["x_dim_adc"] / 2, 0, specs["pool_gb_xsize_adc"] / 2, specs["y_dim_pool"], specs["pool_power"], 0]
        GB1 = [specs["x_dim_adc"] / 2, specs["y_dim_pool"], specs["pool_gb_xsize_adc"] / 2, specs["y_dim_gb"], specs["gb_power"], 0]
        P2 = [
            specs["x_dim_adc"] / 2 + specs["pool_gb_xsize_adc"] / 2 + specs["tsv_xsize_adc"],
            specs["y_dim_gb"],
            specs["pool_gb_xsize_adc"] / 2,
            specs["y_dim_pool"],
            specs["pool_power"],
            0,
        ]
        GB2 = [
            specs["x_dim_adc"] / 2 + specs["pool_gb_xsize_adc"] / 2 + specs["tsv_xsize_adc"],
            0,
            specs["pool_gb_xsize_adc"] / 2,
            specs["y_dim_gb"],
            specs["gb_power"],
            0,
        ]
        die2_map = np.vstack([die2_map, P1, GB1, P2, GB2])

        chip.map = np.vstack([die1_map, die2_map])
        chip.blk_name = [""] * (specs["nMEM"] * 2 + specs["nADC"] * 2 + 4)
        chip.blk_num = np.array([specs["nMEM"] * 2, specs["nADC"] * 2 + 4])

        print(f"\n\nDie size: {chip.Xsize:12.3e} m")
        print(f"Die area: {chip.Xsize * chip.Ysize:12.3e} m2")
        print(f"Power for Logic: {chip.power[1]:12.3e} W")
        print(f"Power for Memory: {chip.power[0]:12.3e} W")
        print(f"Total stack power: {(chip.power[0] + chip.power[1]):12.3e} W")
        print(f"ubump diameter: {chip.ubump.d:12.3e} m")
        print(f"ubump pitch (x and y): {chip.ubump.px:12.3e} m")
        print(f"C4 diameter: {chip.c4.d:12.3e} m")
        print(f"C4 pitch (x and y): {chip.c4.px:12.3e} m")
        print(f"Number of metal layers: {chip.Metal.N[0]:12.3e}")

        power_noise_sim(system, chip_list)

    return system, chip_list


def run_3d_taehoon(
    excel_path: str,
    output_dir: str = "./results",
    system_sheet: str = "system",
    chip_sheet: str = "chip",
    block_sheet: str = "block_layout_specs",
    bridge_flag: int = 0,
):
    system, chip_list, _ = build_system_and_chip_from_excel(
        excel_path,
        system_sheet=system_sheet,
        chip_sheet=chip_sheet,
        block_sheet=block_sheet,
        bridge_flag=bridge_flag,
    )
    system.output_dir = output_dir

    chip = chip_list[0]
    _prepare_uniform_two_die_setup(system, chip)

    chip.tsv_map = np.array([0.0, 0.0, chip.Xsize, chip.Ysize], dtype=float)
    chip.TSV.d = 1e-6
    chip.TSV.px = 2e-6
    chip.TSV.py = 2e-6
    chip.TSV.thick = 50e-6
    chip.TSV.Nbundle = 1

    chip.ubump.px = 120e-6
    chip.ubump.py = 120e-6
    chip.ubump.d = 80e-6
    chip.ubump.h = 80e-6

    chip.c4.px = 200e-6
    chip.c4.py = 200e-6
    chip.c4.d = 50e-6
    chip.c4.h = 50e-6

    print(f"\n\nDie X size: {chip.Xsize:12.3e} m")
    print(f"Die Y size: {chip.Ysize:12.3e} m")
    print(f"Die area: {chip.Xsize * chip.Ysize:12.3e} m2")
    if chip.power.size >= 2:
        print(f"Power for Logic: {chip.power[1]:12.3e} W")
        print(f"Power for Memory: {chip.power[0]:12.3e} W")
        print(f"Total stack power: {(chip.power[0] + chip.power[1]):12.3e} W")
    print(f"Chip TSV Nbundle: {chip.TSV.Nbundle:12.3e}")
    print(f"ubump pitch (x and y): {chip.ubump.px:12.3e} m")
    print(f"ubump diameter: {chip.ubump.d:12.3e} m")
    print(f"C4 diameter: {chip.c4.d:12.3e} m")
    print(f"C4 pitch (x and y): {chip.c4.px:12.3e} m")
    print(f"Number of metal layers: {chip.Metal.N}")
    print(f"TSV diameter: {chip.TSV.d:12.3e} m")

    power_noise_sim(system, chip_list)
    return system, chip_list


def run_3dhi_phase1_2d(
    excel_path: str,
    output_dir: str = "./results",
    system_sheet: str = "system",
    chip_sheet: str = "chip",
    block_sheet: str = "block_layout_specs",
    bridge_flag: int = 0,
):
    system, chip_list, _ = build_system_and_chip_from_excel(
        excel_path,
        system_sheet=system_sheet,
        chip_sheet=chip_sheet,
        block_sheet=block_sheet,
        bridge_flag=bridge_flag,
    )
    system.output_dir = output_dir

    chip = chip_list[0]
    power_from_excel = np.asarray(chip.power, dtype=float).reshape(-1)

    # Match my_testbench_3DHI_study_phase1_2D_0619.m overrides.
    system.version = 0
    system.TOV = 0
    system.drawP = 1
    system.clamp = 0
    system.background_last_die_half_area = 0

    chip.blk_num = np.array([0, 0], dtype=int)
    chip.map = np.zeros((0, 6), dtype=float)
    chip.blk_name = [""] * (38880 + 38880)
    chip.name = "stacked memory"
    chip.xl = (system.pkg.Xsize - chip.Xsize) / 2
    chip.yb = (system.pkg.Ysize - chip.Ysize) / 2

    chip.tsv_map = np.array([0.0, 0.0, chip.Xsize, chip.Ysize], dtype=float)
    chip.TSV.d = 4e-6
    chip.TSV.px = 1000e-6
    chip.TSV.py = 1000e-6
    chip.TSV.thick = 50e-6
    chip.TSV.Nbundle = 8

    chip.ubump.px = 50e-6
    chip.ubump.py = 50e-6
    chip.ubump.d = 12e-6
    chip.ubump.h = 12e-6

    chip.c4.px = 100e-6
    chip.c4.py = 100e-6
    chip.c4.d = 50e-6
    chip.c4.h = 50e-6

    metal_ar_4 = np.array([1.8, 1.8, 1.8, 0.4], dtype=float)
    metal_pitch_4 = np.array([160e-9, 560e-9, 560e-9, 39.5e-6], dtype=float) * 2
    metal_thick_4 = np.array([144e-9, 144e-9, 324e-9, 7e-6], dtype=float)
    via_R_4 = np.array([0.4253, 0.4253, 0.1890, 0.0], dtype=float) * 45
    via_N_4 = np.array([4e9, 4e9, 8e8, 1e5], dtype=float) / 45

    chip.Metal.N = np.array([4, 4], dtype=float)
    chip.Metal.p = np.array([18e-9, 18e-9], dtype=float)
    chip.Metal.ar = np.concatenate([metal_ar_4, metal_ar_4])
    chip.Metal.pitch = np.concatenate([metal_pitch_4, metal_pitch_4])
    chip.Metal.thick = np.concatenate([metal_thick_4, metal_thick_4])
    chip.Via.R = np.concatenate([via_R_4, via_R_4])
    chip.Via.N = np.concatenate([via_N_4, via_N_4])

    # Keep the original E22:F22 convention from MATLAB for reporting.
    if power_from_excel.size == 1:
        chip.power = np.array([power_from_excel[0], power_from_excel[0]], dtype=float)
    elif power_from_excel.size >= 2:
        chip.power = power_from_excel[:2].astype(float)

    # MATLAB testbench reads Tr/Tf/Tc as scalars (E52:E54).
    chip.Tr = float(np.asarray(chip.Tr, dtype=float).reshape(-1)[0])
    chip.Tf = float(np.asarray(chip.Tf, dtype=float).reshape(-1)[0])
    chip.Tc = float(np.asarray(chip.Tc, dtype=float).reshape(-1)[0])

    print(f"\n\nDie X size: {chip.Xsize:12.3e} m")
    print(f"Die Y size: {chip.Ysize:12.3e} m")
    print(f"Die area: {chip.Xsize * chip.Ysize:12.3e} m2")
    if chip.power.size >= 2:
        print(f"Power for Logic: {chip.power[1]:12.3e} W")
        print(f"Power for Memory: {chip.power[0]:12.3e} W")
        print(f"Total stack power: {(chip.power[0] + chip.power[1]):12.3e} W")
    print(f"Chip TSV Nbundle: {chip.TSV.Nbundle:12.3e}")
    print(f"ubump pitch (x and y): {chip.ubump.px:12.3e} m")
    print(f"ubump diameter: {chip.ubump.d:12.3e} m")
    print(f"C4 diameter: {chip.c4.d:12.3e} m")
    print(f"C4 pitch (x and y): {chip.c4.px:12.3e} m")
    print(f"Number of metal layers: {chip.Metal.N}")
    print(f"TSV diameter: {chip.TSV.d:12.3e} m")

    power_noise_sim(system, chip_list)
    return system, chip_list


def run_3dhi_phase1_2d_from_config(
    config_path: str,
    output_dir: str = "./results",
    bridge_flag: Optional[int] = None,
):
    system, chip_list = build_system_and_chip_from_config(config_path, bridge_flag=bridge_flag)
    system.output_dir = output_dir

    chip = chip_list[0]
    print(f"\n\nDie X size: {chip.Xsize:12.3e} m")
    print(f"Die Y size: {chip.Ysize:12.3e} m")
    print(f"Die area: {chip.Xsize * chip.Ysize:12.3e} m2")
    if chip.power.size >= 2:
        print(f"Power for Logic: {chip.power[1]:12.3e} W")
        print(f"Power for Memory: {chip.power[0]:12.3e} W")
        print(f"Total stack power: {(chip.power[0] + chip.power[1]):12.3e} W")
    print(f"Chip TSV Nbundle: {chip.TSV.Nbundle:12.3e}")
    print(f"ubump pitch (x and y): {chip.ubump.px:12.3e} m")
    print(f"ubump diameter: {chip.ubump.d:12.3e} m")
    print(f"C4 diameter: {chip.c4.d:12.3e} m")
    print(f"C4 pitch (x and y): {chip.c4.px:12.3e} m")
    print(f"Number of metal layers: {chip.Metal.N}")
    print(f"TSV diameter: {chip.TSV.d:12.3e} m")

    power_noise_sim(system, chip_list)
    return system, chip_list


def run_amytest1002_3d_f2f_wo_pkg_from_config(
    config_path: str = "./configs/amytest1002_3d_f2f_wo_pkg.yaml",
    output_dir: str = "./results_amytest1002_3d_f2f_wo_pkg",
    bridge_flag: Optional[int] = None,
):
    return run_3dhi_phase1_2d_from_config(
        config_path,
        output_dir=output_dir,
        bridge_flag=bridge_flag,
    )


def run_amytest1002_3d_f2f_wo_pkg(
    output_dir: str = "./results_amytest1002_3d_f2f_wo_pkg",
    chip_tsv_nbundle: int = 4,
):
    # This preset mirrors the active case in Amytest1002_3d_f2f_wo_pkg.m.
    system = ns()
    system.type = ns(P=1, G=2)
    system.bridge = ns(FLAG=0)
    system.chip = ns(N=1)
    system.pkg = ns()
    system.board = ns()
    system.BGA = ns()
    system.TSV = ns()
    system.Vdd = ns()
    system.box = ns()

    chip = ns()
    chip.N = 2
    chip.Xsize = 2.5e-3
    chip.Ysize = 2.5e-3
    chip.xl = 1e-3
    chip.yb = 1e-3

    chip.power = np.array([2.0, 2.0], dtype=float)
    chip.blk_num = np.array([1, 1], dtype=int)
    chip.map = np.array(
        [
            [0.25e-3, 0.25e-3, 2e-3, 2e-3, chip.power[0], 0.05],
            [0.25e-3, 0.25e-3, 2e-3, 2e-3, chip.power[1], 0.05],
        ],
        dtype=float,
    )
    chip.blk_name = ["", ""]
    chip.name = "CPU"
    chip.tsv_map = np.array([0.0, 0.0, chip.Xsize, chip.Ysize], dtype=float)

    chip.mesh_grid = ns(custom=1, px=240e-6 / 4, py=200e-6 / 4)
    chip.meshlvl = 0

    chip.Metal = ns()
    chip.Metal.N = np.array([2, 2], dtype=float)
    chip.Metal.p = np.array([60e-9, 1.68e-8], dtype=float)
    chip.Metal.ar = np.array([0.2667, 0.025, 0.011111, 0.011111], dtype=float)
    chip.Metal.pitch = np.array([48e-6, 250e-6, 100e-6, 100e-6], dtype=float)
    chip.Metal.thick = np.array([0.8e-6, 2e-6, 1e-6, 1e-6], dtype=float)

    chip.Via = ns()
    chip.Via.R = np.array([0.00278, 0.00278, 3.14e-7, 3.14e-7], dtype=float)
    chip.Via.N = np.array([500, 500, 500, 500], dtype=float) * 4.0

    chip.cap_per = np.array([0.05, 0.05], dtype=float)
    chip.cap_th = np.array([0.9e-9, 0.9e-9], dtype=float)

    chip.Tp = 1e-9
    chip.Tr = 0.4e-9
    chip.Tf = 0.4e-9
    chip.Tc = 0.2e-9

    chip.TSV = ns()
    chip.TSV.d = 4e-6
    chip.TSV.contact = 0.45 * (1e-6 ** 2)
    chip.TSV.liner = 0.2e-6
    chip.TSV.mu = 1.257e-6
    chip.TSV.rou = 1.68e-8
    chip.TSV.thick = 100e-6
    chip.TSV.Nbundle = float(chip_tsv_nbundle)
    chip.TSV.scale = 1.0
    chip.TSV.px = 240e-6
    chip.TSV.py = 200e-6
    chip.TSV.vdd_first = 0
    chip.TSV.staggered = 1
    chip.TSV.xoffset = 0.0
    chip.TSV.yoffset = 0.0
    chip.TSV.custom = ns(para=0, R=1e-12)

    chip.TOV = ns(
        rou=chip.TSV.rou,
        thick=chip.TSV.thick,
        d=chip.TSV.d,
        liner=chip.TSV.liner,
        mu=chip.TSV.mu,
        px=chip.TSV.px,
        py=chip.TSV.py,
        contact=chip.TSV.contact,
        Nbundle=chip.TSV.Nbundle,
        custom=ns(para=1, R=1e-12),
    )

    chip.ubump = ns()
    chip.ubump.rou = 400e-9
    chip.ubump.d = 12e-6
    chip.ubump.h = 12e-6
    chip.ubump.px = 240e-6
    chip.ubump.py = 200e-6
    chip.ubump.mu = 1.257e-6
    chip.ubump.scale = 0.5
    chip.ubump.vdd_first = 0
    chip.ubump.staggered = 0
    chip.ubump.xoffset = 0.0
    chip.ubump.yoffset = 0.0
    chip.ubump.custom = ns(para=0, R=1e-12)

    chip.c4 = ns()
    chip.c4.rou = 400e-9
    chip.c4.d = 75e-6
    chip.c4.h = 75e-6
    chip.c4.px = 240e-6
    chip.c4.py = 200e-6
    chip.c4.mu = 1.257e-6
    chip.c4.scale = 1.0
    chip.c4.Nbundle = 1.0
    chip.c4.vdd_first = 0
    chip.c4.staggered = 1
    chip.c4.custom = ns(para=0, R=1e-12)

    chip.HB = ns(R=0.0, custom=ns(R=1e-12))

    system.pkg.Xsize = 4.5e-3
    system.pkg.Ysize = 4.5e-3
    system.pkg.wire_p = 1e-12
    system.pkg.N = 4.0
    system.pkg.wire_thick = 0.02e-3
    system.pkg.decap = np.array([52e-6, 5.61e-13 * 2.5 / 1.5, 541.5e-9 / 8], dtype=float)
    system.pkg.Rs = 1e-6
    system.pkg.Ls = 2.4e-8
    system.pkg.ViaR = 1e-12
    system.pkg.ViaN = 1e12
    system.pkg.mu = 1.257e-6

    system.board.Rs = 1e-12
    system.board.Ls = 21e-12
    system.board.decap = np.array([[240e-6, 19.536e-6, 166e-6]], dtype=float)

    system.BGA.rou = 123e-9
    system.BGA.d = 250e-6
    system.BGA.h = 150e-6
    system.BGA.px = 240e-6
    system.BGA.py = 200e-6
    system.BGA.mu = 1.257e-6
    system.BGA.scale = 1.0
    system.BGA.vdd_first = 0
    system.BGA.staggered = 1
    system.BGA.custom = ns(para=1, R=1e-12)

    system.TSV.Nbundle = 25.0
    system.TSV.d = 4e-6
    system.TSV.px = 50e-6
    system.TSV.py = 50e-6
    system.TSV.contact = 0.0
    system.TSV.liner = 0.5e-6
    system.TSV.mu = 1.257e-6
    system.TSV.rou = 30e-9
    system.TSV.thick = 100e-6
    system.TSV.scale = 1.0
    system.TSV.custom = ns(para=1, R=1e-12)

    system.inter = 0
    system.emib = 0
    system.emib_via = 0
    system.stacked_die = 1
    system.bridge_ground = 0
    system.bridge_power = 0
    system.bridge_decap = 0
    system.connect = np.zeros((0, 6), dtype=float)

    system.mesh_V_scaling = 2
    system.intermetal = ns(usage=0, rho=1.68e-8, ar=0.011111, pitch=100e-6, thick=1e-6)
    system.pkg_grid = ns(custom=0, px=chip.mesh_grid.px, py=chip.mesh_grid.py)
    system.inter_grid = ns(custom=0, px=chip.mesh_grid.px, py=chip.mesh_grid.py)

    system.version = 0
    system.structure = 1
    system.embeddedchip = 1
    system.RDL = 0
    system.TOV = 0
    system.background_last_die_half_area = 0
    system.tran = 0
    system.write = 0
    system.gif = 0
    system.draw = 1
    system.tranplot = 0
    system.drawP = 1
    system.drawC = 0
    system.drawM = 1
    system.clamp = 0
    system.range = np.array([0.0, 5.0], dtype=float)
    system.skip = 0
    system.TR_FLAG = 1
    system.T = 2e-9
    system.dt = 0.025e-9
    system.Vdd.val = 1.1

    system.output_dir = output_dir
    chip_list = [chip]

    print(f"\n\nDie X size: {chip.Xsize:12.3e} m")
    print(f"Die Y size: {chip.Ysize:12.3e} m")
    print(f"Die area: {chip.Xsize * chip.Ysize:12.3e} m2")
    print(f"Power for Logic: {chip.power[1]:12.3e} W")
    print(f"Power for Memory: {chip.power[0]:12.3e} W")
    print(f"Total stack power: {(chip.power[0] + chip.power[1]):12.3e} W")
    print(f"Chip TSV Nbundle: {chip.TSV.Nbundle:12.3e}")
    print(f"uBump pitch (x and y): {chip.ubump.px:12.3e} m")
    print(f"uBump diameter: {chip.ubump.d:12.3e} m")
    print(f"C4 diameter: {chip.c4.d:12.3e} m")
    print(f"C4 pitch (x and y): {chip.c4.px:12.3e} m")
    print(f"TSV diameter: {chip.TSV.d:12.3e} m")

    power_noise_sim(system, chip_list)
    return system, chip_list
