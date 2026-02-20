function [var, system, chip] = initial_IR(system, chip)
    %different number of unknowns
    system.chip.numV = 0;
    for i = 1:system.chip.N
        if chip.intermetal.usage == 1
            chip(i).numV = chip(i).Nx * chip(i).Ny * (2 * chip(i).N + 1);
        else 
            chip(i).numV = chip(i).Nx * chip(i).Ny * 2 * chip(i).N;
        end
        system.chip.numV = system.chip.numV + chip(i).numV;
    end
    
    system.pkg.numV = system.pkg.Nx * system.pkg.Ny * 2;

    system.pkg.numPort = system.chip.N; 
    % one is between VRM and board_spread
    % board_spread and pre-BGA
    var = system.chip.numV + system.pkg.numV + system.pkg.numPort;
end