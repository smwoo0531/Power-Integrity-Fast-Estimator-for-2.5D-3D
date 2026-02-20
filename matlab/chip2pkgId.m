function [indX, indY] = chip2pkgId(x, y, chip, pkg)
% This function returns the pkg indexes for give coordinates
    xinpkg = x + chip.xl;
    yinpkg = y + chip.yb;
    [~, indX] = min(abs(xinpkg - pkg.Xmesh));
    [~, indY] = min(abs(yinpkg - pkg.Ymesh));
    if abs(xinpkg - pkg.Xmesh(indX)) > 1e-6 || abs(yinpkg - pkg.Ymesh(indY)) > 1e-6
        error('cannot find this chip coordinates in pakcage plane');
    end
return;