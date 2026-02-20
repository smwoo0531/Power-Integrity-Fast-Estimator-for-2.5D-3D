function tranplot_one_time_cmp(system, chip, PLOT_FLAG)
%This is to draw transient plots
    if PLOT_FLAG == 0
        return;
    else
        itefig = 1;
        for ii = 1 : system.chip.N
            const = chip(ii).Nx * chip(ii).Ny;
            for k = 1 : chip(ii).N
                Tlen = length(system.Tmesh);
                MaxNoise = 0;
                file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(system.type.P), '_single'];
                fileIDp = fopen(file_name, 'r');
                file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(system.type.G), '_single'];
                fileIDg = fopen(file_name, 'r');
                for i = 1:Tlen
                    x = zeros(const, 2);
                    sizeA = [const,1];
                    x(:, 1) = fread(fileIDp, sizeA, 'double');
                    x(:, 2) = fread(fileIDg, sizeA, 'double');
                    x = x(:,1) + x(:,2);
                    [tmp1, tmp2] = max(x);
                    if (tmp1 > MaxNoise)
                        MaxNoise = tmp1;
                        NoisePos = tmp2;
                    end
                end
                fclose(fileIDp);
                fclose(fileIDg);
                
                NoisePlot = zeros(Tlen, 1);
                for type = [system.type.P, system.type.G]                
                    file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(type), '_single'];
                    fileID = fopen(file_name, 'r');
                    sizeA = [const,1];
                    for i = 1:Tlen
                        x = fread(fileID, sizeA, 'double');
                        NoisePlot(i) = NoisePlot(i) + x(NoisePos);
                    end
                    fclose(fileID);
                end

                MaxNoise = 0;
                file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(system.type.P), '_emib'];
                fileIDp = fopen(file_name, 'r');
                file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(system.type.G), '_emib'];
                fileIDg = fopen(file_name, 'r');
                for i = 1:Tlen
                    x = zeros(const, 2);
                    sizeA = [const,1];
                    x(:, 1) = fread(fileIDp, sizeA, 'double');
                    x(:, 2) = fread(fileIDg, sizeA, 'double');
                    x = x(:,1) + x(:,2);
                    [tmp1, tmp2] = max(x);
                    if (tmp1 > MaxNoise)
                        MaxNoise = tmp1;
                        NoisePos = tmp2;
                    end
                end
                fclose(fileIDp);
                fclose(fileIDg);
                
                NoisePlot_emib = zeros(Tlen, 1);
                for type = [system.type.P, system.type.G]                
                    file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(type), '_emib'];
                    fileID = fopen(file_name, 'r');
                    sizeA = [const,1];
                    for i = 1:Tlen
                        x = fread(fileID, sizeA, 'double');
                        NoisePlot_emib(i) = NoisePlot_emib(i) + x(NoisePos);
                    end
                    fclose(fileID);
                end                 
                
                MaxNoise = 0;
                file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(system.type.P), '_inter'];
                fileIDp = fopen(file_name, 'r');
                file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(system.type.G), '_inter'];
                fileIDg = fopen(file_name, 'r');
                for i = 1:Tlen
                    x = zeros(const, 2);
                    sizeA = [const,1];
                    x(:, 1) = fread(fileIDp, sizeA, 'double');
                    x(:, 2) = fread(fileIDg, sizeA, 'double');
                    x = x(:,1) + x(:,2);
                    [tmp1, tmp2] = max(x);
                    if (tmp1 > MaxNoise)
                        MaxNoise = tmp1;
                        NoisePos = tmp2;
                    end
                end
                fclose(fileIDp);
                fclose(fileIDg);
                
                NoisePlot_inter = zeros(Tlen, 1);
                for type = [system.type.P, system.type.G]                
                    file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(type), '_inter'];
                    fileID = fopen(file_name, 'r');
                    sizeA = [const,1];
                    for i = 1:Tlen
                        x = fread(fileID, sizeA, 'double');
                        NoisePlot_inter(i) = NoisePlot_inter(i) + x(NoisePos);
                    end
                    fclose(fileID);
                end
                                
                figure(30+itefig);
                h1 = plot(system.Tmesh*1e9, system.Vdd.val - NoisePlot, 'b', 'linewidth', 3); hold on;
                h2 = plot(system.Tmesh*1e9, system.Vdd.val - NoisePlot_inter, 'r', 'linewidth', 3); hold on;
                h3 = plot(system.Tmesh*1e9, system.Vdd.val - NoisePlot_emib, 'k', 'linewidth', 3);
                if ii == 1
                    axis([0 100 0.7, 1])
                else
                    axis([0 100 0.78, 1])
                end
                l1 = 'Single Die';
                l2 = 'Interposer';
                l3 = 'Bridge-chip';
                legend([h1,h2,h3], l1,l2,l3)
                set(gca,'FontSize',16);
                xlabel('Time(ns)');
                ylabel('Power Delivery Noise(mV)');
                set(gca,'FontSize',16);                
                itefig = itefig + 1;
            end
        end
    end
end

