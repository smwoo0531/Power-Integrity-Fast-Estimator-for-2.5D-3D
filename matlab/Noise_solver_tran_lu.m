function x = Noise_solver_tran_lu(L, U, P, Q, R, Y, C, b, bprev, xp, r, FLAG)
    spparms('spumoni', 0);
    if FLAG == 1
        B = C/r-Y/2;
        const = (b + bprev )/2;   
    else
        B = C/r;
        const = b;
    end
    right = const + B*xp;
    x = Q*(U\(L\(P*(R\right))));
end

