function result = power_noise_sim(system, chip)
%this is the main PDN simulator
    system.type.P = 1; system.type.G = 2; 
    t_start = tic;
    [system, chip] = calParasitics(system, chip);

    chip = ubumpGen(system, chip);
    chip = c4Gen(system,chip);
    system = BGAGen(system);

    [system, chip] = mesh(system, chip, system.drawM);
    system.Tmesh = meshTran(system.T, system.dt);

    [var, system, chip] = initial_IR(system, chip);
        
    current_full  = dumpCurrent(system, chip, var, system.drawP);
    
    % build R only matrix
    if system.skip == 1
        tranplot_one_time_cmp(system, chip, system.tranplot);
    else
        if system.tran == 0                
            %this is for IR drop simulations
            i = 1;
            x = zeros(var, 2);
            for type = [system.type.P, system.type.G]
                if system.version == 1
                    [A, D] = ResExtract_1C(system, chip, var, type);
                elseif system.version == 2
                    [A, D] = ResExtract_2(system, chip, var, type);
                elseif system.version == 0
                    if system.structure == 0 
                        [A, D] = ResExtract_baseline(system, chip, var, type);
                    elseif  system.structure == 1
                        [A, D] = ResExtract_baseline_F2B(system, chip, var, type);
                    elseif  system.structure == 2            
                        [A, D] = ResExtract_baseline_F2F(system, chip, var, type);
                    end
                elseif system.version == 3
                    [A, D] = ResExtract_1A(system, chip, var, type);
                else
                    [A, D] = ResExtract_1B(system, chip, var, type);
                end
                Y = MatrixBuild(A, D, var);
                x(:,i) = Noise_solver_ss(Y, current_full);
                power_loss(system, var, Y, x(:, i));
                i = i + 1;
            end
            result = draw_map(system, chip, x(:,1), x(:,2), 0, system.write, system.draw);
        else
            cap_all = dumpCap(system, chip, var, system.drawC);
            Tlen = length(system.Tmesh);
            for type = [system.type.P, system.type.G]
                [A, C, VImark, extVar] = ResCapExtract(system, chip, cap_all, var, type);
                Y = MatrixBuild_tran(A, var);
                [L, U, P, Q, R] = tranFac(Y, C, system.dt, system.TR_FLAG);
                x = VImark * 0;
                draw_map_tran(system, chip, x, 0, system.write, system.draw, type);
                bprev = tranDumpCurrent(system, chip, current_full, 0, extVar);
                perc = 20;
                ratio = 20;
                for i = 2 : Tlen
                    b = tranDumpCurrent(system, chip, current_full, system.Tmesh(i), extVar);
                    x = Noise_solver_tran_lu(L, U, P, Q, R, Y, C, b, bprev, x, system.dt, system.TR_FLAG);
                    bprev = b; 
                    draw_map_tran(system, chip, x, system.Tmesh(i), system.write, system.draw, type);
                    if i >= Tlen * ratio/100
                        fprintf('simulation %d %% done\n', ratio);
                        ratio = ratio + perc;
                    end
                end
            end
            tranplot(system, chip, system.tranplot);
        end
    end
    toc(t_start);
end