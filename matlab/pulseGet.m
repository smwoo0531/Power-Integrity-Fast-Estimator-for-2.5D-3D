function val = pulseGet(Tp, Tr, Tc, Tf, t)
    val1 = 0;
    val2 = 1;
    td = 0;
    tr = Tr;
    tf = Tf;
    tc = Tc;
    tp = Tp;

    tt = mod(t, tp);

    if tt <= td || tt > td+tr+tc+tf
        val = val1;
    else
        if tt>td && tt<=td+tr
            val = val1 + (tt-td)/tr*(val2-val1);
        elseif tt>td+tr && tt<=td+tr+tc
            val = val2;
        else
            seg = tt - (td+tr+tc);
            val = val2 + seg/tf*(val1-val2);
        end
    end
end

