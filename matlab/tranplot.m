function tranplot(system, chip, PLOT_FLAG)
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
                file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(system.type.P)];
                fileIDp = fopen(file_name, 'r');
                file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(system.type.G)];
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
                    file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(type)];
                    fileID = fopen(file_name, 'r');
                    sizeA = [const,1];
                    for i = 1:Tlen
                        x = fread(fileID, sizeA, 'double');
                        NoisePlot(i) = NoisePlot(i) + x(NoisePos);
                    end
                    fclose(fileID);
                end
                [~, Tid] = max(NoisePlot);
                
                NoiseProfile = zeros(const, 1);
                for type = [system.type.P, system.type.G]
                    file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(type)];
                    fileID = fopen(file_name, 'r');                    
                    sizeA = [const,1];
                    for i = 1:Tlen
                        x = fread(fileID, sizeA, 'double');
                        if i == Tid
                            NoiseProfile = NoiseProfile + x;
                            break;
                        end
                    end
                    fclose(fileID);
                end
                                
                figure(30+itefig);
                plot(system.Tmesh*1e9, system.Vdd.val - NoisePlot, 'linewidth', 3);
                xlabel('Time(ns)');
                ylabel('Power Delivery Noise(mV)');
                set(gca,'FontSize',16);
                
                figure(40+itefig);             
                drawT_die = reshape(NoiseProfile, chip(ii).Nx, chip(ii).Ny)';
                fprintf('chip %d, die %d, maximum noise occurs in %.2f ns\n', ii, k, system.Tmesh(Tid)*1e9)
                value = max(NoiseProfile);
                fprintf('Max Noise: %.2f mV\n', value*1e3)
                contourf(chip(ii).Xmesh*100, chip(ii).Ymesh*100, drawT_die*1000, 30, 'Linestyle','none');
                h=colorbar;
                set(get(h,'Title'),'string','Noise/(mV)','FontSize',16);
                set(gca,'FontSize',16);
                xlabel('x(cm)');
                ylabel('y(cm)');
                set(gca,'FontSize',16);       
                
                itefig = itefig + 1;
            end
        end
    end
end

