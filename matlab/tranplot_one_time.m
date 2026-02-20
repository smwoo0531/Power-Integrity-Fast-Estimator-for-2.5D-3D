function tranplot_one_time(system, chip, PLOT_FLAG)
%This is to draw transient plots
    if PLOT_FLAG == 0
        return;
    else
        itefig = 1;
        for ii = 1 : system.chip.N
            const = chip(ii).Nx * chip(ii).Ny;
            for k = 1 : chip(ii).N
                x = zeros(const, 2);
                Tlen = length(system.Tmesh);
                i = 1;
                for type = [system.type.P, system.type.G]
                    file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(type)];
                    fileID = fopen(file_name, 'r');
                    sizeA = [const,1];
                    fread(fileID, sizeA, 'double');
                    x(:,i) = fread(fileID, sizeA, 'double');
                    fclose(fileID);
                    i = i + 1;
                end
                x = x(:,1) + x(:,2);
                [~, NoisePos] = max(x);
                
                NoisePlot = zeros(Tlen, 1);
                NoisePlot_emib = zeros(Tlen, 1);
                NoisePlot_inter = zeros(Tlen, 1);
                for type = [system.type.P]                
                    file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(type)];
                    fileID = fopen(file_name, 'r');
                    sizeA = [const,1];
                    for i = 1:Tlen
                        x = fread(fileID, sizeA, 'double');
                        NoisePlot(i) = NoisePlot(i) + x(NoisePos);
                    end
                    fclose(fileID);
                    
%                     file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(type), '_emib'];
%                     fileID = fopen(file_name, 'r');
%                     sizeA = [const,1];
%                     for i = 1:Tlen
%                         x = fread(fileID, sizeA, 'double');
%                         NoisePlot_emib(i) = NoisePlot_emib(i) + x(NoisePos);
%                     end
%                     fclose(fileID);    
%                     
%                     file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(type), '_inter'];
%                     fileID = fopen(file_name, 'r');
%                     sizeA = [const,1];
%                     for i = 1:Tlen
%                         x = fread(fileID, sizeA, 'double');
%                         NoisePlot_inter(i) = NoisePlot_inter(i) + x(NoisePos);
%                     end
%                     fclose(fileID);                    
                end
                         
                figure(30+itefig);
                h1 = plot(system.Tmesh*1e9, system.Vdd.val - NoisePlot*2, 'b', 'linewidth', 3); hold on;
                h2 = plot(system.Tmesh*1e9, system.Vdd.val - NoisePlot_inter*2, 'r', 'linewidth', 3); hold on;
                h3 = plot(system.Tmesh*1e9, system.Vdd.val - NoisePlot_emib*2, 'k', 'linewidth', 3);
                l1 = 'Standalone';
                l2 = 'Interposer';
                l3 = 'EMIB';
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

