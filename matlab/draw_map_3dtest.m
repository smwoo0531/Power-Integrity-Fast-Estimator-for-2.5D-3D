function result = draw_map(system, chip, xp, xg, t, WRITE_FLAG, DRAW_FLAG)
    x = xp + xg;
    GIF_FLAG = system.gif;
    itefig = 1;
    drawT_pack = ones(system.pkg.Ny, system.pkg.Nx)*NaN;
    Nchip = 0;
    for ii = 1:system.chip.N
        Nchip = Nchip + chip(ii).N;
    end
    result = zeros(Nchip, 2);
    Nchip = 1;
    for ii = 1:system.chip.N
        offset = 0;
        for kk = 1 : ii-1
            offset = offset + chip(kk).numV;
        end
        const = chip(ii).Nx * chip(ii).Ny;
        for k= 1 : chip(ii).N
            if (system.structure == 2) && (k== chip(ii).N)
                st = offset + 2*const*(k-1) + const + 1;
                ed = st + const - 1;
            else 
                st = offset + 2*const*(k-1) + 1;
                ed = st + const - 1;
            end
            if WRITE_FLAG
                file_name = ['./results/chip', num2str(ii), 'die', num2str(k), '.txt'];
                if t == 0
                    fid=fopen(file_name, 'w+');
                    fwrite(fid, x(st:ed), 'double');
                    fclose(fid);
                else
                    fid=fopen(file_name,'a');
                    fwrite(fid, x(st:ed), 'double');
                    fclose(fid);
                end
            end
            if DRAW_FLAG
                drawT_die = reshape(x(st:ed), chip(ii).Nx, chip(ii).Ny)';

                if k == 1
                    start = 1;
                else
                    start = sum(chip(ii).blk_num(1:k-1))+1;
                end
                if k == chip(ii).N
                    End = sum(chip(ii).blk_num(1:k));
                else
                    End = start + chip(ii).blk_num(k)-1;
                end

                map = chip(ii).map(start:End,:);
                blk_name = chip(ii).blk_name;
                index = itefig+30;  
                itefig = itefig + 1;
                [Tmax, Tmin] = DrawSteady(index, chip(ii).Xmesh, chip(ii).Ymesh, drawT_die, map, blk_name, system);

                result(Nchip, :) = [Tmax, Tmin]; Nchip = Nchip + 1;
                string = ['chip', num2str(ii), ' Die', num2str(k), ' Map'];
                title(string);
                fprintf('chip%i Die%i Max: %.2f\n', ii, k, Tmax*1e3);
                fprintf('chip%i Die%i Min: %.2f\n', ii, k, Tmin*1e3);    

                % %Trying to plot embedded dies only
                % if k == 3
                %     drawT_die = reshape(x(st:ed), chip(ii).Nx, chip(ii).Ny)';
                %     for die_count = 1:chip(1).blk_num(3)
                %         %Find in reference to the array
                %         [~, x1] = min(abs(chip(1).Xmesh - map(die_count,1)));
                %         [~,x2] = min(abs(chip(1).Xmesh - (map(die_count,1)+map(die_count,3))));
                %         [~,y1] = min(abs(chip(1).Ymesh - map(die_count,2)));
                %         [~,y2] = min(abs(chip(1).Ymesh - (map(die_count,2)+map(die_count,4))));
                %         drawT_die2 = drawT_die(y1:y2,x1:x2);
                % 
                %         index = itefig+30;  
                %         itefig = itefig + 1;
                % 
                %         hold off
                %         [Tmax, Tmin] = DrawSteady(index, chip(ii).Xmesh(x1:x2), chip(ii).Ymesh(y1:y2), drawT_die2, [map(die_count,1) map(die_count,2) map(die_count,3) map(die_count,4)], blk_name, system);
                %         string = ['Embedded Tier Die', num2str(die_count), ' Map'];
                %         title(string);
                %         fprintf('Embedded Chip Die%i Max: %.2f\n', die_count, Tmax*1e3);
                %         fprintf('Embedded Chip Die%i Min: %.2f\n', die_count, Tmin*1e3);  
                %     end
                % end

                if k == chip(ii).N
                    Chip_xl = find(abs(system.pkg.Xmesh-chip(ii).xl)<1e-5);
                    Chip_yb = find(abs(system.pkg.Ymesh-chip(ii).yb)<1e-5);
                    Chip_xr = find(abs(system.pkg.Xmesh-chip(ii).xl - chip(ii).Xsize)<1e-5);
                    Chip_yt = find(abs(system.pkg.Ymesh-chip(ii).yb - chip(ii).Ysize)<1e-5);    
                    drawT_pack(Chip_yb:Chip_yt,Chip_xl:Chip_xr) = drawT_die;
                end                
                
            end
            if GIF_FLAG
            end
        end
    end

    st = system.chip.numV+1;
    ed = st + system.pkg.Nx * system.pkg.Ny - 1;
    const = system.pkg.Nx * system.pkg.Ny ;
    file_name = './results/pkg';
    if WRITE_FLAG
        if t == 0
            fid=fopen(file_name,'w+');
            fwrite(fid, x(st:ed), 'double');
            fclose(fid);
        else
            fid=fopen(file_name,'a+');
            fwrite(fid, x(st:ed), 'double');
            fclose(fid);
        end
    end
    if DRAW_FLAG
        [accu_map, blk_name] = chip_map_stack(chip, system.chip.N);
        accu_map = [accu_map; system.connect];
        for i=1:size(system.connect, 1)
            blk_name = [blk_name; cellstr('bridge')];
        end    
        %[accu_map, blk_name] = chip_array(chip, system.chip.N);
        index = itefig+30;  
        itefig = itefig + 1;
        
        DrawSteady(index, system.pkg.Xmesh, system.pkg.Ymesh, drawT_pack, accu_map, blk_name, system);                
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
        
        for i = 1:system.chip.N
            drawT = reshape(xp(st+const : ed+const), system.pkg.Nx, system.pkg.Ny)';
            mark = floor(system.pkg.type/10) == 1 & system.pkg.domain == i;
            fprintf('number of BGAs: %d\n', sum(sum(double(mark))));
            drawT = (double(mark).*(drawT - xp(end-system.chip.N + i)))/system.BGA.R;
            value = max(max(abs(drawT)));
            fprintf('package, maximum current of BGA: %.2f A\n', value);
            fprintf('package, total current of BGA: %.2f A\n', sum(sum(drawT)));
            figure(itefig+30+i);
            imagesc(drawT);
            h=colorbar;
            set(get(h,'Title'),'string','Noise/(mV)','FontSize',16);
            set(gca,'FontSize',16);
            xlabel('x(cm)');
            ylabel('y(cm)');
            set(gca,'FontSize',16);     
        end
    end

    for i = 1:system.chip.N
        fprintf('board %d, flowing: %.2f A\n', i, xp(end-system.chip.N+i)/system.board.Rs);
        fprintf('board %d, noise: %.2f mV\n', i, x(end-system.chip.N+i)*1e3);
    end
    if GIF_FLAG
    end
end

