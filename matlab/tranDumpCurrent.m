function current = tranDumpCurrent(system, chip, current_full, dt, var)
% dumping current based on time information
% chip(2).Tp = 1e-9; %period
% chip(2).Tr = 0.45e-9; %rise time
% chip(2).Tf = 0.45e-9; %fall time  
    current = zeros(size(current_full));
    for ii = 1:system.chip.N
        idoffset = 0;
        for jj = 1:ii-1
            idoffset = idoffset + chip(jj).numV;
        end
        const = chip(ii).Nx * chip(ii).Ny;
        alpha = pulseGet(chip(ii).Tp, chip(ii).Tr, chip(ii).Tc, chip(ii).Tf, dt);
        for k = 1:chip(ii).N
            st = 1 + idoffset + (k-1)*2*const;
            ed = const + idoffset + (k-1)*2*const;
            current(st:ed) = current_full(st:ed)*alpha;
        end
    end
    current = [current; zeros(var, 1)];
end

