function [system_, chip_] = calParasitics(system, chip)
    for i = 1:system.chip.N
        chip(i).c_gate = 3.9*8.85e-12./chip(i).cap_th*2;
        for j = 1:chip(i).N
            st = sum(chip(i).blk_num(1:j-1))+1;
            ed = st + chip(i).blk_num(j) - 1;
            if ed >= st
                chip(i).map(st:ed, 6) = chip(i).map(st:ed, 6)*chip(i).c_gate(j)*2;           
            end
        end
    end

    if system.inter == 1 || system.emib_via == 1 || system.stacked_die == 1
        rou = system.TSV.rou;
        h = system.TSV.thick;
        d = system.TSV.d;
        liner = system.TSV.liner;
        mu = system.TSV.mu;
        pitch = system.TSV.px/2;
        system.TSV.R =  (rou*h/(0.25*pi*(d-2*liner)^2) + system.TSV.contact/(0.25*pi*(d-2*liner)^2))/system.TSV.Nbundle;

        Lself = mu*h/(2*pi)*log(2*pitch/d);
        Lmutual = 4*0.199*mu*h*log(1+1.0438*h/sqrt(pitch^2/2))-4*0.199*mu*h*log(1+1.0438*h/pitch);
        system.TSV.L = (Lself + Lmutual)/system.TSV.Nbundle;
    end    
    
    for i = 1:system.chip.N
        if chip(i).N > 1
            rou = chip(i).TSV.rou;
            h = chip(i).TSV.thick;
            d = chip(i).TSV.d;
            liner = chip(i).TSV.liner;
            mu = chip(i).TSV.mu;
            pitch = chip(i).TSV.px/2;
            chip(i).TSV.R =  ((rou*h/(0.25*pi*(d-2*liner)^2) + chip(i).TSV.contact/(0.25*pi*d^2))/chip(i).TSV.Nbundle) * chip(i).ubump.scale;
            
            Lself = mu*h/(2*pi)*log(1+2.84*h/(pi*(d/2)));
            Lmutual = 4*0.199*mu*h*log(1+1.0438*h/sqrt(pitch^2/2))-4*0.199*mu*h*log(1+1.0438*h/pitch);
            chip(i).TSV.L = (Lself + Lmutual)/system.TSV.Nbundle;

            % Repeat for TOVs - this is only true for the reconstituted
            % tier case
            if system.TOV == 1
                rou = chip(i).TOV.rou;
                h = chip(i).TOV.thick;
                d = chip(i).TOV.d;
                liner = chip(i).TOV.liner;
                mu = chip(i).TOV.mu;
                pitch = chip(i).TOV.px/2;
                chip(i).TOV.R =  (rou*h/(0.25*pi*(d-2*liner)^2) + chip(i).TOV.contact/(0.25*pi*d^2))/chip(i).TOV.Nbundle;
                
                % change if running transient
                Lself = mu*h/(2*pi)*log(1+2.84*h/(pi*(d/2)));
                Lmutual = 4*0.199*mu*h*log(1+1.0438*h/sqrt(pitch^2/2))-4*0.199*mu*h*log(1+1.0438*h/pitch);
                chip(i).TOV.L = (Lself + Lmutual)/chip(i).TOV.Nbundle;
            end

        end
        %% for microbump
        rou = chip(i).ubump.rou;
        h = chip(i).ubump.h;
        d = chip(i).ubump.d;
        mu = chip(i).ubump.mu;
        pitch = chip(i).ubump.px/2;
        chip(i).ubump.R =  rou*h/(0.25*pi*d^2)*chip(i).ubump.scale;
        chip(i).HB.R =  rou*h/(0.25*pi*d^2);

        Lself = mu*h/(2*pi)*log(2*pitch/d)*chip(i).ubump.scale;
        Lmutual = 0; %4*0.199*mu*h*log(1+1.0438*h/sqrt(pitch^2/2))-4*0.199*mu*h*log(1+1.0438*h/pitch);
        chip(i).ubump.L = (Lself + Lmutual); 
        
        rou = chip(i).c4.rou;
        h = chip(i).c4.h;
        d = chip(i).c4.d;
        mu = chip(i).c4.mu;
        pitch = chip(i).c4.px/2;
        chip(i).c4.R =  rou*h/(0.25*pi*d^2)*chip(i).c4.scale/chip(i).c4.Nbundle;

        Lself = mu*h/(2*pi)*log(2*pitch/d)*chip(i).c4.scale;
        Lmutual = 0; %0.199*mu*h*log(1+1.0438*h/sqrt(pitch^2/2))-4*0.199*mu*h*log(1+1.0438*h/pitch);
        chip(i).c4.L = (Lself + Lmutual)/chip(i).c4.Nbundle;
                
        if system.inter == 1
            chip(i).ubump.R = chip(i).c4.R/chip(i).c4.Nbundle + chip(i).ubump.R + system.TSV.R;
            chip(i).ubump.L = chip(i).c4.L/chip(i).c4.Nbundle + chip(i).ubump.L + system.TSV.L;
        elseif system.bridge_ground == 1
            chip(i).c4.R = chip(i).c4.R/chip(i).c4.Nbundle;
            chip(i).c4.L = chip(i).c4.L/chip(i).c4.Nbundle;
        end
    end
    
%    system.pkg.Cdst = 1.1*8.85e-12*system.pkg.N*0.5*2/system.pkg.wire_thick;

    %% for BGA
    rou = system.BGA.rou;
    h = system.BGA.h;
    d = system.BGA.d;
    mu = system.BGA.mu;
    pitch = system.BGA.px/2;
    system.BGA.R =  rou*h/(0.25*pi*d^2)*system.BGA.scale;

    Lself = mu*h/(2*pi)*log(1+2.84*h/(pi*(d/2)));
    Lmutual = 4*0.199*mu*h*log(1+1.0438*h/sqrt(pitch^2/2))-4*0.199*mu*h*log(1+1.0438*h/pitch);
    system.BGA.L = Lself + Lmutual;       

%     decap = sum(system.board.decap(:,1)); 
%     induct = 1/sum(1./system.board.decap(:,2));
%     res = 1/sum(1./system.board.decap(:,3));
%     system.board.decap = [decap, induct, res];
    
    system_ = system;
    chip_ = chip;
end

