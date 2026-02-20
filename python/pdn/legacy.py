import os
from typing import List, Tuple

import numpy as np
import scipy.sparse as sp
import scipy.sparse.linalg as spla
import matplotlib.pyplot as plt


DEFAULT_CMAP = "viridis"


def _output_dir(system) -> str:
    out = getattr(system, "output_dir", None)
    if out is None:
        out = "./results"
    os.makedirs(out, exist_ok=True)
    return out


def _colormap(system):
    plot = getattr(system, "plot", None)
    if plot is not None and getattr(plot, "cmap", None) is not None:
        return plot.cmap
    return DEFAULT_CMAP


def _sparse_from_triplets(rows, cols, vals, shape):
    if len(rows) == 0:
        return sp.csr_matrix(shape)
    return sp.csr_matrix((vals, (rows, cols)), shape=shape)


def cal_overlap(boundary1, boundary2):
    xl1, xr1, yb1, yt1 = boundary1
    xl2, xr2, yb2, yt2 = boundary2
    if xr1 <= xl2 or xl1 >= xr2 or yb1 >= yt2 or yt1 <= yb2:
        return 0.0
    xs = sorted([xl1, xr1, xl2, xr2])
    ys = sorted([yb1, yt1, yb2, yt2])
    return (xs[2] - xs[1]) * (ys[2] - ys[1])


# ------------------------- Mesh and geometry -------------------------

def meshTran(T, dt):
    length = int(round(T / dt))
    return np.linspace(0, T, length + 1)


def _reshape_solver_plane(vec, nx, ny):
    # Match MATLAB's column-major reshape used throughout legacy plotting/output paths.
    return np.asarray(vec).reshape((nx, ny), order="F").T


def chip2pkgId(x, y, chip, pkg):
    xinpkg = x + chip.xl
    yinpkg = y + chip.yb
    indX = int(np.argmin(np.abs(xinpkg - pkg.Xmesh)))
    indY = int(np.argmin(np.abs(yinpkg - pkg.Ymesh)))
    if abs(xinpkg - pkg.Xmesh[indX]) > 1e-6 or abs(yinpkg - pkg.Ymesh[indY]) > 1e-6:
        raise ValueError("cannot find this chip coordinates in package plane")
    return indX + 1, indY + 1


def mesh(system, chip_list, drawM):
    N = system.chip.N
    system.chip.Xgrid = system.pkg.Xsize
    system.chip.Ygrid = system.pkg.Ysize
    for i in range(N):
        chip = chip_list[i]
        mesh_grid = getattr(chip, "mesh_grid", None)
        if mesh_grid is not None and int(getattr(mesh_grid, "custom", 0)) == 1:
            system.chip.Xgrid = float(getattr(mesh_grid, "px"))
            system.chip.Ygrid = float(getattr(mesh_grid, "py"))
        else:
            grid = chip.ubump.px / (2 ** (1 + chip.meshlvl))
            system.chip.Xgrid = min(grid, system.chip.Xgrid)
            grid = chip.ubump.py / (2 ** (1 + chip.meshlvl))
            system.chip.Ygrid = min(grid, system.chip.Ygrid)

    xl = min([c.xl for c in chip_list[:N]])
    xr = max([c.xl + c.Xsize for c in chip_list[:N]])
    yb = min([c.yb for c in chip_list[:N]])
    yt = max([c.yb + c.Ysize for c in chip_list[:N]])

    system.box.Nx = int(round((xr - xl) / system.chip.Xgrid))
    system.box.Ny = int(round((yt - yb) / system.chip.Ygrid))
    system.box.Xmesh = np.linspace(xl, xr, system.box.Nx + 1)
    system.box.Ymesh = np.linspace(yb, yt, system.box.Ny + 1)

    pkg_grid = getattr(system, "pkg_grid", None)
    if pkg_grid is not None and int(getattr(pkg_grid, "custom", 0)) == 1:
        system.pkg.Xgrid = float(getattr(pkg_grid, "px"))
        system.pkg.Ygrid = float(getattr(pkg_grid, "py"))
    else:
        system.pkg.Xgrid = system.BGA.px / 2
        system.pkg.Ygrid = system.BGA.py / 2

    eps = 1e-12
    Xleft = np.arange(0, xl + eps, system.pkg.Xgrid)
    Xright = np.arange(xr, system.pkg.Xsize + eps, system.pkg.Xgrid)
    Ybottom = np.arange(0, yb + eps, system.pkg.Ygrid)
    Ytop = np.arange(yt, system.pkg.Ysize + eps, system.pkg.Ygrid)

    system.pkg.Xmesh = np.unique(np.concatenate([Xleft, system.box.Xmesh, Xright]))
    system.pkg.Ymesh = np.unique(np.concatenate([Ybottom, system.box.Ymesh, Ytop]))

    system.Nbridge = 0 if len(getattr(system, "connect", [])) == 0 else np.shape(system.connect)[0]
    system.interbox = np.zeros((system.Nbridge, 4), dtype=int)
    for i in range(system.Nbridge):
        xl = system.connect[i, 0]
        yb = system.connect[i, 1]
        xr = xl + system.connect[i, 2]
        yt = yb + system.connect[i, 3]
        xlInd = int(np.argmin(np.abs(xl - system.pkg.Xmesh)))
        xrInd = int(np.argmin(np.abs(xr - system.pkg.Xmesh)))
        ybInd = int(np.argmin(np.abs(yb - system.pkg.Ymesh)))
        ytInd = int(np.argmin(np.abs(yt - system.pkg.Ymesh)))
        system.interbox[i, :] = [xlInd, xrInd, ybInd, ytInd]

    system.pkg.Nx = len(system.pkg.Xmesh)
    system.pkg.Ny = len(system.pkg.Ymesh)

    system.pkg.type = np.zeros((system.pkg.Ny, system.pkg.Nx))
    system.pkg.IsCap = np.ones((system.pkg.Ny, system.pkg.Nx))

    box = [system.pkg.Nx, 0, system.pkg.Ny, 0]
    for i in range(system.chip.N):
        chip = chip_list[i]
        xlInd = int(np.argmin(np.abs(chip.xl - system.pkg.Xmesh)))
        xrInd = int(np.argmin(np.abs(chip.xl + chip.Xsize - system.pkg.Xmesh)))
        ybInd = int(np.argmin(np.abs(chip.yb - system.pkg.Ymesh)))
        ytInd = int(np.argmin(np.abs(chip.yb + chip.Ysize - system.pkg.Ymesh)))

        box[0] = min(box[0], xlInd)
        box[1] = max(box[1], xrInd)
        box[2] = min(box[2], ybInd)
        box[3] = max(box[3], ytInd)

        chip.Xmesh = system.pkg.Xmesh[xlInd:xrInd + 1] - chip.xl
        chip.Ymesh = system.pkg.Ymesh[ybInd:ytInd + 1] - chip.yb
        chip.Nx = xrInd - xlInd + 1
        chip.Ny = ytInd - ybInd + 1
        chip.type = np.zeros((chip.Ny, chip.Nx))
        chip.typec4 = np.zeros((chip.Ny, chip.Nx))
        chip.typeTSV = np.zeros((chip.Ny, chip.Nx))
        chip.ubump.R_map = np.ones((chip.Ny, chip.Nx)) * chip.ubump.R
        chip.ubump.L_map = np.ones((chip.Ny, chip.Nx)) * chip.ubump.L
        chip.c4.R_map = np.ones((chip.Ny, chip.Nx)) * chip.c4.R
        chip.c4.L_map = np.ones((chip.Ny, chip.Nx)) * chip.c4.L
        chip.TSV.R_map = np.ones((chip.Ny, chip.Nx)) * float(getattr(chip.TSV, "R", 0.0))
        chip.TSV.L_map = np.ones((chip.Ny, chip.Nx)) * float(getattr(chip.TSV, "L", 0.0))

        for j in range(chip.ubump.P + chip.ubump.G):
            x, y, bump_type = chip.ubump.loc[j, :]
            xind = int(np.argmin(np.abs(x + chip.xl - system.pkg.Xmesh)))
            yind = int(np.argmin(np.abs(y + chip.yb - system.pkg.Ymesh)))
            INTER_FLAG = 0
            for ii in range(system.Nbridge):
                xlI, xrI, ybI, ytI = system.interbox[ii, :]
                if xlI <= xind <= xrI and ybI <= yind <= ytI:
                    INTER_FLAG = 1
                    break
            if INTER_FLAG != 1 or system.emib_via == 1:
                system.pkg.type[yind, xind] = bump_type
                xind2 = int(np.argmin(np.abs(x - chip.Xmesh)))
                yind2 = int(np.argmin(np.abs(y - chip.Ymesh)))
                chip.type[yind2, xind2] = bump_type
                if system.emib_via == 1 and INTER_FLAG == 1:
                    chip.ubump.R_map[yind2, xind2] = chip.ubump.R_map[yind2, xind2] + system.TSV.R
                    chip.ubump.L_map[yind2, xind2] = chip.ubump.L_map[yind2, xind2] + system.TSV.L
            elif (system.bridge_ground == 1 and INTER_FLAG == 1 and bump_type == 2) or (
                system.bridge_power == 1 and INTER_FLAG == 1
            ):
                system.pkg.type[yind, xind] = bump_type
                xind2 = int(np.argmin(np.abs(x - chip.Xmesh)))
                yind2 = int(np.argmin(np.abs(y - chip.Ymesh)))
                chip.type[yind2, xind2] = bump_type
                chip.ubump.R_map[yind2, xind2] = chip.c4.R
                chip.ubump.L_map[yind2, xind2] = chip.c4.L

        print(f"Chip #{i+1} actually has {np.sum(chip.type == system.type.P)} power bumps")
        print(f"Chip #{i+1} actually has {np.sum(chip.type == system.type.G)} ground bumps")

        # Adding C4 bump map to chip (fixed to run per-chip)
        for j in range(chip.c4.P + chip.c4.G):
            x, y, bump_type = chip.c4.loc[j, :]
            xind = int(np.argmin(np.abs(x + chip.xl - system.pkg.Xmesh)))
            yind = int(np.argmin(np.abs(y + chip.yb - system.pkg.Ymesh)))
            INTER_FLAG = 0
            for ii in range(system.Nbridge):
                xlI, xrI, ybI, ytI = system.interbox[ii, :]
                if xlI <= xind <= xrI and ybI <= yind <= ytI:
                    INTER_FLAG = 1
                    break
            if INTER_FLAG != 1 or system.emib_via == 1:
                xind2 = int(np.argmin(np.abs(x - chip.Xmesh)))
                yind2 = int(np.argmin(np.abs(y - chip.Ymesh)))
                chip.typec4[yind2, xind2] = bump_type
            elif (system.bridge_ground == 1 and INTER_FLAG == 1 and bump_type == 2) or (
                system.bridge_power == 1 and INTER_FLAG == 1
            ):
                system.pkg.type[yind, xind] = bump_type
                xind2 = int(np.argmin(np.abs(x - chip.Xmesh)))
                yind2 = int(np.argmin(np.abs(y - chip.Ymesh)))
                chip.type[yind2, xind2] = bump_type
                chip.c4.R_map[yind2, xind2] = chip.c4.R
                chip.c4.L_map[yind2, xind2] = chip.c4.L

        print(f"Chip #{i+1} actually has {np.sum(chip.typec4 == system.type.P)} power c4 bumps")
        print(f"Chip #{i+1} actually has {np.sum(chip.typec4 == system.type.G)} ground c4 bumps")

        has_tsv_loc = hasattr(chip.TSV, "loc") and np.size(chip.TSV.loc) > 0
        has_tsv_pg = hasattr(chip.TSV, "P") and hasattr(chip.TSV, "G")
        if has_tsv_loc and has_tsv_pg:
            for j in range(int(chip.TSV.P + chip.TSV.G)):
                x, y, bump_type = chip.TSV.loc[j, :]
                xind = int(np.argmin(np.abs(x + chip.xl - system.pkg.Xmesh)))
                yind = int(np.argmin(np.abs(y + chip.yb - system.pkg.Ymesh)))
                INTER_FLAG = 0
                for ii in range(system.Nbridge):
                    xlI, xrI, ybI, ytI = system.interbox[ii, :]
                    if xlI <= xind <= xrI and ybI <= yind <= ytI:
                        INTER_FLAG = 1
                        break
                if INTER_FLAG != 1 or system.emib_via == 1:
                    system.pkg.type[yind, xind] = bump_type
                    xind2 = int(np.argmin(np.abs(x - chip.Xmesh)))
                    yind2 = int(np.argmin(np.abs(y - chip.Ymesh)))
                    chip.typeTSV[yind2, xind2] = bump_type
                    if system.emib_via == 1 and INTER_FLAG == 1:
                        chip.TSV.R_map[yind2, xind2] = chip.TSV.R_map[yind2, xind2] + system.TSV.R
                        chip.TSV.L_map[yind2, xind2] = chip.TSV.L_map[yind2, xind2] + system.TSV.L
                elif (system.bridge_ground == 1 and INTER_FLAG == 1 and bump_type == 2) or (
                    system.bridge_power == 1 and INTER_FLAG == 1
                ):
                    system.pkg.type[yind, xind] = bump_type
                    xind2 = int(np.argmin(np.abs(x - chip.Xmesh)))
                    yind2 = int(np.argmin(np.abs(y - chip.Ymesh)))
                    chip.typeTSV[yind2, xind2] = bump_type
                    chip.TSV.R_map[yind2, xind2] = chip.c4.R
                    chip.TSV.L_map[yind2, xind2] = chip.c4.L

            print(f"Chip #{i+1} actually has {np.sum(chip.typeTSV == system.type.P)} power TSV bumps")
            print(f"Chip #{i+1} actually has {np.sum(chip.typeTSV == system.type.G)} ground TSV bumps")

    # find package domain separation
    if system.chip.N > 1:
        indl, _ = chip2pkgId(chip_list[0].Xmesh[-1], chip_list[0].Ymesh[0], chip_list[0], system.pkg)
        indr, _ = chip2pkgId(chip_list[1].Xmesh[0], chip_list[1].Ymesh[0], chip_list[1], system.pkg)
        if (indr - indl) % 2 == 0:
            sep = [(indr + indl) // 2 - 1, (indr + indl) // 2]
        else:
            sep = [indl + (indr - indl - 1) // 2, indr - (indr - indl - 1) // 2]
    else:
        sep = None

    system.pkg.domain = np.ones((system.pkg.Ny, system.pkg.Nx))
    if system.chip.N > 1 and sep is not None:
        system.pkg.domain[:, : sep[0]] = 1
        system.pkg.domain[:, sep[1] - 1 :] = 2

    # calculate decaps per area
    xl, xr, yb, yt = box
    area_pkg = system.pkg.Xsize * system.pkg.Ysize
    area_decap = area_pkg - (system.pkg.Xmesh[xr] - system.pkg.Xmesh[xl]) * (
        system.pkg.Ymesh[yt] - system.pkg.Ymesh[yb]
    )
    system.pkg.decap = np.array(
        [system.pkg.decap[0] / area_decap, system.pkg.decap[1] * area_decap, system.pkg.decap[2] * area_decap]
    )
    system.pkg.IsCap[yb:yt + 1, xl:xr + 1] = 0

    # mark the IOs
    for i in range(system.BGA.P + system.BGA.G):
        x, y, bump_type = system.BGA.loc[i, :]
        xind = int(np.argmin(np.abs(x - system.pkg.Xmesh)))
        yind = int(np.argmin(np.abs(y - system.pkg.Ymesh)))
        system.pkg.type[yind, xind] = system.pkg.type[yind, xind] + bump_type * 10

    if drawM:
        X, Y = np.meshgrid(system.pkg.Xmesh, system.pkg.Ymesh)
        drawdata = np.vstack([X.T.reshape(-1), Y.T.reshape(-1), system.pkg.type.T.reshape(-1)]).T
        colors = ["k", "r", "b"]
        markers = [".", "o", "o"]
        for i, bump_type in enumerate([0, system.type.P, system.type.G]):
            plt.figure(1)
            idx = np.floor(drawdata[:, 2] / 10) == bump_type
            data = drawdata[idx, :]
            plt.plot(data[:, 0], data[:, 1], color=colors[i], marker=markers[i], linestyle="None", markersize=5)
            plt.axis("equal")
            plt.figure(2)
            idx = (drawdata[:, 2] % 10) == bump_type
            data = drawdata[idx, :]
            plt.plot(data[:, 0], data[:, 1], color=colors[i], marker=markers[i], linestyle="None", markersize=5)
            plt.axis("equal")

    return system, chip_list


# ------------------------- Parasitics and bump generation -------------------------

def calParasitics(system, chip_list):
    for i in range(system.chip.N):
        chip = chip_list[i]
        chip.c_gate = 3.9 * 8.85e-12 / chip.cap_th * 2
        for j in range(chip.N):
            st = int(np.sum(chip.blk_num[:j]))
            ed = st + int(chip.blk_num[j])
            if ed >= st:
                chip.map[st:ed, 5] = chip.map[st:ed, 5] * chip.c_gate[j] * 2

    if system.inter == 1 or system.emib_via == 1 or system.stacked_die == 1:
        rou = system.TSV.rou
        h = system.TSV.thick
        d = system.TSV.d
        liner = system.TSV.liner
        mu = system.TSV.mu
        pitch = system.TSV.px / 2
        system_tsv_custom = getattr(system.TSV, "custom", None)
        if system_tsv_custom is not None and int(getattr(system_tsv_custom, "para", 0)) == 1:
            system.TSV.R = float(getattr(system_tsv_custom, "R"))
        else:
            system.TSV.R = (rou * h / (0.25 * np.pi * (d - 2 * liner) ** 2) + system.TSV.contact / (0.25 * np.pi * (d - 2 * liner) ** 2)) / system.TSV.Nbundle

        Lself = mu * h / (2 * np.pi) * np.log(2 * pitch / d)
        Lmutual = 4 * 0.199 * mu * h * np.log(1 + 1.0438 * h / np.sqrt(pitch ** 2 / 2)) - 4 * 0.199 * mu * h * np.log(1 + 1.0438 * h / pitch)
        system.TSV.L = (Lself + Lmutual) / system.TSV.Nbundle

    for i in range(system.chip.N):
        chip = chip_list[i]
        if chip.N > 1:
            rou = chip.TSV.rou
            h = chip.TSV.thick
            d = chip.TSV.d
            liner = chip.TSV.liner
            mu = chip.TSV.mu
            pitch = chip.TSV.px / 2
            chip_tsv_custom = getattr(chip.TSV, "custom", None)
            if chip_tsv_custom is not None and int(getattr(chip_tsv_custom, "para", 0)) == 1:
                chip.TSV.R = float(getattr(chip_tsv_custom, "R"))
            else:
                # Taehoon branch scales TSV resistance with TSV/uBump contact factor.
                tsv_scale = float(getattr(chip.TSV, "scale", getattr(chip.ubump, "scale", 1.0)))
                chip.TSV.R = ((rou * h / (0.25 * np.pi * (d - 2 * liner) ** 2) + chip.TSV.contact / (0.25 * np.pi * d ** 2)) / chip.TSV.Nbundle) * tsv_scale

            Lself = mu * h / (2 * np.pi) * np.log(1 + 2.84 * h / (np.pi * (d / 2)))
            Lmutual = 4 * 0.199 * mu * h * np.log(1 + 1.0438 * h / np.sqrt(pitch ** 2 / 2)) - 4 * 0.199 * mu * h * np.log(1 + 1.0438 * h / pitch)
            chip.TSV.L = (Lself + Lmutual) / system.TSV.Nbundle

            if getattr(system, "TOV", 0) == 1:
                rou = chip.TOV.rou
                h = chip.TOV.thick
                d = chip.TOV.d
                liner = chip.TOV.liner
                mu = chip.TOV.mu
                pitch = chip.TOV.px / 2
                tov_custom = getattr(chip.TOV, "custom", None)
                if tov_custom is not None and int(getattr(tov_custom, "para", 0)) == 1:
                    chip.TOV.R = float(getattr(tov_custom, "R"))
                else:
                    chip.TOV.R = (rou * h / (0.25 * np.pi * (d - 2 * liner) ** 2) + chip.TOV.contact / (0.25 * np.pi * d ** 2)) / chip.TOV.Nbundle

                Lself = mu * h / (2 * np.pi) * np.log(1 + 2.84 * h / (np.pi * (d / 2)))
                Lmutual = 4 * 0.199 * mu * h * np.log(1 + 1.0438 * h / np.sqrt(pitch ** 2 / 2)) - 4 * 0.199 * mu * h * np.log(1 + 1.0438 * h / pitch)
                chip.TOV.L = (Lself + Lmutual) / chip.TOV.Nbundle

        rou = chip.ubump.rou
        h = chip.ubump.h
        d = chip.ubump.d
        mu = chip.ubump.mu
        pitch = chip.ubump.px / 2
        ubump_custom = getattr(chip.ubump, "custom", None)
        hb_custom = getattr(chip.HB, "custom", None)
        if ubump_custom is not None and int(getattr(ubump_custom, "para", 0)) == 1:
            chip.ubump.R = float(getattr(ubump_custom, "R"))
            if hb_custom is not None and hasattr(hb_custom, "R"):
                chip.HB.R = float(getattr(hb_custom, "R"))
            else:
                chip.HB.R = rou * h / (0.25 * np.pi * d ** 2)
        else:
            chip.ubump.R = rou * h / (0.25 * np.pi * d ** 2) * chip.ubump.scale
            chip.HB.R = rou * h / (0.25 * np.pi * d ** 2)

        Lself = mu * h / (2 * np.pi) * np.log(2 * pitch / d) * chip.ubump.scale
        Lmutual = 0
        chip.ubump.L = Lself + Lmutual

        rou = chip.c4.rou
        h = chip.c4.h
        d = chip.c4.d
        mu = chip.c4.mu
        pitch = chip.c4.px / 2
        c4_custom = getattr(chip.c4, "custom", None)
        if c4_custom is not None and int(getattr(c4_custom, "para", 0)) == 1:
            chip.c4.R = float(getattr(c4_custom, "R"))
        else:
            chip.c4.R = rou * h / (0.25 * np.pi * d ** 2) * chip.c4.scale / chip.c4.Nbundle

        Lself = mu * h / (2 * np.pi) * np.log(2 * pitch / d) * chip.c4.scale
        Lmutual = 0
        chip.c4.L = (Lself + Lmutual) / chip.c4.Nbundle

        if system.inter == 1:
            chip.ubump.R = chip.c4.R / chip.c4.Nbundle + chip.ubump.R + system.TSV.R
            chip.ubump.L = chip.c4.L / chip.c4.Nbundle + chip.ubump.L + system.TSV.L
        elif system.bridge_ground == 1:
            chip.c4.R = chip.c4.R / chip.c4.Nbundle
            chip.c4.L = chip.c4.L / chip.c4.Nbundle

    rou = system.BGA.rou
    h = system.BGA.h
    d = system.BGA.d
    mu = system.BGA.mu
    pitch = system.BGA.px / 2
    bga_custom = getattr(system.BGA, "custom", None)
    if bga_custom is not None and int(getattr(bga_custom, "para", 0)) == 1:
        system.BGA.R = float(getattr(bga_custom, "R"))
    else:
        system.BGA.R = rou * h / (0.25 * np.pi * d ** 2) * system.BGA.scale

    Lself = mu * h / (2 * np.pi) * np.log(1 + 2.84 * h / (np.pi * (d / 2)))
    Lmutual = 4 * 0.199 * mu * h * np.log(1 + 1.0438 * h / np.sqrt(pitch ** 2 / 2)) - 4 * 0.199 * mu * h * np.log(1 + 1.0438 * h / pitch)
    system.BGA.L = Lself + Lmutual

    return system, chip_list


def ubumpGen(system, chip_list):
    for i in range(system.chip.N):
        chip = chip_list[i]
        loc = []

        has_adv_fields = all(
            hasattr(chip.ubump, name)
            for name in ("staggered", "vdd_first", "xoffset", "yoffset")
        )
        staggered = int(getattr(chip.ubump, "staggered", 0))
        vdd_first = int(getattr(chip.ubump, "vdd_first", 0))
        xoffset = float(getattr(chip.ubump, "xoffset", 0.0))
        yoffset = float(getattr(chip.ubump, "yoffset", 0.0))

        for bump_type in [system.type.P, system.type.G]:
            if has_adv_fields:
                if staggered == 1:
                    if vdd_first == 1:
                        if bump_type == system.type.P:
                            x_start = 0.0 + xoffset
                            y_start = 0.0 + yoffset
                        else:
                            x_start = chip.ubump.px / 2 + xoffset
                            y_start = chip.ubump.py / 2 + yoffset
                    else:
                        if bump_type == system.type.P:
                            x_start = chip.ubump.px / 2 + xoffset
                            y_start = chip.ubump.py / 2 + yoffset
                        else:
                            x_start = 0.0 + xoffset
                            y_start = 0.0 + yoffset
                else:
                    if vdd_first == 1:
                        if bump_type == system.type.P:
                            x_start = 0.0 + xoffset
                        else:
                            x_start = chip.ubump.px / 2 + xoffset
                    else:
                        if bump_type == system.type.P:
                            x_start = chip.ubump.px / 2 + xoffset
                        else:
                            x_start = 0.0 + xoffset
                    y_start = 0.0 + yoffset
            else:
                # Backward-compatible fallback for older inputs without advanced uBump controls.
                x_start = chip.ubump.px / 2 if bump_type == system.type.P else 0.0
                y_start = chip.ubump.py / 2

            x = x_start
            y = y_start
            while y < chip.Ysize + 1e-6:
                loc.append([x, y, bump_type])
                x += chip.ubump.px
                if x > chip.Xsize + 1e-6:
                    x = x_start
                    y += chip.ubump.py

        chip.ubump.loc = np.asarray(loc, dtype=float) if loc else np.zeros((0, 3), dtype=float)
        chip.ubump.P = int(np.sum(chip.ubump.loc[:, 2] == system.type.P))
        chip.ubump.G = int(np.sum(chip.ubump.loc[:, 2] == system.type.G))
        print(f"Chip #{i+1} could have {chip.ubump.P} power bumps")
        print(f"Chip #{i+1} could have {chip.ubump.G} ground bumps")
    return chip_list


def c4Gen(system, chip_list):
    for i in range(system.chip.N):
        chip = chip_list[i]
        loc = []

        has_adv_fields = all(
            hasattr(chip.c4, name)
            for name in ("staggered", "vdd_first")
        )
        staggered = int(getattr(chip.c4, "staggered", 0))
        vdd_first = int(getattr(chip.c4, "vdd_first", 0))

        for bump_type in [system.type.P, system.type.G]:
            if has_adv_fields:
                if staggered == 1:
                    if vdd_first == 1:
                        if bump_type == system.type.P:
                            x_start = 0.0
                            y_start = 0.0
                        else:
                            x_start = chip.c4.px / 2
                            y_start = chip.c4.py / 2
                    else:
                        if bump_type == system.type.P:
                            x_start = chip.c4.px / 2
                            y_start = chip.c4.py / 2
                        else:
                            x_start = 0.0
                            y_start = 0.0
                else:
                    if vdd_first == 1:
                        if bump_type == system.type.P:
                            x_start = 0.0
                        else:
                            x_start = chip.c4.px / 2
                    else:
                        if bump_type == system.type.P:
                            x_start = chip.c4.px / 2
                        else:
                            x_start = 0.0
                    y_start = 0.0
            else:
                # Backward-compatible fallback for older inputs without advanced C4 controls.
                x_start = chip.c4.px / 2 if bump_type == system.type.P else 0.0
                y_start = chip.c4.py / 2

            x = x_start
            y = y_start
            while y < chip.Ysize + 1e-6:
                loc.append([x, y, bump_type])
                x += chip.c4.px
                if x > chip.Xsize + 1e-6:
                    x = x_start
                    y += chip.c4.py

        chip.c4.loc = np.asarray(loc, dtype=float) if loc else np.zeros((0, 3), dtype=float)
        chip.c4.P = int(np.sum(chip.c4.loc[:, 2] == system.type.P))
        chip.c4.G = int(np.sum(chip.c4.loc[:, 2] == system.type.G))
        print(f"Chip #{i+1} could have {chip.c4.P} power c4 bumps")
        print(f"Chip #{i+1} could have {chip.c4.G} ground c4 bumps")
    return chip_list


def BGAGen(system):
    Nx = int(np.floor(system.pkg.Xsize / (system.BGA.px / 2)) + 1)
    Ny = int(np.floor(system.pkg.Ysize / (system.BGA.py / 2)) + 1)
    Nmax = Nx * Ny
    system.BGA.loc = np.zeros((Nmax, 3))
    pointer = 0
    has_adv_fields = all(
        hasattr(system.BGA, name)
        for name in ("staggered", "vdd_first")
    )
    staggered = int(getattr(system.BGA, "staggered", 0))
    vdd_first = int(getattr(system.BGA, "vdd_first", 0))

    for bump_type in [system.type.P, system.type.G]:
        if has_adv_fields:
            if staggered == 1:
                if vdd_first == 1:
                    if bump_type == system.type.P:
                        x_start = 0.0
                        y_start = 0.0
                    else:
                        x_start = system.BGA.px / 2
                        y_start = system.BGA.py / 2
                else:
                    if bump_type == system.type.P:
                        x_start = system.BGA.px / 2
                        y_start = system.BGA.py / 2
                    else:
                        x_start = 0.0
                        y_start = 0.0
            else:
                if vdd_first == 1:
                    x_start = 0.0 if bump_type == system.type.P else system.BGA.px / 2
                else:
                    x_start = system.BGA.px / 2 if bump_type == system.type.P else 0.0
                y_start = 0.0
        else:
            x_start = system.BGA.px if bump_type == system.type.P else system.BGA.px / 2
            y_start = system.BGA.py / 2

        x = x_start
        y = y_start
        while y < system.pkg.Ysize + 1e-6:
            system.BGA.loc[pointer, :] = [x, y, bump_type]
            pointer += 1
            x += system.BGA.px
            if x > system.pkg.Xsize + 1e-6:
                x = x_start
                y += system.BGA.py
    system.BGA.loc = system.BGA.loc[:pointer, :]
    system.BGA.P = int(np.sum(system.BGA.loc[:, 2] == system.type.P))
    system.BGA.G = int(np.sum(system.BGA.loc[:, 2] == system.type.G))
    print(f"Package has {system.BGA.P} power bumps")
    print(f"Package has {system.BGA.G} ground bumps")
    return system


# ------------------------- Power maps -------------------------

def logic_power_map_gen(x_margin_adc, y_margin_adc, nyADC, nxADC, block_dimension, y_pitch, x_pitch, per_ADC_power):
    A = None
    x_ctr = 0
    y_ctr = 1
    while x_ctr < nxADC:
        while y_ctr <= nyADC:
            if x_ctr == 0:
                if y_ctr == 1:
                    B = [x_margin_adc, y_margin_adc, block_dimension, block_dimension, per_ADC_power, 0]
                    A = np.array([B], dtype=float)
                else:
                    B = [
                        x_margin_adc,
                        (A[(x_ctr * nyADC + y_ctr) - 2, 1] + (block_dimension + y_pitch)),
                        block_dimension,
                        block_dimension,
                        per_ADC_power,
                        0,
                    ]
                    A = np.vstack([A, B])
            else:
                if y_ctr == 1:
                    B = [
                        (A[(x_ctr * nyADC + 1) - 2, 0] + (block_dimension + x_pitch)),
                        y_margin_adc,
                        block_dimension,
                        block_dimension,
                        per_ADC_power,
                        0,
                    ]
                    A = np.vstack([A, B])
                else:
                    B = [
                        (A[(x_ctr * nyADC + 1) - 2, 0] + (block_dimension + x_pitch)),
                        (A[(x_ctr * nyADC + y_ctr) - 2, 1] + (block_dimension + y_pitch)),
                        block_dimension,
                        block_dimension,
                        per_ADC_power,
                        0,
                    ]
                    A = np.vstack([A, B])
            y_ctr += 1
        x_ctr += 1
        y_ctr = 1
    return A


def findmap(system, chip_list, i=None):
    if i is None:
        if hasattr(chip_list[0], "blk_num") and len(chip_list[0].blk_num) > 1:
            i = int(chip_list[0].blk_num[1])
        else:
            i = 1
    i = int(i)
    if i <= 0:
        i = 1
    map_arr = np.zeros((len(chip_list[0].Ymesh), len(chip_list[0].Xmesh)))
    if i == 1:
        chip2XSize = system.embeddedchip * (chip_list[0].Xsize)
        chip2YSize = system.embeddedchip * (chip_list[0].Ysize)
    elif i == 2:
        chip2XSize = system.embeddedchip * (chip_list[0].Xsize / 2)
        chip2YSize = (chip_list[0].Ysize) / 2
    else:
        chip2XSize = system.embeddedchip * (chip_list[0].Xsize) / (i / 2)
        chip2YSize = system.embeddedchip * (chip_list[0].Ysize) / 2

    if i == 1:
        startX = (chip_list[0].Xsize - chip2XSize) / 2
        startY = (chip_list[0].Ysize - chip2YSize) / 2
        endX = startX + chip2XSize
        endY = startY + chip2YSize
        x1 = int(np.argmin(np.abs(chip_list[0].Xmesh - startX)))
        x2 = int(np.argmin(np.abs(chip_list[0].Xmesh - endX)))
        y1 = int(np.argmin(np.abs(chip_list[0].Ymesh - startY)))
        y2 = int(np.argmin(np.abs(chip_list[0].Ymesh - endY)))
        map_arr[y1:y2 + 1, x1:x2 + 1] = 1
        return map_arr

    tempX = chip2XSize * 2
    tempY = chip2YSize * 2
    if i == 2:
        for j in range(1, 3):
            startX = (tempX - chip2XSize) / 2 + tempX * (j - 1)
            startY = (chip_list[0].Ysize - chip2YSize) / 2
            endX = startX + chip2XSize
            endY = startY + chip2YSize
            x1 = int(np.argmin(np.abs(chip_list[0].Xmesh - startX)))
            x2 = int(np.argmin(np.abs(chip_list[0].Xmesh - endX)))
            y1 = int(np.argmin(np.abs(chip_list[0].Ymesh - startY)))
            y2 = int(np.argmin(np.abs(chip_list[0].Ymesh - endY)))
            map_arr[y1:y2 + 1, x1:x2 + 1] = 1
    else:
        for j in range(1, 3):
            for k in range(1, int(i / 2) + 1):
                startX = (tempX - chip2XSize) / 2 + tempX * (k - 1)
                startY = (tempY - chip2YSize) / 2 + tempY * (j - 1)
                endX = startX + chip2XSize
                endY = startY + chip2YSize
                x1 = int(np.argmin(np.abs(chip_list[0].Xmesh - startX)))
                x2 = int(np.argmin(np.abs(chip_list[0].Xmesh - endX)))
                y1 = int(np.argmin(np.abs(chip_list[0].Ymesh - startY)))
                y2 = int(np.argmin(np.abs(chip_list[0].Ymesh - endY)))
                map_arr[y1:y2 + 1, x1:x2 + 1] = 1
    return map_arr


# ------------------------- Initialization -------------------------

def initial_IR(system, chip_list):
    system.chip.numV = 0
    for i in range(system.chip.N):
        chip_list[i].numV = chip_list[i].Nx * chip_list[i].Ny * 2 * chip_list[i].N
        system.chip.numV += chip_list[i].numV
    system.pkg.numV = system.pkg.Nx * system.pkg.Ny * 2
    system.pkg.numPort = system.chip.N
    var = system.chip.numV + system.pkg.numV + system.pkg.numPort
    return var, system, chip_list


# ------------------------- Current and capacitance -------------------------

def pulseGet(Tp, Tr, Tc, Tf, t):
    if t < Tr:
        return t / Tr
    if t < Tr + Tc:
        return 1
    if t < Tr + Tc + Tf:
        return 1 - (t - Tr - Tc) / Tf
    if t < Tp:
        return 0
    return pulseGet(Tp, Tr, Tc, Tf, t - Tp)


def dumpCurrent(system, chip_list, var, drawP):
    current = np.zeros(var)
    drawP_pkg = np.ones((system.pkg.Ny, system.pkg.Nx)) * np.nan
    for ii in range(system.chip.N):
        die_num = chip_list[ii].N
        drawP_die = np.zeros((chip_list[ii].Ny, chip_list[ii].Nx, chip_list[ii].N))

        gridNx_chip = chip_list[ii].Nx
        gridNy_chip = chip_list[ii].Ny
        chip_xmesh = chip_list[ii].Xmesh
        chip_ymesh = chip_list[ii].Ymesh
        for DIE in range(1, die_num + 1):
            background = 0
            if DIE == 1:
                start = 1
            else:
                start = int(np.sum(chip_list[ii].blk_num[: DIE - 1])) + 1
            if DIE == die_num:
                End = int(np.sum(chip_list[ii].blk_num[:DIE]))
            else:
                End = start + int(chip_list[ii].blk_num[DIE - 1]) - 1

            if End - start < 0:
                if DIE != die_num:
                    background = chip_list[ii].power[DIE - 1] / ((chip_list[ii].Xsize * chip_list[ii].Ysize) * system.Vdd.val)
                else:
                    use_half_area = int(getattr(system, "background_last_die_half_area", 0))
                    if use_half_area == 1:
                        area = (chip_list[ii].Xsize / 2) * (chip_list[ii].Ysize / 2)
                    else:
                        area = chip_list[ii].Xsize * chip_list[ii].Ysize
                    background = chip_list[ii].power[DIE - 1] / (area * system.Vdd.val)
            else:
                if abs(chip_list[ii].power[DIE - 1] - np.sum(chip_list[ii].map[start - 1:End, 4])) > 1e-8:
                    power_back = chip_list[ii].power[DIE - 1] - np.sum(chip_list[ii].map[start - 1:End, 4])
                    tmp = chip_list[ii].Xsize * chip_list[ii].Ysize - np.sum(chip_list[ii].map[start - 1:End, 2] * chip_list[ii].map[start - 1:End, 3])
                    if tmp <= 10e-12:
                        area_back = chip_list[ii].Xsize * chip_list[ii].Ysize
                    else:
                        area_back = tmp
                    background = power_back / (area_back * system.Vdd.val)

            idOffset = 0
            for jj in range(ii):
                idOffset += chip_list[jj].numV

            if background > 1e-8:
                for i in range(1, gridNx_chip + 1):
                    for j in range(1, gridNy_chip + 1):
                        id1 = i + (j - 1) * gridNx_chip + idOffset + (DIE - 1) * 2 * chip_list[ii].Nx * chip_list[ii].Ny
                        if i == 1:
                            boundary1 = chip_xmesh[i - 1]
                        else:
                            boundary1 = (chip_xmesh[i - 2] + chip_xmesh[i - 1]) / 2
                        if i == gridNx_chip:
                            boundary2 = chip_xmesh[i - 1]
                        else:
                            boundary2 = (chip_xmesh[i - 1] + chip_xmesh[i]) / 2
                        if j == 1:
                            boundary3 = chip_ymesh[j - 1]
                        else:
                            boundary3 = (chip_ymesh[j - 2] + chip_ymesh[j - 1]) / 2
                        if j == gridNy_chip:
                            boundary4 = chip_ymesh[j - 1]
                        else:
                            boundary4 = (chip_ymesh[j - 1] + chip_ymesh[j]) / 2

                        if DIE == die_num:
                            if getattr(system, "version", 0) != 0:
                                if getattr(system, "RDL", 0) == 0:
                                    tiermap = findmap(system, chip_list, int(chip_list[0].blk_num[1]) if len(chip_list[0].blk_num) > 1 else 1)
                                else:
                                    tiermap = findmap(system, chip_list, int(chip_list[0].blk_num[2]) if len(chip_list[0].blk_num) > 2 else 1)
                            gridx = boundary2 - boundary1
                            gridy = boundary4 - boundary3
                            area = gridx * gridy
                            if getattr(system, "version", 0) != 0:
                                if tiermap[i - 1, j - 1] == 1:
                                    current[id1 - 1] += background * area
                                    drawP_die[j - 1, i - 1, DIE - 1] = background
                            else:
                                current[id1 - 1] += background * area
                                drawP_die[j - 1, i - 1, DIE - 1] = background
                        else:
                            gridx = boundary2 - boundary1
                            gridy = boundary4 - boundary3
                            area = gridx * gridy
                            if getattr(system, "version", 0) != 0 and DIE == 1:
                                tiermap = findmap(system, chip_list, int(chip_list[0].blk_num[0]) if len(chip_list[0].blk_num) > 0 else 1)
                                if tiermap[i - 1, j - 1] == 1:
                                    current[id1 - 1] += background * area
                                    drawP_die[j - 1, i - 1, DIE - 1] = background
                            else:
                                current[id1 - 1] += background * area
                                drawP_die[j - 1, i - 1, DIE - 1] = background

            if End < start:
                continue
            density = np.zeros(int(np.sum(chip_list[ii].blk_num)))

            for k in range(start, End + 1):
                density[k - 1] = chip_list[ii].map[k - 1, 4] / (
                    chip_list[ii].map[k - 1, 2] * chip_list[ii].map[k - 1, 3] * system.Vdd.val
                ) - background
                if density[k - 1] == 0:
                    continue
                blkXl = chip_list[ii].map[k - 1, 0]
                blkXr = chip_list[ii].map[k - 1, 0] + chip_list[ii].map[k - 1, 2]
                blkYt = chip_list[ii].map[k - 1, 1]
                blkYb = chip_list[ii].map[k - 1, 1] + chip_list[ii].map[k - 1, 3]

                xl = np.sum(chip_xmesh < blkXl)
                if xl <= 0:
                    xl = 1
                xr = np.sum(chip_xmesh < blkXr) + 1
                if xr >= gridNx_chip:
                    xr = gridNx_chip
                yb = np.sum(chip_ymesh < blkYt)
                if yb <= 0:
                    yb = 1
                yt = np.sum(chip_ymesh < blkYb) + 1
                if yt >= gridNy_chip:
                    yt = gridNy_chip
                boundary_blk = [blkXl, blkXr, blkYt, blkYb]

                for i in range(xl, xr + 1):
                    for j in range(yb, yt + 1):
                        id1 = i + (j - 1) * gridNx_chip + idOffset + (DIE - 1) * 2 * chip_list[ii].Nx * chip_list[ii].Ny
                        if i == 1:
                            boundary1 = chip_xmesh[i - 1]
                        else:
                            boundary1 = (chip_xmesh[i - 2] + chip_xmesh[i - 1]) / 2
                        if i == gridNx_chip:
                            boundary2 = chip_xmesh[i - 1]
                        else:
                            boundary2 = (chip_xmesh[i - 1] + chip_xmesh[i]) / 2
                        if j == 1:
                            boundary3 = chip_ymesh[j - 1]
                        else:
                            boundary3 = (chip_ymesh[j - 2] + chip_ymesh[j - 1]) / 2
                        if j == gridNy_chip:
                            boundary4 = chip_ymesh[j - 1]
                        else:
                            boundary4 = (chip_ymesh[j - 1] + chip_ymesh[j]) / 2
                        grid_area = cal_overlap([boundary1, boundary2, boundary3, boundary4], boundary_blk)

                        gridx = boundary2 - boundary1
                        gridy = boundary4 - boundary3
                        area = gridx * gridy

                        current[id1 - 1] += density[k - 1] * grid_area
                        drawP_die[j - 1, i - 1, DIE - 1] = current[id1 - 1] / area

        if drawP == 1:
            if DIE == chip_list[ii].N:
                Chip_xl = np.where(np.abs(system.pkg.Xmesh - chip_list[ii].xl) < 1e-5)[0]
                Chip_yb = np.where(np.abs(system.pkg.Ymesh - chip_list[ii].yb) < 1e-5)[0]
                Chip_xr = np.where(np.abs(system.pkg.Xmesh - chip_list[ii].xl - chip_list[ii].Xsize) < 1e-5)[0]
                Chip_yt = np.where(np.abs(system.pkg.Ymesh - chip_list[ii].yb - chip_list[ii].Ysize) < 1e-5)[0]
                drawP_pkg[Chip_yb[0] : Chip_yt[0] + 1, Chip_xl[0] : Chip_xr[0] + 1] = drawP_die[:, :, DIE - 1]

            idOffset = 0
            for jj in range(ii):
                idOffset += chip_list[jj].N

            if drawP == 1:
                for DIE in range(1, chip_list[ii].N + 1):
                    if system.drawP == 1:
                        fig = plt.figure(20 + DIE)
                        if chip_list[ii].blk_num[DIE - 1] > 0:
                            if DIE == chip_list[ii].N:
                                plt.contourf(
                                    chip_list[ii].Xmesh * 100,
                                    chip_list[ii].Ymesh * 100,
                                    drawP_die[:, :, DIE - 1] * 1000,
                                    int(chip_list[ii].blk_num[DIE - 1]) * 2,
                                    cmap=_colormap(system),
                                )
                                plt.colorbar()
                                plt.xlabel("x(cm)")
                                plt.ylabel("y(cm)")
                        else:
                            print(f"Chip #{ii+1}, Die #{DIE} has uniform power map, skipped")

    return current


def dumpCap(system, chip_list, var, DRAW_FLAG):
    Cap = np.zeros(var)
    itefig = 1
    for ii in range(system.chip.N):
        die_num = chip_list[ii].N
        gridNx_chip = chip_list[ii].Nx
        gridNy_chip = chip_list[ii].Ny
        chip_xmesh = chip_list[ii].Xmesh
        chip_ymesh = chip_list[ii].Ymesh
        const = chip_list[ii].Nx * chip_list[ii].Ny
        idoffset = 0
        for jj in range(ii):
            idoffset += chip_list[jj].numV

        for DIE in range(1, die_num + 1):
            background = chip_list[ii].cap_per[DIE - 1] * chip_list[ii].c_gate[DIE - 1]
            drawP_die = np.ones((chip_list[ii].Ny, chip_list[ii].Nx)) * chip_list[ii].c_gate[DIE - 1] * chip_list[ii].cap_per[DIE - 1]

            for i in range(1, gridNx_chip + 1):
                for j in range(1, gridNy_chip + 1):
                    id1 = i + (j - 1) * gridNx_chip + idoffset + (DIE - 1) * 2 * const
                    if i == 1:
                        boundary1 = chip_xmesh[i - 1]
                    else:
                        boundary1 = (chip_xmesh[i - 2] + chip_xmesh[i - 1]) / 2
                    if i == gridNx_chip:
                        boundary2 = chip_xmesh[i - 1]
                    else:
                        boundary2 = (chip_xmesh[i - 1] + chip_xmesh[i]) / 2
                    if j == 1:
                        boundary3 = chip_ymesh[j - 1]
                    else:
                        boundary3 = (chip_ymesh[j - 2] + chip_ymesh[j - 1]) / 2
                    if j == gridNy_chip:
                        boundary4 = chip_ymesh[j - 1]
                    else:
                        boundary4 = (chip_ymesh[j - 1] + chip_ymesh[j]) / 2
                    grid_area = (boundary2 - boundary1) * (boundary4 - boundary3)
                    Cap[id1 - 1] = background * grid_area

            if DIE == 1:
                start = 1
            else:
                start = int(np.sum(chip_list[ii].blk_num[: DIE - 1])) + 1
            if DIE == die_num:
                End = int(np.sum(chip_list[ii].blk_num[:DIE]))
            else:
                End = start + int(chip_list[ii].blk_num[DIE - 1]) - 1

            if End < start:
                continue
            cap = np.zeros(int(np.sum(chip_list[ii].blk_num)))

            for k in range(start, End + 1):
                cap[k - 1] = chip_list[ii].map[k - 1, 5] - background
                blkXl = chip_list[ii].map[k - 1, 0]
                blkXr = chip_list[ii].map[k - 1, 0] + chip_list[ii].map[k - 1, 2]
                blkYt = chip_list[ii].map[k - 1, 1]
                blkYb = chip_list[ii].map[k - 1, 1] + chip_list[ii].map[k - 1, 3]

                xl = np.sum(chip_xmesh < blkXl)
                if xl <= 0:
                    xl = 1
                xr = np.sum(chip_xmesh < blkXr) + 1
                if xr >= gridNx_chip:
                    xr = gridNx_chip
                yb = np.sum(chip_ymesh < blkYt)
                if yb <= 0:
                    yb = 1
                yt = np.sum(chip_ymesh < blkYb) + 1
                if yt >= gridNy_chip:
                    yt = gridNy_chip
                boundary_blk = [blkXl, blkXr, blkYt, blkYb]

                for i in range(xl, xr + 1):
                    for j in range(yb, yt + 1):
                        id1 = i + (j - 1) * gridNx_chip + idoffset + (DIE - 1) * 2 * const
                        if i == 1:
                            boundary1 = chip_xmesh[i - 1]
                        else:
                            boundary1 = (chip_xmesh[i - 2] + chip_xmesh[i - 1]) / 2
                        if i == gridNx_chip:
                            boundary2 = chip_xmesh[i - 1]
                        else:
                            boundary2 = (chip_xmesh[i - 1] + chip_xmesh[i]) / 2
                        if j == 1:
                            boundary3 = chip_ymesh[j - 1]
                        else:
                            boundary3 = (chip_ymesh[j - 2] + chip_ymesh[j - 1]) / 2
                        if j == gridNy_chip:
                            boundary4 = chip_ymesh[j - 1]
                        else:
                            boundary4 = (chip_ymesh[j - 1] + chip_ymesh[j]) / 2
                        grid_area = cal_overlap([boundary1, boundary2, boundary3, boundary4], boundary_blk)

                        gridx = boundary2 - boundary1
                        gridy = boundary4 - boundary3
                        area = gridx * gridy

                        Cap[id1 - 1] += cap[k - 1] * grid_area
                        drawP_die[j - 1, i - 1] = Cap[id1 - 1] / (2 * area)

            if DRAW_FLAG:
                plt.figure(10 + itefig)
                itefig += 1
                if chip_list[ii].blk_num[DIE - 1] > 0:
                    plt.contourf(
                        chip_list[ii].Xmesh * 100,
                        chip_list[ii].Ymesh * 100,
                        drawP_die * 1000,
                        int(chip_list[ii].blk_num[DIE - 1]) * 2,
                        cmap=_colormap(system),
                    )
                    plt.colorbar()
                    plt.xlabel("x(cm)")
                    plt.ylabel("y(cm)")
                else:
                    print(f"Chip #{ii+1}, Die #{DIE} has uniform decap map, skipped")

    print("Dumping capacitance out")
    return Cap


def tranDumpCurrent(system, chip_list, current_full, dt, var):
    current = np.zeros_like(current_full)
    for ii in range(system.chip.N):
        idoffset = 0
        for jj in range(ii):
            idoffset += chip_list[jj].numV
        const = chip_list[ii].Nx * chip_list[ii].Ny
        alpha = pulseGet(chip_list[ii].Tp, chip_list[ii].Tr, chip_list[ii].Tc, chip_list[ii].Tf, dt)
        for k in range(1, chip_list[ii].N + 1):
            st = 1 + idoffset + (k - 1) * 2 * const
            ed = const + idoffset + (k - 1) * 2 * const
            current[st - 1:ed] = current_full[st - 1:ed] * alpha
    current = np.concatenate([current, np.zeros(var)])
    return current


# ------------------------- Extraction and matrix assembly -------------------------

def MatrixBuild(A, D, var):
    A = -(A + A.T)
    Dsum = -A[:var, :].sum(axis=1)
    Dsum = sp.diags(np.asarray(Dsum).reshape(-1), 0, shape=(var, var))
    Y = A + D + Dsum
    return Y


def MatrixBuild_tran(Aall, var):
    A = Aall[:var, :var]
    i, j = A.nonzero()
    s = A.data
    m, n = Aall.shape
    Aminus = sp.csr_matrix(( -s, (i, j)), shape=(m, n))
    A = -(A + A.T)
    Dsum = -A[:var, :].sum(axis=1)
    Dsum = sp.diags(np.asarray(Dsum).reshape(-1), 0, shape=(var, var))
    A = A + Dsum
    i, j = A.nonzero()
    s = A.data
    Aplus = sp.csr_matrix((s, (i, j)), shape=(m, n))
    Y = Aall + Aminus + Aplus
    return Y


def Noise_solver_ss(Y, current_full):
    return spla.spsolve(Y, current_full)


def tranFac(Y, C, r, FLAG):
    if FLAG == 1:
        A = C / r + Y / 2
    else:
        A = C / r + Y
    lu = spla.splu(A.tocsc())
    return lu


def Noise_solver_tran_lu(lu, Y, C, b, bprev, xp, r, FLAG):
    if FLAG == 1:
        B = C / r - Y / 2
        const = (b + bprev) / 2
    else:
        B = C / r
        const = b
    right = const + B.dot(xp)
    return lu.solve(right)

# ------------------------- Map helpers and display -------------------------

def chip_map_stack(chip_list, N):
    N_block = 0
    Ncol = 0
    for i in range(N):
        if chip_list[i].blk_num is not None and len(chip_list[i].blk_num) > 0:
            N_block += int(chip_list[i].blk_num[-1])
            Ncol = max(chip_list[i].map.shape[1], Ncol)
    accu_map = np.zeros((N_block, Ncol))
    accu_name = [""] * N_block
    l = 0
    for i in range(N):
        if chip_list[i].blk_num is not None and len(chip_list[i].blk_num) > 0:
            End = int(np.sum(chip_list[i].blk_num))
            Stt = End - int(chip_list[i].blk_num[-1]) + 1
            length = int(chip_list[i].blk_num[-1])
            if length == 0:
                length = 1
                accu_map[l:l + length, :] = [chip_list[i].xl, chip_list[i].yb, chip_list[i].Xsize, chip_list[i].Ysize, 0, 0]
                accu_name[l:l + length] = [chip_list[i].name]
            else:
                mapped = chip_list[i].map.copy()
                mapped[:, 0] = mapped[:, 0] + chip_list[i].xl
                mapped[:, 1] = mapped[:, 1] + chip_list[i].yb
                accu_map[l:l + length, :] = mapped[Stt - 1:End, :]
                accu_name[l:l + length] = chip_list[i].blk_name[Stt - 1:End]
            l += length
    return accu_map, accu_name


def DrawSteady(index, Xmesh, Ymesh, drawT_die, mapping, name, system):
    MinT = float(np.min(drawT_die)) if drawT_die.size else 0.0
    MaxT = float(np.max(drawT_die)) if drawT_die.size else 0.0
    plt.figure(index)
    if drawT_die.size:
        plt.contourf(Xmesh * 100, Ymesh * 100, np.abs(drawT_die) * 1000, 30, cmap=_colormap(system))
    length = mapping.shape[0] if mapping is not None else 0
    for i in range(length):
        xl = mapping[i, 0]
        width = mapping[i, 2]
        yb = mapping[i, 1]
        height = mapping[i, 3]
        if str(name[i]) == "bridge":
            rect = plt.Rectangle((xl * 100, yb * 100), width * 100, height * 100, linewidth=1.5, edgecolor="r", linestyle="--", fill=False)
        else:
            rect = plt.Rectangle((xl * 100, yb * 100), width * 100, height * 100, linewidth=1, edgecolor="k", fill=False)
        plt.gca().add_patch(rect)
        if str(name[i]) != "":
            plt.text((xl + width / 2) * 100, (yb + height / 2) * 100, str(name[i]), ha="center", fontsize=14, fontweight="bold")
    if getattr(system, "clamp", 0) == 1 and drawT_die.size:
        plt.clim(system.range[0], system.range[1])
    plt.axis("off")
    plt.axis("equal")
    if drawT_die.size:
        cb = plt.colorbar()
        cb.set_label("Noise(mV)")
    plt.xlabel("x(cm)")
    plt.ylabel("y(cm)")
    return MaxT, MinT


def draw_map(system, chip_list, xp, xg, t, WRITE_FLAG, DRAW_FLAG):
    x = xp + xg
    GIF_FLAG = system.gif
    itefig = 1
    drawT_pack = np.ones((system.pkg.Ny, system.pkg.Nx)) * np.nan
    Nchip = sum([c.N for c in chip_list[: system.chip.N]])
    result = np.zeros((Nchip, 2))
    Nchip = 0

    out_dir = _output_dir(system)

    for ii in range(system.chip.N):
        offset = sum([chip_list[kk].numV for kk in range(ii)])
        const = chip_list[ii].Nx * chip_list[ii].Ny
        for k in range(1, chip_list[ii].N + 1):
            st = offset + 2 * const * (k - 1) + 1
            ed = st + const - 1
            if WRITE_FLAG:
                file_name = os.path.join(out_dir, f"chip{ii+1}die{k}.txt")
                mode = "wb" if t == 0 else "ab"
                with open(file_name, mode) as f:
                    np.asarray(x[st - 1:ed], dtype=np.float64).tofile(f)
            if DRAW_FLAG:
                drawT_die = _reshape_solver_plane(x[st - 1:ed], chip_list[ii].Nx, chip_list[ii].Ny)
                if k == 1:
                    start = 1
                else:
                    start = int(np.sum(chip_list[ii].blk_num[: k - 1])) + 1
                if k == chip_list[ii].N:
                    End = int(np.sum(chip_list[ii].blk_num[:k]))
                else:
                    End = start + int(chip_list[ii].blk_num[k - 1]) - 1

                mapping = chip_list[ii].map[start - 1:End, :]
                blk_name = chip_list[ii].blk_name
                index = itefig + 30
                itefig += 1
                Tmax, Tmin = DrawSteady(index, chip_list[ii].Xmesh, chip_list[ii].Ymesh, drawT_die, mapping, blk_name, system)

                result[Nchip, :] = [Tmax, Tmin]
                Nchip += 1
                print(f"chip{ii+1} Die{k} Max: {Tmax*1e3:.2f}")
                print(f"chip{ii+1} Die{k} Min: {Tmin*1e3:.2f}")

                if k == chip_list[ii].N:
                    Chip_xl = np.where(np.abs(system.pkg.Xmesh - chip_list[ii].xl) < 1e-5)[0][0]
                    Chip_yb = np.where(np.abs(system.pkg.Ymesh - chip_list[ii].yb) < 1e-5)[0][0]
                    Chip_xr = np.where(np.abs(system.pkg.Xmesh - chip_list[ii].xl - chip_list[ii].Xsize) < 1e-5)[0][0]
                    Chip_yt = np.where(np.abs(system.pkg.Ymesh - chip_list[ii].yb - chip_list[ii].Ysize) < 1e-5)[0][0]
                    drawT_pack[Chip_yb:Chip_yt + 1, Chip_xl:Chip_xr + 1] = drawT_die

    st = system.chip.numV + 1
    ed = st + system.pkg.Nx * system.pkg.Ny - 1
    const = system.pkg.Nx * system.pkg.Ny
    file_name = os.path.join(out_dir, "pkg")
    if WRITE_FLAG:
        mode = "wb" if t == 0 else "ab"
        with open(file_name, mode) as f:
            np.asarray(x[st - 1:ed], dtype=np.float64).tofile(f)
    if DRAW_FLAG:
        accu_map, blk_name = chip_map_stack(chip_list, system.chip.N)
        if len(getattr(system, "connect", [])):
            accu_map = np.vstack([accu_map, system.connect])
            for _ in range(system.connect.shape[0]):
                blk_name.append("bridge")
        index = itefig + 30
        itefig += 1
        DrawSteady(index, system.pkg.Xmesh, system.pkg.Ymesh, drawT_pack, accu_map, blk_name, system)
        drawT = _reshape_solver_plane(x[st - 1:ed], system.pkg.Nx, system.pkg.Ny)
        value = np.max(np.abs(drawT) * 1000)
        print(f"package, maximum noise: {value:.2f} mV")
        plt.figure(itefig + 30)
        plt.contourf(system.pkg.Xmesh * 100, system.pkg.Ymesh * 100, np.abs(drawT) * 1000, 30, cmap=_colormap(system))
        plt.colorbar()
        plt.xlabel("x(cm)")
        plt.ylabel("y(cm)")

        for i in range(system.chip.N):
            drawT = _reshape_solver_plane(x[st - 1 + const: ed + const], system.pkg.Nx, system.pkg.Ny)
            mark = (np.floor(system.pkg.type / 10) == 1) & (system.pkg.domain == (i + 1))
            print(f"number of BGAs: {np.sum(mark)}")
            drawT = (mark.astype(float) * (drawT - xp[-system.chip.N + i])) / system.BGA.R
            value = np.max(np.abs(drawT))
            print(f"package, maximum current of BGA: {value:.2f} A")
            print(f"package, total current of BGA: {np.sum(drawT):.2f} A")
            plt.figure(itefig + 30 + i)
            plt.imshow(drawT, aspect="auto")
            plt.colorbar()
            plt.xlabel("x(cm)")
            plt.ylabel("y(cm)")

    for i in range(system.chip.N):
        print(f"board {i+1}, flowing: {xp[-system.chip.N + i] / system.board.Rs:.2f} A")
        print(f"board {i+1}, noise: {x[-system.chip.N + i] * 1e3:.2f} mV")

    return result


def draw_map_tran(system, chip_list, x, t, WRITE_FLAG, DRAW_FLAG, type_val):
    itefig = 1
    out_dir = _output_dir(system)
    for ii in range(system.chip.N):
        offset = sum([chip_list[kk].numV for kk in range(ii)])
        const = chip_list[ii].Nx * chip_list[ii].Ny
        for k in range(1, chip_list[ii].N + 1):
            st = offset + 2 * const * (k - 1) + 1
            ed = st + const - 1
            if WRITE_FLAG:
                file_name = os.path.join(out_dir, f"chip{ii+1}_die{k}_{type_val}")
                mode = "wb" if t == 0 else "ab"
                with open(file_name, mode) as f:
                    np.asarray(x[st - 1:ed], dtype=np.float64).tofile(f)
            if DRAW_FLAG:
                drawT_die = _reshape_solver_plane(x[st - 1:ed], chip_list[ii].Nx, chip_list[ii].Ny)
                value = np.max(x[st - 1:ed] * 1000)
                print(f"chip {ii+1}, die {k}, maximum noise: {value:.2f} mV")
                plt.figure(itefig + 30)
                itefig += 1
                plt.contourf(chip_list[ii].Xmesh * 100, chip_list[ii].Ymesh * 100, np.abs(drawT_die) * 1000, 30, cmap=_colormap(system))
                plt.colorbar()
                plt.xlabel("x(cm)")
                plt.ylabel("y(cm)")

    st = system.chip.numV + 1
    ed = st + system.pkg.Nx * system.pkg.Ny - 1
    file_name = os.path.join(out_dir, f"pkg_{type_val}")
    if WRITE_FLAG:
        mode = "wb" if t == 0 else "ab"
        with open(file_name, mode) as f:
            np.asarray(x[st - 1:ed], dtype=np.float64).tofile(f)
    if DRAW_FLAG:
        drawT = _reshape_solver_plane(x[st - 1:ed], system.pkg.Nx, system.pkg.Ny)
        value = np.max(np.abs(drawT) * 1000)
        print(f"package, maximum noise: {value:.2f} mV")
        plt.figure(itefig + 30)
        plt.contourf(system.pkg.Xmesh * 100, system.pkg.Ymesh * 100, np.abs(drawT) * 1000, 30, cmap=_colormap(system))
        plt.colorbar()
        plt.xlabel("x(cm)")
        plt.ylabel("y(cm)")


def power_loss(system, var, Y, x):
    total = x.T @ (Y @ x)
    print(f"total power loss: {total:.2f}")

# ------------------------- Resistance extraction (baseline) -------------------------

def ResExtract_baseline(system, chip_list, var, type_val):
    rows = []
    cols = []
    vals = []

    for ii in range(system.chip.N):
        chip = chip_list[ii]
        for k in range(1, chip.N + 1):
            IOmap = chip.type == type_val
            IOmapc4 = chip.typec4 == type_val
            id_offset = sum([chip_list[kk].numV for kk in range(ii)])
            Nmetal = int(chip.Metal.N[k - 1])
            rou = chip.Metal.p[k - 1]
            offset = int(np.sum(chip.Metal.N[: k - 1]))
            ar = chip.Metal.ar[offset: offset + Nmetal]
            pitch = chip.Metal.pitch[offset: offset + Nmetal]
            thick = chip.Metal.thick[offset: offset + Nmetal]
            viaR = chip.Via.R[offset: offset + Nmetal]
            viaN = chip.Via.N[offset: offset + Nmetal]

            viaR = np.sum(viaR / viaN) * chip.Xsize * chip.Ysize
            pitch_V = pitch[1::2]
            pitch_L = pitch[0::2]
            thick_V = thick[1::2]
            thick_L = thick[0::2]
            ar_V = ar[1::2]
            ar_L = ar[0::2]
            const = chip.Nx * chip.Ny
            for LineOrient in [1, 0]:
                for j in range(1, chip.Ny + 1):
                    for i in range(1, chip.Nx + 1):
                        if i > 1:
                            x1 = chip.Xmesh[i - 1] - chip.Xmesh[i - 2]
                        else:
                            x1 = 0
                        if i < chip.Nx:
                            x2 = chip.Xmesh[i] - chip.Xmesh[i - 1]
                        else:
                            x2 = 0
                        gridx = (x1 + x2) / 2

                        if j > 1:
                            y1 = chip.Ymesh[j - 1] - chip.Ymesh[j - 2]
                        else:
                            y1 = 0
                        if j < chip.Ny:
                            y2 = chip.Ymesh[j] - chip.Ymesh[j - 1]
                        else:
                            y2 = 0
                        gridy = (y1 + y2) / 2
                        area = gridx * gridy

                        id1 = (j - 1) * chip.Nx + i + LineOrient * const + (k - 1) * const * 2 + id_offset

                        if LineOrient == 0:
                            frontId = id1 + 1
                            bottomId = id1 + const
                            via_R = viaR / area
                            if i < chip.Nx:
                                temp = rou * x2 / (thick_L ** 2 / ar_L) / (gridy / pitch_L)
                                val = 1 / np.sum(1 / temp)
                                rows.append(id1 - 1)
                                cols.append(frontId - 1)
                                vals.append(val)
                            rows.append(id1 - 1)
                            cols.append(bottomId - 1)
                            vals.append(via_R)
                        else:
                            frontId = id1 + chip.Nx
                            if j < chip.Ny:
                                temp = rou * y2 / (thick_V ** 2 / ar_V) / (gridx / pitch_V)
                                val = 1 / np.sum(1 / temp)
                                rows.append(id1 - 1)
                                cols.append(frontId - 1)
                                vals.append(val)
                            if IOmap[j - 1, i - 1] == 1:
                                if k == chip.N:
                                    indX, indY = chip2pkgId(chip.Xmesh[i - 1], chip.Ymesh[j - 1], chip, system.pkg)
                                    bottomId = system.chip.numV + indX + (indY - 1) * system.pkg.Nx
                                    via_R = chip.c4.R_map[j - 1, i - 1]
                                    rows.append(id1 - 1)
                                    cols.append(bottomId - 1)
                                    vals.append(via_R)
                            if IOmap[j - 1, i - 1] == 1:
                                if k != chip.N:
                                    bottomId = id1 + const
                                    via_R = chip.TSV.R + chip.ubump.R_map[j - 1, i - 1]
                                    if (
                                        chip.Xmesh[i - 1] >= chip.tsv_map[0]
                                        and chip.Xmesh[i - 1] <= chip.tsv_map[0] + chip.tsv_map[2]
                                        and chip.Ymesh[j - 1] <= chip.tsv_map[1] + chip.tsv_map[3]
                                        and chip.Ymesh[j - 1] >= chip.tsv_map[1]
                                    ):
                                        rows.append(id1 - 1)
                                        cols.append(bottomId - 1)
                                        vals.append(via_R)

    const = system.pkg.Nx * system.pkg.Ny
    numBGA = np.zeros(system.chip.N)
    for k in range(1, 3):
        for j in range(1, system.pkg.Ny + 1):
            for i in range(1, system.pkg.Nx + 1):
                if i > 1:
                    x1 = system.pkg.Xmesh[i - 1] - system.pkg.Xmesh[i - 2]
                else:
                    x1 = 0
                if i < system.pkg.Nx:
                    x2 = system.pkg.Xmesh[i] - system.pkg.Xmesh[i - 1]
                else:
                    x2 = 0
                gridx = (x1 + x2) / 2

                if j > 1:
                    y1 = system.pkg.Ymesh[j - 1] - system.pkg.Ymesh[j - 2]
                else:
                    y1 = 0
                if j < system.pkg.Ny:
                    y2 = system.pkg.Ymesh[j] - system.pkg.Ymesh[j - 1]
                else:
                    y2 = 0
                gridy = (y1 + y2) / 2
                area = gridx * gridy

                id1 = system.chip.numV + (j - 1) * system.pkg.Nx + i + (k - 1) * const
                INTER_FLAG = 0
                if system.emib == 1:
                    for ii in range(system.Nbridge):
                        xl, xr, yb, yt = system.interbox[ii, :]
                        if xl <= i <= xr and yb <= j <= yt:
                            INTER_FLAG = 1
                            break
                if INTER_FLAG == 1 and k == 1:
                    Rx = system.pkg.Rs * x2 * ((system.pkg.N / 4) / (system.pkg.N / 4 - 1))
                    Ry = system.pkg.Rs * y2 * ((system.pkg.N / 4) / (system.pkg.N / 4 - 1))
                else:
                    Rx = system.pkg.Rs * x2
                    Ry = system.pkg.Rs * y2

                if k == 1:
                    if INTER_FLAG != 1:
                        bottomId = id1 + const
                        scale = system.pkg.Xsize * system.pkg.Ysize / area
                        rows.append(id1 - 1)
                        cols.append(bottomId - 1)
                        vals.append(system.pkg.ViaR * scale)
                else:
                    if int(np.floor(system.pkg.type[j - 1, i - 1] / 10)) == type_val:
                        domain = int(system.pkg.domain[j - 1, i - 1])
                        numBGA[domain - 1] += 1
                        bottomId = var - system.chip.N + domain
                        rows.append(id1 - 1)
                        cols.append(bottomId - 1)
                        vals.append(system.BGA.R)

                if i < system.pkg.Nx:
                    if system.bridge_ground == 1 and (system.bridge.FLAG != 0):
                        bridge_flagX = 0
                        bridge_flagY = 0
                        if system.emib == 1:
                            for ii in range(system.Nbridge):
                                xl, xr, yb, yt = system.interbox[ii, :]
                                if (i == xl or i == xr - 1) and (yb <= j <= yt) and k == 1:
                                    bridge_flagX = 1
                                if (j == yb or j == yt - 1) and (xl <= i <= xr) and k == 1:
                                    bridge_flagY = 1
                        if bridge_flagX == 0:
                            rows.append(id1 - 1)
                            cols.append(id1)
                            vals.append(Rx)
                    else:
                        rows.append(id1 - 1)
                        cols.append(id1)
                        vals.append(Rx)
                if j < system.pkg.Ny:
                    if system.bridge_ground == 1 and (system.bridge.FLAG != 0):
                        bridge_flagX = 0
                        bridge_flagY = 0
                        if system.emib == 1:
                            for ii in range(system.Nbridge):
                                xl, xr, yb, yt = system.interbox[ii, :]
                                if (i == xl or i == xr - 1) and (yb <= j <= yt) and k == 1:
                                    bridge_flagX = 1
                                if (j == yb or j == yt - 1) and (xl <= i <= xr) and k == 1:
                                    bridge_flagY = 1
                        if bridge_flagY == 0:
                            Nid = id1 + system.pkg.Nx
                            rows.append(id1 - 1)
                            cols.append(Nid - 1)
                            vals.append(Ry)
                    else:
                        Nid = id1 + system.pkg.Nx
                        rows.append(id1 - 1)
                        cols.append(Nid - 1)
                        vals.append(Ry)

    for i in range(system.chip.N):
        print(f"chip {i+1}, BGA number: {numBGA[i]}")

    A = _sparse_from_triplets(rows, cols, 1 / np.array(vals), (var, var))
    row = np.arange(var - system.chip.N, var)
    col = np.arange(var - system.chip.N, var)
    val = system.board.Rs * np.ones(system.chip.N)
    D = sp.csr_matrix((1 / val, (row, col)), shape=(var, var))
    return A, D


def _finalize_res_extract(var, rows, cols, vals, system):
    A = _sparse_from_triplets(rows, cols, 1 / np.array(vals), (var, var))
    row = np.arange(var - system.chip.N, var)
    col = np.arange(var - system.chip.N, var)
    val = system.board.Rs * np.ones(system.chip.N)
    D = sp.csr_matrix((1 / val, (row, col)), shape=(var, var))
    return A, D


def _res_extract_pkg_part(system, var, type_val, rows, cols, vals):
    const = system.pkg.Nx * system.pkg.Ny
    numBGA = np.zeros(system.chip.N)
    for k in range(1, 3):
        for j in range(1, system.pkg.Ny + 1):
            for i in range(1, system.pkg.Nx + 1):
                if i > 1:
                    x1 = system.pkg.Xmesh[i - 1] - system.pkg.Xmesh[i - 2]
                else:
                    x1 = 0
                if i < system.pkg.Nx:
                    x2 = system.pkg.Xmesh[i] - system.pkg.Xmesh[i - 1]
                else:
                    x2 = 0
                gridx = (x1 + x2) / 2

                if j > 1:
                    y1 = system.pkg.Ymesh[j - 1] - system.pkg.Ymesh[j - 2]
                else:
                    y1 = 0
                if j < system.pkg.Ny:
                    y2 = system.pkg.Ymesh[j] - system.pkg.Ymesh[j - 1]
                else:
                    y2 = 0
                gridy = (y1 + y2) / 2
                area = gridx * gridy

                id1 = system.chip.numV + (j - 1) * system.pkg.Nx + i + (k - 1) * const
                Eid = id1 + 1
                Nid = id1 + system.pkg.Nx

                INTER_FLAG = 0
                bridge_flagX = 0
                bridge_flagY = 0
                if system.emib == 1:
                    for ii in range(system.Nbridge):
                        xl, xr, yb, yt = system.interbox[ii, :]
                        if (i == xl - 1 or i == xr) and (yb <= j <= yt) and k == 1:
                            bridge_flagX = 1
                        if (j == yb - 1 or j == yt) and (xl <= i <= xr) and k == 1:
                            bridge_flagY = 1
                        if xl <= i <= xr and yb <= j <= yt:
                            INTER_FLAG = 1
                            break

                if INTER_FLAG == 1 and k == 1:
                    Rx = system.pkg.Rs * x2 * ((system.pkg.N / 4) / (system.pkg.N / 4 - 1))
                    Ry = system.pkg.Rs * y2 * ((system.pkg.N / 4) / (system.pkg.N / 4 - 1))
                else:
                    Rx = system.pkg.Rs * x2
                    Ry = system.pkg.Rs * y2

                if k == 1:
                    if INTER_FLAG != 1:
                        bottomId = id1 + const
                        scale = system.pkg.Xsize * system.pkg.Ysize / area
                        rows.append(id1 - 1)
                        cols.append(bottomId - 1)
                        vals.append(system.pkg.ViaR * scale)
                else:
                    if int(np.floor(system.pkg.type[j - 1, i - 1] / 10)) == type_val:
                        domain = int(system.pkg.domain[j - 1, i - 1])
                        numBGA[domain - 1] += 1
                        bottomId = var - system.chip.N + domain
                        rows.append(id1 - 1)
                        cols.append(bottomId - 1)
                        vals.append(system.BGA.R)

                if i < system.pkg.Nx and (system.pkg.domain[j - 1, i - 1] == system.pkg.domain[j - 1, i]):
                    if bridge_flagX != 1:
                        rows.append(id1 - 1)
                        cols.append(Eid - 1)
                        vals.append(Rx)

                if j < system.pkg.Ny:
                    if bridge_flagY != 1:
                        rows.append(id1 - 1)
                        cols.append(Nid - 1)
                        vals.append(Ry)

    for i in range(system.chip.N):
        print(f"chip {i+1}, BGA number: {numBGA[i]}")


def _res_extract_1x(system, chip_list, var, type_val, *, add_beol_via: bool, add_tsv_link: bool, block_top_lateral: bool):
    rows = []
    cols = []
    vals = []
    tiermap = findmap(system, chip_list)

    for ii in range(system.chip.N):
        chip = chip_list[ii]
        for k in range(1, chip.N + 1):
            IOmap = chip.type == type_val
            id_offset = sum(chip_list[kk].numV for kk in range(ii))
            Nmetal = int(chip.Metal.N[k - 1])
            rou = chip.Metal.p[k - 1]
            offset = int(np.sum(chip.Metal.N[: k - 1]))
            ar = chip.Metal.ar[offset: offset + Nmetal]
            pitch = chip.Metal.pitch[offset: offset + Nmetal]
            thick = chip.Metal.thick[offset: offset + Nmetal]
            viaR = chip.Via.R[offset: offset + Nmetal]
            viaN = chip.Via.N[offset: offset + Nmetal]

            viaR = np.sum(viaR / viaN) * chip.Xsize * chip.Ysize
            pitch_V = pitch[1::2]
            pitch_L = pitch[0::2]
            thick_V = thick[1::2]
            thick_L = thick[0::2]
            ar_V = ar[1::2]
            ar_L = ar[0::2]
            const = chip.Nx * chip.Ny

            for LineOrient in [1, 0]:
                for j in range(1, chip.Ny + 1):
                    for i in range(1, chip.Nx + 1):
                        if i > 1:
                            x1 = chip.Xmesh[i - 1] - chip.Xmesh[i - 2]
                        else:
                            x1 = 0
                        if i < chip.Nx:
                            x2 = chip.Xmesh[i] - chip.Xmesh[i - 1]
                        else:
                            x2 = 0
                        gridx = (x1 + x2) / 2

                        if j > 1:
                            y1 = chip.Ymesh[j - 1] - chip.Ymesh[j - 2]
                        else:
                            y1 = 0
                        if j < chip.Ny:
                            y2 = chip.Ymesh[j] - chip.Ymesh[j - 1]
                        else:
                            y2 = 0
                        gridy = (y1 + y2) / 2
                        area = gridx * gridy

                        map_val = tiermap[j - 1, i - 1]
                        id_raw = (j - 1) * chip.Nx + i + LineOrient * const + (k - 1) * const * 2 + id_offset
                        id1 = id_raw

                        if LineOrient == 0:
                            if k == 1:
                                frontId = id1 + 1
                                bottomId = id1 + const * 3
                            else:
                                id1 = id1 - const
                                frontId = id1 + 1
                                bottomId = id1 + const

                            via_R = viaR / area
                            if i < chip.Nx:
                                temp = rou * x2 / (thick_L ** 2 / ar_L) / (gridy / pitch_L)
                                val = 1 / np.sum(1 / temp)
                                rows.append(id1 - 1)
                                cols.append(frontId - 1)
                                vals.append(1e12 if (map_val == 0 and k == 2) else val)

                            rows.append(id1 - 1)
                            cols.append(bottomId - 1)
                            if (map_val == 1 and k == 1) or (map_val == 0 and k == 2):
                                vals.append(1e12)
                            else:
                                vals.append(via_R)

                            if add_beol_via and k > 1:
                                id2 = id1 + const
                                bottomId2 = id2 + const
                                rows.append(id2 - 1)
                                cols.append(bottomId2 - 1)
                                vals.append(1e12 if map_val == 0 else via_R)
                        else:
                            if k == 1:
                                id1 = id1 + const * 2
                            else:
                                id1 = id1 - const

                            frontId = id1 + chip.Nx
                            if j < chip.Ny:
                                temp = rou * y2 / (thick_V ** 2 / ar_V) / (gridx / pitch_V)
                                val = 1 / np.sum(1 / temp)
                                block_bottom = (map_val == 0 and k == 2)
                                block_top = (map_val == 1 and k == 1 and block_top_lateral)
                                rows.append(id1 - 1)
                                cols.append(frontId - 1)
                                vals.append(1e12 if (block_bottom or block_top) else val)

                            if IOmap[j - 1, i - 1] == 1:
                                id_io = id_raw
                                if k == chip.N:
                                    indX, indY = chip2pkgId(chip.Xmesh[i - 1], chip.Ymesh[j - 1], chip, system.pkg)
                                    bottomId = system.chip.numV + indX + (indY - 1) * system.pkg.Nx
                                    via_R = chip.ubump.R_map[j - 1, i - 1]
                                    rows.append(id_io - 1)
                                    cols.append(bottomId - 1)
                                    vals.append(via_R)
                                elif add_tsv_link:
                                    id_tsv = id_io - const
                                    bottomId = id_tsv + 2 * const
                                    via_R = chip.TSV.R
                                    if (
                                        chip.Xmesh[i - 1] >= chip.tsv_map[0]
                                        and chip.Xmesh[i - 1] <= chip.tsv_map[0] + chip.tsv_map[2]
                                        and chip.Ymesh[j - 1] <= chip.tsv_map[1] + chip.tsv_map[3]
                                        and chip.Ymesh[j - 1] >= chip.tsv_map[1]
                                    ):
                                        rows.append(id_tsv - 1)
                                        cols.append(bottomId - 1)
                                        vals.append(1e12 if map_val == 0 else via_R)

    _res_extract_pkg_part(system, var, type_val, rows, cols, vals)
    return _finalize_res_extract(var, rows, cols, vals, system)


def ResExtract_1A(system, chip_list, var, type_val):
    return _res_extract_1x(
        system,
        chip_list,
        var,
        type_val,
        add_beol_via=True,
        add_tsv_link=False,
        block_top_lateral=True,
    )


def ResExtract_1B(system, chip_list, var, type_val):
    return _res_extract_1x(
        system,
        chip_list,
        var,
        type_val,
        add_beol_via=False,
        add_tsv_link=True,
        block_top_lateral=False,
    )


def ResExtract_1C(system, chip_list, var, type_val):
    return _res_extract_1x(
        system,
        chip_list,
        var,
        type_val,
        add_beol_via=True,
        add_tsv_link=True,
        block_top_lateral=True,
    )


def _blk_num_or_default(chip, idx_1based):
    idx = idx_1based - 1
    if idx < 0 or idx >= len(chip.blk_num):
        return 1
    val = int(chip.blk_num[idx])
    return val if val > 0 else 1


def ResExtract_2(system, chip_list, var, type_val):
    rows = []
    cols = []
    vals = []

    chip0 = chip_list[0]
    if system.RDL == 0:
        tiermap_bottom = findmap(system, chip_list, _blk_num_or_default(chip0, 2))
    else:
        tiermap_bottom = findmap(system, chip_list, _blk_num_or_default(chip0, 3))
    tiermap_top = findmap(system, chip_list, _blk_num_or_default(chip0, 1))

    for ii in range(system.chip.N):
        chip = chip_list[ii]
        for k in range(1, chip.N + 1):
            IOmapc4 = chip.typec4 == type_val
            id_offset = sum(chip_list[kk].numV for kk in range(ii))
            Nmetal = int(chip.Metal.N[k - 1])
            rou = chip.Metal.p[k - 1]
            offset = int(np.sum(chip.Metal.N[: k - 1]))
            ar = chip.Metal.ar[offset: offset + Nmetal]
            pitch = chip.Metal.pitch[offset: offset + Nmetal]
            thick = chip.Metal.thick[offset: offset + Nmetal]
            viaR = chip.Via.R[offset: offset + Nmetal]
            viaN = chip.Via.N[offset: offset + Nmetal]

            viaR = np.sum(viaR / viaN) * chip.Xsize * chip.Ysize
            pitch_V = pitch[1::2]
            pitch_L = pitch[0::2]
            thick_V = thick[1::2]
            thick_L = thick[0::2]
            ar_V = ar[1::2]
            ar_L = ar[0::2]
            const = chip.Nx * chip.Ny

            for LineOrient in [1, 0]:
                for j in range(1, chip.Ny + 1):
                    for i in range(1, chip.Nx + 1):
                        if i > 1:
                            x1 = chip.Xmesh[i - 1] - chip.Xmesh[i - 2]
                        else:
                            x1 = 0
                        if i < chip.Nx:
                            x2 = chip.Xmesh[i] - chip.Xmesh[i - 1]
                        else:
                            x2 = 0
                        gridx = (x1 + x2) / 2

                        if j > 1:
                            y1 = chip.Ymesh[j - 1] - chip.Ymesh[j - 2]
                        else:
                            y1 = 0
                        if j < chip.Ny:
                            y2 = chip.Ymesh[j] - chip.Ymesh[j - 1]
                        else:
                            y2 = 0
                        gridy = (y1 + y2) / 2
                        area = gridx * gridy

                        map_bottom = tiermap_bottom[j - 1, i - 1]
                        map_top = tiermap_top[j - 1, i - 1]
                        id1 = (j - 1) * chip.Nx + i + LineOrient * const + (k - 1) * const * 2 + id_offset

                        if LineOrient == 0:
                            frontId = id1 + 1
                            bottomId = id1 + const
                            via_R = viaR / area
                            if system.RDL == 1 and k == 2:
                                via_R = via_R * float(getattr(chip_list[0], "rdlscale", 1.0))

                            if i < chip.Nx:
                                temp = rou * x2 / (thick_L ** 2 / ar_L) / (gridy / pitch_L)
                                val = 1 / np.sum(1 / temp)
                                rows.append(id1 - 1)
                                cols.append(frontId - 1)
                                if (map_bottom == 0 and k == 3) or (map_top == 0 and k == 1):
                                    vals.append(1e12)
                                else:
                                    vals.append(val)

                            rows.append(id1 - 1)
                            cols.append(bottomId - 1)
                            if (map_bottom == 0 and k == 3) or (map_top == 0 and k == 1):
                                vals.append(1e12)
                            else:
                                vals.append(via_R)
                        else:
                            frontId = id1 + chip.Nx
                            if j < chip.Ny:
                                temp = rou * y2 / (thick_V ** 2 / ar_V) / (gridx / pitch_V)
                                val = 1 / np.sum(1 / temp)
                                rows.append(id1 - 1)
                                cols.append(frontId - 1)
                                if (map_bottom == 0 and k == 3) or (map_top == 0 and k == 1):
                                    vals.append(1e12)
                                else:
                                    vals.append(val)

                            if k == 1 and system.RDL == 1 and map_top == 1:
                                bottomId = id1 + const
                                via_R = viaR / area
                                rows.append(id1 - 1)
                                cols.append(bottomId - 1)
                                vals.append(via_R)

                            if IOmapc4[j - 1, i - 1] == 1 and k == chip.N:
                                indX, indY = chip2pkgId(chip.Xmesh[i - 1], chip.Ymesh[j - 1], chip, system.pkg)
                                bottomId = system.chip.numV + indX + (indY - 1) * system.pkg.Nx
                                via_R = chip.c4.R_map[j - 1, i - 1]
                                rows.append(id1 - 1)
                                cols.append(bottomId - 1)
                                vals.append(via_R)

                            if IOmapc4[j - 1, i - 1] == 1 and k == 2 and map_bottom == 0:
                                bottomId = id1 + const
                                tov_r = chip.TOV.R if hasattr(chip, "TOV") and hasattr(chip.TOV, "R") else chip.TSV.R
                                via_R = tov_r + chip_list[0].ubump.R_map[0, 0]
                                rows.append(id1 - 1)
                                cols.append(bottomId + const - 1)
                                vals.append(via_R)

    _res_extract_pkg_part(system, var, type_val, rows, cols, vals)
    return _finalize_res_extract(var, rows, cols, vals, system)

# ------------------------- Resistance/Capacitance extraction (transient) -------------------------

def ResCapExtract(system, chip_list, cap, var, type_val):
    extVar = 0
    for ii in range(system.chip.N):
        IOmap = chip_list[ii].type == type_val
        Ncur = int(np.sum(IOmap))
        extVar += Ncur * chip_list[ii].N

    extVar = extVar + system.pkg.Ny * (system.pkg.Nx - system.chip.N) * 2 + system.pkg.Nx * (system.pkg.Ny - 1) * 2
    for ii in range(system.Nbridge):
        xl, xr, yb, yt = system.interbox[ii, :]
        extVar -= (xr - xl + 1) * 2 + (yt - yb + 1) * 2

    IOmap = np.floor(system.pkg.type / 10) == type_val
    Ncur = int(np.sum(IOmap))
    extVar += Ncur

    Carray_len = int(np.sum(system.pkg.IsCap))
    extVar += Carray_len * 2

    Ndecap = system.board.decap.shape[0]
    extVar += (1 + 2 * Ndecap) * system.chip.N

    VImark = np.ones(var + extVar)

    rows = []
    cols = []
    vals = []
    crow = []
    ccol = []
    cval = []

    Pext = 1

    # on-die matrix build
    for ii in range(system.chip.N):
        chip = chip_list[ii]
        IOmap = chip.type == type_val
        for k in range(1, chip.N + 1):
            id_offset = sum([chip_list[kk].numV for kk in range(ii)])
            Nmetal = int(chip.Metal.N[k - 1])
            rou = chip.Metal.p[k - 1]
            offset = int(np.sum(chip.Metal.N[: k - 1]))
            ar = chip.Metal.ar[offset: offset + Nmetal]
            pitch = chip.Metal.pitch[offset: offset + Nmetal]
            thick = chip.Metal.thick[offset: offset + Nmetal]
            viaR = chip.Via.R[offset: offset + Nmetal]
            viaN = chip.Via.N[offset: offset + Nmetal]
            viaR = np.sum(viaR / viaN) * chip.Xsize * chip.Ysize
            pitch_V = pitch[1::2]
            pitch_L = pitch[0::2]
            thick_V = thick[1::2]
            thick_L = thick[0::2]
            ar_V = ar[1::2]
            ar_L = ar[0::2]
            const = chip.Nx * chip.Ny
            for LineOrient in [0, 1]:
                for j in range(1, chip.Ny + 1):
                    for i in range(1, chip.Nx + 1):
                        if i > 1:
                            x1 = chip.Xmesh[i - 1] - chip.Xmesh[i - 2]
                        else:
                            x1 = 0
                        if i < chip.Nx:
                            x2 = chip.Xmesh[i] - chip.Xmesh[i - 1]
                        else:
                            x2 = 0
                        gridx = (x1 + x2) / 2

                        if j > 1:
                            y1 = chip.Ymesh[j - 1] - chip.Ymesh[j - 2]
                        else:
                            y1 = 0
                        if j < chip.Ny:
                            y2 = chip.Ymesh[j] - chip.Ymesh[j - 1]
                        else:
                            y2 = 0
                        gridy = (y1 + y2) / 2
                        area = gridx * gridy

                        id1 = (j - 1) * chip.Nx + i + LineOrient * const + (k - 1) * const * 2 + id_offset

                        if LineOrient == 0:
                            frontId = id1 + 1
                            bottomId = id1 + const
                            via_R = viaR / area

                            if i < chip.Nx:
                                temp = rou * x2 / (thick_L ** 2 / ar_L) / (gridy / pitch_L)
                                rows.append(id1 - 1)
                                cols.append(frontId - 1)
                                vals.append(np.sum(1 / temp))
                            rows.append(id1 - 1)
                            cols.append(bottomId - 1)
                            vals.append(1 / via_R)

                            crow.append(id1 - 1)
                            ccol.append(id1 - 1)
                            cval.append(cap[id1 - 1])
                        else:
                            frontId = id1 + chip.Nx
                            if j < chip.Ny:
                                temp = rou * y2 / (thick_V ** 2 / ar_V) / (gridx / pitch_V)
                                rows.append(id1 - 1)
                                cols.append(frontId - 1)
                                vals.append(np.sum(1 / temp))

                            if IOmap[j - 1, i - 1] == 1:
                                if k < chip.N and (
                                    chip.Xmesh[i - 1] < chip.tsv_map[0]
                                    or chip.Xmesh[i - 1] > chip.tsv_map[0] + chip.tsv_map[2]
                                    or chip.Ymesh[j - 1] > chip.tsv_map[1] + chip.tsv_map[3]
                                    or chip.Ymesh[j - 1] < chip.tsv_map[1]
                                ):
                                    extVar -= 1
                                    continue

                                bI = var + Pext
                                VImark[bI - 1] = 0
                                Pext += 1

                                if k == chip.N:
                                    indX, indY = chip2pkgId(chip.Xmesh[i - 1], chip.Ymesh[j - 1], chip, system.pkg)
                                    bottomId = system.chip.numV + indX + (indY - 1) * system.pkg.Nx
                                    via_R = chip.ubump.R_map[j - 1, i - 1]
                                    via_L = chip.ubump.L_map[j - 1, i - 1]
                                else:
                                    bottomId = id1 + const
                                    via_R = chip.TSV.R
                                    via_L = chip.TSV.L

                                rows.append(id1 - 1)
                                cols.append(bI - 1)
                                vals.append(1)

                                rows.append(bottomId - 1)
                                cols.append(bI - 1)
                                vals.append(-1)

                                rows.append(bI - 1)
                                cols.append(id1 - 1)
                                vals.append(-1)

                                rows.append(bI - 1)
                                cols.append(bottomId - 1)
                                vals.append(1)

                                rows.append(bI - 1)
                                cols.append(bI - 1)
                                vals.append(via_R)

                                crow.append(bI - 1)
                                ccol.append(bI - 1)
                                cval.append(via_L)

    const = system.pkg.Nx * system.pkg.Ny
    for k in range(1, 3):
        for j in range(1, system.pkg.Ny + 1):
            for i in range(1, system.pkg.Nx + 1):
                if i > 1:
                    x1 = system.pkg.Xmesh[i - 1] - system.pkg.Xmesh[i - 2]
                else:
                    x1 = 0
                if i < system.pkg.Nx:
                    x2 = system.pkg.Xmesh[i] - system.pkg.Xmesh[i - 1]
                else:
                    x2 = 0
                gridx = (x1 + x2) / 2

                if j > 1:
                    y1 = system.pkg.Ymesh[j - 1] - system.pkg.Ymesh[j - 2]
                else:
                    y1 = 0
                if j < system.pkg.Ny:
                    y2 = system.pkg.Ymesh[j] - system.pkg.Ymesh[j - 1]
                else:
                    y2 = 0
                gridy = (y1 + y2) / 2
                area = gridx * gridy
                id1 = system.chip.numV + (j - 1) * system.pkg.Nx + i + (k - 1) * const
                Eid = id1 + 1
                Nid = id1 + system.pkg.Nx

                INTER_FLAG = 0
                bridge_flagX = 0
                bridge_flagY = 0
                if system.emib == 1:
                    for ii in range(system.Nbridge):
                        xl, xr, yb, yt = system.interbox[ii, :]
                        if (i == xl - 1 or i == xr) and (yb <= j <= yt) and k == 1:
                            bridge_flagX = 1
                        if (j == yb - 1 or j == yt) and (xl <= i <= xr) and k == 1:
                            bridge_flagY = 1
                        if xl <= i <= xr and yb <= j <= yt:
                            INTER_FLAG = 1
                            break
                if INTER_FLAG == 1 and k == 1:
                    Rx = system.pkg.Rs * x2 * ((system.pkg.N / 4) / (system.pkg.N / 4 - 1))
                    Ry = system.pkg.Rs * y2 * ((system.pkg.N / 4) / (system.pkg.N / 4 - 1))
                    Lx = system.pkg.Ls * x2 * ((system.pkg.N / 4) / (system.pkg.N / 4 - 1))
                    Ly = system.pkg.Ls * y2 * ((system.pkg.N / 4) / (system.pkg.N / 4 - 1))
                else:
                    Rx = system.pkg.Rs * x2
                    Ry = system.pkg.Rs * y2
                    Lx = system.pkg.Ls * x2
                    Ly = system.pkg.Ls * y2

                if i < system.pkg.Nx and (system.pkg.domain[j - 1, i - 1] == system.pkg.domain[j - 1, i]):
                    if bridge_flagX != 1:
                        eI = var + Pext
                        VImark[eI - 1] = 0
                        Pext += 1
                        rows.append(id1 - 1)
                        cols.append(eI - 1)
                        vals.append(1)
                        rows.append(Eid - 1)
                        cols.append(eI - 1)
                        vals.append(-1)
                        rows.append(eI - 1)
                        cols.append(id1 - 1)
                        vals.append(-1)
                        rows.append(eI - 1)
                        cols.append(Eid - 1)
                        vals.append(1)
                        rows.append(eI - 1)
                        cols.append(eI - 1)
                        vals.append(Rx)
                        crow.append(eI - 1)
                        ccol.append(eI - 1)
                        cval.append(Lx)

                if j < system.pkg.Ny:
                    if bridge_flagY != 1:
                        nI = var + Pext
                        VImark[nI - 1] = 0
                        Pext += 1
                        rows.append(id1 - 1)
                        cols.append(nI - 1)
                        vals.append(1)
                        rows.append(Nid - 1)
                        cols.append(nI - 1)
                        vals.append(-1)
                        rows.append(nI - 1)
                        cols.append(id1 - 1)
                        vals.append(-1)
                        rows.append(nI - 1)
                        cols.append(Nid - 1)
                        vals.append(1)
                        rows.append(nI - 1)
                        cols.append(nI - 1)
                        vals.append(Ry)
                        crow.append(nI - 1)
                        ccol.append(nI - 1)
                        cval.append(Ly)

                if k == 1:
                    if INTER_FLAG != 1:
                        bottomId = id1 + const
                        scale = system.pkg.Xsize * system.pkg.Ysize / area
                        rows.append(id1 - 1)
                        cols.append(bottomId - 1)
                        vals.append(1 / (system.pkg.ViaR * scale))

                    if system.bridge_decap > 0 and INTER_FLAG == 1 and (system.bridge_ground == 1 and system.bridge_power == 1):
                        crow.append(id1 - 1)
                        ccol.append(id1 - 1)
                        cval.append(system.bridge_decap * area * 2)
                else:
                    if int(np.floor(system.pkg.type[j - 1, i - 1] / 10)) == type_val:
                        bottomId = var - system.chip.N + int(system.pkg.domain[j - 1, i - 1])
                        bI = var + Pext
                        VImark[bI - 1] = 0
                        Pext += 1
                        rows.append(id1 - 1)
                        cols.append(bI - 1)
                        vals.append(1)
                        rows.append(bottomId - 1)
                        cols.append(bI - 1)
                        vals.append(-1)
                        rows.append(bI - 1)
                        cols.append(id1 - 1)
                        vals.append(-1)
                        rows.append(bI - 1)
                        cols.append(bottomId - 1)
                        vals.append(1)
                        rows.append(bI - 1)
                        cols.append(bI - 1)
                        vals.append(system.BGA.R)
                        crow.append(bI - 1)
                        ccol.append(bI - 1)
                        cval.append(system.BGA.L)

    # surface mounted decaps
    k = 1
    for j in range(1, system.pkg.Ny + 1):
        for i in range(1, system.pkg.Nx + 1):
            if system.pkg.IsCap[j - 1, i - 1] == 0:
                continue
            if i > 1:
                x1 = system.pkg.Xmesh[i - 1] - system.pkg.Xmesh[i - 2]
            else:
                x1 = 0
            if i < system.pkg.Nx and (system.pkg.domain[j - 1, i - 1] == system.pkg.domain[j - 1, i]):
                x2 = system.pkg.Xmesh[i] - system.pkg.Xmesh[i - 1]
            else:
                x2 = 0
            gridx = (x1 + x2) / 2

            if j > 1:
                y1 = system.pkg.Ymesh[j - 1] - system.pkg.Ymesh[j - 2]
            else:
                y1 = 0
            if j < system.pkg.Ny:
                y2 = system.pkg.Ymesh[j] - system.pkg.Ymesh[j - 1]
            else:
                y2 = 0
            gridy = (y1 + y2) / 2
            area = gridx * gridy
            id1 = system.chip.numV + (j - 1) * system.pkg.Nx + i + (k - 1) * const

            pkgcap = system.pkg.decap[0] * area * 2
            induct = system.pkg.decap[1] / (2 * area)
            res = system.pkg.decap[2] / (2 * area)

            Iid = var + Pext
            VImark[Iid - 1] = 0
            Pext += 1
            Vid = var + Pext
            Pext += 1

            rows.append(id1 - 1)
            cols.append(Iid - 1)
            vals.append(1)

            rows.append(Iid - 1)
            cols.append(id1 - 1)
            vals.append(-1)

            rows.append(Iid - 1)
            cols.append(Vid - 1)
            vals.append(1)

            rows.append(Iid - 1)
            cols.append(Iid - 1)
            vals.append(res)

            crow.append(Iid - 1)
            ccol.append(Iid - 1)
            cval.append(induct)

            rows.append(Vid - 1)
            cols.append(Iid - 1)
            vals.append(-1)

            crow.append(Vid - 1)
            ccol.append(Vid - 1)
            cval.append(pkgcap)

    # board decap
    for j in range(1, system.chip.N + 1):
        id1 = var - system.chip.N + j
        for i in range(1, Ndecap + 1):
            pkgcap = system.board.decap[i - 1, 0] * 2
            induct = system.board.decap[i - 1, 1] / 2
            res = system.board.decap[i - 1, 2] / 2

            Iid = var + Pext
            Pext += 1
            VImark[Iid - 1] = 0
            Vid = var + Pext
            Pext += 1

            rows.append(id1 - 1)
            cols.append(Iid - 1)
            vals.append(1)

            rows.append(Iid - 1)
            cols.append(id1 - 1)
            vals.append(-1)

            rows.append(Iid - 1)
            cols.append(Vid - 1)
            vals.append(1)

            rows.append(Iid - 1)
            cols.append(Iid - 1)
            vals.append(res)

            crow.append(Iid - 1)
            ccol.append(Iid - 1)
            cval.append(induct)

            rows.append(Vid - 1)
            cols.append(Iid - 1)
            vals.append(-1)

            crow.append(Vid - 1)
            ccol.append(Vid - 1)
            cval.append(pkgcap)

        Iid = var + Pext
        Pext += 1
        VImark[Iid - 1] = 0

        rows.append(id1 - 1)
        cols.append(Iid - 1)
        vals.append(1)

        rows.append(Iid - 1)
        cols.append(id1 - 1)
        vals.append(-1)

        rows.append(Iid - 1)
        cols.append(Iid - 1)
        vals.append(system.board.Rs)

        crow.append(Iid - 1)
        ccol.append(Iid - 1)
        cval.append(system.board.Ls)

    print(f"Extra parameters expected: {extVar}, Actually added: {Pext - 1}")
    VImark = VImark[: var + extVar]

    A = _sparse_from_triplets(rows, cols, vals, (var + extVar, var + extVar))
    C = _sparse_from_triplets(crow, ccol, cval, (var + extVar, var + extVar))
    return A, C, VImark, extVar

def tranplot_one_time_cmp(system, chip_list, PLOT_FLAG):
    if PLOT_FLAG == 0:
        return
    itefig = 1
    out_dir = _output_dir(system)
    for ii in range(system.chip.N):
        const = chip_list[ii].Nx * chip_list[ii].Ny
        for k in range(1, chip_list[ii].N + 1):
            Tlen = len(system.Tmesh)
            MaxNoise = 0
            file_name_p = os.path.join(out_dir, f"chip{ii+1}_die{k}_{system.type.P}_single")
            file_name_g = os.path.join(out_dir, f"chip{ii+1}_die{k}_{system.type.G}_single")
            with open(file_name_p, "rb") as fp, open(file_name_g, "rb") as fg:
                for _ in range(Tlen):
                    xp = np.fromfile(fp, dtype=np.float64, count=const)
                    xg = np.fromfile(fg, dtype=np.float64, count=const)
                    xsum = xp + xg
                    tmp1 = np.max(xsum)
                    if tmp1 > MaxNoise:
                        MaxNoise = tmp1
                        NoisePos = int(np.argmax(xsum))

            NoisePlot = np.zeros(Tlen)
            for type_val in [system.type.P, system.type.G]:
                file_name = os.path.join(out_dir, f"chip{ii+1}_die{k}_{type_val}_single")
                with open(file_name, "rb") as f:
                    for t in range(Tlen):
                        x = np.fromfile(f, dtype=np.float64, count=const)
                        NoisePlot[t] += x[NoisePos]

            MaxNoise = 0
            file_name_p = os.path.join(out_dir, f"chip{ii+1}_die{k}_{system.type.P}_emib")
            file_name_g = os.path.join(out_dir, f"chip{ii+1}_die{k}_{system.type.G}_emib")
            with open(file_name_p, "rb") as fp, open(file_name_g, "rb") as fg:
                for _ in range(Tlen):
                    xp = np.fromfile(fp, dtype=np.float64, count=const)
                    xg = np.fromfile(fg, dtype=np.float64, count=const)
                    xsum = xp + xg
                    tmp1 = np.max(xsum)
                    if tmp1 > MaxNoise:
                        MaxNoise = tmp1
                        NoisePos = int(np.argmax(xsum))

            NoisePlot_emib = np.zeros(Tlen)
            for type_val in [system.type.P, system.type.G]:
                file_name = os.path.join(out_dir, f"chip{ii+1}_die{k}_{type_val}_emib")
                with open(file_name, "rb") as f:
                    for t in range(Tlen):
                        x = np.fromfile(f, dtype=np.float64, count=const)
                        NoisePlot_emib[t] += x[NoisePos]

            MaxNoise = 0
            file_name_p = os.path.join(out_dir, f"chip{ii+1}_die{k}_{system.type.P}_inter")
            file_name_g = os.path.join(out_dir, f"chip{ii+1}_die{k}_{system.type.G}_inter")
            with open(file_name_p, "rb") as fp, open(file_name_g, "rb") as fg:
                for _ in range(Tlen):
                    xp = np.fromfile(fp, dtype=np.float64, count=const)
                    xg = np.fromfile(fg, dtype=np.float64, count=const)
                    xsum = xp + xg
                    tmp1 = np.max(xsum)
                    if tmp1 > MaxNoise:
                        MaxNoise = tmp1
                        NoisePos = int(np.argmax(xsum))

            NoisePlot_inter = np.zeros(Tlen)
            for type_val in [system.type.P, system.type.G]:
                file_name = os.path.join(out_dir, f"chip{ii+1}_die{k}_{type_val}_inter")
                with open(file_name, "rb") as f:
                    for t in range(Tlen):
                        x = np.fromfile(f, dtype=np.float64, count=const)
                        NoisePlot_inter[t] += x[NoisePos]

            plt.figure(30 + itefig)
            plt.plot(system.Tmesh * 1e9, system.Vdd.val - NoisePlot, "b", linewidth=3)
            plt.plot(system.Tmesh * 1e9, system.Vdd.val - NoisePlot_inter, "r", linewidth=3)
            plt.plot(system.Tmesh * 1e9, system.Vdd.val - NoisePlot_emib, "k", linewidth=3)
            plt.xlabel("Time(ns)")
            plt.ylabel("Power Delivery Noise(mV)")
            itefig += 1

def tranplot(system, chip_list, PLOT_FLAG):
    if PLOT_FLAG == 0:
        return
    itefig = 1
    out_dir = _output_dir(system)
    for ii in range(system.chip.N):
        const = chip_list[ii].Nx * chip_list[ii].Ny
        for k in range(1, chip_list[ii].N + 1):
            Tlen = len(system.Tmesh)
            MaxNoise = 0
            file_name_p = os.path.join(out_dir, f"chip{ii+1}_die{k}_{system.type.P}")
            file_name_g = os.path.join(out_dir, f"chip{ii+1}_die{k}_{system.type.G}")
            with open(file_name_p, "rb") as fp, open(file_name_g, "rb") as fg:
                for _ in range(Tlen):
                    xp = np.fromfile(fp, dtype=np.float64, count=const)
                    xg = np.fromfile(fg, dtype=np.float64, count=const)
                    xsum = xp + xg
                    tmp1 = np.max(xsum)
                    if tmp1 > MaxNoise:
                        MaxNoise = tmp1
                        NoisePos = int(np.argmax(xsum))

            NoisePlot = np.zeros(Tlen)
            for type_val in [system.type.P, system.type.G]:
                file_name = os.path.join(out_dir, f"chip{ii+1}_die{k}_{type_val}")
                with open(file_name, "rb") as f:
                    for t in range(Tlen):
                        x = np.fromfile(f, dtype=np.float64, count=const)
                        NoisePlot[t] += x[NoisePos]

            Tid = int(np.argmax(NoisePlot))
            NoiseProfile = np.zeros(const)
            for type_val in [system.type.P, system.type.G]:
                file_name = os.path.join(out_dir, f"chip{ii+1}_die{k}_{type_val}")
                with open(file_name, "rb") as f:
                    for t in range(Tlen):
                        x = np.fromfile(f, dtype=np.float64, count=const)
                        if t == Tid:
                            NoiseProfile += x
                            break

            plt.figure(30 + itefig)
            plt.plot(system.Tmesh * 1e9, system.Vdd.val - NoisePlot, linewidth=3)
            plt.xlabel("Time(ns)")
            plt.ylabel("Power Delivery Noise(mV)")

            plt.figure(40 + itefig)
            drawT_die = _reshape_solver_plane(NoiseProfile, chip_list[ii].Nx, chip_list[ii].Ny)
            print(f"chip {ii+1}, die {k}, maximum noise occurs in {system.Tmesh[Tid]*1e9:.2f} ns")
            value = np.max(NoiseProfile)
            print(f"Max Noise: {value*1e3:.2f} mV")
            plt.contourf(chip_list[ii].Xmesh * 100, chip_list[ii].Ymesh * 100, drawT_die * 1000, 30, cmap=_colormap(system))
            plt.colorbar()
            plt.xlabel("x(cm)")
            plt.ylabel("y(cm)")
            itefig += 1


# ------------------------- Main simulation -------------------------

def power_noise_sim(system, chip_list):
    system.type.P = 1
    system.type.G = 2
    system, chip_list = calParasitics(system, chip_list)

    chip_list = ubumpGen(system, chip_list)
    chip_list = c4Gen(system, chip_list)
    system = BGAGen(system)

    system, chip_list = mesh(system, chip_list, system.drawM)
    system.Tmesh = meshTran(system.T, system.dt)

    var, system, chip_list = initial_IR(system, chip_list)
    current_full = dumpCurrent(system, chip_list, var, system.drawP)

    if system.skip == 1:
        tranplot_one_time_cmp(system, chip_list, system.tranplot)
        return None

    if system.tran == 0:
        i = 0
        x = np.zeros((var, 2))
        for type_val in [system.type.P, system.type.G]:
            version = getattr(system, "version", 0)
            if version == 1:
                A, D = ResExtract_1C(system, chip_list, var, type_val)
            elif version == 2:
                A, D = ResExtract_2(system, chip_list, var, type_val)
            elif version == 0:
                structure = int(getattr(system, "structure", 0))
                if structure == 1:
                    # Match Amytest-style F2B selector (version=0, structure=1).
                    A, D = ResExtract_1C(system, chip_list, var, type_val)
                else:
                    A, D = ResExtract_baseline(system, chip_list, var, type_val)
            elif version == 3:
                A, D = ResExtract_1A(system, chip_list, var, type_val)
            else:
                A, D = ResExtract_1B(system, chip_list, var, type_val)

            Y = MatrixBuild(A, D, var)
            x[:, i] = Noise_solver_ss(Y, current_full)
            power_loss(system, var, Y, x[:, i])
            i += 1
        result = draw_map(system, chip_list, x[:, 0], x[:, 1], 0, system.write, system.draw)
        return result

    cap_all = dumpCap(system, chip_list, var, system.drawC)
    Tlen = len(system.Tmesh)
    for type_val in [system.type.P, system.type.G]:
        A, C, VImark, extVar = ResCapExtract(system, chip_list, cap_all, var, type_val)
        Y = MatrixBuild_tran(A, var)
        lu = tranFac(Y, C, system.dt, system.TR_FLAG)
        x = VImark * 0
        draw_map_tran(system, chip_list, x, 0, system.write, system.draw, type_val)
        bprev = tranDumpCurrent(system, chip_list, current_full, 0, extVar)
        perc = 20
        ratio = 20
        for i in range(1, Tlen):
            b = tranDumpCurrent(system, chip_list, current_full, system.Tmesh[i], extVar)
            x = Noise_solver_tran_lu(lu, Y, C, b, bprev, x, system.dt, system.TR_FLAG)
            bprev = b
            draw_map_tran(system, chip_list, x, system.Tmesh[i], system.write, system.draw, type_val)
            if i >= Tlen * ratio / 100:
                print(f"simulation {ratio} % done")
                ratio += perc
    tranplot(system, chip_list, system.tranplot)
    return None
