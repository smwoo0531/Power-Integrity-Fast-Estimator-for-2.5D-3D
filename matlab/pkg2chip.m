function [indX, indY] = pkg2chip(x, y, chip)
% This function returns the chip indexes for give coordinates
    indX = -1;
    indY = -1;
if x < chip.Xpos || x > chip.Xpos+chip.Xsize || y < chip.Ypos || y > chip.Ypos+chip.Ysize
    return;
end

for k = 1:1:chip.Nx
    if abs(chip.Xmesh(k)-x) < 1e-12
        indX = k;
        break;
    end
end

for k = 1:1:chip.Ny
    if abs(chip.Ymesh(k)-y) < 1e-12
        indY = k;
        break;
    end
end
return;