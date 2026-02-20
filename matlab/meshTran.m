function Tmesh = meshTran(T, dt)
%use uniform time steps to enable pre-LU factorization
    len = round(T/dt);
    Tmesh = linspace(0, T, len+1);
end

