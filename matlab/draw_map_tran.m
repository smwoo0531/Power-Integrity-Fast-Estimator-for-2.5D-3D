function draw_map_tran(system, chip, x, t, WRITE_FLAG, DRAW_FLAG, type)
    GIF_FLAG = system.gif;
    itefig = 1;
    for ii = 1:system.chip.N
        offset = 0;
        for kk = 1 : ii-1
            offset = offset + chip(kk).numV;
        end
        const = chip(ii).Nx * chip(ii).Ny;
        for k= 1 : chip(ii).N
            st = offset + 2*const*(k-1) + 1;
            ed = st + const - 1;
            if WRITE_FLAG
                file_name = ['./results/chip', num2str(ii), '_die', num2str(k), '_', num2str(type)];
                if t == 0
                    fid=fopen(file_name,'w+');
                    fwrite(fid, x(st:ed), 'double');
                    fclose(fid);
                else
                    fid=fopen(file_name,'a+');
                    while fid <= 0
                        fid=fopen(file_name,'a+');
                    end
                    fwrite(fid, x(st:ed), 'double');
                    fclose(fid);
                end
            end
            if DRAW_FLAG
                drawT_die = reshape(x(st:ed), chip(ii).Nx, chip(ii).Ny)';
                value = max(x(st:ed)*1000);
                fprintf('chip %d, die %d, maximum noise: %.2f mV\n', ii, k, value);
                figure(itefig+30); 
                itefig = itefig + 1;
                contourf(chip(ii).Xmesh*100, chip(ii).Ymesh*100, abs(drawT_die)*1000,30, 'Linestyle','none');
                h=colorbar;
                set(get(h,'Title'),'string','Noise/(mV)','FontSize',16);
                set(gca,'FontSize',16);
                xlabel('x(cm)');
                ylabel('y(cm)');
                set(gca,'FontSize',16);                
            end
            if GIF_FLAG
                
            end
        end
    end

    st = system.chip.numV+1;
    ed = st + system.pkg.Nx * system.pkg.Ny - 1;
    file_name = ['./results/pkg_', num2str(type)];
    if WRITE_FLAG
        if t == 0
            fid=fopen(file_name,'w+');
            fwrite(fid, x(st:ed), 'double');
            fclose(fid);
        else
            fid=fopen(file_name,'a+');
            while fid <= 0
                fid=fopen(file_name,'a+');
            end
            fwrite(fid, x(st:ed), 'double');
            fclose(fid);
        end
    end
    if DRAW_FLAG
        drawT = reshape(x(st:ed), system.pkg.Nx, system.pkg.Ny)';
        value = max(max(abs(drawT)*1000));
        fprintf('package, maximum noise: %.2f mV\n', value);
        figure(itefig+30);
        contourf(system.pkg.Xmesh*100, system.pkg.Ymesh*100, abs(drawT)*1000, 30, 'Linestyle','none');
        h=colorbar;
        set(get(h,'Title'),'string','Noise/(mV)','FontSize',16);
        set(gca,'FontSize',16);
        xlabel('x(cm)');
        ylabel('y(cm)');
        set(gca,'FontSize',16);                
    end
    if GIF_FLAG
    end
end

