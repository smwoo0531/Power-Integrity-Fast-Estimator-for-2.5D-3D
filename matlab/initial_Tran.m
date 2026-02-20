function [var, system, chip] = initial_Tran(system, chip)
    %different number of unknowns
    system.chip.numI = 0;
    for i = 1:system.chip.N
        chip(i).numI = chip(i).Nx * chip(i).Ny * 2 * chip(i).N;
        system.chip.numV = system.chip.numV + chip(i).numV;
    end
    
    system.pkg.numV = system.pkg.Nx * system.pkg.Ny * 2;

    system.pkg.numPort = 2; 
    % one is between VRM and board_spread
    % board_spread and pre-BGA
    var = system.chip.numV + system.pkg.numV + system.pkg.numPort;
end